#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# tun_limit.sh — OpenVPN tun0 限速
#
# 硬性目标（不可突破）:
#   1) 总带宽 ≤ TOTAL_CEIL   （默认 30mbit）
#   2) 单 IP  ≤ IP_CEIL     （默认 5mbit）
#
# 实现要点:
#   - 总顶: HTB 父类 1:1 的 rate=ceil=TOTAL_CEIL，reload 只 class change，不删 root
#   - 单 IP: 子类 ceil=IP_CEIL；rate 按在线数均分且 sum(rate)≤TOTAL_CEIL
#             （若子类 rate 之和远大于父类，HTB 总顶会失效）
#   - 上传: 若 ifb 可用，在 ifb 上用同样 HTB；否则仅 per-IP police（无总顶）
# =============================================================================

DEV="tun0"
IFB_DEV="ifb-tun0"

TOTAL_RATE="30mbit"
TOTAL_CEIL="30mbit"
TOTAL_BURST="6k"

IP_CEIL="5mbit"
IP_BURST="8k"
# 单 IP 保证带宽下限（kbit）；实际 rate = min(IP_CEIL, max(IP_RATE_MIN, TOTAL/N))
IP_RATE_MIN_KBIT=8

# 默认类 minor（新建树用 2；现网旧树可能是 9999）
DEFAULT_CLASS_MINOR="2"

STATUS_FILE="/etc/openvpn/openvpn-status.log"
STATE_DIR="/var/run/tun-limit"
HASH_FILE="${STATE_DIR}/last_ips.sha256"
IPS_FILE="${STATE_DIR}/last_ips.txt"
LOCK_FILE="/var/run/tun_limit.lock"

mkdir -p "$STATE_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "已有实例在运行，跳过本次执行。"
    exit 0
fi

# ---------- 基础工具 ----------

get_client_ips() {
    [[ -f "$STATUS_FILE" ]] || {
        echo "错误: 找不到状态文件 $STATUS_FILE" >&2
        return 1
    }
    awk -F',' '
        /^ROUTING TABLE$/ {in_table=1; next}
        /^GLOBAL STATS$/  {in_table=0}
        in_table && $1 != "Virtual Address" && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $1}
    ' "$STATUS_FILE" | sort -u
}

hash_ips() {
    local ips="${1-}"
    if [[ -z "$ips" ]]; then
        echo "EMPTY"
    else
        printf '%s\n' "$ips" | sha256sum | awk '{print $1}'
    fi
}

count_lines() {
    local s="${1-}"
    [[ -z "$s" ]] && { echo 0; return; }
    printf '%s\n' "$s" | grep -c .
}

# 把 30mbit / 5mbit / 8kbit 转成 kbit 整数
to_kbit() {
    local v="${1,,}"
    local n u
    n="$(printf '%s' "$v" | tr -dc '0-9.')"
    u="$(printf '%s' "$v" | tr -d '0-9.')"
    case "$u" in
        gbit|gbps) awk -v n="$n" 'BEGIN{printf "%d", n*1000000}' ;;
        mbit|mbps) awk -v n="$n" 'BEGIN{printf "%d", n*1000}' ;;
        kbit|kbps|"") awk -v n="$n" 'BEGIN{printf "%d", n}' ;;
        bit|bps) awk -v n="$n" 'BEGIN{printf "%d", n/1000}' ;;
        *) echo "错误: 无法解析速率 $1" >&2; return 1 ;;
    esac
}

# 按在线数计算单 IP 的 HTB rate（kbit），保证 sum(rate) ≤ TOTAL
calc_ip_rate_kbit() {
    local n="$1"
    local total_kbit ip_ceil_kbit per
    total_kbit="$(to_kbit "$TOTAL_CEIL")"
    ip_ceil_kbit="$(to_kbit "$IP_CEIL")"
    if [[ "$n" -le 0 ]]; then
        echo "$IP_RATE_MIN_KBIT"
        return
    fi
    per=$((total_kbit / n))
    (( per < IP_RATE_MIN_KBIT )) && per="$IP_RATE_MIN_KBIT"
    (( per > ip_ceil_kbit )) && per="$ip_ceil_kbit"
    # 再夹一次：N*per 不得超过 total（整除误差时 per 已 OK；min 抬升后可能超）
    if (( n * per > total_kbit )); then
        per=$((total_kbit / n))
        (( per < 1 )) && per=1
    fi
    echo "$per"
}

