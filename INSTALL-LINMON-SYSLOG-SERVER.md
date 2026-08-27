# LINMON syslog server — installation guide

**Audience:** operator installing a new Ubuntu amd64 host that **receives** syslog (UDP/TCP 514) and serves the LINMON web UI.

**Not this document:** Linux **client** rsyslog forwarder, Windows Winlog, or the `vide` source tree.

| Item | Value |
|------|--------|
| Runtime directory | `/data/linmon` |
| Web | HTTP `:80` until TLS certificates are installed; then HTTPS `:443` |
| Syslog | Host LAN IP, port **514/udp** and **514/tcp** (never the website hostname) |
| Source of binaries / images | Private GitHub `andylee03/linmon-bin` (no source code) |
| Bootstrap script | Public `https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh` |
| Office publish | `.\scripts\release-linmon-bin.ps1` on the development PC |

Do not clone `andylee03/vide` onto the server. Do not copy `.env` or `configs/linmon.json` from another site.

---

## 1. Credentials

Office path: `D:\vide\keys\`. GitHub deploy keys are **read-only** and **one key per repository**.

| File | Purpose | Used by this install |
|------|---------|----------------------|
| `linmon-bin-deploy` (private key; not `.pub`) | Clone `andylee03/linmon-bin` | **Yes.** Same file as 3.200 / 11.4 `~/.linmon/bin_deploy` |
| `linmon-syslog-deploy` | Clone `andylee03/linmon-syslog` (Linux **client** pack) | No |
| `id_ed25519` | SSH to existing hosts (3.200:7788, 11.4:22) | No |

Public Linux client installer (`linmon-winlog` `INSTALL.sh`) does not use a key.

| Check | Pass | Fail |
|-------|------|------|
| File type | First line `-----BEGIN OPENSSH PRIVATE KEY-----`, ~400 bytes | `.pub` file; PEM password blob; `id_ed25519` |
| Git clone | `git@github.com:andylee03/linmon-bin.git` succeeds with this key | `Permission denied (publickey)` — wrong key |

Copy **only** `linmon-bin-deploy` to the new host (for example `~/linmon-bin-deploy`). Mode `600`.

---

## 2. Host prerequisites

Ubuntu amd64. Unprivileged user in group `docker` (example `athenabest`). **Do not run INSTALL as root.**

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git openssl
sudo usermod -aG docker "$USER"
```

Log out and log in (or `newgrp docker`). Open **80/tcp, 443/tcp, 514/udp, 514/tcp**.

```bash
sudo mkdir -p /data/linmon
sudo chown "$USER:$USER" /data/linmon
id
docker info
```

| Check | Pass | Fail |
|-------|------|------|
| `id` | `groups=` includes `docker` | `docker` missing → log in again after `usermod` |
| `docker info` (no sudo) | Output contains `Server:` | `permission denied` … `docker.sock` → group not active |
| | | `Cannot connect to the Docker daemon` → `sudo systemctl start docker` |
| `/data/linmon` | Owned by the installing user | Owned by `root` → INSTALL cannot write `.env` |

```bash
id | grep -q docker && echo "id: OK" || echo "id: FAIL"
docker info >/dev/null 2>&1 && echo "docker info: OK" || echo "docker info: FAIL"
```

Both lines must print `OK`. If `docker-compose-v2` is missing: `sudo apt-get install -y docker.io docker-compose git openssl`.

---

## 3. Install (GitHub)

Copy `linmon-bin-deploy` onto the host, then pass its **real path** (the file must exist; `./` is relative to the current directory).

```bash
ls -l "$HOME/linmon-bin-deploy"    # must exist before INSTALL
wget -qO /tmp/SERVER-INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
bash /tmp/SERVER-INSTALL.sh --key "$HOME/linmon-bin-deploy" --dir /data/linmon
```

If the shell is in `/tmp` and the key is in the home directory, `--key ./linmon-bin-deploy` fails (`key file not found`). Use `"$HOME/linmon-bin-deploy"`.

The script clones `andylee03/linmon-bin` (image tarball, compose files, `linmon` / `collect-log` binaries), loads images, starts Compose, then copies binaries into the containers.

