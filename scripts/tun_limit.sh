#!/usr/bin/env bash
set -euo pipefail

# ===== 配置区 =====
DEV="tun0"

# 每客户端上限（ceil）；rate 必须很小，否则上百客户端时
# sum(child rate) >> parent rate，HTB 父类总带宽会失效并突破。
RATE="8kbit"
CEIL="5mbit"
BURST="16k"

# 出口总带宽硬顶（class 1:1）
DEFAULT_RATE="30mbit"
DEFAULT_CEIL="30mbit"
DEFAULT_BURST="8k"

# 默认类用 1:2，避免 default 9999 被 tc 当成 0x9999 指空类（走 direct）
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

minor_equals() {
    local shown="${1,,}"
    local want_dec="$2"
    local want_hex
    want_hex="$(printf '%x' "$want_dec")"
    [[ "$shown" == "$want_dec" || "$shown" == "$want_hex" ]]
}

is_preserved_minor() {
    local shown="$1"
    minor_equals "$shown" 1 || minor_equals "$shown" "$DEFAULT_CLASS_MINOR" || minor_equals "$shown" 9999
}

list_htb_minors() {
    tc class show dev "$DEV" 2>/dev/null | awk '
        tolower($1) == "class" && tolower($2) == "htb" {
            split($3, a, ":")
            if (a[1] == "1" && a[2] != "") print a[2]
        }
    '
}

has_class_minor() {
    local want_dec="$1"
    local minor
    while read -r minor; do
        [[ -z "$minor" ]] && continue
        if minor_equals "$minor" "$want_dec"; then
            return 0
        fi
    done < <(list_htb_minors)
    return 1
}

cleanup_tc() {
    tc qdisc del dev "$DEV" root 2>/dev/null || true
    tc qdisc del dev "$DEV" ingress 2>/dev/null || true
}

# 读取 HTB default 的原始 minor 字符串（去掉 0x）。
# 例: default 0x9999 -> 9999（创建/change 时用 classid 1:9999）
get_htb_default_raw() {
    tc qdisc show dev "$DEV" 2>/dev/null | awk '
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

# 只要 tun0 上已有 HTB root 就视为已初始化（勿再 qdisc replace）
has_our_htb_root() {
    tc qdisc show dev "$DEV" 2>/dev/null | grep -qi 'qdisc htb'
}

has_any_root_qdisc() {
    tc qdisc show dev "$DEV" 2>/dev/null | grep -qE '[[:space:]]root([[:space:]]|$)'
}

class_change_or_add() {
    local parent="$1"
    local classid="$2"
    local rate="$3"
    local ceil="$4"
    local burst="$5"

    if tc class change dev "$DEV" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500 2>/dev/null; then
        return 0
    fi
    if tc class add dev "$DEV" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500 2>/dev/null; then
        return 0
    fi
    # 最后再试一次 change（add 因 File exists 失败时）
    tc class change dev "$DEV" parent "$parent" classid "$classid" htb \
        rate "$rate" ceil "$ceil" burst "$burst" cburst "$burst" quantum 1500
}

# 原地同步总带宽；绝不 qdisc del/replace（避免空窗突破）
ensure_default_classes() {
    local def_raw
    def_raw="$(get_htb_default_raw || true)"
    [[ -n "$def_raw" ]] || def_raw="$DEFAULT_CLASS_MINOR"

    echo "同步总带宽硬顶：$DEFAULT_CEIL（原地 class change，不删除 qdisc）"
    echo "当前 HTB default -> classid 1:${def_raw}"

    # 父类 1:1：总出口硬顶
    class_change_or_add "1:" "1:1" "$DEFAULT_CEIL" "$DEFAULT_CEIL" "$DEFAULT_BURST"

    # 改 HTB 正在使用的 default class（现网是 1:9999 / default 0x9999）
    if [[ "$def_raw" != "1" ]]; then
        class_change_or_add "1:1" "1:${def_raw}" "$DEFAULT_RATE" "$DEFAULT_CEIL" "$DEFAULT_BURST"
        tc qdisc add dev "$DEV" parent "1:${def_raw}" handle "${def_raw}:" sfq perturb 10 2>/dev/null || true
    fi

    # 兼容：显式再压一次常见默认类
    if has_class_minor 9999; then
        class_change_or_add "1:1" "1:9999" "$DEFAULT_RATE" "$DEFAULT_CEIL" "$DEFAULT_BURST"
    fi
    if [[ "$def_raw" != "$DEFAULT_CLASS_MINOR" ]]; then
        class_change_or_add "1:1" "1:${DEFAULT_CLASS_MINOR}" "$DEFAULT_RATE" "$DEFAULT_CEIL" "$DEFAULT_BURST"
        tc qdisc add dev "$DEV" parent "1:${DEFAULT_CLASS_MINOR}" handle "${DEFAULT_CLASS_MINOR}:" sfq perturb 10 2>/dev/null || true
    fi

    if ! has_class_minor 1; then
        echo "错误: class 1:1 不存在" >&2
        tc class show dev "$DEV" >&2 || true
        return 1
    fi

    # 打印关键 class，便于确认已从 40Mbit 降到 30Mbit
    tc class show dev "$DEV" | awk '
        /class htb 1:1 / || /class htb 1:2 / || /class htb 1:9999 / {print}
    ' || true

    local direct
    direct="$(tc -s qdisc show dev "$DEV" 2>/dev/null | awk '
        /qdisc htb/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "direct_packets_stat") { print $(i + 1); exit }
            }
        }
    ')"
    if [[ -n "${direct:-}" && "$direct" =~ ^[0-9]+$ && "$direct" -gt 1000 ]]; then
        echo "警告: direct_packets_stat=$direct 较高，部分流量可能未进入 HTB class" >&2
    fi
}

