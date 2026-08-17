#!/usr/bin/env bash
# One-shot Tiny CRM bring-up on the win-iis-dev VM.
#
#   ./scripts/start-shop.sh              # start VM, SQL, IIS, http://localhost:5174
#   ./scripts/start-shop.sh --browser    # also open Firefox on the Pop screen
#   ./scripts/start-shop.sh --rdp        # also open an RDP window
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_SCRIPTS="${HOME}/vms/windows-server/scripts"
PW_FILE="${VM_PW_FILE:-${HOME}/vms/windows-server/unattended/admin-password.txt}"
GUEST_USER="${VM_USER:-Administrator}"
DEFAULT_IP="192.168.122.226"
APP_PATH="/Shop"
LOGIN_USER="${SHOP_USER:-admin}"
LOGIN_PASS="${SHOP_PASS:-Admin@123}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-180}"
HTTP_HOST_PORT="${HTTP_HOST_PORT:-8088}"
LOCAL_PORT="${LOCAL_PORT:-5174}"
PROXY_PID_FILE="${PROXY_PID_FILE:-/tmp/tiny-crm-local-proxy.pid}"
PROXY_LOG_FILE="${PROXY_LOG_FILE:-/tmp/tiny-crm-local-proxy.log}"
OPEN_BROWSER=0
OPEN_RDP=0

usage() {
  cat <<'EOF'
Usage: ./scripts/start-shop.sh [options]

Start win-iis-dev, wait for Windows, start SQL Express + IIS Shop,
and publish Tiny CRM at http://localhost:5174 only.

Options:
  --browser      Also open Firefox on the Pop screen
  --no-browser   Ignored (browser is off by default)
  --rdp          Also launch xfreerdp to the guest desktop
  --timeout N    Seconds to wait for guest SSH (default: 180)
  -h, --help     Show this help

Env:
  VM_PW_FILE       Guest admin password file
  SHOP_USER        App login (default: admin)
  SHOP_PASS        App password (default: Admin@123)
  LOCAL_PORT       App port (default: 5174)
  HTTP_HOST_PORT   Unused leftover (default: 8088)
  DISPLAY          X display for --browser (default: :0)
EOF
}

log() { printf '[start-shop] %s\n' "$*" >&2; }
die() { printf '[start-shop] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-browser) OPEN_BROWSER=0; shift ;;
    --browser)    OPEN_BROWSER=1; shift ;;
    --rdp)        OPEN_RDP=1; shift ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout needs a number"
      BOOT_TIMEOUT="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd virsh
need_cmd ssh
need_cmd sshpass
need_cmd curl
need_cmd nc

[[ -x "${VM_SCRIPTS}/start.sh" ]] || die "VM start script not found: ${VM_SCRIPTS}/start.sh"
[[ -f "$PW_FILE" ]] || die "guest password file not found: $PW_FILE"
PW="$(cat "$PW_FILE")"
[[ -n "$PW" ]] || die "guest password file is empty: $PW_FILE"

guest_ip() {
  local ip=""
  if [[ -x "${VM_SCRIPTS}/ip.sh" ]]; then
    ip="$("${VM_SCRIPTS}/ip.sh" 2>/dev/null || true)"
  fi
  if [[ -z "$ip" || "$ip" == "unknown" ]]; then
    ip="$DEFAULT_IP"
  fi
  printf '%s\n' "$ip"
}

guest_ssh() {
  local ip="$1"
  shift
  sshpass -p "$PW" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=10 \
    "${GUEST_USER}@${ip}" "$@"
}

port_open() {
  local host="$1" port="$2"
  nc -z -w 2 "$host" "$port" >/dev/null 2>&1
}

