# LINMON syslog server — installation guide

**Audience:** operator installing a new Ubuntu amd64 host that **receives** syslog (UDP/TCP 514) and serves the LINMON web UI.

**Not this document:** Linux **client** rsyslog forwarder, Windows Winlog, or the `vide` source tree.

| Item | Value |
|------|--------|
| Runtime directory | `/data/linmon` |
| Web | HTTP `:80` until TLS certificates are installed; then HTTPS `:443` |
| Syslog | Host LAN IP, port **514/udp** and **514/tcp** (never the website hostname) |
| Source of binaries / images | **GitHub only** — private `andylee03/linmon-bin` (no source). Never scp / USB bins from the office PC |
| Bootstrap | `wget` public `https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-INSTALL.sh` |
| Update | `wget` public `…/SERVER-UPDATE.sh` (not Linux-client `UPDATE.sh`) |
| Uninstall | `wget` public `…/SERVER-UNINSTALL.sh` |
| Publish pack | GitHub Action `release-linmon-bin` on `vide` `main` (secret `PACK_GITHUB_TOKEN`) |

Do not clone `andylee03/vide` onto the server. Do not copy `.env` or `configs/linmon.json` from another site. Do not copy `dist\` from the office PC onto the server.

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

Put **only** that private key on the new host (`~/linmon-bin-deploy`, mode `600`). After first INSTALL it lives at `~/.linmon/bin_deploy`. Packs always come from GitHub after that.

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

Wipe this host (same public repo; not as root). `--yes` deletes the database. Deploy key is kept by default:

```bash
wget -qO /tmp/SERVER-UNINSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UNINSTALL.sh
bash /tmp/SERVER-UNINSTALL.sh --dir /data/linmon --yes
```

If `rm` prints `Permission denied` on `configs/session.secret` (container wrote root-owned files): `sudo rm -rf /data/linmon` then INSTALL again. See §7.

If the shell is in `/tmp` and the key is in the home directory, `--key ./linmon-bin-deploy` fails (`key file not found`). Use `"$HOME/linmon-bin-deploy"`.

The script clones `andylee03/linmon-bin` (image tarball, compose files, `linmon` / `collect-log` binaries), loads images, starts Compose, then copies binaries into the containers.

| Stage | Pass | Fail |
|-------|------|------|
| `wget` | `/tmp/SERVER-INSTALL.sh` starts with `#!/bin/bash` | HTTP 404 — bootstrap not on `linmon-winlog` |
| Key | Log line `wrote …/.linmon/bin_deploy` | `key file not found: ./linmon-bin-deploy` — file is not in the current directory; use `$HOME/linmon-bin-deploy` |
| Clone | `Cloning into` `andylee03/linmon-bin` | `Permission denied (publickey)` — not `linmon-bin-deploy` |
| Images | `Loaded image: linmon:latest` (and nginx / rdp-enc) | `linmon-images.tgz missing` — `linmon-bin` GitHub pack is incomplete; wait for Action `release-linmon-bin` |
| Compose | Containers `Up` / `healthy` | `do not run as root`; `docker not usable`; **`linmon is unhealthy`** — see below |

If compose prints **`dependency failed to start: container linmon is unhealthy`**, do not re-clone. Inspect and fix, then start again:

```bash
docker logs linmon --tail 80
docker ps -a --filter name=linmon
ls -l /data/linmon/configs/linmon.json /data/linmon/.env
ss -tulnp | grep -E ':514|:80 '
```

| Log / symptom | Cause | Fix |
|---------------|--------|-----|
| `load config … no such file` | `configs/linmon.json` missing | `cp /data/linmon/configs/linmon.example.json /data/linmon/configs/linmon.json` |
| `Bind for 0.0.0.0:514 failed` / `port is already allocated` | Host **rsyslog** (or another syslog) already owns UDP/TCP 514 | `sudo ss -ulnp \| grep 514` then stop that listener (often `sudo systemctl stop rsyslog`) **or** disable `imudp`/`imtcp` in `/etc/rsyslog.conf`, then `cd /data/linmon && bash scripts/dc.sh up -d` |
| `address already in use` on `:80` | Another web server | Stop it or set `WEB_PORT` in `.env` |
| Process running but `/healthz` fails | Binary not listening yet | `docker logs -f linmon`; wait; `curl -sS http://127.0.0.1:8080/healthz` is not on the host — use `docker exec linmon curl -fsS http://127.0.0.1:8080/healthz` |