minor_equals() {
    local shown="${1,,}"
    local want_dec="$2"
    local want_hex
    want_hex="$(printf '%x' "$want_dec")"
    [[ "$shown" == "$want_dec" || "$shown" == "$want_hex" ]]
}

is_preserved_minor() {
    local shown="$1"
    minor_equals "$shown" 1 \
        || minor_equals "$shown" "$DEFAULT_CLASS_MINOR" \
        || minor_equals "$shown" 9999
}

list_htb_minors() {
    local dev="$1"
    tc class show dev "$dev" 2>/dev/null | awk '
        tolower($1) == "class" && tolower($2) == "htb" {
            split($3, a, ":")
            if (a[1] == "1" && a[2] != "") print a[2]
        }
    '
}

has_class_minor() {
    local dev="$1"
    local want_dec="$2"
    local minor
    while read -r minor; do
        [[ -z "$minor" ]] && continue
        if minor_equals "$minor" "$want_dec"; then
            return 0
        fi
    done < <(list_htb_minors "$dev")
    return 1
}

has_htb_root() {
    local dev="$1"
    tc qdisc show dev "$dev" 2>/dev/null | grep -qi 'qdisc htb'
}

has_any_root() {
    local dev="$1"
    tc qdisc show dev "$dev" 2>/dev/null | grep -qE '[[:space:]]root([[:space:]]|$)'
}

get_htb_default_raw() {
    local dev="$1"
    tc qdisc show dev "$dev" 2>/dev/null | awk '
        tolower($2) == "htb" {
            for (i = 1; i <= NF; i++) {
                if ($i == "default") {
                    raw = $(i + 1)
                    gsub(/^0[xX]/, "", raw)
                    print raw
                    exit
                }
            }
        }
    '
}

class_change_or_add() {
    local dev="$1" parent="$2" classid="$3" rate="$4" ceil="$5" burst="$6"
    if tc class change dev "$dev" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500 2>/dev/null; then
        return 0
    fi
    if tc class add dev "$dev" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500 2>/dev/null; then
        return 0
    fi
    tc class change dev "$dev" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500
}

# 确认 class 行里的 rate/ceil 数值（Mbit）不超过期望 mbit
# 解析 "rate 30Mbit ceil 30Mbit" / "rate 8Kbit"
class_rate_ceil_ok() {
    local line="$1"
    local max_mbit="$2"
    local rate_s ceil_s rate_k ceil_k max_k
    rate_s="$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if($i=="rate"){print $(i+1); exit}}')"
    ceil_s="$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if($i=="ceil"){print $(i+1); exit}}')"
    [[ -n "$rate_s" && -n "$ceil_s" ]] || return 1
    rate_k="$(to_kbit "$rate_s")"
    ceil_k="$(to_kbit "$ceil_s")"
    max_k="$(to_kbit "${max_mbit}")"
    (( ceil_k <= max_k + 1 )) && (( rate_k <= max_k + 1 ))
}

# ---------- 下载（tun0 egress = 服务端→客户端）----------

ensure_total_cap() {
    local dev="$1"
    local def_raw
    def_raw="$(get_htb_default_raw "$dev" || true)"
    [[ -n "$def_raw" ]] || def_raw="$DEFAULT_CLASS_MINOR"

    echo "[$dev] 同步总带宽硬顶 ${TOTAL_CEIL}（class change，不删 qdisc） default=1:${def_raw}"

    # 父类：总带宽硬顶
    class_change_or_add "$dev" "1:" "1:1" "$TOTAL_RATE" "$TOTAL_CEIL" "$TOTAL_BURST"

    # HTB default 指向的类
    if [[ "$def_raw" != "1" ]]; then
        class_change_or_add "$dev" "1:1" "1:${def_raw}" "$TOTAL_RATE" "$TOTAL_CEIL" "$TOTAL_BURST"
        tc qdisc add dev "$dev" parent "1:${def_raw}" handle "${def_raw}:" sfq perturb 10 2>/dev/null || true
    fi

    # 兼容旧 1:9999 / 新 1:2
    if has_class_minor "$dev" 9999; then
        class_change_or_add "$dev" "1:1" "1:9999" "$TOTAL_RATE" "$TOTAL_CEIL" "$TOTAL_BURST"
    fi
    if [[ "$def_raw" != "$DEFAULT_CLASS_MINOR" ]]; then
        class_change_or_add "$dev" "1:1" "1:${DEFAULT_CLASS_MINOR}" "$TOTAL_RATE" "$TOTAL_CEIL" "$TOTAL_BURST"
        tc qdisc add dev "$dev" parent "1:${DEFAULT_CLASS_MINOR}" handle "${DEFAULT_CLASS_MINOR}:" sfq perturb 10 2>/dev/null || true
    fi
}

