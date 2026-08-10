#!/usr/bin/env bash
set -euo pipefail

# ===== 配置区 =====
DEV="tun0"
RATE="5mbit"
CEIL="5mbit"
BURST="64k"

DEFAULT_RATE="30mbit"
DEFAULT_CEIL="30mbit"
# 默认类 burst 宜小，避免短时冲高（nload Max 虚高）
DEFAULT_BURST="16k"

STATUS_FILE="/etc/openvpn/openvpn-status.log"

# 状态与锁文件
STATE_DIR="/var/run/tun-limit"
HASH_FILE="${STATE_DIR}/last_ips.sha256"
IPS_FILE="${STATE_DIR}/last_ips.txt"
LOCK_FILE="/var/run/tun_limit.lock"

mkdir -p "$STATE_DIR"

# 防并发：避免 cron 重叠执行
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

# tc 可能把 minor 显示成十进制（9999）或十六进制（270f）
# 注意：不能把 "9999" 当十六进制解析（0x9999=39321）
minor_equals() {
    local shown="${1,,}"
    local want_dec="$2"
    local want_hex
    want_hex="$(printf '%x' "$want_dec")"

    # 十进制原文
    if [[ "$shown" == "$want_dec" ]]; then
        return 0
    fi
    # 十六进制原文（无 0x 前缀）
    if [[ "$shown" == "$want_hex" ]]; then
        return 0
    fi
    return 1
}

is_preserved_minor() {
    local shown="$1"
    minor_equals "$shown" 1 || minor_equals "$shown" 9999
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

# 完全清除（仅 stop 使用）。reload 绝不能走这条路径，
# 否则删除 DEFAULT_RATE/DEFAULT_CEIL 窗口内总带宽会失控。
cleanup_tc() {
    tc qdisc del dev "$DEV" root 2>/dev/null || true
    tc qdisc del dev "$DEV" ingress 2>/dev/null || true
}

# 是否已有本脚本的 HTB root（handle 1:）
has_our_htb_root() {
    tc qdisc show dev "$DEV" 2>/dev/null \
        | grep -qiE 'qdisc[[:space:]]+htb[[:space:]]+1:([0-9a-fA-F]*)[[:space:]]+root'
}

has_any_root_qdisc() {
    tc qdisc show dev "$DEV" 2>/dev/null | grep -qE '[[:space:]]root([[:space:]]|$)'
}

# 原地 add/change 默认类速率，绝不 del（避免总带宽空窗）
ensure_default_classes() {
    echo "同步默认带宽：parent/default = $DEFAULT_RATE/$DEFAULT_CEIL（原地 change，不删除）"

    if has_class_minor 1; then
        tc class change dev "$DEV" parent 1: classid 1:1 htb \
            rate "$DEFAULT_CEIL" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
    else
        tc class add dev "$DEV" parent 1: classid 1:1 htb \
            rate "$DEFAULT_CEIL" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
    fi

    if has_class_minor 9999; then
        tc class change dev "$DEV" parent 1:1 classid 1:9999 htb \
            rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
    else
        # 已存在时 add 会 File exists；兼容检测边界情况
        if ! tc class add dev "$DEV" parent 1:1 classid 1:9999 htb \
            rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST" 2>/dev/null; then
            tc class change dev "$DEV" parent 1:1 classid 1:9999 htb \
                rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
        fi
        tc qdisc add dev "$DEV" parent 1:9999 handle 9999: sfq perturb 10 2>/dev/null || true
    fi

    # 确认默认类仍在：若被误删，未分类流量会走 direct，总带宽会失控
    if ! has_class_minor 1 || ! has_class_minor 9999; then
        echo "错误: 默认 class 1:1 / 1:9999 不完整，当前 class 如下：" >&2
        tc class show dev "$DEV" >&2 || true
        return 1
    fi
}

ensure_download_base() {
    if has_our_htb_root; then
        ensure_default_classes
        return 0
    fi

    echo "初始化下载默认带宽：rate=$DEFAULT_RATE ceil=$DEFAULT_CEIL"
    # 内核常预挂 fq_codel 等，add 会报 Exclusivity；仅首次用 replace
    if has_any_root_qdisc; then
        tc qdisc replace dev "$DEV" root handle 1: htb default 9999
    else
        tc qdisc add dev "$DEV" root handle 1: htb default 9999
    fi
    tc class add dev "$DEV" parent 1: classid 1:1 htb \
        rate "$DEFAULT_CEIL" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
    tc class add dev "$DEV" parent 1:1 classid 1:9999 htb \
        rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL" burst "$DEFAULT_BURST" cburst "$DEFAULT_BURST"
    tc qdisc add dev "$DEV" parent 1:9999 handle 9999: sfq perturb 10
}

ensure_upload_base() {
    if tc qdisc show dev "$DEV" 2>/dev/null | grep -qiE 'qdisc[[:space:]]+ingress'; then
        return 0
    fi

    echo "初始化上传 ingress qdisc"
    if ! tc qdisc add dev "$DEV" handle ffff: ingress 2>/dev/null; then
        echo "警告: 无法添加 ingress（可能已存在或不受支持），跳过" >&2
        tc qdisc show dev "$DEV" >&2 || true
    fi
}

# 只清客户端下载 class/filter，保留 1:1 / 1:9999
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

    # 清完客户端后再次确认默认类仍在
    if ! has_class_minor 1 || ! has_class_minor 9999; then
        echo "警告: 清理客户端后默认类缺失，正在补回..." >&2
        ensure_default_classes
    fi
}

