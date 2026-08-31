# linmon-winlog

Public **download** repo for LINMON agents (no token).

Source code stays in the private `vide` repo.

## Guides

- [User Guide](LINMON-USER-GUIDE.md) — login, TOTP, dashboard, Logs
- [Administrator Guide](LINMON-ADMIN-GUIDE.md) — Host/Syslog/User Setup, SMTP, Linux client, server UPDATE
- [Linux host client (rsyslog)](INSTALL-LINUX-HOST-CLIENT.md) — public wget INSTALL / UPDATE
- [LINMON server install](INSTALL-LINMON-SYSLOG-SERVER.md) — Docker host (`SERVER-INSTALL.sh`)

## Windows Event Log agent

- Releases: [`linmon-winlog-setup.exe`](https://github.com/andylee03/linmon-winlog/releases)
- On Windows: tray ? **Update from GitHub.**
- Tag format: `winlog-v1.0.4`

## Linux syslog forwarder

Public **shell** install (not PowerShell): [INSTALL-LINUX-HOST-CLIENT.md](INSTALL-LINUX-HOST-CLIENT.md)

Installer **v1.0.2+** includes SSH Failed password (`authpriv.info`).

```bash
wget -S --spider https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh

wget -qO /tmp/INSTALL.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
```

Update:

```bash
wget -qO /tmp/UPDATE.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
sudo bash /tmp/UPDATE.sh
```

If UPDATE fails with `error in libcrypto` on `/etc/linmon/github_deploy`, move that key aside and wget `install-linux-syslog.sh` (see the Linux client doc).

## Proxmox VE API token (linmon Host Setup)

Run as **root on the PVE host** (no GitHub token):

```bash
wget -qO /tmp/install-pve-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
bash /tmp/install-pve-linmon-api.sh
```

## Proxmox Backup Server API token

Run as **root on the PBS host**:

```bash
wget -qO /tmp/install-pbs-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
bash /tmp/install-pbs-linmon-api.sh
```

Host Setup: Kind `pbs`, Port `8007`, User `linmon@pbs!linmon`, Password = secret.
