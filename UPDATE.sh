#!/bin/bash
# Re-download the public installer and re-apply saved /etc/linmon-syslog.conf
#
#   wget -qO /tmp/UPDATE.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
#   sudo bash /tmp/UPDATE.sh
#
#   wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh \
#     | sudo bash
#
# Always prefers the public script. If an old /etc/linmon/github_deploy exists but
# is broken, do NOT fail — fall back to public re-apply (move key aside optional).
set -eu
RAW="https://raw.githubusercontent.com/andylee03/linmon-winlog/main"
MAIN="/tmp/install-linux-syslog.sh"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

wget -qO "$MAIN" "$RAW/install-linux-syslog.sh"
chmod 755 "$MAIN"

# Optional: try private repo only when a deploy key/token exists AND works.
# Broken keys (common: tiny/corrupt github_deploy) used to abort the whole UPDATE.
if grep -q -- '--update' "$MAIN" 2>/dev/null && { [ -f /etc/linmon/github_deploy ] || [ -f /etc/linmon/github_token ]; }; then
  if bash "$MAIN" --update; then
    exit 0
  fi
  echo "==> private --update failed (bad /etc/linmon/github_deploy?); using public re-apply" >&2
  echo "    tip: sudo mv /etc/linmon/github_deploy /etc/linmon/github_deploy.broken" >&2
fi
exec bash "$MAIN"
