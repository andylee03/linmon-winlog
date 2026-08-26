# linmon-winlog

Public **download** repo for LINMON agents (no token).

Source code stays in the private `vide` repo.

## Windows Event Log agent

- Releases: [`linmon-winlog-setup.exe`](https://github.com/andylee03/linmon-winlog/releases)
- On Windows: tray → **Update from GitHub…**
- Tag format: `winlog-v1.0.4`

## Linux syslog forwarder

Public **shell** install (not PowerShell): [INSTALL-LINUX-HOST-CLIENT.md](INSTALL-LINUX-HOST-CLIENT.md)

`ash
wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh

wget -qO /tmp/INSTALL.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
`

Update:

`ash
wget -qO /tmp/UPDATE.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
sudo bash /tmp/UPDATE.sh
`

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