wait_for_guest() {
  local deadline=$((SECONDS + BOOT_TIMEOUT))
  local ip=""
  log "waiting up to ${BOOT_TIMEOUT}s for guest SSH..."
  while (( SECONDS < deadline )); do
    ip="$(guest_ip)"
    if [[ -n "$ip" && "$ip" != "unknown" ]] && port_open "$ip" 22; then
      if guest_ssh "$ip" 'echo ready' >/dev/null 2>&1; then
        printf '%s\n' "$ip"
        return 0
      fi
    fi
    sleep 3
  done
  die "guest did not become reachable over SSH within ${BOOT_TIMEOUT}s"
}

ensure_vm() {
  log "starting VM (no-op if already running)"
  "${VM_SCRIPTS}/start.sh"
}

ensure_rdp_forward() {
  if [[ -x "${VM_SCRIPTS}/rdp-forward.sh" ]]; then
    log "enabling RDP forward host:3390 -> guest:3389"
    "${VM_SCRIPTS}/rdp-forward.sh" on
  else
    log "rdp-forward.sh not found; skipping"
  fi
}

ensure_http_forward() {
  if [[ -x "${VM_SCRIPTS}/http-forward.sh" ]]; then
    log "enabling HTTP forward host:${HTTP_HOST_PORT} -> guest:80"
    HTTP_HOST_PORT="${HTTP_HOST_PORT}" "${VM_SCRIPTS}/http-forward.sh" on
  else
    die "http-forward.sh not found: ${VM_SCRIPTS}/http-forward.sh"
  fi
}

proxy_running() {
  local pid=""
  if [[ -f "$PROXY_PID_FILE" ]]; then
    pid="$(cat "$PROXY_PID_FILE" 2>/dev/null || true)"
  fi
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  return 1
}

ensure_local_proxy() {
  local guest_ip="$1"
  local proxy="${SCRIPT_DIR}/local-proxy.py"
  [[ -f "$proxy" ]] || die "missing ${proxy}"
  need_cmd python3

  local ts_ip
  ts_ip="$(tailscale_ip)"
  local ts_ok=0
  if [[ -n "$ts_ip" ]] && curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 8 "http://${ts_ip}:${LOCAL_PORT}/Shop/Account/Login" 2>/dev/null | grep -qx '200'; then
    ts_ok=1
  fi
  if proxy_running && curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 8 "http://127.0.0.1:${LOCAL_PORT}/Shop/Account/Login" | grep -qx '200' && [[ "$ts_ok" -eq 1 || -z "$ts_ip" ]]; then
    log "localhost and Tailscale :${LOCAL_PORT} already running"
    return 0
  fi

  if proxy_running; then
    log "replacing proxy so Tailscale :${LOCAL_PORT} is reachable"
    kill "$(cat "$PROXY_PID_FILE")" 2>/dev/null || true
    sleep 1
  fi

  if ss -lnt | awk '{print $4}' | grep -qE ":${LOCAL_PORT}$"; then
    die "port ${LOCAL_PORT} is already in use by something else"
  fi

  log "starting 0.0.0.0:${LOCAL_PORT} -> ${guest_ip}:80"
  nohup python3 "$proxy" \
    --listen-host 0.0.0.0 \
    --listen-port "$LOCAL_PORT" \
    --upstream-host "$guest_ip" \
    --upstream-port 80 \
    >"$PROXY_LOG_FILE" 2>&1 &
  echo $! >"$PROXY_PID_FILE"

  local i code
  for i in $(seq 1 20); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 "http://127.0.0.1:${LOCAL_PORT}/Shop/Account/Login" || true)"
    if [[ "$code" == "200" ]]; then
      log "localhost:${LOCAL_PORT} is up"
      return 0
    fi
    sleep 0.3
  done
  die "localhost:${LOCAL_PORT} proxy did not become ready (see ${PROXY_LOG_FILE})"
}

tailscale_ip() {
  tailscale ip -4 2>/dev/null | head -1 || true
}

tailscale_name() {
  tailscale status --json 2>/dev/null | python3 -c '
import json,sys
try:
    name=(json.load(sys.stdin).get("Self") or {}).get("DNSName") or ""
    print(name.rstrip("."))
except Exception:
    pass
' 2>/dev/null || true
}

