#!/bin/bash
# Re-download the public installer and re-apply saved /etc/linmon-syslog.conf
#
#   wget -qO /tmp/UPDATE.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
#   sudo bash /tmp/UPDATE.sh
#
#   wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh \
#     | sudo bash
set -eu
RAW="https://raw.githubusercontent.com/andylee03/linmon-winlog/main"
MAIN="/tmp/install-linux-syslog.sh"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

wget -qO "$MAIN" "$RAW/install-linux-syslog.sh"
chmod 755 "$MAIN"
if grep -q -- '--update' "$MAIN" 2>/dev/null && { [ -f /etc/linmon/github_deploy ] || [ -f /etc/linmon/github_token ]; }; then
  exec bash "$MAIN" --update
fi
exec bash "$MAIN"
