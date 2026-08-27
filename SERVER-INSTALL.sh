#!/bin/bash
# Bootstrap LINMON syslog SERVER from GitHub (no scp of the 90MB pack).
# Public: https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
#
# You still need the small private deploy key once (linmon-bin-deploy).
# Everything else is git clone of private andylee03/linmon-bin.
#
#   wget -qO /tmp/SERVER-INSTALL.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
#   bash /tmp/SERVER-INSTALL.sh --key ./linmon-bin-deploy --dir /data/linmon
set -eu
BIN_REPO="${LINMON_BIN_REPO:-andylee03/linmon-bin}"
KEY=""
DIR="${LINMON_DIR:-/data/linmon}"
CLONE="${HOME}/.linmon/bin-repo"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run as root. Use a docker-group user." >&2
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --key|--install-key) KEY="${2:-}"; shift ;;
    --dir) DIR="${2:-}"; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$KEY" ] || [ ! -f "$KEY" ]; then
  echo "ERROR: --key FILE is required (private deploy key linmon-bin-deploy)" >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: need git" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: need docker" >&2; exit 1; }

mkdir -p "$(dirname "$CLONE")" "$HOME/.linmon"
chmod 600 "$KEY" 2>/dev/null || true
cp -f "$KEY" "$HOME/.linmon/bin_deploy"
chmod 600 "$HOME/.linmon/bin_deploy"
echo "Clone git@github.com:${BIN_REPO}.git (images + bins)…"
rm -rf "$CLONE"
GIT_SSH_COMMAND="ssh -i ${HOME}/.linmon/bin_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --depth 1 "git@github.com:${BIN_REPO}.git" "$CLONE"
chmod 755 "$CLONE/INSTALL.sh" "$CLONE/install-linmon-bin.sh" "$CLONE/linmon" "$CLONE/collect-log" 2>/dev/null || true
exec bash "$CLONE/INSTALL.sh" --key "$HOME/.linmon/bin_deploy" --dir "$DIR"