ensure_download_base() {
    if has_our_htb_root; then
        ensure_default_classes
        return 0
    fi

    echo "初始化下载 HTB：总带宽 $DEFAULT_CEIL，default class 1:${DEFAULT_CLASS_MINOR}"
    if has_any_root_qdisc; then
        # 仅首次：替换 fq_codel 等；已有 HTB 时禁止走到这里
        tc qdisc replace dev "$DEV" root handle 1: htb default "$DEFAULT_CLASS_MINOR"
    else
        tc qdisc add dev "$DEV" root handle 1: htb default "$DEFAULT_CLASS_MINOR"
    fi
    tc class add dev "$DEV" parent 1: classid 1:1 htb \
        rate "$DEFAULT_CEIL" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST" quantum 1500
    tc class add dev "$DEV" parent 1:1 classid "1:${DEFAULT_CLASS_MINOR}" htb \
        rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST" quantum 1500
    tc qdisc add dev "$DEV" parent "1:${DEFAULT_CLASS_MINOR}" handle "${DEFAULT_CLASS_MINOR}:" sfq perturb 10
}

ensure_upload_base() {
    if tc qdisc show dev "$DEV" 2>/dev/null | grep -qiE 'qdisc[[:space:]]+ingress'; then
        return 0
    fi
    echo "初始化上传 ingress qdisc"
    tc qdisc add dev "$DEV" handle ffff: ingress 2>/dev/null || \
        echo "警告: 无法添加 ingress" >&2
}

clear_client_download_rules() {
    local minor

    while tc filter del dev "$DEV" parent 1: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent 1: prio 1 2>/dev/null; do :; done

    while read -r minor; do
        [[ -z "$minor" ]] && continue
        if is_preserved_minor "$minor"; then
            continue
        fi
        tc qdisc del dev "$DEV" parent "1:${minor}" 2>/dev/null || true
        tc class del dev "$DEV" classid "1:${minor}" 2>/dev/null || true
    done < <(list_htb_minors)

    # 清理后再次压一次总带宽，防止误伤
    ensure_default_classes
}

clear_client_upload_rules() {
    while tc filter del dev "$DEV" parent ffff: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent ffff: prio 1 2>/dev/null; do :; done
}

