#!/usr/bin/env bash
# Open Tiny CRM at http://localhost:5174 on THIS machine.
#
#   On the Pop (VM host): starts the VM + app, then that URL works.
#   On a laptop: tunnels to the Pop so Chrome still uses http://localhost:5174
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PORT="${LOCAL_PORT:-5174}"
POP_HOST="${POP_HOST:-pop-os-1.tail2e3aa.ts.net}"
POP_USER="${POP_USER:-krylor}"
TUNNEL_PID_FILE="${TUNNEL_PID_FILE:-/tmp/tiny-crm-localhost-tunnel.pid}"

log() { printf '[shop] %s\n' "$*" >&2; }
die() { printf '[shop] ERROR: %s\n' "$*" >&2; exit 1; }

shop_ok() {
  curl -sS -o /tmp/shop-local-check.html -w '%{http_code}' --connect-timeout 3 --max-time 8 \
    "http://127.0.0.1:${LOCAL_PORT}/Shop/Account/Login" 2>/dev/null | grep -qx '200' \
    && grep -q 'Tiny CRM' /tmp/shop-local-check.html
}

is_vm_host() {
  [[ -x "${HOME}/vms/windows-server/scripts/start.sh" ]] && command -v virsh >/dev/null 2>&1
}

if shop_ok; then
  log "already available"
elif is_vm_host; then
  log "starting the app on this Pop"
  "${SCRIPT_DIR}/start-shop.sh"
elif [[ -n "${SSH_CONNECTION:-}" ]] && is_vm_host; then
  "${SCRIPT_DIR}/start-shop.sh"
else
  log "opening SSH tunnel to ${POP_USER}@${POP_HOST} so localhost:${LOCAL_PORT} works here"
  if [[ -f "$TUNNEL_PID_FILE" ]] && kill -0 "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null; then
    log "tunnel already running"
  else
    if ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE ":${LOCAL_PORT}$"; then
      die "port ${LOCAL_PORT} is already in use on this machine"
    fi
    ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
      -L "${LOCAL_PORT}:127.0.0.1:${LOCAL_PORT}" \
      "${POP_USER}@${POP_HOST}"
    # ssh -f background does not print pid easily; find the listener
    pgrep -f "ssh .* -L ${LOCAL_PORT}:127.0.0.1:${LOCAL_PORT}" | head -1 >"$TUNNEL_PID_FILE" || true
  fi
  shop_ok || die "tunnel is up but http://localhost:${LOCAL_PORT} is not serving Tiny CRM. Start the app on the Pop first: ./scripts/start-shop.sh"
fi

cat <<EOF

Open:   http://localhost:${LOCAL_PORT}
Login:  admin / Admin@123

EOF
