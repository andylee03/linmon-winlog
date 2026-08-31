#!/bin/bash
# Configure this Linux host to forward syslog to linmon (:514).
# Detects rsyslog, syslog-ng, or classic syslogd. No extra agent binary.
#
# Private repo (same idea as Winlog GitHub update — syslog only):
#   andylee03/linmon-syslog
# Key on the machine after first install:
#   /etc/linmon/github_deploy     read-only GitHub deploy key
#   /etc/linmon/github_token      optional PAT (contents:read) if no SSH key
#
# First install (from USB / scp, not public wget):
#   sudo bash INSTALL.sh --key /path/to/linmon-syslog-deploy --host 192.168.3.200
#   sudo bash INSTALL.sh --setup
#
# Later update (uses the key already on the box):
#   sudo bash UPDATE.sh
#   sudo linmon-syslog-update
#
# Options:
#   --setup / --reconfigure     interactive menu (needs a terminal)
#   --show                      print saved + installed config
#   --host IP_OR_NAME           linmon host  (default 192.168.3.200)
#   --port N                    514
#   --proto udp|tcp
#   --min err|warn|crit|info|debug
#   --all                       send everything (overrides --min)
#   --test                      send one test message
#   --update                    pull latest script from private repo, then re-apply
#   --install-key FILE          install deploy key to /etc/linmon/github_deploy
#   --install-token FILE        install PAT to /etc/linmon/github_token
#   --uninstall                 remove forwarder (keeps key unless you delete it)
#   -h / --help
#
# Default: UDP 192.168.3.200:514, only err/crit/alert/emerg + auth + kernel.
# Does not dump history — only new messages after reload.
# Last applied values are stored in /etc/linmon-syslog.conf

set -eu

SYSLOG_VERSION="1.0.1"
SYSLOG_REPO="andylee03/linmon-syslog"
LINMON_DIR="/etc/linmon"
DEPLOY_KEY="${LINMON_DIR}/github_deploy"
TOKEN_FILE="${LINMON_DIR}/github_token"
INSTALLED_SH="/usr/local/sbin/install-linux-syslog.sh"
STATE_FILE="/etc/linmon-syslog.conf"
CONF_NAME="99-linmon.conf"

HOST="192.168.3.200"
PORT="514"
PROTO="udp"
MIN="err"
ALL="0"
DO_TEST="0"
UNINSTALL="0"
DO_SETUP="0"
DO_SHOW="0"
DO_UPDATE="0"
INSTALL_KEY=""
INSTALL_TOKEN=""

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \?//'
  exit 0
}

load_state() {
  [ -f "$STATE_FILE" ] || return 0
  while IFS='=' read -r k v || [ -n "${k:-}" ]; do
    k=$(echo "${k:-}" | tr -d '[:space:]')
    v=$(echo "${v:-}" | tr -d '[:space:]')
    case "$k" in
      HOST) [ -n "$v" ] && HOST=$v ;;
      PORT) [ -n "$v" ] && PORT=$v ;;
      PROTO) [ -n "$v" ] && PROTO=$v ;;
      MIN) [ -n "$v" ] && MIN=$v ;;
      ALL) [ -n "$v" ] && ALL=$v ;;
    esac
  done < "$STATE_FILE"
}

save_state() {
  cat > "$STATE_FILE" <<EOF
# linmon linux syslog forwarder — last applied by install-linux-syslog.sh
HOST=$HOST
PORT=$PORT
PROTO=$PROTO
MIN=$MIN
ALL=$ALL
EOF
  echo "saved $STATE_FILE"
}

load_state

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --port) PORT="${2:-}"; shift 2 ;;
    --proto) PROTO="${2:-}"; shift 2 ;;
    --min) MIN="${2:-}"; ALL="0"; shift 2 ;;
    --all) ALL="1"; shift ;;
    --test) DO_TEST="1"; shift ;;
    --uninstall) UNINSTALL="1"; shift ;;
    --setup|--reconfigure|-i|--interactive) DO_SETUP="1"; shift ;;
    --show) DO_SHOW="1"; shift ;;
    --update) DO_UPDATE="1"; shift ;;
    --install-key) INSTALL_KEY="${2:-}"; shift 2 ;;
    --install-token) INSTALL_TOKEN="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1  (try --help)" >&2; exit 2 ;;
  esac
done

