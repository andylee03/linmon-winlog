# Hand install: LINMON syslog **server** on a new host

This is the **server that receives logs** (web UI + **514/udp+tcp**).  
It is **not** the public Linux **client** `INSTALL.sh` (that only forwards rsyslog).

Source stays on the office PC. The new host does **not** `git clone vide`.

---

## Which key?

Office folder: `D:\vide\keys\`

| File | Use it for | Not for |
|------|------------|---------|
| **`linmon-bin-deploy`** (private, no `.pub`) | **This guide** — syslog **server** `SERVER-INSTALL.sh` / `UPDATE.sh` | Linux client rsyslog; SSH to 3.200/11.4 |
| `linmon-syslog-deploy` | Linux **client** private pack `andylee03/linmon-syslog` | Server INSTALL |
| `id_ed25519` | SSH into 3.200 / 11.4 as `athenabest` | GitHub deploy / INSTALL `--key` |

It is the **same** `linmon-bin-deploy` already used on 3.200 and 11.4 (`~/.linmon/bin_deploy`). GitHub allows one deploy key per repo, so the **syslog** key cannot clone `linmon-bin`.

Public Linux **client** wget (`andylee03/linmon-winlog` `INSTALL.sh`) needs **no** key.

**Expected (`linmon-bin-deploy`):** first line `-----BEGIN OPENSSH PRIVATE KEY-----`, size ~411 bytes.  
**Error:** you copied `linmon-bin-deploy.pub` — INSTALL needs the **private** file.  
**Error:** `Permission denied (publickey)` on clone — you used syslog key or `id_ed25519`.

---

## 0. Download from GitHub (no scp of the 90MB tgz)

You only copy **one small file** to the new host: **`linmon-bin-deploy`** (see table above). Everything else is `git clone` of private `andylee03/linmon-bin` (Docker images tgz + linux bins + compose + INSTALL).

On the **new host** (docker-group user, **not root**):

```bash
# --key must be linmon-bin-deploy (same key as 3.200 / 11.4). See “Which key?” above.
wget -qO /tmp/SERVER-INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh
bash /tmp/SERVER-INSTALL.sh --key ./linmon-bin-deploy --dir /data/linmon
```

`--key ./linmon-bin-deploy` is **not** the syslog client key and **not** `id_ed25519`. It is the **same** private file as office `D:\vide\keys\linmon-bin-deploy` and as `~/.linmon/bin_deploy` on 3.200 / 11.4.

**Expected (`wget`):** file `/tmp/SERVER-INSTALL.sh` exists; first line `#!/bin/bash`.  
**Expected (`SERVER-INSTALL.sh`):** `Clone git@github.com:andylee03/linmon-bin.git`, `docker load`, `docker compose up`, `docker cp`, then JSON from `/api/version`.  
**Expected (key):** `wrote /home/…/.linmon/bin_deploy`

**Error:** `wget` 404 — `SERVER-INSTALL.sh` not on `linmon-winlog` yet; office must push it.  
**Error:** `ERROR: --key FILE is required` / `key file not found` — put **`linmon-bin-deploy`** (private, no `.pub`) in the current directory and pass `--key ./linmon-bin-deploy`.  
**Error:** `Permission denied (publickey)` — **wrong key**. Do not use `linmon-syslog-deploy` or `id_ed25519`. Copy `D:\vide\keys\linmon-bin-deploy` again.  
**Error:** `linmon-images.tgz missing` — office must run `.\scripts\release-linmon-bin.ps1` so the tgz is in the private repo.  
**Error:** `ERROR: do not run as root` — drop `sudo`.

Office publish (after source commit):

```powershell
.\scripts\release-linmon-bin.ps1
```

**Expected:** `pushed main` on `andylee03/linmon-bin` (includes `linmon-images.tgz`).

---

## 0b. Optional USB (only if GitHub is unreachable)

On the office PC:

| Folder | What |
|--------|------|
| `D:\vide\dist\linmon-server\` | Docker stack + `linmon-images.tgz` + `INSTALL.sh` |
| `D:\vide\dist\linmon-bin\` | linux amd64 bins + `linmon-bin-deploy` |

If `linmon-images.tgz` (~90MB) is missing:

```powershell
cd D:\vide
.\scripts\pack-linmon-server.ps1
```

**Expected (pack):** last lines like:

```text
    90.8 MB