setup_client_download_limits() {
    local ips="${1-}"
    local class_minor=10
    local count=0

    echo "配置下载限速：每 IP ceil=$CEIL（rate=$RATE，避免子类 rate 之和撑破父类）..."

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc class add dev "$DEV" parent 1:1 classid 1:"$class_minor" htb \
                rate "$RATE" ceil "$CEIL" burst "$BURST" cburst "$BURST" quantum 1500
            tc qdisc add dev "$DEV" parent 1:"$class_minor" handle "${class_minor}0": sfq perturb 10
            tc filter add dev "$DEV" parent 1: protocol ip prio 1 u32 \
                match ip dst "$ip"/32 flowid 1:"$class_minor"
            class_minor=$((class_minor + 1))
            count=$((count + 1))
        done <<< "$ips"
    fi

    echo "下载限速完成：$count 个IP"
}

setup_client_upload_limits() {
    local ips="${1-}"
    local count=0

    echo "配置上传限速（police $CEIL）..."

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc filter add dev "$DEV" parent ffff: protocol ip prio 1 u32 \
                match ip src "$ip"/32 \
                police rate "$CEIL" burst "$BURST" drop flowid :1
            count=$((count + 1))
        done <<< "$ips"
    fi

    echo "上传限速完成：$count 个IP"
}

apply_limits() {
    local ips="${1-}"
    ensure_download_base
    ensure_upload_base
    clear_client_download_rules
    clear_client_upload_rules
    setup_client_download_limits "$ips"
    setup_client_upload_limits "$ips"
    echo "--- 校验 ---"
    tc class show dev "$DEV" | awk '
        /class htb 1:1 / || /class htb 1:2 / || /class htb 1:9999 / {print}
    ' || true
}

reload_if_needed() {
    local force="${1:-0}"
    local ips new_hash old_hash=""

    ips="$(get_client_ips)"
    new_hash="$(hash_ips "$ips")"

    if [[ -f "$HASH_FILE" ]]; then
        old_hash="$(<"$HASH_FILE")"
    fi

    if [[ "$force" != "1" && "$new_hash" == "$old_hash" ]]; then
        ensure_download_base
        ensure_upload_base
        echo "在线IP集合未变化，已同步总带宽 $DEFAULT_CEIL。"
        exit 0
    fi

    echo "刷新客户端限速（总带宽原地同步为 $DEFAULT_CEIL，不删 HTB root）..."
    apply_limits "$ips"

    printf '%s\n' "$new_hash" > "$HASH_FILE"
    printf '%s\n' "$ips" > "$IPS_FILE"

    local ip_count=0
    [[ -n "$ips" ]] && ip_count="$(printf '%s\n' "$ips" | wc -l)"
    echo "重载完成。当前在线IP: $ip_count"
}

show_status() {
    echo "=== qdisc ==="
    tc -s qdisc show dev "$DEV" | head -n 20 || true
    echo
    echo "=== class (parent/default) ==="
    tc class show dev "$DEV" | awk '
        /class htb 1:1 / || /class htb 1:2 / || /class htb 1:9999 / {print}
    ' || true
    echo
    echo "=== class count ==="
    tc class show dev "$DEV" 2>/dev/null | grep -c 'class htb' || true
    echo
    echo "=== filter count (egress) ==="
    tc filter show dev "$DEV" parent 1: 2>/dev/null | grep -c 'flowid' || true
    echo
    echo "=== last ips (count) ==="
    if [[ -f "$IPS_FILE" ]]; then
        wc -l < "$IPS_FILE"
    else
        echo 0
    fi
}

usage() {
    cat <<EOF
用法: $0 {start|reload|force-reload|stop|status|ips|help}

关键点:
  - 总带宽由 class 1:1 ceil=$DEFAULT_CEIL 控制；reload 只用 class change，不删 root
  - 每客户端 rate=$RATE ceil=$CEIL（rate 必须小，否则上百客户端会撑破父类）
  - 若 status 里 1:1 仍是 40Mbit，说明旧脚本未更新成功
EOF
}

case "${1:-}" in
    start|reload|enable)
        reload_if_needed 0
        ;;
    force-reload)
        reload_if_needed 1
        ;;
    stop|disable|clean)
        cleanup_tc
        rm -f "$HASH_FILE" "$IPS_FILE"
        echo "已清除所有限速规则。"
        ;;
    status|show)
        show_status
        ;;
    ips)
        get_client_ips
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "错误: 无效参数"
        usage
        exit 1
        ;;
esac
