# Install Linux host client (syslog forwarder)

**Public** (no GitHub token):  
https://github.com/andylee03/linmon-winlog/blob/main/INSTALL-LINUX-HOST-CLIENT.md  
https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL-LINUX-HOST-CLIENT.md

This is **not** a linmon server install. It only configures the Linux box to **forward syslog** to linmon on **UDP/TCP 514**.

There is **no extra agent binary**. The script writes rsyslog / syslog-ng / syslogd.

**HK blueprint:** send to **`192.168.3.200:514`** (the host behind **https://syslog.athenabest.com**).  
Do **not** send to `172.16.0.20` or to the HTTPS URL.

Product user/admin guides live in the private `vide` repo (`docs/LINMON-USER-GUIDE.md`, `docs/LINMON-ADMIN-GUIDE.md`).

---

## Before you start

On the Linux client:

- Ubuntu/Debian/RHEL (amd64 is fine)
- `rsyslog` installed (`sudo apt-get install -y rsyslog` if missing)
- Network to linmon: **514/udp** and/or **514/tcp**
- Root (`sudo`)

Check the installer URL is reachable:

```bash
wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh
```

Expect HTTP **200**. Then continue.

---

## Path A — public wget (quick, no deploy key)

Use this for a one-off host. Updates later are another wget (the public file may lag the private pack).

```bash
wget -qO /tmp/install-linux-syslog.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh

# menu
sudo bash /tmp/install-linux-syslog.sh --setup

# or no menu — HK linmon
sudo bash /tmp/install-linux-syslog.sh --host 192.168.3.200 --port 514 --proto udp --min err
```

Pipe (no `--setup`; needs flags):

```bash
wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh \
  | sudo bash -s -- --host 192.168.3.200 --port 514 --proto udp --min err
```

Across VPN/NAT prefer **`--proto tcp`**.

---

## Path B — country pack (INSTALL.sh + UPDATE.sh)

Office USB/scp: `dist/linmon-syslog/` from `.\scripts\pack-linux-syslog.ps1`, plus read-only deploy key `linmon-syslog-deploy`.

Private repo: `andylee03/linmon-syslog` (not `vide`, not Winlog).

```bash
cd /path/to/linmon-syslog

sudo bash INSTALL.sh --key ./linmon-syslog-deploy --host 192.168.3.200 --port 514 --proto udp --min err

# or menu
sudo bash INSTALL.sh --key ./linmon-syslog-deploy --setup
```

Later (key already on the box):

```bash
sudo bash UPDATE.sh
# or:
sudo linmon-syslog-update
```

Key is stored as `/etc/linmon/github_deploy`. If it leaks, others can only pull this installer, not `linmon.json`.

---

## Flags

| Flag | Meaning |
|------|---------|
| `--host` | linmon IP (HK: `192.168.3.200`) |
| `--port` | `514` |
| `--proto` | `udp` or `tcp` |
| `--min` | `err` (default) · `warn` · `crit` · `info` · `debug` |
| `--all` | send everything |
| `--setup` | interactive menu (needs a terminal; do not pipe) |
| `--test` | send one test line |
| `--show` | print saved config |
| `--uninstall` | remove forwarder (keeps deploy key) |
| `--key FILE` | INSTALL.sh only: install GitHub deploy key |

Default filter (`--min err`): err/crit/alert/emerg + auth + kernel. **No history** is dumped — only new messages after reload.

---

## After install

```bash
sudo /usr/local/sbin/install-linux-syslog.sh --show
sudo /usr/local/sbin/install-linux-syslog.sh --test
```

On **https://syslog.athenabest.com** → **Logs** → linux. Host = this machine’s **hostname**.

If the IP shows as `172.16.0.1`, an admin sets **MENU → Syslog Setup**: `hostname=LAN-IP`.

---

## Files on the client

| Path | Role |
|------|------|
| `/etc/rsyslog.d/99-linmon.conf` | Forwarder |
| `/etc/linmon-syslog.conf` | Last host/port/proto/filter |
| `/etc/linmon/github_deploy` | Private-repo key (path B only) |
| `/usr/local/sbin/install-linux-syslog.sh` | Installed script |
| `/usr/local/sbin/linmon-syslog-update` | Path B update |

---

## If it fails

| Symptom | Check |
|---------|--------|
| spider / wget not 200 | GitHub reachability; TLS; use Path B pack |
| `--setup` from a pipe | Download to a file first, then run `--setup` |
| No rsyslog | `sudo apt-get install -y rsyslog` and run again |
| No logs in linmon | `--host` is **192.168.3.200** (not the HTTPS name); firewall 514; `--test` |
| `syslog not connected` | That message is Winlog (Windows). This client is Linux rsyslog. |