init_htb_tree() {
    local dev="$1"
    echo "[$dev] 初始化 HTB：总顶 ${TOTAL_CEIL}，default 1:${DEFAULT_CLASS_MINOR}"
    if has_any_root "$dev"; then
        tc qdisc replace dev "$dev" root handle 1: htb default "$DEFAULT_CLASS_MINOR"
    else
        tc qdisc add dev "$dev" root handle 1: htb default "$DEFAULT_CLASS_MINOR"
    fi
    tc class add dev "$dev" parent 1: classid 1:1 htb \
        rate "$TOTAL_RATE" ceil "$TOTAL_CEIL" burst "$TOTAL_BURST" cburst "$TOTAL_BURST" quantum 1500
    tc class add dev "$dev" parent 1:1 classid "1:${DEFAULT_CLASS_MINOR}" htb \
        rate "$TOTAL_RATE" ceil "$TOTAL_CEIL" burst "$TOTAL_BURST" cburst "$TOTAL_BURST" quantum 1500
    tc qdisc add dev "$dev" parent "1:${DEFAULT_CLASS_MINOR}" handle "${DEFAULT_CLASS_MINOR}:" sfq perturb 10
}

ensure_download_base() {
    if has_htb_root "$DEV"; then
        ensure_total_cap "$DEV"
    else
        init_htb_tree "$DEV"
    fi
}

clear_client_classes_filters() {
    local dev="$1"
    local minor

    while tc filter del dev "$dev" parent 1: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$dev" parent 1: prio 1 2>/dev/null; do :; done

    while read -r minor; do
        [[ -z "$minor" ]] && continue
        if is_preserved_minor "$minor"; then
            continue
        fi
        tc qdisc del dev "$dev" parent "1:${minor}" 2>/dev/null || true
        tc class del dev "$dev" classid "1:${minor}" 2>/dev/null || true
    done < <(list_htb_minors "$dev")

    ensure_total_cap "$dev"
}

setup_client_download() {
    local ips="${1-}"
    local n per_kbit class_minor=10 count=0
    n="$(count_lines "$ips")"
    per_kbit="$(calc_ip_rate_kbit "$n")"

    echo "[$DEV] 单IP限速: ceil=${IP_CEIL}, rate=${per_kbit}kbit (N=${n}, 总顶 ${TOTAL_CEIL})"

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc class add dev "$DEV" parent 1:1 classid 1:"$class_minor" htb \
                rate "${per_kbit}kbit" ceil "$IP_CEIL" burst "$IP_BURST" cburst "$IP_BURST" quantum 1500
            tc qdisc add dev "$DEV" parent 1:"$class_minor" handle "${class_minor}0": sfq perturb 10
            tc filter add dev "$DEV" parent 1: protocol ip prio 1 u32 \
                match ip dst "$ip"/32 flowid 1:"$class_minor"
            class_minor=$((class_minor + 1))
            count=$((count + 1))
        done <<< "$ips"
    fi
    echo "[$DEV] 下载客户端规则: ${count} 个IP"
}

# ---------- 上传（客户端→服务端）----------

clear_ingress_filters() {
    while tc filter del dev "$DEV" parent ffff: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent ffff: prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent ffff: protocol all prio 1 2>/dev/null; do :; done
}