pack: D:\vide\dist\linmon-server
```

`Test-Path D:\vide\dist\linmon-server\linmon-images.tgz` is `True`.

**Error:** `missing image linmon:latest` — run `.\scripts\build.ps1` first, then pack again.  
**Error:** `pack produced empty ...tgz` — Docker save failed; `docker image ls` must show `linmon`, `linmon-nginx`, `linmon-rdp-enc`.

If `linmon-bin` is incomplete:

```powershell
.\scripts\release-linmon-bin.ps1
Copy-Item -Force .\keys\linmon-bin-deploy .\dist\linmon-bin\linmon-bin-deploy
```

**Expected (release):** `pushed main` and `private: https://github.com/andylee03/linmon-bin`.  
`D:\vide\dist\linmon-bin\` contains `linmon`, `collect-log`, `INSTALL.sh`, `linmon-bin-deploy` (no `.pub` required on the host).

**Error:** `go not found` / `gh CLI not found` — install Go and GitHub CLI on the office PC.  
**Error:** missing `linmon-bin-deploy` — copy from `D:\vide\keys\linmon-bin-deploy` (private key).

Copy onto the new host, for example:

```text
/tmp/linmon-server/
/tmp/linmon-bin/
```

**Do not** copy `configs/linmon.json`, `.env`, `certs/`, or `keys/id_ed25519` from 3.200.

On the new host:

```bash
ls -l /tmp/linmon-server/INSTALL.sh /tmp/linmon-server/linmon-images.tgz /tmp/linmon-server/docker-compose.yml
ls -l /tmp/linmon-bin/INSTALL.sh /tmp/linmon-bin/linmon /tmp/linmon-bin/collect-log /tmp/linmon-bin/linmon-bin-deploy
```

**Expected:** six files listed, sizes roughly: `linmon-images.tgz` ~90MB, `linmon` ~13MB, `collect-log` ~8MB, `linmon-bin-deploy` a few hundred bytes.

**Error:** `No such file or directory` — USB/scp incomplete; copy the whole folders again.

---

## 1. Prepare the host (Ubuntu amd64)

Use a normal user (e.g. `athenabest`). **Do not run INSTALL as root.**

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git openssl
sudo usermod -aG docker "$USER"
```

**Expected:** `apt-get` finishes with `0` errors; `usermod` prints nothing.

**Error:** `Unable to locate package docker-compose-v2` — try `sudo apt-get install -y docker.io docker-compose git openssl` (plugin name varies by Ubuntu).  
**Error:** `usermod: user '…' does not exist` — you are not logged in as that user; run `whoami` and use that name.

**Log out and log in again** (or `newgrp docker`), then check:

```bash
id
docker info
```

### `id`

**Expected:** the word `docker` appears in `groups=` (uid/name can differ):

```text
uid=1000(athenabest) gid=1000(athenabest) groups=1000(athenabest),27(sudo),113(docker)
```

**Error (no `docker` group)** — log out and back in after `usermod`:

```text
uid=1000(athenabest) gid=1000(athenabest) groups=1000(athenabest),27(sudo)
```

### `docker info`

Must **exit 0**, **no sudo**. **Expected:** a `Server:` section (daemon is up):

```text
Client:
 Version:    27.x.x
 ...
Server:
 Containers: 0
  Running: 0
 ...
 Server Version: 27.x.x
 Storage Driver: overlay2
```

**Error** — still not in group `docker` (or need `newgrp docker` / re-login):

```text
permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

**Error** — Docker service is down (`sudo systemctl start docker`, then `docker info` again without sudo):

```text
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

Quick check (both lines should print `OK`):

```bash
id | grep -q docker && echo "id: OK" || echo "id: MISSING docker group"
docker info >/dev/null 2>&1 && echo "docker info: OK" || echo "docker info: FAIL"
```

**Expected:**

```text
id: OK
docker info: OK
```

Open firewall ports: **80/tcp, 443/tcp, 514/udp, 514/tcp**.

