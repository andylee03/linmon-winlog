# linmon-winlog

Public **download** repo for LINMON agents (no token).

Source code stays in the private `vide` repo.

## Windows Event Log agent

- Releases: [`linmon-winlog-setup.exe`](https://github.com/andylee03/linmon-winlog/releases)
- On Windows: tray → **Update from GitHub…**
- Tag format: `winlog-v1.0.4`

## Linux syslog forwarder

Full install steps (public, no token):
[INSTALL-LINUX-HOST-CLIENT.md](INSTALL-LINUX-HOST-CLIENT.md)

Download and open the settings menu (host / port / proto / filter):

```bash
curl -fsSL -o /tmp/install-linux-syslog.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh
sudo bash /tmp/install-linux-syslog.sh --setup
```

One-shot (no menu, pipe-safe):

```bash
curl -fsSL https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh \
  | sudo bash -s -- --host 192.168.3.200 --port 514 --proto udp --min err
```

Options:

| Flag | Meaning |
|------|---------|
| `--setup` / `--reconfigure` | Interactive menu (needs a terminal) |
| `--show` | Print saved + installed config |
| `--host` | linmon IP / name (default `192.168.3.200`) |
| `--port` | default `514` |
| `--proto` | `udp` or `tcp` |
| `--min` | `err` (default) / `warn` / `crit` / `info` / `debug` |
| `--all` | send everything |
| `--test` | send one test message |
| `--uninstall` | remove forwarder |

Default: UDP `192.168.3.200:514`, only err/crit + auth + kernel. Last apply is stored in `/etc/linmon-syslog.conf`.

## Proxmox VE API token (linmon Host Setup)

Run as **root on the PVE host** (no GitHub token):

```bash
wget -qO /tmp/install-pve-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
bash /tmp/install-pve-linmon-api.sh
```

Paste Token ID `linmon@pve!linmon` + secret into linmon Host Setup (Kind `pve`, Port `8006`). `--recreate` issues a new secret.

## Proxmox Backup Server API token

Run as **root on the PBS host**:

```bash
wget -qO /tmp/install-pbs-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
bash /tmp/install-pbs-linmon-api.sh
```

Host Setup: Kind `pbs`, Port `8007`, User `linmon@pbs!linmon`, Password = secret.
