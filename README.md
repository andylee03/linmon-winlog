# linmon-winlog

Public **download** repo for LINMON agents (no token).

Source code stays in the private `vide` repo.

## Windows Event Log agent

- Releases: [`linmon-winlog-setup.exe`](https://github.com/andylee03/linmon-winlog/releases)
- On Windows: tray → **Update from GitHub…**
- Tag format: `winlog-v1.0.4`

## Linux syslog forwarder

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