HOST=$(echo "$HOST" | tr -d '[:space:]')
PORT=$(echo "$PORT" | tr -d '[:space:]')
PROTO=$(echo "$PROTO" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
MIN=$(echo "$MIN" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash $0 $*" >&2
  exit 1
fi

if [ "$PROTO" != "tcp" ]; then
  PROTO="udp"
fi

# rsyslog: @udp  @@tcp    classic syslogd: @host (port 514 implied)
fwd_target() {
  if [ "$1" = "classic" ]; then
    echo "@${HOST}"
    return
  fi
  if [ "$PROTO" = "tcp" ]; then
    echo "@@${HOST}:${PORT}"
  else
    echo "@${HOST}:${PORT}"
  fi
}

# syslog selector for traditional syntax
selector() {
  if [ "$ALL" = "1" ]; then
    echo "*.*"
    return
  fi
  # NOTE: sshd "Failed password" is usually authpriv.info (not notice).
  # authpriv.notice would miss SSH login failures on Ubuntu/Debian.
  case "$MIN" in
    debug) echo "*.*;auth,authpriv.none" ;;
    info|information) echo "*.info;*.notice;*.warn;*.err;*.crit;*.alert;*.emerg" ;;
    warn|warning) echo "*.warn;*.err;*.crit;*.alert;*.emerg;auth,authpriv.info;kern.warning" ;;
    crit|critical) echo "*.crit;*.alert;*.emerg;auth,authpriv.err" ;;
    *) echo "*.err;*.crit;*.alert;*.emerg;auth,authpriv.info;kern.err" ;;
  esac
}

filter_label() {
  if [ "$ALL" = "1" ]; then
    echo "ALL (*.*)"
  else
    echo "min=${MIN} (+ auth / kernel)"
  fi
}

detect() {
  if command -v rsyslogd >/dev/null 2>&1 || [ -d /etc/rsyslog.d ] || [ -f /etc/rsyslog.conf ]; then
    echo rsyslog
  elif [ -f /etc/syslog-ng/syslog-ng.conf ] || command -v syslog-ng >/dev/null 2>&1; then
    echo syslog-ng
  elif [ -f /etc/syslog.conf ]; then
    echo classic
  else
    echo none
  fi
}

reload_syslog() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart rsyslog 2>/dev/null && return 0
    systemctl restart syslog-ng 2>/dev/null && return 0
    systemctl restart syslog 2>/dev/null && return 0
  fi
  if command -v service >/dev/null 2>&1; then
    service rsyslog restart 2>/dev/null && return 0
    service syslog-ng restart 2>/dev/null && return 0
    service sysklogd restart 2>/dev/null && return 0
    service syslog restart 2>/dev/null && return 0
  fi
  if [ -x /etc/init.d/rsyslog ]; then
    /etc/init.d/rsyslog restart && return 0
  fi
  if [ -x /etc/init.d/sysklogd ]; then
    /etc/init.d/sysklogd restart && return 0
  fi
  echo "WARN: could not restart syslog — reload manually" >&2
  return 1
}

uninstall_rsyslog() {
  rm -f "/etc/rsyslog.d/${CONF_NAME}"
  if [ -f /etc/rsyslog.conf ]; then
    grep -v 'linmon-syslog-forward' /etc/rsyslog.conf > /etc/rsyslog.conf.linmon.tmp && \
      mv /etc/rsyslog.conf.linmon.tmp /etc/rsyslog.conf
  fi
}

uninstall_classic() {
  if [ -f /etc/syslog.conf ]; then
    grep -v 'linmon-syslog-forward' /etc/syslog.conf > /etc/syslog.conf.linmon.tmp && \
      mv /etc/syslog.conf.linmon.tmp /etc/syslog.conf
  fi
}

uninstall_syslog_ng() {
  rm -f /etc/syslog-ng/conf.d/linmon.conf
}

do_uninstall() {
  kind=$(detect)
  echo "==> uninstall ($kind)"
  case "$kind" in
    rsyslog) uninstall_rsyslog ;;
    syslog-ng) uninstall_syslog_ng ;;
    classic) uninstall_classic ;;
    *) echo "no known syslog config found" ;;
  esac
  rm -f "$STATE_FILE"
  reload_syslog || true
  echo "removed linmon forwarder"
}

