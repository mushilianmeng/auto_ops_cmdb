#!/usr/bin/env bash
# 从 hosts 文件读取 controller01 以及所有 compute* 主机，
# 配置基于主机名的互相 SSH 免密登录（网状互信）。
#
# 用法：
#   export SSH_PASSWORD='登录密码'
#   ./scripts/setup_cluster_ssh.sh                 # 默认读 /etc/hosts
#   ./scripts/setup_cluster_ssh.sh -f scripts/cluster.hosts -u root
#   ./scripts/setup_cluster_ssh.sh --list          # 只打印将处理的主机
#
# 常用选项：
#   -f FILE        hosts 文件（默认 /etc/hosts）
#   -u USER        SSH 用户（默认 root）
#   -p PASSWORD    初始登录密码（更推荐用环境变量 SSH_PASSWORD）
#   --list         仅列出目标主机后退出
#   --no-sync-hosts  不同步集群 hosts 记录（默认会同步，否则主机名无法解析）
#   --no-verify    配置完成后不做互访探测
#   --sudo         远程写 /etc/hosts 时使用 sudo（SSH 用户非 root 时需要）

set -euo pipefail

# 若启动时没有打印这一版号，说明节点上仍是旧文件
SCRIPT_VERSION="2"

HOSTS_FILE="/etc/hosts"
SSH_USER="root"
PASSWORD="${SSH_PASSWORD:-}"
SYNC_HOSTS=1
VERIFY=1
LIST_ONLY=0
REMOTE_SUDO=0

MARKER_BEGIN="# BEGIN CLUSTER-SSH-TRUST"
MARKER_END="# END CLUSTER-SSH-TRUST"

usage() {
  cat <<'EOF'
从 hosts 读取 controller01 和所有 compute* 主机，配置基于主机名的互相 SSH 免密。

用法:
  export SSH_PASSWORD='登录密码'
  ./scripts/setup_cluster_ssh.sh
  ./scripts/setup_cluster_ssh.sh -f scripts/cluster.hosts -u root
  ./scripts/setup_cluster_ssh.sh --list

选项:
  -f FILE          hosts 文件（默认 /etc/hosts）
  -u USER          SSH 用户（默认 root）
  -p PASSWORD      初始登录密码（更推荐环境变量 SSH_PASSWORD）
  --list           仅列出目标主机后退出
  --no-sync-hosts  不同步集群 hosts 记录
  --no-verify      配置完成后不做互访探测
  --sudo           远程写 /etc/hosts 时使用 sudo
  -h, --help       显示帮助
EOF
  exit "${1:-0}"
}

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--hosts-file) HOSTS_FILE="${2:?}"; shift 2 ;;
    -u|--user)       SSH_USER="${2:?}"; shift 2 ;;
    -p|--password)   PASSWORD="${2:?}"; shift 2 ;;
    --list)          LIST_ONLY=1; shift ;;
    --no-sync-hosts) SYNC_HOSTS=0; shift ;;
    --no-verify)     VERIFY=0; shift ;;
    --sudo)          REMOTE_SUDO=1; shift ;;
    -h|--help)       usage 0 ;;
    *)               die "未知参数: $1（用 -h 查看帮助）" ;;
  esac
done

[[ -r "$HOSTS_FILE" ]] || die "无法读取 hosts 文件: $HOSTS_FILE"

log "脚本版本 ${SCRIPT_VERSION}（没有这行就是旧文件，请覆盖后再跑）"