Then:

```bash
cd /data/linmon
bash scripts/dc.sh up -d
docker ps
curl -sS http://127.0.0.1/api/version
```

Postgres volume is already created — this does **not** wipe the database.
| API | JSON from `/api/version` (see below) | `curl: (7) Failed to connect` — `docker ps`, `docker logs linmon-nginx --tail 50` |
| nginx TLS | First boot uses HTTP (`ENABLE_HTTPS=0`) | nginx exits: `ENABLE_HTTPS=1 but … pem missing` |

```bash
docker ps
curl -sS http://127.0.0.1/api/version
```

Pass (example):

```text
{"version":"1.4.98","commit":"7ea0b2b","build_time":"…","go_version":"…","display":"v1.4.98 · 7ea0b2b"}
```

`docker ps` should list `linmon`, `linmon-postgres`, `linmon-nginx`, `linmon-collect-log`, and typically `linmon-guacd`, `linmon-rdp-enc`.

Browser: `http://<LAN-IP>/` — LINMON login.

| Item | Default (from `linmon.example.json`) |
|------|--------------------------------------|
| User | **`admin`** |
| Password | **`change-me`** |

Change the password on first login. Syslog clients use **`<LAN-IP>`**, not the HTTPS name.

---

## 4. Updates

Does **not** drop Postgres / `.env` / `linmon.json`. Restarts `linmon` and `linmon-collect-log` for a few seconds.

**Public wget** (same as INSTALL). This is **`SERVER-UPDATE.sh`**, not the Linux-client `UPDATE.sh`.

The binary pack is **private** (`andylee03/linmon-bin`). wget only fetches the bootstrap; git clone with `~/.linmon/bin_deploy` pulls `linmon` + `collect-log`. Do not `sudo`. Full clone (not sparse) — avoids `fatal: 'INSTALL.sh' is not a directory`.

```bash
wget -qO /tmp/SERVER-UPDATE.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UPDATE.sh
bash /tmp/SERVER-UPDATE.sh
curl -sS http://127.0.0.1/api/version
# or: curl -skS https://127.0.0.1/api/version
```

`--dir` is optional if the `linmon` container is running (script reads Compose working dir). Explicit:

| Site | `--dir` | Notes |
|------|---------|-------|
| **3.200** (prod) | **`/data/linmon`** (`/mnt/data1t` bind-mounted as `/data`) | Do not `git pull` `/home/athenabest/vide`. |
| SG 11.4 / syslog-4 | `/data/linmon` | |

Old on-disk `UPDATE.sh` uses sparse-checkout (`fatal: INSTALL.sh is not a directory`) — always wget `SERVER-UPDATE.sh`.

Do **not** `git pull` `vide` on 3.200. Do not `sudo`.

Always **wget a fresh `SERVER-UPDATE.sh` from GitHub**. Do not scp binaries from the office PC. Do not rely on an old `/data/linmon/UPDATE.sh` (sparse-checkout bug). `--key` only if `~/.linmon/bin_deploy` is missing.

| Check | Pass | Fail |
|-------|------|------|
| wget | HTTP 200, file starts `#!/bin/bash` | 404 — not on `linmon-winlog` |
| Clone | `andylee03/linmon-bin`; then `docker cp` | `Permission denied (publickey)` — restore `--key` |
| | | `linmon is not running` — INSTALL first |
| | | `git: command not found` — `sudo apt-get install -y git` |
| API | JSON `version` matches **GitHub** `linmon-bin` `VERSION` | Old commit — clone failed |

**Invariant:** `andylee03/linmon-bin` **`main` is the pack servers clone.** Developers push `vide` `main`; Action `release-linmon-bin` publishes the pack (repo secret `PACK_GITHUB_TOKEN`). Servers never pull from the office disk.

---

## 5. Site configuration

First web login: **`admin` / `change-me`**. Change that password immediately. Do not copy `linmon.json` from another site.

**Android APK (sideload WebView):** https://github.com/andylee03/linmon-winlog/releases/download/linmon-apk-v1.0.0/linmon.apk — default `https://syslog.athenabest.com`; open app → pick site before sign-in. APK version independent of server. Not Play Store / not GitHub Latest.

**MENU how-to** (Save writes; Close discards): **`docs/LINMON-ADMIN-GUIDE.md` §3b–3g**.

