# Install Linux host client (syslog forwarder)

**Public** (no GitHub token, **shell only** — not PowerShell):

https://github.com/andylee03/linmon-winlog/blob/main/INSTALL-LINUX-HOST-CLIENT.md

Scripts:

- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh

This is **not** a linmon server install. It only configures the Linux box to **forward syslog** to linmon on **UDP/TCP 514**. There is **no extra agent binary** (rsyslog / syslog-ng / syslogd).

**HK blueprint:** `--host 192.168.3.200` (the machine behind **https://syslog.athenabest.com**).  
Do **not** send to `172.16.0.20` or to the HTTPS name.

---

## Before you start

- Ubuntu/Debian/RHEL, `sudo`, `wget`
- `sudo apt-get install -y rsyslog` if needed
- Network to linmon **514/udp** and/or **514/tcp**

```bash
wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
```

Expect HTTP **200**. Then install.

---

## INSTALL

Download the shell installer, then run it:

```bash
wget -qO /tmp/INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh

# menu (needs a real terminal)
sudo bash /tmp/INSTALL.sh --setup

# no menu — HK linmon
sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
```

One line (no `--setup`):

```bash
wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh \
  | sudo bash -s -- --host 192.168.3.200 --port 514 --proto udp --min err
```

VPN/NAT: use `--proto tcp`.

---

## UPDATE

```bash
wget -qO /tmp/UPDATE.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
sudo bash /tmp/UPDATE.sh
```

Or:

```bash
wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh | sudo bash
```

Re-downloads `install-linux-syslog.sh` and applies the saved `/etc/linmon-syslog.conf`.

---

## Flags (passed through to the installer)

| Flag | Meaning |
|------|---------|
| `--host` | linmon IP (HK: `192.168.3.200`) |
| `--port` | `514` |
| `--proto` | `udp` or `tcp` |
| `--min` | `err` (default) · `warn` · `crit` · `info` · `debug` |
| `--all` | send everything |
| `--setup` | menu (file, not pipe) |
| `--test` | one test line |
| `--show` | print saved config |
| `--uninstall` | remove forwarder |

Default `--min err`: err/crit/alert/emerg + auth + kernel. No history dump.

---

## After install

```bash
sudo bash /tmp/INSTALL.sh --test
```

On **https://syslog.athenabest.com** → **Logs** → linux. Host = this machine’s hostname.

If the IP is `172.16.0.1`, an admin sets **MENU → Syslog Setup**: `hostname=LAN-IP`.

---

## Files on the client

| Path | Role |
|------|------|
| `/etc/rsyslog.d/99-linmon.conf` | Forwarder |
| `/etc/linmon-syslog.conf` | Last host/port/proto/filter |

---

## If it fails

| Symptom | Check |
|---------|--------|
| spider not 200 | GitHub / TLS |
| `--setup` from a pipe | `wget -qO /tmp/INSTALL.sh` then `sudo bash /tmp/INSTALL.sh --setup` |
| No rsyslog | `sudo apt-get install -y rsyslog` |
| No logs | `--host` is **192.168.3.200**, not the HTTPS name; firewall 514; `--test` |
