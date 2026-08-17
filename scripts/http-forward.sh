#!/usr/bin/env bash
# Port-forward host TCP 8088 → guest IIS 80 (Tailscale / LAN access to Tiny CRM).
# Usage: http-forward.sh on|off|status
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

HOST_PORT="${HTTP_HOST_PORT:-8088}"
GUEST_PORT="${HTTP_GUEST_PORT:-80}"
GUEST_IP="${HTTP_GUEST_IP:-$(guest_ip 2>/dev/null || true)}"
if [[ -z "${GUEST_IP}" || "${GUEST_IP}" == "unknown" ]]; then
  GUEST_IP="192.168.122.226"
fi

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    exec sudo -E env "PATH=$PATH" \
      "HTTP_HOST_PORT=${HOST_PORT}" \
      "HTTP_GUEST_PORT=${GUEST_PORT}" \
      "HTTP_GUEST_IP=${GUEST_IP}" \
      bash "$0" "$@"
  fi
}

rule_exists_nat() {
  iptables -t nat -C "$@" 2>/dev/null
}

add_rules() {
  local iface
  for iface in tailscale0 '' ; do
    local -a pren=(PREROUTING -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}")
    if [[ -n "$iface" ]]; then
      pren=(PREROUTING -i "$iface" -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}")
    fi
    if ! rule_exists_nat "${pren[@]}"; then
      iptables -t nat -A "${pren[@]}"
    fi
  done

  # Do not DNAT 127.0.0.1:HOST_PORT — local-to-loopback DNAT never completes a TCP handshake.
  local ts_ip
  ts_ip=$(tailscale ip -4 2>/dev/null | head -1 || true)
  if [[ -n "${ts_ip}" ]]; then
    local -a out_ts=(OUTPUT -p tcp -d "${ts_ip}" --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}")
    if ! rule_exists_nat "${out_ts[@]}"; then
      iptables -t nat -A "${out_ts[@]}"
    fi
  fi

  if ! iptables -C FORWARD -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
    iptables -I FORWARD 1 -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
  fi
  if ! iptables -C FORWARD -p tcp -s "${GUEST_IP}" --sport "${GUEST_PORT}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
    iptables -I FORWARD 1 -p tcp -s "${GUEST_IP}" --sport "${GUEST_PORT}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  fi

  # So the guest answers Tailscale clients via this host.
  if ! rule_exists_nat POSTROUTING -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -j MASQUERADE; then
    iptables -t nat -A POSTROUTING -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -j MASQUERADE
  fi

  sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

del_rules() {
  while iptables -t nat -C PREROUTING -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" 2>/dev/null; do
    iptables -t nat -D PREROUTING -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" || break
  done
  while iptables -t nat -C PREROUTING -i tailscale0 -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" 2>/dev/null; do
    iptables -t nat -D PREROUTING -i tailscale0 -p tcp --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" || break
  done
  while iptables -t nat -C OUTPUT -p tcp -d 127.0.0.1 --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" 2>/dev/null; do
    iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" || break
  done
  local ts_ip
  ts_ip=$(tailscale ip -4 2>/dev/null | head -1 || true)
  if [[ -n "${ts_ip}" ]]; then
    while iptables -t nat -C OUTPUT -p tcp -d "${ts_ip}" --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" 2>/dev/null; do
      iptables -t nat -D OUTPUT -p tcp -d "${ts_ip}" --dport "${HOST_PORT}" -j DNAT --to-destination "${GUEST_IP}:${GUEST_PORT}" || break
    done
  fi
  while iptables -t nat -C POSTROUTING -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -j MASQUERADE 2>/dev/null; do
    iptables -t nat -D POSTROUTING -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -j MASQUERADE || break
  done
  while iptables -C FORWARD -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -p tcp -d "${GUEST_IP}" --dport "${GUEST_PORT}" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT || break
  done
  while iptables -C FORWARD -p tcp -s "${GUEST_IP}" --sport "${GUEST_PORT}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do
    iptables -D FORWARD -p tcp -s "${GUEST_IP}" --sport "${GUEST_PORT}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || break
  done
}

status_rules() {
  echo "Host port:  ${HOST_PORT}"
  echo "Guest:      ${GUEST_IP}:${GUEST_PORT}"
  echo "VM state:   $(virsh_cmd domstate "$VM_NAME" 2>/dev/null || echo unknown)"
  echo "Host Tailscale IPv4: $(tailscale ip -4 2>/dev/null | head -1 || echo n/a)"
  echo
  echo "=== nat PREROUTING (dport ${HOST_PORT}) ==="
  iptables -t nat -L PREROUTING -n -v --line-numbers 2>/dev/null | grep -E "dpt:${HOST_PORT}" || echo "(none)"
  echo "=== nat OUTPUT (dport ${HOST_PORT}) ==="
  iptables -t nat -L OUTPUT -n -v --line-numbers 2>/dev/null | grep -E "dpt:${HOST_PORT}" || echo "(none)"
  echo "=== nat POSTROUTING (guest ${GUEST_PORT}) ==="
  iptables -t nat -L POSTROUTING -n -v --line-numbers 2>/dev/null | grep -E "${GUEST_IP}" | grep -E "dpt:${GUEST_PORT}|MASQUERADE" || echo "(none)"
}

cmd="${1:-status}"
case "$cmd" in
  on|start|enable)
    need_root on
    add_rules
    echo "HTTP forward ON: *:${HOST_PORT} → ${GUEST_IP}:${GUEST_PORT}"
    status_rules
    ;;
  off|stop|disable)
    need_root off
    del_rules
    echo "HTTP forward OFF for ${HOST_PORT} → ${GUEST_IP}:${GUEST_PORT}"
    status_rules
    ;;
  status)
    if [[ "$(id -u)" -ne 0 ]]; then
      sudo bash "$0" status
      exit $?
    fi
    status_rules
    ;;
  *)
    echo "Usage: $0 on|off|status"
    echo "  Env: HTTP_HOST_PORT (default 8088), HTTP_GUEST_IP (default from guest agent / 192.168.122.226)"
    exit 1
    ;;
esac
