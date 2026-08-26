# Install Linux host client (syslog forwarder)

**Public** (no GitHub token, **shell only** — not PowerShell):

https://github.com/andylee03/linmon-winlog/blob/main/INSTALL-LINUX-HOST-CLIENT.md

Scripts:

- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh

This is **not** a linmon server install. It only configures the Linux box to **forward syslog** to linmon on **UDP/TCP 514**. There is **no extra agent binary** (rsyslog / syslog-ng / syslogd).

**Where to send (`--host`)** — the **linmon server LAN IP**, never the website name:

| Site | Run INSTALL **on** | `--host` |
|------|---------------------|----------|
| Hong Kong | A Linux **client** (not 3.200 itself) | `192.168.3.200` |
| Singapore | A Linux **client** (not 11.4 itself) | `192.168.11.4` |

Do **not** use `https://syslog.athenabest.com` or Docker `172.16.0.20` as `--host` on a **normal client**.

**Do not run INSTALL on the linmon server** to send to its **own** LAN IP (`--host 192.168.11.4` **on** 11.4, or `--host 192.168.3.200` **on** 3.200). Docker will listen on 514, but rsyslog talking to that same host IP often **never arrives** (hairpin). FortiGate/other PCs can still send fine.

If you really must collect rsyslog from the linmon box itself, point at the **container** IP:

```bash
# only when this Linux machine *is* the linmon Docker host
sudo bash /tmp/INSTALL.sh --host 172.16.0.20 --port 514 --proto udp --min err
# or after a wrong install:
sudo sed -i 's/@192.168.11.4:514/@172.16.0.20:514/' /etc/rsyslog.d/99-linmon.conf
sudo systemctl restart rsyslog
```

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

# no menu — HK linmon (run this ON another Linux PC, not on 3.200)
sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err

# Singapore linmon (run ON another Linux PC, not on 11.4)
sudo bash /tmp/INSTALL.sh --host 192.168.11.4 --port 514 --proto udp --min err
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

Open the linmon website for **that** server:

- HK: **https://syslog.athenabest.com**
- SG: the 11.4 HTTPS URL (not syslog.athenabest.com)

**MENU → Logs**. Device type is **`linux (error)`** / `linux_error`, **not** `linux`.  
`linux` in the database is SSH poll snapshots. rsyslog lines are **`linux_error`**.

Host name = this machine’s **hostname** (e.g. `scandoc-sg`).

If the IP is `172.16.0.1`, an admin sets **MENU → Syslog Setup**: `hostname=LAN-IP`.

Test:

```bash
logger -p user.err 'linmon-syslog-test from this host'
```

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
| No logs in UI | Filter **linux (error)** not `linux`; `--host` is linmon **IP**; `--test` / `logger -p user.err` |
| Install ran on linmon server, still no logs | Hairpin: you used `--host` = this machine’s LAN IP. Use `172.16.0.20` or install on a **different** Linux box |
| Logs appear on HK but you wanted SG | You used `--host 192.168.3.200`; SG needs `192.168.11.4` |
