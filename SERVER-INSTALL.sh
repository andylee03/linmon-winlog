#!/bin/bash
# Bootstrap LINMON syslog SERVER from GitHub (no scp of the 90MB pack).
# Public: https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
#
#   wget -qO /tmp/SERVER-INSTALL.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
#   bash /tmp/SERVER-INSTALL.sh --key /path/to/linmon-bin-deploy --dir /data/linmon
set -eu
BIN_REPO="${LINMON_BIN_REPO:-andylee03/linmon-bin}"
KEY=""
DIR="${LINMON_DIR:-/data/linmon}"
CLONE="${HOME}/.linmon/bin-repo"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run as root. Use a docker-group user." >&2
  exit 1
fi

strip_cr() { printf '%s' "$1" | tr -d '\r'; }

while [ $# -gt 0 ]; do
  a="$(strip_cr "$1")"
  case "$a" in
    --key|--install-key)
      if [ $# -lt 2 ]; then
        echo "ERROR: $a requires a path to linmon-bin-deploy" >&2
        exit 1
      fi
      KEY="$(strip_cr "$2")"
      shift 2
      ;;
    --key=*)
      KEY="$(strip_cr "${a#--key=}")"
      shift
      ;;
    --dir)
      if [ $# -lt 2 ]; then
        echo "ERROR: --dir requires a path" >&2
        exit 1
      fi
      DIR="$(strip_cr "$2")"
      shift 2
      ;;
    --dir=*)
      DIR="$(strip_cr "${a#--dir=}")"
      shift
      ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $a" >&2
      exit 1
      ;;
  esac
done

if [ -z "$KEY" ]; then
  echo "ERROR: missing --key /path/to/linmon-bin-deploy" >&2
  echo "  cwd=$(pwd)" >&2
  echo "  example: bash $0 --key \$HOME/linmon-bin-deploy --dir /data/linmon" >&2
  exit 1
fi
if [ ! -f "$KEY" ]; then
  echo "ERROR: key file not found: $KEY" >&2
  echo "  cwd=$(pwd)" >&2
  echo "  ls -l $(dirname -- "$KEY")" >&2
  ls -l "$(dirname -- "$KEY")" 2>/dev/null || true
  echo "  Copy the private key (not .pub) from the office PC: D:\\vide\\keys\\linmon-bin-deploy" >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: need git (sudo apt-get install -y git)" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: need docker" >&2; exit 1; }

mkdir -p "$(dirname "$CLONE")" "$HOME/.linmon"
chmod 600 "$KEY" 2>/dev/null || true
STASH="$HOME/.linmon/bin_deploy"
if [ "$(readlink -f "$KEY" 2>/dev/null || echo "$KEY")" != "$(readlink -f "$STASH" 2>/dev/null || echo "$STASH")" ]; then
  cp -f "$KEY" "$STASH"
fi
chmod 600 "$STASH"
echo "Clone git@github.com:${BIN_REPO}.git (images + bins)…"
rm -rf "$CLONE"
GIT_SSH_COMMAND="ssh -i ${HOME}/.linmon/bin_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --depth 1 "git@github.com:${BIN_REPO}.git" "$CLONE"
chmod 755 "$CLONE/INSTALL.sh" "$CLONE/install-linmon-bin.sh" "$CLONE/linmon" "$CLONE/collect-log" 2>/dev/null || true
exec bash "$CLONE/INSTALL.sh" --key "$HOME/.linmon/bin_deploy" --dir "$DIR"