install_rsyslog() {
  tgt=$(fwd_target rsyslog)
  sel=$(selector)
  line="${sel}  ${tgt}    # linmon-syslog-forward"
  if [ -d /etc/rsyslog.d ]; then
    dest="/etc/rsyslog.d/${CONF_NAME}"
    cat > "$dest" <<EOF
# linmon — generated by install-linux-syslog.sh  (do not edit by hand)
# Forward to ${HOST}:${PORT} ${PROTO}
${line}
EOF
    echo "wrote $dest"
  else
    uninstall_rsyslog
    echo "$line" >> /etc/rsyslog.conf
    echo "appended /etc/rsyslog.conf"
  fi
}

install_classic() {
  tgt=$(fwd_target classic)
  sel=$(selector)
  uninstall_classic
  echo "${sel}  ${tgt}    # linmon-syslog-forward" >> /etc/syslog.conf
  echo "appended /etc/syslog.conf → ${tgt}"
}

install_syslog_ng() {
  mkdir -p /etc/syslog-ng/conf.d
  dest=/etc/syslog-ng/conf.d/linmon.conf
  if [ "$PROTO" = "tcp" ]; then
    drv="network(\"${HOST}\" port(${PORT}) transport(\"tcp\"))"
  else
    drv="network(\"${HOST}\" port(${PORT}) transport(\"udp\"))"
  fi
  filt='level(err..emerg) or facility(auth, authpriv) or facility(kern)'
  if [ "$ALL" = "1" ]; then
    filt="1"
  else
    case "$MIN" in
      debug) filt="1" ;;
      info|information) filt="level(info..emerg)" ;;
      warn|warning) filt="level(warn..emerg) or facility(auth, authpriv)" ;;
      crit|critical) filt="level(crit..emerg) or facility(auth, authpriv)" ;;
    esac
  fi
  cat > "$dest" <<EOF
# linmon — generated by install-linux-syslog.sh
destination d_linmon { ${drv}; };
filter f_linmon { ${filt}; };
log { source(s_src); filter(f_linmon); destination(d_linmon); };
EOF
  echo "wrote $dest"
}

send_test() {
  msg="linmon-syslog-test $(hostname) $(date '+%Y-%m-%dT%H:%M:%S')"
  if command -v logger >/dev/null 2>&1; then
    logger -p user.err "$msg" || logger "$msg"
    echo "sent via logger: $msg"
  elif command -v nc >/dev/null 2>&1; then
    hn=$(hostname)
    printf '<11>%s %s linmon-test: %s\n' "$(date '+%b %e %H:%M:%S')" "$hn" "$msg" | nc -u -w1 "$HOST" "$PORT"
    echo "sent via nc UDP ${HOST}:${PORT}"
  else
    echo "no logger/nc — write a line yourself" >&2
    return 1
  fi
  echo "check linmon Logs → device linux / syslog   host=$(hostname)"
}

show_config() {
  kind=$(detect)
  echo "=== linmon linux syslog ==="
  echo "    daemon:  $kind"
  echo "    dest:    ${PROTO} ${HOST}:${PORT}"
  echo "    filter:  $(filter_label)"
  if [ -f "$STATE_FILE" ]; then
    echo "    state:   $STATE_FILE"
  else
    echo "    state:   (none — not applied yet, showing defaults / flags)"
  fi
  echo "    script:  v${SYSLOG_VERSION}  repo=${SYSLOG_REPO}"
  if [ -f "$DEPLOY_KEY" ]; then
    echo "    deploy key: $DEPLOY_KEY"
  elif [ -f "$TOKEN_FILE" ]; then
    echo "    github token: $TOKEN_FILE"
  else
    echo "    github:  no key — --install-key / --install-token then --update"
  fi
  echo
  for f in "/etc/rsyslog.d/${CONF_NAME}" /etc/syslog-ng/conf.d/linmon.conf /etc/rsyslog.conf /etc/syslog.conf; do
    [ -f "$f" ] || continue
    if grep -q 'linmon' "$f" 2>/dev/null; then
      echo "---- $f ----"
      grep -n 'linmon' "$f" || true
      echo
    fi
  done
}

do_install() {
  kind=$(detect)
  echo "==> syslog: $kind"
  echo "    dest:  ${PROTO} ${HOST}:${PORT}"
  echo "    filter: $(filter_label)"

  case "$kind" in
    rsyslog) install_rsyslog ;;
    syslog-ng) install_syslog_ng ;;
    classic) install_classic ;;
    none)
      echo "No rsyslog / syslog-ng / syslogd found." >&2
      echo "On Ubuntu/Debian:  apt-get install -y rsyslog   then re-run." >&2
      exit 1
      ;;
  esac

  save_state
  install_self
  reload_syslog
  echo "==> done. New messages only (no history)."
  echo "    change later:  sudo bash $0 --setup"
  echo "    or flags:      sudo bash $0 --host ${HOST} --port ${PORT} --proto ${PROTO} --min ${MIN}"
  echo "    test:          sudo bash $0 --test"
  echo "    update:        sudo ${INSTALLED_SH} --update"
}