| MENU | Use |
|------|-----|
| Host Setup | Linux / Windows / SMA / PVE / PBS / FortiGate. This box: IP `172.17.0.1`, not its LAN IP. |
| Web / SSL Setup | Websites in **Postgres**. DOWN/SSL mail + Slack. Not Host Setup. |
| Syslog Setup | `Name=LAN-IP` for FG / QNAP / SMA (Docker 172.16.0.1). |
| Scheduler | CSV path e.g. `/data/exportlog`. Test Export. |
| Display | This browser only. **Apply**. |
| User Setup | **Save policy**, enroll Authenticator/Yubi, Admin/SSH/RDP ticks. |

---

## 5b. Create API users on FortiGate / SMA / PVE / PBS

Dashboard CPU/RAM for these kinds comes from **REST API**, not SSH. Create the account **on the device first**, copy the secret **once**, then paste into **MENU → Host Setup**. Blank Password on later saves keeps the stored key.

Do not put API secrets in git. Linmon server must reach the **management IP** (443 / 8443 / 8006 / 8007). Syslog is still **LAN IP:514**.

| Kind | How to create the API user | Host Setup User | Password | Port |
|------|----------------------------|-----------------|----------|------|
| **PVE** | **Script** (root on the node) — do not invent the user by hand | `linmon@pve!linmon` | printed secret | **8006** |
| **PBS** | **Script** (root on PBS) — do not invent the user by hand | `linmon@pbs!linmon` | printed secret | **8007** |
| FortiGate | No script — REST API Admin GUI/CLI | e.g. `linmon` | API key | **443** |
| SMA | No script — Administrator → API Keys | `API-USER` | AMC API key | **8443** |

### PVE / PBS — public scripts (canonical)

Same public repo as `SERVER-INSTALL.sh` (no GitHub token). Run as **root on the Proxmox / PBS box**, not on the linmon server.

**PVE:**

```bash
wget -qO /tmp/install-pve-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
bash /tmp/install-pve-linmon-api.sh
```

Creates `linmon@pve` + token `linmon`, role **PVEAuditor**. Prints Token ID + secret **once**.  
Host Setup → **+ PVE**: Port **8006**, User **`linmon@pve!linmon`**, Password = that secret.

**PBS:**

```bash
wget -qO /tmp/install-pbs-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
bash /tmp/install-pbs-linmon-api.sh
```

Creates `linmon@pbs` + token `linmon`, ACL **Audit** `/` + **DatastoreAudit** `/datastore` on **user and token**.  
Host Setup → **+ PBS**: Port **8007**, User **`linmon@pbs!linmon`**, Password = that secret.

```bash
bash /tmp/install-pve-linmon-api.sh --recreate   # new PVE secret
bash /tmp/install-pbs-linmon-api.sh --recreate   # new PBS secret
```

Office copies (same files): `scripts/install-pve-linmon-api.sh`, `scripts/install-pbs-linmon-api.sh`.

| Check | Pass | Fail |
|-------|------|------|
| Script | prints `Host Setup → + PVE/PBS` and a secret | `pveum` / `proxmox-backup-manager` not found — wrong machine |
| Card | CPU/RAM after poll | 401 — User is not the **full** `user@realm!tokenid`; PBS token ACL missing |

### FortiGate (REST API Admin)

On the FortiGate GUI (HTTPS management):

1. **System → Administrators → Create New → REST API Admin**.
2. **Username** e.g. `linmon` (this is Host Setup **User**).
3. **Administrator Profile:** `super_admin_readonly` (or a custom read-only profile).
4. **Trusted Hosts:** the **linmon server** LAN IP (e.g. `192.168.21.4/32`). Not Cloudflare, not 172.16.0.20.
5. **OK**. Copy the **API key** — shown **once**. That is Host Setup **Password**.

CLI (same result):

```bash
config system api-user
    edit "linmon"
        set accprofile "super_admin_readonly"
        set comments "linmon dashboard"
        config trusthost
            edit 1
                set ipv4-trusthost 192.168.21.4 255.255.255.255
            next
        end
    next
end
execute api-user generate-key linmon
```

Then **Host Setup → + FortiGate**: Name, IP = FG **management** IP, Port **443**, User `linmon`, Password = API key, On, **Save**.

Syslog still needs **Syslog Setup** `devname=LAN-IP` (display name and `devname` may differ).

