# Usage: bash sqlq.sh "SELECT * FROM ShopCRM.dbo.Users"
set -euo pipefail
QUERY="$1"
PW="$(cat "$HOME/vms/windows-server/unattended/admin-password.txt")"
# Write query to temp file on guest, then execute
sshpass -p "$PW" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR Administrator@192.168.122.226 "powershell -NoProfile -Command \"Set-Content -Path C:\src\temp-query.sql -Value '$QUERY' -NoNewline; sqlcmd -S 127.0.0.1,1433 -E -i C:\src\temp-query.sql\""