ensure_sql() {
  local ip="$1"
  log "starting SQL Server (SQLEXPRESS)"
  local out
  out="$(guest_ssh "$ip" 'net start "SQL Server (SQLEXPRESS)"' 2>&1 || true)"
  if printf '%s\n' "$out" | grep -qiE 'started successfully|already been started'; then
    log "SQL Express is running"
  else
    printf '%s\n' "$out" >&2
    die "could not start SQL Express"
  fi

  local i
  for i in $(seq 1 20); do
    if guest_ssh "$ip" 'sqlcmd -S 127.0.0.1,1433 -E -Q "SELECT 1"' >/dev/null 2>&1; then
      log "SQL Express accepted a query"
      return 0
    fi
    sleep 2
  done
  die "SQL Express started but 127.0.0.1,1433 is not accepting queries"
}

ensure_iis() {
  local ip="$1"
  log "starting IIS (W3SVC) and Shop app pool"
  guest_ssh "$ip" 'net start W3SVC' >/dev/null 2>&1 || true
  # Start only — do not recycle a healthy pool (that races the first login).
  guest_ssh "$ip" 'powershell -NoProfile -Command "Import-Module WebAdministration; Start-WebAppPool -Name ShopAppPool -ErrorAction SilentlyContinue; Start-Website -Name '"'"'Default Web Site'"'"' -ErrorAction SilentlyContinue"'
}