| Check | Pass | Fail |
|-------|------|------|
| Card | CPU/RAM bars after a poll | 401 — wrong key; 403 — profile/trusthost; timeout — linmon cannot reach :443 |

### SMA (FortiAuthenticator AMC)

Do **not** use the Services menu. API keys live under **administrator accounts**.

1. Log in to SMA GUI `https://<SMA>:8443`.
2. **System → Administration → Administrators** (wording varies by FortiAuthenticator version) → create **`API-USER`** if missing. Enable **REST API**.
3. Open that administrator → **API Keys** → generate. Copy the key **once**.
4. **Host Setup → + SMA**: IP = SMA LAN IP, Port **8443**, User **`API-USER`**, Password = API key, **Save**.

Linmon sends header `X-API-Key`. Syslog hostname is often **`SMAHK`**, not the Host Setup display name — map in **Syslog Setup** if needed.

| Check | Pass | Fail |
|-------|------|------|
| Card | CPU/RAM + user count | 401 — key from wrong menu; timeout — :8443 not reachable from linmon |

If the PVE/PBS script is unavailable, GUI fallback is in the script comments (`Datacenter → Permissions → API Tokens` / PBS **Access Control**). Prefer the wget.

---

## 5a. HTTPS (port 443)

**Default after INSTALL is HTTP `:80`.** Compose already publishes **443** on the host, but nginx stays HTTP-only until **both** certificate files exist **and** `.env` has `ENABLE_HTTPS=1`. INSTALL forces `ENABLE_HTTPS=0` when `certs/` is empty so nginx does not exit.

Syslog stays **514/udp + 514/tcp** on the LAN IP. TLS is **only** for the browser UI. Do not point rsyslog / Winlog at the HTTPS hostname.

Do **not** copy `.env`, `linmon.json`, or `certs/` from another site (3.200 / 11.4). Each host needs its own files.

### Files (exact names)

| Host path | Role |
|-----------|------|
| `/data/linmon/certs/fullchain.pem` | Certificate + chain (PEM) |
| `/data/linmon/certs/privkey.pem` | Private key (PEM, unencrypted) |
| `/data/linmon/.env` | `ENABLE_HTTPS=1` · `HTTPS_PORT=443` · `WEB_PORT=80` · `LINMON_TLS_DIR=./certs` |

Other filenames (`cert.pem`, `key.pem`, Let’s Encrypt live paths) are **not** read. Copy or symlink into those two names.

```bash
sudo mkdir -p /data/linmon/certs
# then copy/symlink fullchain.pem + privkey.pem
ls -l /data/linmon/certs/fullchain.pem /data/linmon/certs/privkey.pem
```

| Check | Pass | Fail |
|-------|------|------|
| Names | Both files exist under `/data/linmon/certs/` | nginx log: `ENABLE_HTTPS=1 but … pem missing` → container exits |
| Key | `openssl rsa -in /data/linmon/certs/privkey.pem -check -noout` | Encrypted key / wrong file |
| Chain | `openssl x509 -in /data/linmon/certs/fullchain.pem -noout -subject -dates` | Empty or DER binary |

### Option A — Cloudflare Origin CA (PEM) + DNS

Browsers talk **HTTPS to Cloudflare**. This host is the **origin**. Put Cloudflare’s **Origin Certificate + private key** in `certs/` and set `ENABLE_HTTPS=1`. Do **not** use a Let’s Encrypt cert on origin if Cloudflare is already terminating TLS (Origin CA is enough).

**Need a public path to this machine’s :443.** LAN-only syslog-4 (`192.168.21.4` with no NAT / no tunnel) cannot use orange-cloud. Either:

- public IP (or WAN NAT **443/tcp** to this host), or
- **Cloudflare Tunnel** (`cloudflared`) if there is no inbound 443

Syslog **514 must stay LAN-only**. Do not publish 514 through Cloudflare.

#### A1. DNS

Cloudflare dashboard → **DNS → Records**:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A (or AAAA) | e.g. `syslog-4` (or `@`) | **Public** IPv4/IPv6 of this origin (or tunnel CNAME later) | **Proxied** (orange cloud) |

Wait until `dig +short syslog-4.example.com` returns a **Cloudflare** anycast IP (not the LAN IP).

#### A2. SSL / TLS mode

**SSL/TLS → Overview → encryption mode: Full (strict).**

