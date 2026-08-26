#!/bin/bash
# Public Linux host client (syslog → linmon :514). No extra agent. No PowerShell.
#
#   wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
#
#   wget -qO /tmp/INSTALL.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
#   sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
#
#   wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh \
#     | sudo bash -s -- --host 192.168.3.200 --port 514 --proto udp --min err
#
# Menu (must be a file, not a pipe):
#   sudo bash /tmp/INSTALL.sh --setup
set -eu
RAW="https://raw.githubusercontent.com/andylee03/linmon-winlog/main"
MAIN="/tmp/install-linux-syslog.sh"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

HERE=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$HERE" ] && [ -f "$HERE/install-linux-syslog.sh" ]; then
  MAIN="$HERE/install-linux-syslog.sh"
else
  wget -qO "$MAIN" "$RAW/install-linux-syslog.sh"
  chmod 755 "$MAIN"
fi

exec bash "$MAIN" "$@"