```bash
sudo mkdir -p /data/linmon
sudo chown "$USER:$USER" /data/linmon
ls -ld /data/linmon
```

**Expected:** directory owned by your user, not `root`:

```text
drwxr-xr-x 2 athenabest athenabest 4096 ... /data/linmon
```

**Error:** still `root root` — `chown` was skipped; INSTALL cannot write configs.

---

## 2. First time: start the syslog server stack

```bash
cd /tmp/linmon-server
ls -l INSTALL.sh linmon-images.tgz docker-compose.yml
bash INSTALL.sh --dir /data/linmon
```

If you omit `--dir`, the default is `/data/linmon`.

**Expected (script output, similar):**

```text
Using --dir /data/linmon
Install runtime → /data/linmon
    created /data/linmon/configs/linmon.json
    created /data/linmon/.env
    generated POSTGRES_PASSWORD + LINMON_SECRET_KEY in /data/linmon/.env
    ENABLE_HTTPS=0 (no certs yet — HTTP :80)
=== before ===
(no version yet)
Loading /tmp/linmon-server/linmon-images.tgz → /data/linmon
docker load (gzip)…
Loaded image: linmon:latest
Loaded image: linmon-nginx:latest
Loaded image: linmon-rdp-enc:latest
Recreate containers (keep volumes / configs)
...
=== after ===
{"version":"1.4.95","commit":"...","display":"v1.4.95 · ..."}
```

`docker ps` **expected:** `linmon`, `linmon-postgres`, `linmon-nginx`, `linmon-collect-log` (and usually `linmon-guacd`, `linmon-rdp-enc`) **Up** / **healthy**.

```bash
docker ps
curl -sS http://127.0.0.1/api/version
```

**Expected (`curl`):** one JSON line, for example:

```text
{"version":"1.4.95","commit":"892dd68","build_time":"...","go_version":"...","display":"v1.4.95 · 892dd68"}
```

Browser: `http://NEW-HOST-LAN-IP/` shows the LINMON login page.

**Error:** `ERROR: do not run as root` — drop sudo; use the docker-group user.  
**Error:** `ERROR: docker not usable as …` — step 1 `docker info` is not OK.  
**Error:** `ERROR: image pack missing` — `linmon-images.tgz` not next to `INSTALL.sh`.  
**Error:** `ERROR: pack incomplete (no docker-compose.yml)` — copy the whole `linmon-server` folder.  
**Error:** `ERROR: unknown arg:` — you passed a flag the script does not know; use `--dir` / `--file` only.  
**Error:** `nginx` exits with `ENABLE_HTTPS=1 but ... pem missing` — keep `ENABLE_HTTPS=0` in `/data/linmon/.env` until certs exist, then `bash /data/linmon/scripts/dc.sh up -d`.  
**Error:** `curl: (7) Failed to connect` — containers not healthy yet; `docker ps` and `docker logs linmon-nginx --tail 50`.  
**Error:** browser connection refused — firewall 80, or you used HTTPS while `ENABLE_HTTPS=0`.

Syslog destination for clients (`--host`): the **LAN IP**, never the website name.

---

## 3. Apply the app binaries (same as 3.200 / 11.4)

```bash
cd /tmp/linmon-bin
ls -l INSTALL.sh linmon collect-log linmon-bin-deploy
bash INSTALL.sh --key ./linmon-bin-deploy
```

**Expected:**

```text
    wrote /home/athenabest/.linmon/bin_deploy
Using binaries next to INSTALL.sh
=== before ===
{"version":"1.4.95","commit":"892dd68",...}

    docker cp linmon → linmon:/app/linmon
    docker cp collect-log → linmon-collect-log:/app/collect-log
Restart linmon…
linmon
linmon-collect-log

=== after ===
{"version":"1.4.95","commit":"fb4b4e3","build_time":"...","display":"v1.4.95 · fb4b4e3"}
Done. Next time: bash UPDATE.sh   (uses /home/athenabest/.linmon/bin_deploy)
```

`commit` after this step should match the office `.\scripts\release-linmon-bin.ps1` build (not the old image commit).

```bash
curl -sS http://127.0.0.1/api/version
ls -l ~/.linmon/bin_deploy
```