| Mode | Use |
|------|-----|
| **Full (strict)** | Required with Origin CA PEM on this host |
| Full | Works with self-signed; weaker |
| Flexible | Cloudflare → origin **HTTP :80**. Do **not** use if you installed PEM / `ENABLE_HTTPS=1` |

#### A3. Create Origin Certificate (PEM)

1. **SSL/TLS → Origin Server → Create Certificate**.
2. Hostnames: the DNS name(s) from A1 (e.g. `syslog-4.example.com` and `*.example.com` if needed).
3. Key type **RSA (2048)**. Validity **15 years** is fine.
4. **Create**.
5. Copy **Origin Certificate** (block starts `-----BEGIN CERTIFICATE-----`) — this is shown again later, but save it.
6. Copy **Private Key** (block starts `-----BEGIN PRIVATE KEY-----`) — **shown once**. If lost, create a new certificate.

On the linmon host (example `syslog-4`):

```bash
sudo mkdir -p /data/linmon/certs
sudo nano /data/linmon/certs/fullchain.pem   # paste Origin Certificate, save
sudo nano /data/linmon/certs/privkey.pem     # paste Private Key, save
sudo chmod 600 /data/linmon/certs/privkey.pem
sudo chown "$USER:$USER" /data/linmon/certs/*.pem
openssl x509 -in /data/linmon/certs/fullchain.pem -noout -issuer -subject -dates
openssl rsa -in /data/linmon/certs/privkey.pem -check -noout
```

Pass: issuer contains **Cloudflare Origin CA**; `rsa: OK`.  
You do **not** need Cloudflare’s universal “edge” cert on this box. Do **not** copy 3.200 `certs/` (that name is `syslog.athenabest.com`).

Then **Turn HTTPS on** below (`ENABLE_HTTPS=1`, recreate nginx).

#### A4. Firewall / Cloudflare