clear_client_upload_rules() {
    while tc filter del dev "$DEV" parent ffff: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent ffff: prio 1 2>/dev/null; do :; done
}

setup_client_download_limits() {
    local ips="${1-}"
    local class_minor=10
    local count=0

    echo "配置下载限速（服务端 -> 客户端）..."

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc class add dev "$DEV" parent 1:1 classid 1:"$class_minor" htb \
                rate "$RATE" ceil "$CEIL" burst "$BURST"
            tc qdisc add dev "$DEV" parent 1:"$class_minor" handle "${class_minor}0": sfq perturb 10
            tc filter add dev "$DEV" parent 1: protocol ip prio 1 u32 \
                match ip dst "$ip"/32 flowid 1:"$class_minor"
            class_minor=$((class_minor + 1))
            count=$((count + 1))
        done <<< "$ips"
    fi

    echo "下载限速完成：$count 个IP，每个 $RATE（默认类未删除）"
}

setup_client_upload_limits() {
    local ips="${1-}"
    local count=0

    echo "配置上传限速（客户端 -> 服务端）..."

    if [[ -n "$ips" ]]; then
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            tc filter add dev "$DEV" parent ffff: protocol ip prio 1 u32 \
                match ip src "$ip"/32 \
                police rate "$RATE" burst "$BURST" drop flowid :1
            count=$((count + 1))
        done <<< "$ips"
    fi

    echo "上传限速完成：$count 个IP，每个 $RATE（ingress 未重建）"
}

apply_limits() {
    local ips="${1-}"
    ensure_download_base
    ensure_upload_base
    clear_client_download_rules
    clear_client_upload_rules
    setup_client_download_limits "$ips"
    setup_client_upload_limits "$ips"
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
        # IP 未变也同步默认速率，并确保默认类在
        ensure_download_base
        ensure_upload_base
        echo "在线IP集合未变化，已同步默认带宽，跳过客户端规则重载。"
        exit 0
    fi

    echo "检测到IP集合变化，刷新客户端限速（保留并同步默认 $DEFAULT_RATE/$DEFAULT_CEIL）..."
    apply_limits "$ips"

    printf '%s\n' "$new_hash" > "$HASH_FILE"
    printf '%s\n' "$ips" > "$IPS_FILE"

    local ip_count=0
    [[ -n "$ips" ]] && ip_count="$(printf '%s\n' "$ips" | wc -l)"
    echo "重载完成。当前在线IP: $ip_count"
}

show_status() {
    echo "=== qdisc ==="
    tc qdisc show dev "$DEV" || true
    echo
    echo "=== class ==="
    tc class show dev "$DEV" || true
    echo
    echo "=== filter(root 1:) ==="
    tc filter show dev "$DEV" parent 1: || true
    echo
    echo "=== filter(ingress ffff:) ==="
    tc filter show dev "$DEV" parent ffff: || true
    echo
    echo "=== last ips ==="
    [[ -f "$IPS_FILE" ]] && cat "$IPS_FILE" || echo "(empty)"
}

usage() {
    cat <<EOF
用法: $0 {start|reload|force-reload|stop|status|ips|help}
  start/reload   IP 变化时刷新客户端限速；默认带宽原地 change，不删除
  force-reload   强制刷新客户端限速（仍保留并同步 DEFAULT_*）
  stop           清除所有限速规则（含默认带宽）
  status         查看当前tc状态
  ips            查看当前在线IP
  help           显示帮助

说明:
  默认总带宽由 class 1:1 / 1:9999 控制，reload 只用 change 同步速率，
  避免 del/add 空窗导致总带宽突破。
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