setup_ifb() {
    modprobe ifb 2>/dev/null || true
    if ! ip link show "$IFB_DEV" &>/dev/null; then
        ip link add "$IFB_DEV" type ifb 2>/dev/null || return 1
    fi
    ip link set "$IFB_DEV" up || return 1

    # tun0 ingress -> ifb
    if ! tc qdisc show dev "$DEV" 2>/dev/null | grep -qi 'qdisc ingress'; then
        tc qdisc add dev "$DEV" handle ffff: ingress
    fi
    # 清掉旧 redirect 后重加
    clear_ingress_filters
    tc filter add dev "$DEV" parent ffff: protocol all prio 1 u32 \
        match u32 0 0 action mirred egress redirect dev "$IFB_DEV"
}

setup_client_upload_ifb() {
    local ips="${1-}"
    local n per_kbit class_minor=10 count=0
    n="$(count_lines "$ips")"
    per_kbit="$(calc_ip_rate_kbit "$n")"

    if has_htb_root "$IFB_DEV"; then
        ensure_total_cap "$IFB_DEV"
    else
        # ifb 可安全 replace（不影响 tun0 总顶空窗；上传侧重建可接受）
        tc qdisc del dev "$IFB_DEV" root 2>/dev/null || true
        init_htb_tree "$IFB_DEV"
    fi

    clear_client_classes_filters "$IFB_DEV"

    echo "[$IFB_DEV] 上传单IP: ceil=${IP_CEIL}, rate=${per_kbit}kbit (总顶 ${TOTAL_CEIL})"
    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            # ifb 上看到的是入站包，源地址为客户端虚拟 IP
            tc class add dev "$IFB_DEV" parent 1:1 classid 1:"$class_minor" htb \
                rate "${per_kbit}kbit" ceil "$IP_CEIL" burst "$IP_BURST" cburst "$IP_BURST" quantum 1500
            tc qdisc add dev "$IFB_DEV" parent 1:"$class_minor" handle "${class_minor}0": sfq perturb 10
            tc filter add dev "$IFB_DEV" parent 1: protocol ip prio 1 u32 \
                match ip src "$ip"/32 flowid 1:"$class_minor"
            class_minor=$((class_minor + 1))
            count=$((count + 1))
        done <<< "$ips"
    fi
    echo "[$IFB_DEV] 上传客户端规则: ${count} 个IP"
}

setup_client_upload_police_fallback() {
    local ips="${1-}"
    local count=0
    echo "警告: ifb 不可用，上传仅 per-IP police ${IP_CEIL}（无 ${TOTAL_CEIL} 总顶）" >&2

    if ! tc qdisc show dev "$DEV" 2>/dev/null | grep -qi 'qdisc ingress'; then
        tc qdisc add dev "$DEV" handle ffff: ingress 2>/dev/null || true
    fi
    clear_ingress_filters

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc filter add dev "$DEV" parent ffff: protocol ip prio 1 u32 \
                match ip src "$ip"/32 \
                police rate "$IP_CEIL" burst "$IP_BURST" drop flowid :1
            count=$((count + 1))
        done <<< "$ips"
    fi
    echo "[$DEV] 上传 police: ${count} 个IP"
}

setup_upload() {
    local ips="${1-}"
    if setup_ifb; then
        setup_client_upload_ifb "$ips"
    else
        setup_client_upload_police_fallback "$ips"
    fi
}

# ---------- 校验 ----------

verify_caps() {
    local ok=1 line

    echo "=== 校验总顶 / 单IP顶 ==="
    line="$(tc class show dev "$DEV" 2>/dev/null | awk '/class htb 1:1 /{print; exit}')"
    if [[ -z "$line" ]]; then
        echo "FAIL: 缺少 $DEV class 1:1" >&2
        ok=0
    elif class_rate_ceil_ok "$line" "$TOTAL_CEIL"; then
        echo "OK  下载总顶: $line"
    else
        echo "FAIL: 下载总顶不是 ≤${TOTAL_CEIL}: $line" >&2
        ok=0
    fi

    # 抽查一个客户端 class（若有）
    line="$(tc class show dev "$DEV" 2>/dev/null | awk '
        /class htb 1:/ && !/class htb 1:1 / && !/class htb 1:2 / && !/class htb 1:9999 / {print; exit}
    ')"
    if [[ -n "$line" ]]; then
        if class_rate_ceil_ok "$line" "$IP_CEIL"; then
            echo "OK  单IP样例: $line"
        else
            echo "FAIL: 单IP ceil 超过 ${IP_CEIL}: $line" >&2
            ok=0
        fi
    fi

    if has_htb_root "$IFB_DEV" 2>/dev/null; then
        line="$(tc class show dev "$IFB_DEV" 2>/dev/null | awk '/class htb 1:1 /{print; exit}')"
        if [[ -n "$line" ]] && class_rate_ceil_ok "$line" "$TOTAL_CEIL"; then
            echo "OK  上传总顶: $line"
        elif [[ -n "$line" ]]; then
            echo "FAIL: 上传总顶不是 ≤${TOTAL_CEIL}: $line" >&2
            ok=0
        fi
    fi

    (( ok == 1 ))
}