verify_shop() {
  local ip="$1"
  local base="http://${ip}${APP_PATH}"
  log "checking ${base}"

  local attempt code token post_code dash_code
  for attempt in 1 2 3 4 5; do
    rm -f /tmp/start-shop-cookies.txt
    code="$(curl -sS -c /tmp/start-shop-cookies.txt -b /tmp/start-shop-cookies.txt \
      -o /tmp/start-shop-login.html -w '%{http_code}' \
      --connect-timeout 8 --max-time 20 "${base}/Account/Login" || true)"
    token="$(grep -oP 'name="__RequestVerificationToken" type="hidden" value="\K[^"]+' /tmp/start-shop-login.html | head -1 || true)"
    if [[ "$code" == "200" && -n "$token" ]] && grep -q 'Tiny CRM' /tmp/start-shop-login.html; then
      post_code="$(curl -sS -c /tmp/start-shop-cookies.txt -b /tmp/start-shop-cookies.txt \
        -o /tmp/start-shop-post.html \
        -w '%{http_code}' \
        -X POST \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "__RequestVerificationToken=${token}" \
        --data-urlencode "Username=${LOGIN_USER}" \
        --data-urlencode "Password=${LOGIN_PASS}" \
        --data-urlencode "ReturnUrl=" \
        "${base}/Account/Login" || true)"
      if [[ "$post_code" == "302" ]]; then
        break
      fi
      log "login POST returned HTTP ${post_code:-down}, retry ${attempt}/5"
    else
      log "login page not ready yet (HTTP ${code:-down}), retry ${attempt}/5"
    fi
    sleep 3
  done
  [[ "${post_code:-}" == "302" ]] || die "login POST returned HTTP ${post_code:-unknown} (expected 302). SQL/IIS may not be ready."

  dash_code="$(curl -sS -b /tmp/start-shop-cookies.txt -o /tmp/start-shop-dash.html -w '%{http_code}' --max-time 20 "${base}/Dashboard")"
  [[ "$dash_code" == "200" ]] || die "dashboard returned HTTP ${dash_code}"
  grep -q 'Dashboard - Tiny CRM' /tmp/start-shop-dash.html || die "dashboard did not render"
  log "login works; dashboard is up"
}

verify_forwarded() {
  local url="$1"
  local label="$2"
  log "checking forwarded ${label}: ${url}"
  local code
  code="$(curl -sS -o /tmp/start-shop-fwd.html -w '%{http_code}' --connect-timeout 8 --max-time 20 "${url}/Account/Login" || true)"
  [[ "$code" == "200" ]] || die "${label} ${url}/Account/Login returned HTTP ${code:-down}"
  grep -q 'Tiny CRM' /tmp/start-shop-fwd.html || die "${label} login page did not contain Tiny CRM"
  log "${label} is serving Tiny CRM"
}

open_browser() {
  local url="$1"
  if [[ "$OPEN_BROWSER" -ne 1 ]]; then
    return 0
  fi
  if ! command -v firefox >/dev/null 2>&1 && ! command -v xdg-open >/dev/null 2>&1; then
    log "no Firefox/xdg-open; open this yourself: $url"
    return 0
  fi

  export DISPLAY="${DISPLAY:-:0}"
  if [[ -z "${XAUTHORITY:-}" ]]; then
    if [[ -f "${HOME}/.Xauthority" ]]; then
      export XAUTHORITY="${HOME}/.Xauthority"
    elif [[ -f /run/user/$(id -u)/gdm/Xauthority ]]; then
      export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    fi
  fi

  if ! xdpyinfo >/dev/null 2>&1; then
    log "no graphical display on ${DISPLAY}; open this yourself: $url"
    return 0
  fi

  log "opening ${url} on Pop display ${DISPLAY}"
  if command -v firefox >/dev/null 2>&1; then
    nohup firefox --new-window "$url" >/tmp/start-shop-firefox.log 2>&1 &
  else
    nohup xdg-open "$url" >/tmp/start-shop-browser.log 2>&1 &
  fi
}

open_rdp() {
  local ip="$1"
  if [[ "$OPEN_RDP" -ne 1 ]]; then
    return 0
  fi
  if ! command -v xfreerdp >/dev/null 2>&1 && ! command -v xfreerdp3 >/dev/null 2>&1; then
    log "xfreerdp not installed; RDP from another client to ${ip}:3389 or host:3390"
    return 0
  fi
  local rdp_bin
  rdp_bin="$(command -v xfreerdp3 || command -v xfreerdp)"
  log "launching RDP to ${ip}"
  nohup "$rdp_bin" "/v:${ip}" "/u:${GUEST_USER}" "/p:${PW}" /cert:ignore /dynamic-resolution \
    >/tmp/start-shop-rdp.log 2>&1 &
}

# --- run ---
ensure_vm
GUEST_IP="$(wait_for_guest)"
log "guest is up at ${GUEST_IP}"
ensure_rdp_forward
ensure_http_forward
ensure_sql "$GUEST_IP"
ensure_iis "$GUEST_IP"
verify_shop "$GUEST_IP"
ensure_local_proxy "$GUEST_IP"

LOCAL_URL="http://localhost:${LOCAL_PORT}"
verify_forwarded "${LOCAL_URL}${APP_PATH}" "localhost:${LOCAL_PORT}"

TS_IP="$(tailscale_ip)"
TS_NAME="$(tailscale_name)"
TS_URL=""
if [[ -n "$TS_NAME" ]]; then
  TS_URL="http://${TS_NAME}:${LOCAL_PORT}"
elif [[ -n "$TS_IP" ]]; then
  TS_URL="http://${TS_IP}:${LOCAL_PORT}"
fi
if [[ -n "$TS_URL" ]]; then
  verify_forwarded "${TS_URL}${APP_PATH}" "Tailscale :${LOCAL_PORT}"
fi

open_browser "$LOCAL_URL"
open_rdp "$GUEST_IP"

cat <<EOF

Tiny CRM is running.

  Local:      ${LOCAL_URL}
  Tailscale:  ${TS_URL:-n/a}
  Compare:    http://${TS_NAME:-${TS_IP:-pop-os-1}}:5173  (new .NET 10 + Vue)
              ${TS_URL:-http://localhost:5174}  (legacy .NET 4.7 Razor)
  Login:      ${LOGIN_USER} / ${LOGIN_PASS}

EOF