| Stage | Pass | Fail |
|-------|------|------|
| `wget` | `/tmp/SERVER-INSTALL.sh` starts with `#!/bin/bash` | HTTP 404 — bootstrap not on `linmon-winlog` |
| Key | Log line `wrote …/.linmon/bin_deploy` | `key file not found: ./linmon-bin-deploy` — file is not in the current directory; use `$HOME/linmon-bin-deploy` |
| Clone | `Cloning into` `andylee03/linmon-bin` | `Permission denied (publickey)` — not `linmon-bin-deploy` |
| Images | `Loaded image: linmon:latest` (and nginx / rdp-enc) | `linmon-images.tgz missing` — office must run `release-linmon-bin.ps1` |
| Compose | Containers `Up` / `healthy` | `do not run as root`; `docker not usable` |
| API | JSON from `/api/version` (see below) | `curl: (7) Failed to connect` — `docker ps`, `docker logs linmon-nginx --tail 50` |
| nginx TLS | First boot uses HTTP (`ENABLE_HTTPS=0`) | nginx exits: `ENABLE_HTTPS=1 but … pem missing` |

```bash
docker ps
curl -sS http://127.0.0.1/api/version
```

Pass (example):

```text
{"version":"1.4.95","commit":"705def0","build_time":"…","go_version":"…","display":"v1.4.95 · 705def0"}
```

`docker ps` should list `linmon`, `linmon-postgres`, `linmon-nginx`, `linmon-collect-log`, and typically `linmon-guacd`, `linmon-rdp-enc`.

Browser: `http://<LAN-IP>/` — LINMON login. Syslog clients use **`<LAN-IP>`**, not the HTTPS name.

---

## 4. Updates

Does not drop Postgres volumes or rewrite `.env` / `linmon.json`. Restarts `linmon` and `linmon-collect-log` for a few seconds.

```bash
bash /data/linmon/UPDATE.sh
```

| Check | Pass | Fail |
|-------|------|------|
| Fetch | Sparse clone of `linmon-bin`; `docker cp`; JSON `commit` matches latest `release-linmon-bin.ps1` | `Permission denied (publickey)` — restore key with `INSTALL.sh --key ./linmon-bin-deploy` |
| | | `git: command not found` — `sudo apt-get install -y git` |

Office:

```powershell
.\scripts\release-linmon-bin.ps1
```

Pass: `pushed main` on `andylee03/linmon-bin`.

---

## 5. Site configuration

Change the example web password on first login. Use **Host Setup** and **Syslog Setup** for this site only.

TLS: install `/data/linmon/certs/fullchain.pem` and `privkey.pem`, set `ENABLE_HTTPS=1` in `/data/linmon/.env`, then:

```bash
cd /data/linmon
bash scripts/dc.sh up -d
curl -skS https://127.0.0.1/api/version
```

Pass: JSON on HTTPS; HTTP to the same host returns **301**. Fail: nginx missing those exact certificate filenames.

---

## 6. Linux client (sends logs to this server)

Run on **another** host, not on the syslog server’s own LAN IP (Docker hairpin drops those packets).

```bash
wget -qO /tmp/INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host <SERVER-LAN-IP> --port 514 --proto udp --min err
logger -p user.err 'linmon-syslog-test from this host'
```

Pass: `/etc/rsyslog.d/99-linmon.conf` exists; server UI **Logs → linux (error)** shows the client hostname.  
Fail: no row — check 514/udp, `--host` is the LAN IP, and the log type is **linux (error)** (not `linux`, which is SSH poll).

---

## Appendix A — USB when GitHub is unreachable

Office: `.\scripts\pack-linmon-server.ps1` and `.\scripts\release-linmon-bin.ps1`. Copy:

- `D:\vide\dist\linmon-server\` (includes `linmon-images.tgz` ~91 MB)
- `D:\vide\dist\linmon-bin\` including `linmon-bin-deploy`

On the host:

```bash
bash /tmp/linmon-server/INSTALL.sh --dir /data/linmon
bash /tmp/linmon-bin/INSTALL.sh --key /tmp/linmon-bin/linmon-bin-deploy --dir /data/linmon
```

Do not copy `linmon.json`, `.env`, `certs/`, or `id_ed25519` from 3.200.

---

## Appendix B — Constraints

| Prohibited | Reason |
|------------|--------|
| `sudo bash SERVER-INSTALL.sh` / `INSTALL.sh` | Process must use the docker group socket |
| Client `--host` = this server’s LAN IP, run **on** this server | Hairpin NAT; syslog never reaches the container |
| `git pull` of `vide` on the server | Source remains on the office PC |
| Reuse another site’s `.env` / `linmon.json` | `LINMON_SECRET_KEY` is per host |
