#!/usr/bin/env bash
# WinRM/SSH bridge to the win-iis-dev guest. Usage: vmexec.sh "<powershell command>"
set -euo pipefail
PW_FILE="${VM_PW_FILE:-$HOME/vms/windows-server/unattended/admin-password.txt}"
VM_HOST="${VM_HOST:-Administrator@192.168.122.226}"
PW="$(cat "$PW_FILE")"
exec sshpass -p "$PW" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "$VM_HOST" "powershell -NoProfile -Command \"$@\""