# 解析 IP 与主机名：controller01（精确）以及 compute 开头的短主机名
parse_cluster_hosts() {
  awk '
    {
      sub(/#.*/, "")
      if (NF < 2) next
      ip = $1
      if (ip !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) next
      if (ip == "0.0.0.0" || ip ~ /^127\./) next
      for (i = 2; i <= NF; i++) {
        h = $i
        gsub(/^[ \t]+|[ \t]+$/, "", h)
        if (h == "" || h ~ /\./) continue
        if (h == "controller01" || h ~ /^compute/) {
          print ip, h
        }
      }
    }
  ' "$HOSTS_FILE"
}

mapfile -t PAIR_LINES < <(parse_cluster_hosts)

if [[ ${#PAIR_LINES[@]} -eq 0 ]]; then
  die "在 ${HOSTS_FILE} 中没有找到 controller01 或 compute* 主机"
fi

NODE_IPS=()
NODE_HOSTS=()
declare -A IP_OF=()
declare -A SEEN_HOST=()
declare -A SEEN_IP=()

for line in "${PAIR_LINES[@]}"; do
  ip="${line%% *}"
  host="${line##* }"
  if [[ -n "${SEEN_HOST[$host]:-}" && "${IP_OF[$host]}" != "$ip" ]]; then
    warn "主机名 ${host} 对应多个 IP，沿用 ${IP_OF[$host]}，忽略 ${ip}"
    continue
  fi
  if [[ -n "${SEEN_IP[$ip]:-}" ]]; then
    continue
  fi
  SEEN_HOST[$host]=1
  SEEN_IP[$ip]=1
  IP_OF[$host]="$ip"
  NODE_IPS+=("$ip")
  NODE_HOSTS+=("$host")
done

has_controller=0
compute_count=0
for host in "${NODE_HOSTS[@]}"; do
  if [[ "$host" == "controller01" ]]; then
    has_controller=1
  elif [[ "$host" == compute* ]]; then
    compute_count=$((compute_count + 1))
  fi
done

[[ $has_controller -eq 1 ]] || warn "hosts 中没有 controller01"
[[ $compute_count -gt 0 ]] || warn "hosts 中没有 compute* 主机"

log "目标节点（${#NODE_HOSTS[@]}）:"
for i in "${!NODE_HOSTS[@]}"; do
  printf '  %s\t%s\n' "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"
done

if [[ $LIST_ONLY -eq 1 ]]; then
  exit 0
fi

need_sshpass() {
  command -v sshpass >/dev/null 2>&1 || die "需要 sshpass 才能用密码做首次登录。安装：yum/dnf install sshpass  或  apt-get install sshpass"
}

ensure_password() {
  if [[ -z "$PASSWORD" ]]; then
    if [[ -t 0 ]]; then
      printf '请输入 %s 的 SSH 密码（输入不可见）: ' "$SSH_USER" >&2
      read -r -s PASSWORD
      printf '\n' >&2
    fi
  fi
  [[ -n "$PASSWORD" ]] || die "首次互信需要密码：设置 SSH_PASSWORD 或使用 -p"
  export SSHPASS="$PASSWORD"
}

SSH_BASE_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o ConnectTimeout=10
  -o LogLevel=ERROR
  -o ServerAliveInterval=5
)

can_pubkey() {
  local ip="$1"
  ssh -o BatchMode=yes "${SSH_BASE_OPTS[@]}" \
    -o PreferredAuthentications=publickey \
    "${SSH_USER}@${ip}" true >/dev/null 2>&1
}

# ssh 会把参数拼成一条命令交给远端 shell；必须先 %q，否则 # 会被当成注释。
ssh_remote() {
  local ip="$1"
  shift
  local remote
  remote=$(printf '%q ' "$@")
  if can_pubkey "$ip"; then
    ssh "${SSH_BASE_OPTS[@]}" "${SSH_USER}@${ip}" "$remote"
    return
  fi
  ensure_password
  need_sshpass
  sshpass -e ssh "${SSH_BASE_OPTS[@]}" \
    -o PreferredAuthentications=password,keyboard-interactive \
    -o PubkeyAuthentication=no \
    "${SSH_USER}@${ip}" "$remote"
}

ssh_exec() {
  ssh_remote "$@"
}

scp_put() {
  local src="$1" ip="$2" dst="$3"
  if can_pubkey "$ip"; then
    scp -q "${SSH_BASE_OPTS[@]}" "$src" "${SSH_USER}@${ip}:${dst}"
    return
  fi
  ensure_password
  need_sshpass
  sshpass -e scp -q "${SSH_BASE_OPTS[@]}" \
    -o PreferredAuthentications=password,keyboard-interactive \
    -o PubkeyAuthentication=no \
    "$src" "${SSH_USER}@${ip}:${dst}"
}

local_ips() {
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null || true
  fi
  if command -v ip >/dev/null 2>&1; then
    ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1
  fi
}

is_local_node() {
  local ip="$1" host="$2"
  local short
  short="$(hostname -s 2>/dev/null || hostname)"
  [[ "$host" == "$short" || "$host" == "$(hostname)" ]] && return 0
  local lip
  for lip in $(local_ips); do
    [[ "$lip" == "$ip" ]] && return 0
  done
  return 1
}

cluster_hosts_block() {
  printf '%s\n' "$MARKER_BEGIN"
  local i
  for i in "${!NODE_HOSTS[@]}"; do
    printf '%s\t%s\n' "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"
  done
  printf '%s\n' "$MARKER_END"
}

upsert_hosts_file() {
  local target_file="$1"
  local tmp block
  tmp="$(mktemp)"
  block="$(mktemp)"
  cluster_hosts_block >"$block"
  if [[ -f "$target_file" ]]; then
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$target_file" >"$tmp"
  else
    : >"$tmp"
  fi
  printf '\n' >>"$tmp"
  cat "$block" >>"$tmp"
  cat "$tmp" >"$target_file"
  rm -f "$tmp" "$block"
}

WORK_DIR="$(mktemp -d /tmp/cluster-ssh-trust.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/pubkeys"
ALL_PUB="$WORK_DIR/authorized_keys"
KNOWN="$WORK_DIR/known_hosts"
: >"$ALL_PUB"
: >"$KNOWN"

if [[ $SYNC_HOSTS -eq 1 ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    log "更新本机 ${HOSTS_FILE} 中的集群段"
    if [[ "$HOSTS_FILE" == "/etc/hosts" ]]; then
      upsert_hosts_file /etc/hosts
    else
      log "hosts 来源不是 /etc/hosts，把集群段写入 /etc/hosts 以便本机用主机名解析"
      upsert_hosts_file /etc/hosts
    fi
  else
    warn "当前不是 root，跳过写入本机 /etc/hosts；请确保本机已能解析这些主机名"
  fi
fi

scan_node_keys() {
  local ip="$1" host="$2" outfile="$3"
  local tmp
  tmp="$(mktemp)"
  ssh-keyscan -T 8 "$ip" 2>/dev/null | grep -v '^#' >"$tmp" || true
  if [[ ! -s "$tmp" ]]; then
    ssh-keyscan -T 8 -t rsa,ecdsa,ed25519 "$ip" 2>/dev/null | grep -v '^#' >"$tmp" || true
  fi
  if [[ -s "$tmp" ]]; then
    awk -v ip="$ip" -v host="$host" 'NF >= 3 {
      key=$2; blob=$3
      print ip, key, blob
      print host, key, blob
      print host "," ip, key, blob
    }' "$tmp" >>"$outfile"
  fi
  rm -f "$tmp"
}

log "探测各节点主机密钥（ssh-keyscan，含 ed25519）"
for i in "${!NODE_HOSTS[@]}"; do
  scan_node_keys "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}" "$KNOWN"
done
if [[ ! -s "$KNOWN" ]]; then
  warn "ssh-keyscan 没有拿到任何主机密钥，将依赖 StrictHostKeyChecking=no"
else
  sort -u "$KNOWN" -o "$KNOWN"
fi

log "在每台节点上生成密钥并收集公钥"
for i in "${!NODE_HOSTS[@]}"; do
  ip="${NODE_IPS[$i]}"
  host="${NODE_HOSTS[$i]}"
  log "  -> ${host} (${ip})"

  REMOTE_SETUP=$(cat <<'EOS'
set -euo pipefail
umask 077
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ ! -f "$HOME/.ssh/id_ed25519" && ! -f "$HOME/.ssh/id_rsa" ]]; then
  if ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -C "$(hostname -s)" >/dev/null 2>&1; then
    :
  else
    ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" -C "$(hostname -s)" >/dev/null
  fi
fi
if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  cat "$HOME/.ssh/id_ed25519.pub"
elif [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
  cat "$HOME/.ssh/id_rsa.pub"
else
  echo "NO_PUBKEY" >&2
  exit 1
fi
EOS
)

  if is_local_node "$ip" "$host"; then
    pubkey="$(bash -c "$REMOTE_SETUP")"
  else
    pubkey="$(ssh_exec "$ip" bash -s <<<"$REMOTE_SETUP")"
  fi
  [[ -n "$pubkey" && "$pubkey" != *NO_PUBKEY* ]] || die "${host} 未能得到公钥"
  printf '%s\n' "$pubkey" >>"$ALL_PUB"
done

sort -u "$ALL_PUB" -o "$ALL_PUB"
log "共收集到 $(wc -l <"$ALL_PUB" | tr -d ' ') 把公钥"

SSH_CONFIG_SNIPPET="$WORK_DIR/ssh_config_cluster"
{
  printf '%s\n' "$MARKER_BEGIN"
  printf 'Host'
  for i in "${!NODE_HOSTS[@]}"; do
    printf ' %s %s' "${NODE_HOSTS[$i]}" "${NODE_IPS[$i]}"
  done
  printf '\n'
  printf '    User %s\n' "$SSH_USER"
  cat <<'CFG'
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    HashKnownHosts no
    IgnoreUnknown UpdateHostKeys
    UpdateHostKeys no
    LogLevel ERROR
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
CFG
  printf '%s\n' "$MARKER_END"
} >"$SSH_CONFIG_SNIPPET"

HOSTS_BLOCK_FILE="$WORK_DIR/hosts.block"
cluster_hosts_block >"$HOSTS_BLOCK_FILE"

INSTALL_TAG="$$"
KEYSCAN_TARGETS="$WORK_DIR/keyscan.targets"
{
  for i in "${!NODE_HOSTS[@]}"; do
    printf '%s\n' "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"
  done
} >"$KEYSCAN_TARGETS"

merge_marker_file() {
  local src="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$dest"
  fi
  cat "$src"
}

refresh_local_known_hosts() {
  local i
  for i in "${!NODE_HOSTS[@]}"; do
    scan_node_keys "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}" "$HOME/.ssh/known_hosts"
  done
  sort -u "$HOME/.ssh/known_hosts" -o "$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"
}

apply_trust_local() {
  umask 077
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/authorized_keys" "$HOME/.ssh/known_hosts" "$HOME/.ssh/config"
  cat "$ALL_PUB" "$HOME/.ssh/authorized_keys" | sort -u >"$WORK_DIR/ak.local"
  cat "$WORK_DIR/ak.local" >"$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
  cat "$KNOWN" "$HOME/.ssh/known_hosts" | sort -u >"$WORK_DIR/kh.local"
  cat "$WORK_DIR/kh.local" >"$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"
  merge_marker_file "$SSH_CONFIG_SNIPPET" "$HOME/.ssh/config" >"$WORK_DIR/cfg.local"
  cat "$WORK_DIR/cfg.local" >"$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  if [[ $SYNC_HOSTS -eq 1 ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      upsert_hosts_file /etc/hosts
    elif [[ $REMOTE_SUDO -eq 1 ]]; then
      local tmp_hosts
      tmp_hosts="$(mktemp)"
      sudo -n cat /etc/hosts >"$tmp_hosts"
      upsert_hosts_file "$tmp_hosts"
      sudo -n cp "$tmp_hosts" /etc/hosts
      rm -f "$tmp_hosts"
    else
      warn "本机不是 root，跳过写入 /etc/hosts（可加 --sudo）"
    fi
  fi
  refresh_local_known_hosts
}

# 参数全部写进脚本文件，避免 ssh 远端把 # 当成注释（原先 $4 未绑定即因此）
REMOTE_INSTALLER="$WORK_DIR/remote_install.sh"
cat >"$REMOTE_INSTALLER" <<REMOTE
#!/usr/bin/env bash
set -euo pipefail
TAG='${INSTALL_TAG}'
SYNC_HOSTS='${SYNC_HOSTS}'
USE_SUDO='${REMOTE_SUDO}'
MARKER_BEGIN='${MARKER_BEGIN}'
MARKER_END='${MARKER_END}'
umask 077
mkdir -p "\$HOME/.ssh"
chmod 700 "\$HOME/.ssh"
touch "\$HOME/.ssh/authorized_keys" "\$HOME/.ssh/known_hosts" "\$HOME/.ssh/config"

sort -u "/tmp/cluster_authorized_keys.\${TAG}" "\$HOME/.ssh/authorized_keys" > "/tmp/ak.\${TAG}"
cat "/tmp/ak.\${TAG}" > "\$HOME/.ssh/authorized_keys"
chmod 600 "\$HOME/.ssh/authorized_keys"

sort -u "/tmp/cluster_known_hosts.\${TAG}" "\$HOME/.ssh/known_hosts" > "/tmp/kh.\${TAG}"
cat "/tmp/kh.\${TAG}" > "\$HOME/.ssh/known_hosts"
chmod 600 "\$HOME/.ssh/known_hosts"

awk -v b="\$MARKER_BEGIN" -v e="\$MARKER_END" '
  \$0 == b {skip=1; next}
  \$0 == e {skip=0; next}
  !skip {print}
' "\$HOME/.ssh/config" > "/tmp/cfg.\${TAG}"
cat "/tmp/cfg.\${TAG}" "/tmp/cluster_ssh_config.\${TAG}" > "\$HOME/.ssh/config"
chmod 600 "\$HOME/.ssh/config"

if [[ "\$SYNC_HOSTS" == "1" ]]; then
  run() {
    if [[ "\$USE_SUDO" == "1" ]]; then
      sudo -n "\$@"
    else
      "\$@"
    fi
  }
  tmp="\$(mktemp)"
  run cat /etc/hosts > "\$tmp" || { echo "无法读取 /etc/hosts，非 root 时请加 --sudo" >&2; exit 1; }
  awk -v b="\$MARKER_BEGIN" -v e="\$MARKER_END" '
    \$0 == b {skip=1; next}
    \$0 == e {skip=0; next}
    !skip {print}
  ' "\$tmp" > "/tmp/hosts.\${TAG}"
  echo >> "/tmp/hosts.\${TAG}"
  cat "/tmp/cluster_hosts_block.\${TAG}" >> "/tmp/hosts.\${TAG}"
  run cp "/tmp/hosts.\${TAG}" /etc/hosts
  rm -f "\$tmp" "/tmp/hosts.\${TAG}"
fi

if command -v ssh-keyscan >/dev/null 2>&1 && [[ -f "/tmp/cluster_keyscan_targets.\${TAG}" ]]; then
  while IFS= read -r t; do
    [[ -n "\$t" ]] || continue
    ssh-keyscan -T 8 "\$t" 2>/dev/null || true
  done < "/tmp/cluster_keyscan_targets.\${TAG}" | grep -v '^#' >> "\$HOME/.ssh/known_hosts" || true
  sort -u "\$HOME/.ssh/known_hosts" -o "\$HOME/.ssh/known_hosts"
  chmod 600 "\$HOME/.ssh/known_hosts"
fi

rm -f "/tmp/cluster_authorized_keys.\${TAG}" \\
      "/tmp/cluster_known_hosts.\${TAG}" \\
      "/tmp/cluster_ssh_config.\${TAG}" \\
      "/tmp/cluster_hosts_block.\${TAG}" \\
      "/tmp/cluster_keyscan_targets.\${TAG}" \\
      "/tmp/ak.\${TAG}" "/tmp/kh.\${TAG}" "/tmp/cfg.\${TAG}"
REMOTE

install_remote() {
  local ip="$1"
  local host="$2"
  local tag="$INSTALL_TAG"

  if is_local_node "$ip" "$host"; then
    apply_trust_local
    return
  fi

  scp_put "$ALL_PUB" "$ip" "/tmp/cluster_authorized_keys.${tag}"
  scp_put "$KNOWN" "$ip" "/tmp/cluster_known_hosts.${tag}"
  scp_put "$SSH_CONFIG_SNIPPET" "$ip" "/tmp/cluster_ssh_config.${tag}"
  scp_put "$HOSTS_BLOCK_FILE" "$ip" "/tmp/cluster_hosts_block.${tag}"
  scp_put "$KEYSCAN_TARGETS" "$ip" "/tmp/cluster_keyscan_targets.${tag}"
  # 用 stdin 喂 bash -s，与收集公钥相同；不要再跟任何 # 开头的参数
  ssh_exec "$ip" bash -s <"$REMOTE_INSTALLER"
}

log "分发 authorized_keys / known_hosts / ssh config，并同步集群 hosts"
for i in "${!NODE_HOSTS[@]}"; do
  if is_local_node "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"; then
    log "  <- ${NODE_HOSTS[$i]} (${NODE_IPS[$i]}) [本机]"
    install_remote "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"
  fi
done
for i in "${!NODE_HOSTS[@]}"; do
  if ! is_local_node "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"; then
    log "  <- ${NODE_HOSTS[$i]} (${NODE_IPS[$i]})"
    install_remote "${NODE_IPS[$i]}" "${NODE_HOSTS[$i]}"
  fi
done

verify_one() {
  local src_ip="$1" src_host="$2" dst_host="$3"
  if is_local_node "$src_ip" "$src_host"; then
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 \
      "${SSH_USER}@${dst_host}" hostname
  else
    ssh_exec "$src_ip" ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 \
      "${SSH_USER}@${dst_host}" hostname
  fi
}

if [[ $VERIFY -eq 1 ]]; then
  log "按主机名探测互相免密登录"
  fail=0
  for i in "${!NODE_HOSTS[@]}"; do
    src_ip="${NODE_IPS[$i]}"
    src_host="${NODE_HOSTS[$i]}"
    for dst_host in "${NODE_HOSTS[@]}"; do
      if out="$(verify_one "$src_ip" "$src_host" "$dst_host" 2>/dev/null)"; then
        printf '  OK  %s -> %s  (%s)\n' "$src_host" "$dst_host" "$(echo "$out" | tr -d '\r' | head -n1)"
      else
        printf '  FAIL %s -> %s\n' "$src_host" "$dst_host" >&2
        fail=$((fail + 1))
      fi
    done
  done
  if [[ $fail -ne 0 ]]; then
    die "有 ${fail} 条主机名互访失败，请检查 sshd、防火墙和 /etc/hosts"
  fi
  log "全部节点已可用主机名互相免密登录"
else
  log "已跳过互访探测"
fi