install_self() {
  src="${BASH_SOURCE[0]:-$0}"
  case "$src" in
    /*) ;;
    *) src="$(pwd)/$src" ;;
  esac
  if [ ! -f "$src" ]; then
    return 0
  fi
  mkdir -p /usr/local/sbin "$LINMON_DIR"
  if [ "$src" != "$INSTALLED_SH" ]; then
    cp "$src" "$INSTALLED_SH"
    chmod 755 "$INSTALLED_SH"
    echo "    installed $INSTALLED_SH"
  fi
  dir="$(cd "$(dirname "$src")" && pwd)"
  if [ -f "$dir/INSTALL.sh" ]; then
    cp "$dir/INSTALL.sh" /usr/local/sbin/linmon-syslog-install
    chmod 755 /usr/local/sbin/linmon-syslog-install
  fi
  if [ -f "$dir/UPDATE.sh" ]; then
    cp "$dir/UPDATE.sh" /usr/local/sbin/linmon-syslog-update
    chmod 755 /usr/local/sbin/linmon-syslog-update
    echo "    installed /usr/local/sbin/linmon-syslog-update"
  fi
}

install_github_file() {
  # $1 dest  $2 srcfile  $3 mode
  dest="$1"
  src="$2"
  mode="$3"
  if [ -z "$src" ] || [ ! -f "$src" ]; then
    echo "missing key/token file: ${src:-}" >&2
    exit 1
  fi
  mkdir -p "$LINMON_DIR"
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  echo "installed $dest"
}

fetch_latest_dir() {
  dest="$1"
  mkdir -p "$dest"
  if [ -f "$DEPLOY_KEY" ] && command -v git >/dev/null 2>&1; then
    tmp=$(mktemp -d)
    GIT_SSH_COMMAND="ssh -i ${DEPLOY_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
      git clone --depth 1 "git@github.com:${SYSLOG_REPO}.git" "$tmp/repo"
    if [ -f "$tmp/repo/install-linux-syslog.sh" ]; then
      cp "$tmp/repo/install-linux-syslog.sh" "$dest/"
      [ -f "$tmp/repo/INSTALL.sh" ] && cp "$tmp/repo/INSTALL.sh" "$dest/"
      [ -f "$tmp/repo/UPDATE.sh" ] && cp "$tmp/repo/UPDATE.sh" "$dest/"
      rm -rf "$tmp"
      return 0
    fi
    rm -rf "$tmp"
  fi
  if [ -f "$TOKEN_FILE" ] && command -v curl >/dev/null 2>&1; then
    tok=$(tr -d '[:space:]' < "$TOKEN_FILE")
    curl -fsSL \
      -H "Authorization: Bearer ${tok}" \
      -H "Accept: application/vnd.github.raw" \
      "https://api.github.com/repos/${SYSLOG_REPO}/contents/install-linux-syslog.sh" \
      -o "$dest/install-linux-syslog.sh"
    return 0
  fi
  echo "Cannot --update: need ${DEPLOY_KEY} + git, or ${TOKEN_FILE} + curl" >&2
  echo "First install:  sudo bash INSTALL.sh --key /path/to/deploy_key" >&2
  exit 1
}

do_update() {
  echo "==> update from private ${SYSLOG_REPO}"
  tmp=$(mktemp -d)
  fetch_latest_dir "$tmp"
  if ! head -1 "$tmp/install-linux-syslog.sh" | grep -q bash; then
    echo "download does not look like the installer" >&2
    rm -rf "$tmp"
    exit 1
  fi
  mkdir -p /usr/local/sbin
  cp "$tmp/install-linux-syslog.sh" "$INSTALLED_SH"
  chmod 755 "$INSTALLED_SH"
  if [ -f "$tmp/INSTALL.sh" ]; then
    cp "$tmp/INSTALL.sh" /usr/local/sbin/linmon-syslog-install
    chmod 755 /usr/local/sbin/linmon-syslog-install
  fi
  if [ -f "$tmp/UPDATE.sh" ]; then
    cp "$tmp/UPDATE.sh" /usr/local/sbin/linmon-syslog-update
    chmod 755 /usr/local/sbin/linmon-syslog-update
  fi
  rm -rf "$tmp"
  echo "    wrote $INSTALLED_SH"
  exec bash "$INSTALLED_SH"
}

ask() {
  # $1 prompt  $2 current → prints new or current
  cur="$2"
  printf "    %s [%s]: " "$1" "$cur" >&2
  ans=""
  read -r ans || true
  if [ -n "${ans:-}" ]; then
    printf '%s' "$ans"
  else
    printf '%s' "$cur"
  fi
}

need_tty() {
  if [ -t 0 ] && [ -t 1 ]; then
    return 0
  fi
  echo "Interactive --setup needs a terminal (do not pipe the script)."
  echo
  echo "Copy the office pack, then:"
  echo "  sudo bash INSTALL.sh --key /path/to/linmon-syslog-deploy --setup"
  echo
  echo "Or apply without a menu:"
  echo "  sudo bash INSTALL.sh --key /path/to/linmon-syslog-deploy --host 192.168.3.200"
  exit 1
}

setup_menu() {
  need_tty
  while true; do
    kind=$(detect)
    echo
    echo "========================================"
    echo " Linmon Linux syslog  —  change settings"
    echo "========================================"
    echo "  daemon : $kind"
    echo "  host   : $HOST"
    echo "  port   : $PORT"
    echo "  proto  : $PROTO"
    echo "  filter : $(filter_label)"
    echo
    echo "  1) Change host"
    echo "  2) Change port"
    echo "  3) Change protocol  (udp / tcp)"
    echo "  4) Change filter    (err / warn / crit / info / debug / all)"
    echo "  5) Apply + restart syslog"
    echo "  6) Send test message"
    echo "  7) Show installed files"
    echo "  8) Uninstall"
    echo "  9) Update script from private GitHub"
    echo "  0) Quit"
    echo
    printf "Select [0-9]: "
    choice=""
    read -r choice || true
    case "${choice:-}" in
      1)
        HOST=$(ask "linmon host / IP" "$HOST")
        HOST=$(echo "$HOST" | tr -d '[:space:]')
        ;;
      2)
        PORT=$(ask "port" "$PORT")
        PORT=$(echo "$PORT" | tr -d '[:space:]')
        ;;
      3)
        p=$(ask "protocol udp|tcp" "$PROTO")
        p=$(echo "$p" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
        if [ "$p" = "tcp" ]; then PROTO=tcp; else PROTO=udp; fi
        ;;
      4)
        echo "    err=default  warn  crit  info  debug  all"
        f=$(ask "filter" "$MIN")
        f=$(echo "$f" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
        case "$f" in
          all|'*.*') ALL=1 ;;
          debug|info|information|warn|warning|crit|critical|err|error)
            ALL=0
            MIN=$f
            ;;
          *)
            echo "    unknown filter — keeping $(filter_label)"
            ;;
        esac
        ;;
      5)
        do_install
        ;;
      6)
        send_test
        ;;
      7)
        show_config
        ;;
      8)
        do_uninstall
        ;;
      9)
        do_update
        ;;
      0|"")
        echo "bye (nothing applied unless you chose 5)"
        exit 0
        ;;
      *)
        echo "    pick 0–8"
        ;;
    esac
  done
}

# --- main ---

if [ -n "$INSTALL_KEY" ]; then
  install_github_file "$DEPLOY_KEY" "$INSTALL_KEY" 600
fi
if [ -n "$INSTALL_TOKEN" ]; then
  install_github_file "$TOKEN_FILE" "$INSTALL_TOKEN" 600
fi
if [ -n "$INSTALL_KEY" ] || [ -n "$INSTALL_TOKEN" ]; then
  if [ "$DO_UPDATE" != "1" ] && [ "$DO_SETUP" != "1" ] && [ "$DO_SHOW" != "1" ] && [ "$UNINSTALL" != "1" ] && [ "$DO_TEST" != "1" ]; then
    echo "key installed. Next: sudo bash $0 --setup   or   sudo bash $0 --host …"
    exit 0
  fi
fi

if [ "$DO_UPDATE" = "1" ]; then
  do_update
fi

if [ "$DO_SHOW" = "1" ]; then
  show_config
  exit 0
fi

if [ "$DO_SETUP" = "1" ]; then
  setup_menu
  exit 0
fi

if [ "$UNINSTALL" = "1" ]; then
  do_uninstall
  exit 0
fi

if [ "$DO_TEST" = "1" ]; then
  send_test
  exit 0
fi

do_install