- Origin **443/tcp** reachable from Cloudflare (or tunnel). Keep **80/tcp** for HTTP 301 + `/healthz`.
- Restrict origin 443 to [Cloudflare IP ranges](https://www.cloudflare.com/ips/) if the host is on the internet.
- **Do not** open **514** to the internet.

#### A5. LINMON settings behind Cloudflare

In **MENU → Settings** (after login):

- **Local admin internal-only**: leave **off** on a Cloudflare site, **or** run **v1.4.79+** (nginx passes `CF-Ray`; the gate skips when that header is present).
- Login URL is `https://<cloudflare-hostname>/` — not `http://192.168.21.4/`.
- Syslog devices and Linux/Winlog clients still use the **LAN IP** (`192.168.21.4`), never the Cloudflare hostname.

| Check | Pass | Fail |
|-------|------|------|
| Browser via CF | Padlock, LINMON login, no certificate warning | 526 — origin cert missing / `ENABLE_HTTPS=0` / mode not Full (strict) |
| | | 522 — origin :443 not reachable (NAT / firewall / no tunnel) |
| Direct LAN | `https://192.168.21.4/` may warn (cert CN is the DNS name) | Expected; use the Cloudflare hostname for browsers |
| Login | Local `admin` works from the internet | Internal-only on + old build without `CF-Ray` |

### Option B — self-signed (LAN IP, browser warning)

For syslog-4-style hosts with no public name (`http://192.168.21.4/`). Browsers will warn; that is expected.

Replace the IP (and optional DNS) in `-addext`:

```bash
cd /data/linmon/certs
openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes \
  -keyout privkey.pem -out fullchain.pem \
  -subj "/CN=192.168.21.4" \
  -addext "subjectAltName=IP:192.168.21.4"
chmod 600 privkey.pem
```

### Turn HTTPS on

```bash
# in /data/linmon/.env  (do not copy another site's .env)
# ENABLE_HTTPS=1
# HTTPS_PORT=443
# WEB_PORT=80

grep -E '^(ENABLE_HTTPS|WEB_PORT|HTTPS_PORT|LINMON_TLS_DIR)=' /data/linmon/.env
cd /data/linmon
bash scripts/dc.sh up -d --force-recreate nginx
docker logs linmon-nginx --tail 20
```

Expect a log line: `TLS only (443). HTTP :80 redirects to HTTPS.`

If `scripts/dc.sh` is missing:

```bash
cd /data/linmon
docker compose --env-file .env -f docker-compose.yml up -d --force-recreate nginx
```

Firewall: **443/tcp** (and keep **80/tcp** — HTTP is 301 + Docker `/healthz` `/readyz`, not the app).

### Verify

```bash
curl -skS https://127.0.0.1/api/version
curl -sS -o /dev/null -w "http=%{http_code} redirect=%{redirect_url}\n" http://127.0.0.1/
curl -skS -o /dev/null -w "https=%{http_code}\n" https://127.0.0.1/
docker ps --filter name=linmon-nginx
```

| Check | Pass | Fail |
|-------|------|------|
| API | JSON on **https://** (`/api/version`) | `Failed to connect` :443 — recreate nginx; `ss -tlnp \| grep 443` |
| HTTP | **301** to `https://…` | 200 on HTTP — `ENABLE_HTTPS` still `0` or nginx not recreated |
| nginx | `Up` / `healthy` | Restarting — missing PEM names, or `ENABLE_HTTPS=1` before files exist |
| Browser | `https://<LAN-IP>/` or `https://<DNS>/` | Self-signed: accept the warning once |

To go back to HTTP only: set `ENABLE_HTTPS=0`, recreate nginx. Leave cert files in place.

---

## 6. Linux client (sends logs to this server)

Public installer (no GitHub token, **not** PowerShell):  
https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh  
Guide: `docs/INSTALL-LINUX-HOST-CLIENT.md`.

`--host` is always a **syslog IP**, never `https://…` and never the Cloudflare name.

| Where you run INSTALL | `--host` | `--proto` |
|-----------------------|----------|-----------|
| **Another** Linux PC on the same LAN as syslog-4 | `192.168.21.4` | `udp` (VPN/NAT: `tcp`) |
| **On syslog-4 itself** (this Docker host) | `172.16.0.20` | **`tcp`** |
| Another Linux → HK prod | `192.168.3.200` | `udp` |
| Another Linux → SG 11.4 | `192.168.11.4` | `udp` |

**Never** on syslog-4: `--host 192.168.21.4` (Docker hairpin — packets never reach the `linmon` container). Same rule as 3.200 / 11.4.

Look in the UI under **Logs → linux (error)** (`linux_error`). Filter **linux** is SSH poll, not rsyslog.

### 6a. Other Linux PCs → syslog-4

Run **on the client**, not on 21.4:

```bash
wget -qO /tmp/INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host 192.168.21.4 --port 514 --proto udp --min err
logger -p user.err 'linmon-syslog-test from this host'
```

| Check | Pass | Fail |
|-------|------|------|
| Conf | `/etc/rsyslog.d/99-linmon.conf` has `@192.168.21.4:514` | `--host` was a website name |
| UI | **linux (error)** row, hostname = this client | No row — 514/udp blocked; or you looked at **linux** (poll) |

### 6b. Linux client **on syslog-4** (this machine)

syslog-4 is the **server**. Host rsyslog must send to the **container** `172.16.0.20:514` over **TCP** (`@@`). UDP to the published LAN `:514` is dropped (hairpin).

```bash
wget -qO /tmp/INSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
sudo bash /tmp/INSTALL.sh --host 172.16.0.20 --port 514 --proto tcp --min err
```

Confirm:

```bash
grep -E '@' /etc/rsyslog.d/99-linmon.conf
# pass:  @@172.16.0.20:514     (two @ = TCP)
# fail:  @192.168.21.4:514     (hairpin)
```

If a previous INSTALL used the LAN IP, fix in place (do not re-INSTALL with the wrong host):

```bash
sudo sed -i 's/@192.168.21.4:514/@@172.16.0.20:514/' /etc/rsyslog.d/99-linmon.conf
sudo systemctl restart rsyslog
```

Allow host → container 514 (Docker `DOCKER-USER`):

```bash
sudo tee /usr/local/sbin/linmon-host-syslog-iptables.sh >/dev/null <<'EOF'
#!/bin/sh
iptables -C DOCKER-USER -p tcp -d 172.16.0.20 --dport 514 -j ACCEPT 2>/dev/null \
  || iptables -I DOCKER-USER -p tcp -d 172.16.0.20 --dport 514 -j ACCEPT
iptables -C DOCKER-USER -p udp -d 172.16.0.20 --dport 514 -j ACCEPT 2>/dev/null \
  || iptables -I DOCKER-USER -p udp -d 172.16.0.20 --dport 514 -j ACCEPT
EOF
sudo chmod 755 /usr/local/sbin/linmon-host-syslog-iptables.sh
sudo /usr/local/sbin/linmon-host-syslog-iptables.sh

sudo tee /etc/systemd/system/linmon-host-syslog-iptables.service >/dev/null <<'EOF'
[Unit]
Description=Allow host rsyslog to linmon container :514
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/linmon-host-syslog-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now linmon-host-syslog-iptables.service
```

Test (on syslog-4):

```bash
logger -p user.err 'linmon-syslog-test from syslog-4 host'
# UI → Logs → linux (error)  hostname = this box (e.g. metis)
```

| Check | Pass | Fail |
|-------|------|------|
| Conf | `@@172.16.0.20:514` | `@192.168.21.4` — no rows in UI |
| iptables | `iptables -L DOCKER-USER -n` shows ACCEPT dport 514 to `172.16.0.20` | Rule missing after reboot — enable the systemd unit |
| UI | **linux (error)** | Looking at **linux** (SSH collect) |

FortiGate / QNAP / other PCs still send to **`192.168.21.4:514`**. Only the **linmon host itself** uses `172.16.0.20`.

### 6c. Host Setup SSH to **this** machine (21.4 / 11.4 / 3.200)

collect-log is a container. **SSH to the host LAN IP times out** (same class of Docker hairpin as §6b):

```text
SSH offline: dial tcp 192.168.21.4:22: i/o timeout
(no key_path; password set; enable Host Setup: HostKey +ssh-rsa; …)
```

TCP never connected. **Do not** tick HostKey/Pubkey +ssh-rsa to fix a timeout.

**Other Host Setup rows are fine** with their real LAN IPs (collect-log leaves Docker and reaches those machines). Only the **linmon box itself** cannot be `192.168.21.4` / `192.168.11.4` / `192.168.3.200`.

On **syslog-4**, Host Setup Linux row for the box itself:

| Field | Value |
|-------|--------|
| IP / Host | **`host.docker.internal`** (or `172.17.0.1`) — **not** `192.168.21.4` |
| Port | `22` |
| User | e.g. `metis` |
| Key path | `/keys/id_ed25519` if you mounted a key; else Password. **v1.4.104+ Admin:** Host Setup **Upload** into `/keys/` (compose `/keys` **rw**); Key path is a **dropdown** of those files |
| Log | optional SSH journal |

Same for 11.4 (`192.168.11.4` forbidden) and 3.200 (`192.168.3.200` forbidden). Other LAN PCs still use their real IP.

If you only need syslog from this host, skip Host Setup and use §6b rsyslog.

---

## 7. Uninstall (wipe this host)

Removes the Docker stack, `/data/linmon` (including Postgres volume), image tags `linmon` / `linmon-nginx` / `linmon-rdp-enc`, git cache `~/.linmon/bin-repo`, the Linux-client rsyslog drop-in, and the host→container iptables unit. **Does not** remove Docker Engine.

Do **not** run as root. **`--yes` is required.** This deletes the database.

On the host (syslog-4 example: user `metis`). Same public wget as INSTALL — **not** as root:

```bash
wget -qO /tmp/SERVER-UNINSTALL.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UNINSTALL.sh
bash /tmp/SERVER-UNINSTALL.sh --dir /data/linmon --yes
```

If INSTALL already copied the pack script:

```bash
bash /data/linmon/UNINSTALL.sh --dir /data/linmon --yes
```

| Flag | Meaning |
|------|---------|
| `--yes` | Required |
| `--keep-dir` | `compose down -v` only; leave `/data/linmon` |
| `--keep-images` | Do not `docker rmi` linmon images |
| `--keep-key` | Keep `~/.linmon/bin_deploy` (**default** — next INSTALL still works) |
| `--wipe-key` | Also delete `~/.linmon/bin_deploy` and `~/linmon-bin-deploy` |

| Check | Pass | Fail |
|-------|------|------|
| Containers | `docker ps -a --filter name=linmon` empty | Leftover `Restarting` — `docker rm -f linmon linmon-nginx linmon-postgres …` |
| Ports | `ss -tuln` has no `:514` / `:80` from docker-proxy | Another service still bound |
| Dir | `/data/linmon` gone | See **root-owned configs** below |
| Client | `/etc/rsyslog.d/99-linmon.conf` gone | No passwordless sudo — run the printed `sudo rm` lines |

### Root-owned `configs/` after UNINSTALL

Docker may leave files owned by **root**. `bash SERVER-UNINSTALL.sh` (as `metis`) then prints:

```text
rm: cannot remove '/data/linmon/configs/session.secret': Permission denied
rm: cannot remove '/data/linmon/configs/linmon.example.json': Permission denied
rm: cannot remove '/data/linmon/configs/rdp-record.env': Permission denied
rm: cannot remove '/data/linmon/configs/linmon.json': Permission denied
rm: cannot remove '/data/linmon/configs/web.env': Permission denied
```

Stack is already gone. Finish the wipe with **sudo only on rm** (do **not** `sudo bash` UNINSTALL):

```bash
sudo rm -rf /data/linmon
ls -ld /data/linmon
# Pass: No such file or directory
```

If it still exists:

```bash
ls -la /data/linmon/configs
sudo chown -R "$USER:$USER" /data/linmon
rm -rf /data/linmon
```

Then INSTALL again (not as root). Newer `SERVER-UNINSTALL.sh` tries `sudo rm` itself; if sudo asks for a password it prints the same command.

Re-install afterwards is a **new** site (empty hosts, new DB). Do not reuse another site’s `.env`.

---

## Appendix D — 3.200: `/mnt/data1t` bind-mounted as `/data`

Prod (`192.168.3.200`) 1 TB disk is mounted at **`/mnt/data1t`**. Bind it to **`/data`** so paths match 11.4 / syslog-4 (`/data/linmon`). **Do not grow linmon on the 490 GB root LV.**

| Role | Path (after bind) | Same bytes as |
|------|-------------------|----------------|
| Docker engine | `/data/docker` | `/mnt/data1t/docker` (daemon.json can stay that path) |
| Postgres | `/data/docker/volumes/vide_pgdata/_data` | named volume `vide_pgdata` |
| RDP recordings | `/data/docker/rdp-recording` | `/mnt/data1t/docker/rdp-recording` |
| Scheduler CSV | `/data/exportlog` | `/mnt/data1t/exportlog` |
| Linmon runtime | **`/data/linmon`** | compose + configs + keys + certs |

**Done on prod (2026-08-28):** `fstab` has `/mnt/data1t /data none bind 0 0`. Runtime **`/data/linmon`**, `COMPOSE_PROJECT_NAME=vide` (same `vide_pgdata`). UPDATE: `--dir /data/linmon`. Leave `/home/athenabest/vide` unused. Do not `git pull`. Do not `down -v`. Do not unmount `/mnt/data1t`.

---

## Appendix A — USB only if GitHub is unreachable

Normal path is **wget + git clone from GitHub**. USB is emergency only. Do not copy `linmon.json`, `.env`, `certs/`, or `id_ed25519` from another site.

If GitHub is down: a maintainer publishes `linmon-bin` on GitHub when it is back; then INSTALL/UPDATE from GitHub. Do not keep using a USB pack as the update source.

---

## Appendix B — Constraints

| Prohibited | Reason |
|------------|--------|
| `sudo bash SERVER-INSTALL.sh` / `INSTALL.sh` / `UNINSTALL.sh` | Process must use the docker group socket |
| Client `--host` = this server’s LAN IP, run **on** this server | Hairpin NAT; syslog never reaches the container |
| `git pull` of `vide` on the server | Source stays on GitHub `vide`; servers clone **`linmon-bin` only** |
| scp / USB binaries from the office PC | INSTALL / UPDATE are **wget + git from GitHub** |
| Reuse another site’s `.env` / `linmon.json` | `LINMON_SECRET_KEY` is per host |

---

## Appendix C — Maintainers: publish pack to GitHub

Servers do **not** run this. After changing linmon / collect-log / INSTALL scripts:

1. Bump `internal/linmon/version.go`
2. `git push origin main` on **`andylee03/vide`**
3. GitHub Action **`release-linmon-bin`** builds linux bins and pushes **`andylee03/linmon-bin`** + public wget scripts on **`linmon-winlog`**

Repo secret **`PACK_GITHUB_TOKEN`**: PAT with write to `andylee03/linmon-bin` and `andylee03/linmon-winlog`. Without it the Action skips; a maintainer may run `bash scripts/release-linmon-bin.sh` (or `.ps1`) **to GitHub**, never to copy files onto syslog hosts.