# ---------- 主流程 ----------

cleanup_all() {
    tc qdisc del dev "$DEV" root 2>/dev/null || true
    tc qdisc del dev "$DEV" ingress 2>/dev/null || true
    tc qdisc del dev "$IFB_DEV" root 2>/dev/null || true
    ip link del "$IFB_DEV" 2>/dev/null || true
}

apply_limits() {
    local ips="${1-}"

    echo "目标: 总带宽≤${TOTAL_CEIL}，单IP≤${IP_CEIL}"

    ensure_download_base
    clear_client_classes_filters "$DEV"
    setup_client_download "$ips"
    setup_upload "$ips"

    # 最后再压一次总顶，防止清理过程中被干扰
    ensure_total_cap "$DEV"
    has_htb_root "$IFB_DEV" 2>/dev/null && ensure_total_cap "$IFB_DEV"

    verify_caps
}

reload_if_needed() {
    local force="${1:-0}"
    local ips new_hash old_hash=""

    ips="$(get_client_ips)"
    new_hash="$(hash_ips "$ips")"
    [[ -f "$HASH_FILE" ]] && old_hash="$(<"$HASH_FILE")"

    if [[ "$force" != "1" && "$new_hash" == "$old_hash" ]]; then
        ensure_download_base
        has_htb_root "$IFB_DEV" 2>/dev/null && ensure_total_cap "$IFB_DEV"
        verify_caps || true
        echo "在线IP集合未变化，已同步总顶 ${TOTAL_CEIL}。"
        exit 0
    fi

    echo "刷新限速规则..."
    apply_limits "$ips"

    printf '%s\n' "$new_hash" > "$HASH_FILE"
    printf '%s\n' "$ips" > "$IPS_FILE"
    echo "完成。在线IP: $(count_lines "$ips")"
}

show_status() {
    echo "=== $DEV qdisc (head) ==="
    tc -s qdisc show dev "$DEV" 2>/dev/null | head -n 8 || true
    echo
    echo "=== $DEV 总顶/默认类 ==="
    tc class show dev "$DEV" 2>/dev/null | awk '
        /class htb 1:1 / || /class htb 1:2 / || /class htb 1:9999 / {print}
    ' || true
    echo
    echo "=== $DEV 客户端 class 数 ==="
    tc class show dev "$DEV" 2>/dev/null | grep -c 'class htb' || true
    if ip link show "$IFB_DEV" &>/dev/null; then
        echo
        echo "=== $IFB_DEV 总顶 ==="
        tc class show dev "$IFB_DEV" 2>/dev/null | awk '
            /class htb 1:1 / || /class htb 1:2 / || /class htb 1:9999 / {print}
        ' || true
    fi
    echo
    echo "=== last ips ==="
    [[ -f "$IPS_FILE" ]] && wc -l < "$IPS_FILE" || echo 0
}

usage() {
    cat <<EOF
用法: $0 {start|reload|force-reload|stop|status|ips|help}

硬性目标:
  总带宽 ≤ ${TOTAL_CEIL}
  单 IP  ≤ ${IP_CEIL}

reload 不会删除 tun0 上的 HTB root（避免总顶空窗）。
EOF
}

case "${1:-}" in
    start|reload|enable) reload_if_needed 0 ;;
    force-reload)        reload_if_needed 1 ;;
    stop|disable|clean)
        cleanup_all
        rm -f "$HASH_FILE" "$IPS_FILE"
        echo "已清除所有限速规则。"
        ;;
    status|show) show_status ;;
    ips) get_client_ips ;;
    help|--help|-h) usage ;;
    *)
        echo "错误: 无效参数" >&2
        usage
        exit 1
        ;;
esac
