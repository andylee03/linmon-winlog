#!/bin/bash
# Overlay latest linmon + collect-log from private andylee03/linmon-bin.
# Does not wipe Postgres / .env / linmon.json.
#
# Public wget (same repo as SERVER-INSTALL.sh — not the Linux-client UPDATE.sh):
#   wget -qO /tmp/SERVER-UPDATE.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UPDATE.sh
#   bash /tmp/SERVER-UPDATE.sh --dir /data/linmon
#   bash /tmp/SERVER-UPDATE.sh --dir /home/athenabest/vide   # prod 3.200 (no /data/linmon)
#
# Uses ~/.linmon/bin_deploy from first INSTALL. Optional: --key ./linmon-bin-deploy
# Always wget this file from GitHub. Do not scp binaries from the office PC.
set -eu
BIN_REPO="${LINMON_BIN_REPO:-andylee03/linmon-bin}"
KEY=""
DIR="${LINMON_DIR:-}"
CLONE="${HOME}/.linmon/bin-repo"
STASH="${HOME}/.linmon/bin_deploy"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run as root. Use a docker-group user." >&2
  exit 1
fi

strip_cr() { printf '%s' "$1" | tr -d '\r'; }

while [ $# -gt 0 ]; do
  a="$(strip_cr "$1")"
  case "$a" in
    --key|--install-key)
      KEY="$(strip_cr "${2:-}")"; shift 2 ;;
    --key=*)
      KEY="$(strip_cr "${a#--key=}")"; shift ;;
    --dir)
      DIR="$(strip_cr "${2:-}")"; shift 2 ;;
    --dir=*)
      DIR="$(strip_cr "${a#--dir=}")"; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $a" >&2
      exit 1
      ;;
  esac
done

if [ -z "$KEY" ]; then
  if [ -f "$STASH" ]; then
    KEY="$STASH"
  elif [ -f "$HOME/linmon-bin-deploy" ]; then
    KEY="$HOME/linmon-bin-deploy"
  fi
fi
if [ -z "$KEY" ] || [ ! -f "$KEY" ]; then
  echo "ERROR: need deploy key (first INSTALL --key, or ~/.linmon/bin_deploy)" >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: need git" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: need docker" >&2; exit 1; }
if ! docker ps --format '{{.Names}}' | grep -qx linmon; then
  echo "ERROR: container linmon is not running. Use SERVER-INSTALL.sh first." >&2
  docker ps -a --filter name=linmon || true
  exit 1
fi

if [ -z "$DIR" ]; then
  wd="$(docker inspect linmon --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || true)"
  if [ -n "$wd" ] && [ -d "$wd" ]; then
    DIR="$wd"
  elif [ -d /data/linmon ]; then
    DIR=/data/linmon
  elif [ -d "$HOME/vide" ] && [ -f "$HOME/vide/docker-compose.yml" ]; then
    DIR="$HOME/vide"
  else
    DIR=/data/linmon
  fi
fi
echo "Update dir: $DIR"
if [ ! -d "$DIR" ]; then
  echo "ERROR: runtime dir not found: $DIR" >&2
  echo "  3.200:  bash $0 --dir /home/athenabest/vide" >&2
  echo "  11.4 / syslog-4:  bash $0 --dir /data/linmon" >&2
  exit 1
fi

mkdir -p "$(dirname "$CLONE")" "$HOME/.linmon"
chmod 600 "$KEY" 2>/dev/null || true
if [ "$(readlink -f "$KEY" 2>/dev/null || echo "$KEY")" != "$(readlink -f "$STASH" 2>/dev/null || echo "$STASH")" ]; then
  cp -f "$KEY" "$STASH"
fi
chmod 600 "$STASH"

echo "Clone git@github.com:${BIN_REPO}.git (full clone — not sparse)…"
rm -rf "$CLONE"
GIT_SSH_COMMAND="ssh -i ${STASH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --depth 1 "git@github.com:${BIN_REPO}.git" "$CLONE"
chmod 755 "$CLONE/INSTALL.sh" "$CLONE/install-linmon-bin.sh" "$CLONE/linmon" "$CLONE/collect-log" 2>/dev/null || true

# INSTALL.sh with pack next to it: stack already up → docker cp bins only (no down -v).
exec bash "$CLONE/INSTALL.sh" --key "$STASH" --dir "$DIR"
