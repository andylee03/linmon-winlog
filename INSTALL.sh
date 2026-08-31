#!/bin/bash
# Public Linux host client (syslog → linmon :514). No extra agent. No PowerShell.
# Default --min err forwards OS errors + SSH login failures (authpriv.info).
#
#   wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
#
#   wget -qO /tmp/INSTALL.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
#   sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
#
#   # example: syslog-4 / 21.4 (prefer TCP)
#   sudo bash /tmp/INSTALL.sh --host 192.168.21.4 --port 514 --proto tcp --min err
#
#   wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh \
#     | sudo bash -s -- --host 192.168.3.200 --port 514 --proto udp --min err
#
# Menu (must be a file, not a pipe):
#   sudo bash /tmp/INSTALL.sh --setup
#
# Re-apply after Git update:
#   wget -qO /tmp/UPDATE.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
#   sudo bash /tmp/UPDATE.sh
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