**Expected:** JSON with the new `commit`; key file mode `-rw-------` (600).

**Error:** `ERROR: do not run as root` — no sudo.  
**Error:** `ERROR: key file not found` — `linmon-bin-deploy` missing in this folder (private key, not `.pub`).  
**Error:** `ERROR: container 'linmon' is not running` — finish step 2 first.  
**Error:** `ERROR: pack missing linmon / collect-log` — binaries not copied from USB.  
**Error:** `permission denied` on `docker cp` — `docker info` without sudo must work.  
**Error:** after restart, `curl` empty / 502 for >30s — `docker logs linmon --tail 80`; configs in `/data/linmon/configs/linmon.json` must exist.

Later updates (does **not** wipe the database):

```bash
bash /data/linmon/UPDATE.sh
# or:
bash /tmp/linmon-bin/UPDATE.sh
```

**Expected (`UPDATE.sh`):** `Fetch andylee03/linmon-bin…`, `Cloning into …`, `docker cp`, restart, `=== after ===` JSON.

**Error:** `Could not read from remote repository` / `Permission denied (publickey)` — key not installed, or wrong key (must be the **linmon-bin** deploy key). Re-run `bash INSTALL.sh --key ./linmon-bin-deploy`.  
**Error:** `git: command not found` — `sudo apt-get install -y git`.  
**Error:** `need deploy key at ~/.linmon/bin_deploy` — step 3 `--key` was skipped.

Re-running INSTALL/UPDATE will not destroy the system; it only restarts `linmon` and `collect-log` for a few seconds.

---

## 4. Manual setup (scripts do not copy another site’s config)

**Expected:** login page loads; after login you can open **Host Setup** and **Syslog Setup**. Change the example password immediately.

**Error:** login loop / 401 — cookies / HTTP vs HTTPS mismatch; first boot is HTTP.  
**Error:** blank Host Setup — you are not an admin user in `linmon.json` `auth.admin_users`.

HTTPS: put certs in `/data/linmon/certs/fullchain.pem` and `privkey.pem`, set `ENABLE_HTTPS=1` in `.env`, then:

```bash
cd /data/linmon
bash scripts/dc.sh up -d
curl -skS https://127.0.0.1/api/version
```

**Expected:** JSON on HTTPS; `http://` the same host returns **301** to HTTPS.

**Error:** nginx exits `ENABLE_HTTPS=1 but ... pem missing` — cert filenames must be exactly `fullchain.pem` and `privkey.pem`.  
**Error:** browser `NET::ERR_CERT_AUTHORITY_INVALID` — self-signed is OK for a test; install a real cert for production.

---

## 5. Test a Linux **client** sending logs here

On **another** Linux box (do **not** point this server at its own LAN IP):

```bash
wget -qO /tmp/INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host NEW-HOST-LAN-IP --port 514 --proto udp --min err
```

**Expected (client):** script writes `/etc/rsyslog.d/99-linmon.conf` and restarts rsyslog; no error. Then:

```bash
logger -p user.err 'linmon-syslog-test from this host'
```

On the **server** UI: **Logs → linux (error)** — a new row with this hostname.

**Error:** `wget` 404 — use the public raw URL above (repo `andylee03/linmon-winlog`).  
**Error:** client INSTALL OK but no row — firewall **514/udp**; `--host` must be the server **LAN IP**; wait a minute; filter is **linux (error)**, not `linux` (that is SSH poll).  
**Error:** server has no logs from **itself** after public INSTALL `--host` = own LAN IP — Docker hairpin; that is unsupported. Clients must be other machines (or `--host 172.16.0.20` only if you really collect from the Docker host).

---

## Do not

| Don’t | Why |
|-------|-----|
| `sudo bash INSTALL.sh` | **Error:** `do not run as root` |
| Public client INSTALL `--host` = this server’s own LAN IP | Docker hairpin; logs never arrive |
| `git pull` / copy `vide` source onto the server | Source stays on the office PC |
| Copy `.env` / `linmon.json` from 3.200 | Secrets must be unique per site |
| Treat this as Winlog or a syslog **client** | Clients use public `linmon-winlog` `INSTALL.sh` |
