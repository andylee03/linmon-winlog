#!/bin/bash
# Public wipe for a LINMON syslog SERVER (same as pack UNINSTALL.sh).
#   wget -qO /tmp/SERVER-UNINSTALL.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UNINSTALL.sh
#   bash /tmp/SERVER-UNINSTALL.sh --dir /data/linmon --yes
#
# Remove Docker stack + /data/linmon + Linux-client rsyslog + host iptables unit.
#
#   bash UNINSTALL.sh --dir /data/linmon --yes
#
# Does not uninstall Docker itself. Does not touch other compose projects.
# Do not run as root (same as INSTALL).
set -eu

DIR="${LINMON_DIR:-/data/linmon}"
NEED_YES=0
KEEP_IMAGES=0
KEEP_KEY=0
KEEP_DIR=0

usage() {
  cat <<'EOF'
Remove LINMON server install on this host.

  bash UNINSTALL.sh --dir /data/linmon --yes

  --dir PATH       runtime dir (default /data/linmon)
  --yes            required (no prompt)
  --keep-images    do not docker rmi linmon / linmon-nginx / linmon-rdp-enc
  --keep-key       keep ~/.linmon/bin_deploy
  --keep-dir       docker compose down only; leave /data/linmon on disk
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift ;;
    --yes|-y) NEED_YES=1 ;;
    --keep-images) KEEP_IMAGES=1 ;;
    --keep-key) KEEP_KEY=1 ;;
    --keep-dir) KEEP_DIR=1 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: do not run as root. Use the docker-group user (e.g. metis)." >&2
  exit 1
fi
if [ "$NEED_YES" != "1" ]; then
  echo "ERROR: refusing to run without --yes" >&2
  echo "  bash $0 --dir $DIR --yes" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

echo "==> uninstall linmon server  dir=$DIR  user=$(id -un)"

down_compose() {
  if [ ! -d "$DIR" ]; then
    echo "    no $DIR"
    return 0
  fi
  cd "$DIR"
  extra=()
  [ -f .env ] && extra+=(--env-file .env)
  files=()
  [ -f docker-compose.yml ] && files+=(-f docker-compose.yml)
  [ -f docker-compose.data.yml ] && files+=(-f docker-compose.data.yml)
  [ -f docker-compose.mnt.yml ] && files+=(-f docker-compose.mnt.yml)
  if [ ${#files[@]} -gt 0 ]; then
    echo "    docker compose down -v"
    docker compose "${extra[@]}" "${files[@]}" down -v --remove-orphans || true
  elif [ -x scripts/dc.sh ]; then
    bash scripts/dc.sh down -v --remove-orphans || true
  fi
}

down_compose

echo "    stop named containers if leftover"
for n in linmon linmon-nginx linmon-postgres linmon-collect-log linmon-guacd linmon-rdp-enc; do
  docker rm -f "$n" >/dev/null 2>&1 || true
done

echo "    named volumes (names containing linmon)"
docker volume rm -f linmon_rdp-recordings rdp-recordings 2>/dev/null || true
docker volume ls -q | while read -r v; do
  case "$v" in
    *linmon*) docker volume rm -f "$v" >/dev/null 2>&1 || true ;;
  esac
done

if [ "$KEEP_IMAGES" != "1" ]; then
  echo "    docker rmi linmon images"
  docker rmi -f linmon:latest linmon-nginx:latest linmon-rdp-enc:latest 2>/dev/null || true
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | while read -r line; do
    case "$line" in
      linmon*|linmon-nginx*|linmon-rdp-enc*) docker rmi -f $(echo "$line" | awk '{print $2}') >/dev/null 2>&1 || true ;;
    esac
  done
fi

echo "    docker network"
docker network rm linmon_linmon_net linmon_net 2>/dev/null || true

if [ "$KEEP_DIR" != "1" ] && [ -d "$DIR" ]; then
  echo "    rm -rf $DIR"
  rm -rf "$DIR"
fi

CACHE="${HOME}/.linmon"
if [ -d "$CACHE/bin-repo" ]; then
  echo "    rm -rf $CACHE/bin-repo"
  rm -rf "$CACHE/bin-repo"
fi
if [ "$KEEP_KEY" != "1" ]; then
  rm -f "$CACHE/bin_deploy" "$CACHE/github_token"
  echo "    removed deploy key under $CACHE (if any)"
fi
rm -f "$HOME/linmon-bin-deploy" 2>/dev/null || true

# Linux client forwarder + hairpin iptables (needs sudo)
sudo_ok=0
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  sudo_ok=1
fi

remove_client() {
  echo "    Linux client rsyslog + iptables unit"
  if [ "$sudo_ok" = "1" ]; then
    sudo rm -f /etc/rsyslog.d/99-linmon.conf /etc/linmon-syslog.conf
    if [ -f /etc/rsyslog.conf ]; then
      sudo grep -v 'linmon-syslog-forward' /etc/rsyslog.conf > /tmp/rsyslog.conf.linmon.tmp 2>/dev/null \
        && sudo mv /tmp/rsyslog.conf.linmon.tmp /etc/rsyslog.conf || true
    fi
    sudo systemctl restart rsyslog 2>/dev/null || true
    sudo systemctl disable --now linmon-host-syslog-iptables.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/linmon-host-syslog-iptables.service \
      /usr/local/sbin/linmon-host-syslog-iptables.sh
    sudo systemctl daemon-reload 2>/dev/null || true
  else
    echo "    (no passwordless sudo — run as the same user with sudo):"
    echo "      sudo rm -f /etc/rsyslog.d/99-linmon.conf /etc/linmon-syslog.conf"
    echo "      sudo systemctl restart rsyslog"
    echo "      sudo systemctl disable --now linmon-host-syslog-iptables.service"
    echo "      sudo rm -f /etc/systemd/system/linmon-host-syslog-iptables.service /usr/local/sbin/linmon-host-syslog-iptables.sh"
  fi
}
remove_client

echo
echo "=== leftover ==="
docker ps -a --filter name=linmon --format 'table {{.Names}}\t{{.Status}}' || true
ss -tuln 2>/dev/null | grep -E ':80 |:443 |:514 ' || netstat -tuln 2>/dev/null | grep -E ':80 |:443 |:514 ' || true
if [ -d "$DIR" ]; then
  echo "dir still exists: $DIR"
else
  echo "dir gone: $DIR"
fi
echo "Done. Docker engine is still installed. Re-install: SERVER-INSTALL.sh --key … --dir $DIR"
