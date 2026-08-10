#!/usr/bin/env bash
set -euo pipefail

# ===== 配置区 =====
DEV="tun0"
RATE="5mbit"
CEIL="5mbit"
BURST="64k"

DEFAULT_RATE="30mbit"
DEFAULT_CEIL="30mbit"

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

# 完全清除（仅 stop 使用）。reload 绝不能走这条路径，
# 否则删除 DEFAULT_RATE/DEFAULT_CEIL 窗口内总带宽会失控。
cleanup_tc() {
    tc qdisc del dev "$DEV" root 2>/dev/null || true
    tc qdisc del dev "$DEV" ingress 2>/dev/null || true
}

# 确保下载侧根 HTB + 默认类存在；已存在则原样保留，不删不重建。
ensure_download_base() {
    if tc qdisc show dev "$DEV" 2>/dev/null | grep -qE '^qdisc htb 1:'; then
        return 0
    fi

    echo "初始化下载默认带宽：rate=$DEFAULT_RATE ceil=$DEFAULT_CEIL"
    tc qdisc add dev "$DEV" root handle 1: htb default 9999
    tc class add dev "$DEV" parent 1: classid 1:1 htb rate "$DEFAULT_CEIL" ceil "$DEFAULT_CEIL"
    tc class add dev "$DEV" parent 1:1 classid 1:9999 htb rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL"
    tc qdisc add dev "$DEV" parent 1:9999 handle 9999: sfq perturb 10
}

# 确保 ingress qdisc 存在；已存在则保留。
ensure_upload_base() {
    if tc qdisc show dev "$DEV" 2>/dev/null | grep -qE '^qdisc ingress ffff:'; then
        return 0
    fi

    echo "初始化上传 ingress qdisc"
    tc qdisc add dev "$DEV" handle ffff: ingress
}

# 只清客户端下载 class/filter，保留 1: / 1:1 / 1:9999 默认带宽。
clear_client_download_rules() {
    local minor

    # 先删 filter，避免仍指向即将删除的 class
    while tc filter del dev "$DEV" parent 1: protocol ip prio 1 2>/dev/null; do :; done
    while tc filter del dev "$DEV" parent 1: prio 1 2>/dev/null; do :; done

    # 删除非默认 leaf class（保留 1:1 与 1:9999）
    while read -r minor; do
        [[ -z "$minor" ]] && continue
        [[ "$minor" == "1" || "$minor" == "9999" ]] && continue
        tc qdisc del dev "$DEV" parent "1:${minor}" 2>/dev/null || true
        tc class del dev "$DEV" classid "1:${minor}" 2>/dev/null || true
    done < <(tc class show dev "$DEV" 2>/dev/null | awk '
        /class htb 1:/ {
            split($3, a, ":")
            if (a[2] != "" && a[2] != "1" && a[2] != "9999") print a[2]
        }
    ')
}

# 只清客户端上传 police filter，保留 ingress qdisc。
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
            tc class add dev "$DEV" parent 1:1 classid 1:"$class_minor" htb rate "$RATE" ceil "$CEIL" burst "$BURST"
            tc qdisc add dev "$DEV" parent 1:"$class_minor" handle "${class_minor}0": sfq perturb 10
            tc filter add dev "$DEV" parent 1: protocol ip prio 1 u32 \
                match ip dst "$ip"/32 flowid 1:"$class_minor"
            class_minor=$((class_minor + 1))
            count=$((count + 1))
        done <<< "$ips"
    fi

    echo "下载限速完成：$count 个IP，每个 $RATE（默认类未重建）"
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

# reload/start：保留 DEFAULT_* 根限速，只刷新客户端规则
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
        # 即使 IP 未变，也确保默认带宽还在（例如有人误删了 qdisc）
        ensure_download_base
        ensure_upload_base
        echo "在线IP集合未变化，跳过客户端规则重载。"
        exit 0
    fi

    echo "检测到IP集合变化，刷新客户端限速（保留默认 $DEFAULT_RATE/$DEFAULT_CEIL）..."
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
  start/reload   仅当在线IP集合变化时刷新客户端限速；默认带宽类不删除重建
  force-reload   强制刷新客户端限速（仍保留 DEFAULT_RATE/DEFAULT_CEIL）
  stop           清除所有限速规则（含默认带宽）
  status         查看当前tc状态
  ips            查看当前在线IP
  help           显示帮助

说明:
  reload 不会执行 tc qdisc del root/ingress，避免 DEFAULT_RATE/DEFAULT_CEIL
  被删掉重建时出现总带宽突破。若需重建整棵树，请先 stop 再 start。
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
