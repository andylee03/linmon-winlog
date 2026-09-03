# LINMON Administrator Guide

For people who must **change settings**, not only log in.  
If you only need login / Authenticator / reading mail, use the **[User Guide](LINMON-USER-GUIDE.md)** first and practise there.

**Blueprint site:** https://syslog.athenabest.com  
**Server:** `192.168.3.200` Â· SSH **7788** Â· user `athenabest` Â· runtime **`/data/linmon`** (`/mnt/data1t` bind-mounted as `/data`). Leftover git tree `/home/athenabest/vide` â€” **do not `git pull`**.

**Login (v1.5.9+):** separate **Domain** field â€” blank = local admin; filled = AD UPN `user@Domain`. Android APK needs **no** update (WebView loads server `/login`).

![Admin MENU](img/admin-menu.svg)

---

## 0. Are you an admin?

On this site the AD names allowed to change setup are:

`andy.lee` Â· `peter.ip` Â· `steven.khoo`

plus the local user **`admin`**.

If **Host Setup** / **User Setup** / **Syslog Setup** are missing from MENU, you are **not** an admin. Stop and use the User Guide. Do not try to edit `linmon.json` by hand without reading section 2. How to use each MENU overlay: **Â§3bâ€“3g**. Dashboard Linux vs Windows logs: **Â§3h**.

**RDP** and **SSH** are **separate** ticks. `calvin.leung` can use web Terminal but cannot open Host Setup.

---

## 1. Mental model (read once)

```
User browser  --HTTPS 443-->  nginx  -->  linmon :8080
Devices       --514 udp/tcp->  linmon  -->  Postgres device_log
Admin edits                  linmon.json (encrypted) + Postgres websites
```

- **https://syslog.athenabest.com** = humans.  
- **192.168.3.200:514** = FortiGate, QNAP, Winlog, Linux rsyslog.  
- Docker internal `172.16.0.20` = never type this in a device or browser.

Three live servers (do not copy `.env` / `linmon.json` between them):

| Name | HTTPS | LAN / SSH | Runtime |
|------|-------|-----------|---------|
| **Prod** | https://syslog.athenabest.com | `192.168.3.200` Â· SSH **7788** `athenabest` | `/data/linmon` |
| **Metis SG** | https://syslog.metisgl.com.sg | `192.168.11.4` Â· SSH **22** `athenabest` | `/data/linmon` |
| **CPC NET** (syslog-4) | https://syslog.metisgl.com | `192.168.21.4` Â· SSH **22** `metis` | `/data/linmon` |

Live server build (2026-09-02): **v1.5.7 Â· `90c0677`**. Android APK is independent (**1.0.12**).  
Servers **wget from GitHub** (`SERVER-INSTALL.sh` / `SERVER-UPDATE.sh`); they do not clone `vide`.

---

## 2. Files you must not destroy

| File | Commit to git? | If you lose it |
|------|----------------|----------------|
| `configs/linmon.json` | **NEVER** (`git add -f` is forbidden) | Hosts, SMTP, API keys, AD â€” gone or plaintext mess |
| `.env` â†’ `LINMON_SECRET_KEY` | No | Encrypted passwords in json **cannot be decrypted** |
| `certs/fullchain.pem` + `privkey.pem` | No | nginx will **exit**; HTTPS down |
| `keys/` | No | SSH to Linux hosts fails |
| Postgres | n/a | Website list is **only** here, not in json |

Live config is **per machine**. The git file `configs/linmon.example.json` is a **template**, not production.

---

## 3. First-time admin on the website (after you can log in)

1. Open **https://syslog.athenabest.com** and complete login (User Guide Â§1).  
2. Left **MENU**. If you see **Host Setup** and **User Setup**, you are admin.  
3. Open **Settings**. Click **Save** only when you mean it. **Close** without Save discards the overlay.  
4. Prefer the UI over SSH-editing json unless the UI cannot do the job.

Left **MENU** is **nav only**. Each item opens a full-screen overlay. **Save** (or **Apply** / **Save policy**) writes; **Close** or click the dim background / Escape **discards** unsaved edits.

| MENU | What it changes | Where stored |
|------|-----------------|--------------|
| Host Setup | Linux / Windows / SMA / PVE / PBS / FortiGate | `linmon.json` |
| Web / SSL Setup | Website list + SSL/DOWN mail + Slack | **Postgres** `web_host` (not json) |
| Syslog Setup | FG / QNAP / SMA **name â†’ LAN IP** | `linmon.json` `syslog.*_map` |
| Scheduler | CSV export + purge | `linmon.json` housekeeping |
| Display | Card layout / bars (this browser) | browser only |
| User Setup | 2FA policy, enroll, Admin/SSH/RDP ticks | `linmon.json` + enroll table |
| Settings | Poll, SMTP, OTP numbers, site name | `linmon.json` |

If Host / Web / Syslog / Scheduler / User Setup are missing, you are **not** Admin.

---

## 3b. MENU â†’ Host Setup

1. MENU â†’ **Host Setup**. Header: **+ Linux Â· + Windows Â· + SMA Â· + PVE Â· + PBS Â· + FortiGate Â· Save Â· Close**.  
2. Click the **+** for the kind you need. One row appears.  
3. Fill **Name**, **IP / Host**, **Port** (linux 22 / windows 3389 / SMA 8443 / PVE 8006 / PBS 8007 / FG 443), **User / Token**, **Password / API key** (blank = keep saved).  
4. **SSH keys (Admin only, v1.4.104+):** above the table, **Upload** a private key into **`/keys/`**. **Key path** is a **dropdown** â€” browse and pick a file from that folder (no typing). **Del** on a chip removes the file. Non-admins do not see Upload (API 403). Matching **public** key must already be on the target `authorized_keys`. Passphrase-protected keys are not supported. Blank Key path on Save = keep saved path.  
5. Tick **On**. **Log** = SSH `journalctl` warning+ on the 10â€‘min poll (**card â€œSSH journal errorsâ€ only** â€” not Windows Event Log, not rsyslog).  
6. **HostKey +ssh-rsa** / **Pubkey +ssh-rsa**: only old OpenSSH after TCP already works. **Do not** tick to â€œfixâ€ `i/o timeout`.  
7. Trash icon = delete that row (in the draft). **Save**. Wait for **Hosts saved**. Close.

**This linmon box itself:** IP **`172.17.0.1`** or `host.docker.internal`, never `192.168.21.4` / `.11.4` / `.3.200`. **Other machines keep real LAN IPs.**

Dashboard Linux cards (v1.4.109+): **doubleâ€‘click the card** (or click the green **Linux Syslog** box) opens that hostâ€™s Logs (`device_type=linux_error`). See **Â§3h**.

PVE/PBS: run the public wget scripts on the Proxmox host first (Â§6.4). SMA API Keys = Administrator menu, not Services. Full API steps: install guide Â§5b. Linux SSH field-by-field: Â§6.1.

---

## 3c. MENU â†’ Web / SSL Setup

Websites are **not** Host Setup. Stored in **this serverâ€™s Postgres** (DEV Windows â‰  PROD Ubuntu).

1. MENU â†’ **Web / SSL Setup**.  
2. Environment label: **production** on 3.200; **development** only on a lab PC.  
3. **Email alerts (Website only):**  
   - Tick **Email when website DOWN** and/or **SSL expiring**.  
   - **SSL email if days left â‰¤** (default 30).  
   - **Website alert email To** â€” independent of disk/RAM SMTP To. Blank = Settings SMTP To. SMTP must still be enabled.  
   - **Test Email Web DOWN** â€” sample mail to that To.  
4. **Important alive â†’ Slack:** tick Enable, paste Incoming Webhook, mention `Uâ€¦` member ID or `@channel`. **Test Slack**. Does not need SMTP.  
5. Table: **+ Add site** (or **+ Company list** for samples). Name, **URL** (`https://â€¦`), Note, **Imp** (Slack if DOWN), **On**. Trash deletes the row.  
6. **Save**. Close. Dashboard **Websites** section updates on next poll.

SSL colours: OK >30d Â· WARN â‰¤30d Â· CRIT â‰¤7d. Website To â‰  host disk mail.

---

## 3d. MENU â†’ Syslog Setup

Fixes Docker rewriting syslog source to `172.16.0.1`. One line: `Name=192.168.x.x`.

1. MENU â†’ **Syslog Setup**.  
2. **SMA syslog name â†’ LAN IP** (AMC keys stay in Host Setup).  
3. **FortiGate map:** syslog **devname** = management IP. Optional default FG IP.  
4. **QNAP map:** RFC hostname = NAS IP. **Exact hostname** only (`metis-sg` must not match `Metis-SG-BDC`).  
5. **Save**. Applies immediately (no Docker rebuild). Devices must already send to **this linmon LAN IP:514**, not the website hostname.

HK blueprint lines: `athenabest-91g-hk=192.168.3.253`, `abhk-cpc-91=192.168.98.2`, `athenabest-214=192.168.3.214`. Do not paste HK maps onto 21.4.

QNAP management UI is **not** proxied through linmon (removed in v1.5.5). Open the NAS on the LAN / VPN (`https://NAS-IP`) when you need QTS.

---

## 3e. MENU â†’ Scheduler

CSV export + optional purge. collect-log still every **10 minutes** (SSH ErrorCount + web backup); it does **not** write `device_log` unless you tick that box (leave **off** â€” use syslog).

1. MENU â†’ **Scheduler**.  
2. Tick **Enable scheduler**. Tick **scheduled CSV export** and/or **Purge logs older than retain days**.  
3. **Frequency:** daily / weekly / monthly. **Time (local)**. Weekly â†’ weekday. Monthly â†’ day of month. **Keep logs (days)** e.g. 90.  
4. **Export window** (v1.5.8+):  
   - **Previous period** â€” daily = yesterday; weekly = previous week; monthly = previous calendar month.  
   - **Last N days** â€” rolling window ending at run time (set N).  
   Scheduled runs export **only that window** (not the whole DB).  
5. **Host path** e.g. `/data/exportlog` (3.200) or `/data/linmon-logs` (11.4). Must be under `/data` or `/mnt` (compose bind).  
6. **Split CSV by device type** (folders `windows/` `fortigate/` â€¦). Optional combined CSV. Type checkboxes: none checked = all types.  
7. **Save**.  
8. **Manual export (to folder):** set **From / To** (dates) â†’ **Export now**. Optional **Use schedule window** / **Export schedule window**. Writes to the host folder (same split/types). **v1.5.11+** runs export in the **background** and polls status (avoids Cloudflare/nginx **HTTP 524** HTML timeout on large ranges).  
9. **Logs â†’ Export Log** remains the browser download path (filters + dates, max 100k rows).  
10. **Test Housekeeping (dry-run)** counts deletes. **Test Purge (execute)** really deletes old rows â€” use carefully.

Prod path after `/data` bind: **`/data/exportlog`**. Changing a folder under `/data` or `/mnt` does not need `dc.sh`.

---

## 3f. MENU â†’ Display

**This browser only** (not the server). Does not change other usersâ€™ screens.

1. MENU â†’ **Display**.  
2. **Size & position:** cards per row, min width, page max width, gap, density, align.  
3. **Arrange:** Align all (equal size) Â· Reset sizes + order. Drag section list (Windows / Firewall / QNAP / Websites / Linux). Default sort (manual / name / status / â€¦).  
4. **Page items / Host card items:** tick bars (SMA, PVE, Windows Event Log, â€¦), hide header/footer, â€œonly alarms/offlineâ€.  
5. **Apply** (not named Save). **Reset** restores defaults. Close.

Drag card **headers** on the dashboard to reorder when sort is Manual.

---

## 3g. MENU â†’ User Setup

Header: **Refresh Â· Close**. Policy is the **top checkbox row** + **Save policy**.

1. MENU â†’ **User Setup**.  
2. Policy: Require OTP, Allow Authenticator, Allow YubiKey, Allow self-register, Login lockout, Local admin no lockout, **Local admin internal-only** (leave **off** behind Cloudflare), Max fails / Lock minutes. **Save policy**.  
3. **Yubico Client ID + API Secret** â†’ Save policy **before** registering keys. https://upgrade.yubico.com/getapikey/  
4. **Register Authenticator:** type AD `sAMAccountName` Â· Type AD or Local admin Â· **+ Register Authenticator** â†’ user scans QR â†’ 6 digits â†’ **Confirm Authenticator**.  
5. **YubiKey:** Click InKey box â†’ touch key â†’ **+ Register YubiKey** (does not remove Authenticator).  
6. Grid ticks **Admin / SSH / RDP** per user (independent). Local admin always has SSH+RDP.  
7. **Login lockouts:** Unlock / Unlock all.

Show Authenticator secrets = live 6-digit on the grid. Yubi OTP is never shown. Enroll detail: Â§5.

---

## 3h. Dashboard â€” Linux vs Windows logs (v1.4.109+)

Two different pipelines. Do not mix them when a card shows **0** errors but **Logs** is full.

| What you see | Source | How to open |
|--------------|--------|-------------|
| **Windows** bar / **Windows Event Log** box | Winlog â†’ syslog â†’ `device_type=windows` | Click the PC name or the Event Log box |
| **Linux Syslog** box (green) on a Linux card | rsyslog / journald-forward â†’ `device_type=linux_error` | **Doubleâ€‘click the Linux card**, or click the **Linux Syslog** box / â€œâ–¶ This host logsâ€ |
| **SSH journal errors (N)** on a Linux card | Host Setup **Log** tick â†’ SSH `journalctl -p warning..emerg` (10â€‘min poll) | Detail panel only; **not** written to `device_log` unless Scheduler â€œWrite SSH collect into device_logâ€ is on (leave **off**) |

**Linux card clicks (v1.4.109+)**

1. **Doubleâ€‘click** the card â†’ Logs filtered to that host (`linux_error`). Same idea as clicking a Windows PC for Event Log.  
2. **Singleâ€‘click the host name** â†’ expand detail overlay (mem/disk/alarms).  
3. **Doubleâ€‘click the resize handle** (corner) â†’ reset that cardâ€™s saved size (not open Logs).  
4. **âŒ¨** â†’ web Terminal (SSH list only).

**Why card â€œSSH journal errors (0)â€ but Logs â†’ linux (error) has hundreds**

Example: `appserver` / `192.168.21.41` â€” rsyslog sends many **information** lines (SSH login, cron, â€¦) into `linux_error`. The Host Setup **Log** tick only counts **journal warning+**. A quiet journal â†’ card SSH errors = **0**, while **Linux Syslog** still shows total / 24h / err. That is expected, not a broken client.

Install / UPDATE Linux senders: public wget (Â§8). Need **v1.0.2+** for SSH Failed password (`authpriv.info`).

---

## 4. Settings â€” SMTP and alerts (so mail actually works)

![Email](img/email-alerts.svg)

### 4.1 Turn on SMTP (required for almost all mail)

**MENU â†’ Settings** â†’ scroll to **SMTP (IT email server)**.

1. Tick **Enable email alerts**. If this is off, disk, RAM, and website emails **do not send**.  
2. Fill (blueprint):

   | Field | This site |
   |-------|-----------|
   | SMTP host | `smtp.abagile.com` |
   | Port | `587` |
   | Username | as used on this server |
   | Password | type only to change; blank = keep |
   | From | `monitor@abagile.com` |
   | To | `it.helpdesk@athenabest.com` (comma-separated if several) |

3. Click **Save** (top of Settings). Wait for **saved** / OK message.  
4. Click **Test HD email**. Wait for helpdesk inbox (and spam).  
5. Click **Test RAM email** the same way.

If tests fail: host/port/firewall/credentials â€” not syslog.

**New country:** use **their** SMTP and **their** IT mailbox. Do not reuse abagile SMTP if that site cannot reach it.

### 4.2 When disk/RAM mail fires

Same Settings screen, **Alerts** card:

| Control | Blueprint | What it does |
|---------|-----------|----------------|
| Disk WARN / CRIT % | 80 / 90 | Card colour only |
| RAM WARN / CRIT % | 85 / 95 | Card colour only |
| Disk email when â‰¥ % | **95** | Send disk mail |
| RAM email when â‰¥ % | **95** | Send RAM mail |
| RAM must stay high (seconds) | **60** | Ignore 2-second spikes |
| Email cooldown (minutes) | **60** | Same host+kind will not mail every minute |
| Alert on offline / errors | On | Dashboard, not a separate email type |

**To stop disk mail without disabling SMTP:** raise Disk email % to 100, or remove that hostâ€™s disks from concern.  
**To stop all host mail:** untick Enable email alerts (OTP email also needs SMTP â€” do not turn it off lightly).

### 4.3 Website DOWN mail (different To)

**MENU â†’ Web / SSL Setup** (not Host Setup).

1. Tick **Email when website DOWN**.  
2. **Email when SSL expiring** is **off** on this site (leave off unless you want cert mail).  
3. **Website alert email To:** `web_check@athenabest.com`  
   If you leave this **blank**, it uses SMTP To (helpdesk). This site **does not** blank it.  
4. **Save**.  
5. **Test Email Web DOWN** â€” must arrive in **web_check**, not helpdesk.

**Important** checkbox on a site + Slack webhook: extra Slack for those URLs. This site Slack is on, mention `#web-monitor`.

Website rows live in **Postgres**. Windows DEV and 3.200 are **different databases**.

---

## 5. OTP and User Setup (so staff can log in)

### 5.1 Policy (do this before blaming users)

**MENU â†’ Settings â†’ OTP / 2-step policy** **or** **User Setup** top checkboxes, then **Save policy**.

Blueprint:

- **Require OTP** = on (no second factor â†’ no Dashboard)  
- **Allow Authenticator** = on  
- **Allow YubiKey** = on  
- **Allow self-register** = on  
- Local admin Email-OTP address = `it.helpdesk@athenabest.com`  
- TTL 300 seconds, max 5 attempts  
- **Login lockout** = on, **5** fails, **15** minutes  
- **Local admin no lockout** = on  
- **Local admin internal-only** = on (CF-Ray still allows this site)

**Yubico Client ID + Secret** (User Setup, two boxes):

1. Get keys from https://upgrade.yubico.com/getapikey/  
2. Paste Client ID and API Secret.  
3. **Save policy** at the top.  
4. Only then register keys.  

This site already has API keys. A new site without them: Yubi button may show, verify **fails**.

### 5.2 Enroll Authenticator for a user who cannot do it alone

Sit together. User has the phone app installed (User Guide Â§2.1).

1. **MENU â†’ User Setup**.  
2. **Register Authenticator for:** type AD login, e.g. `jane.chan` (sAMAccountName, not email unless that is the sAM).  
3. **Type:** AD user (or Local admin for `admin`).  
4. **+ Register Authenticator**.  
5. A **QR** appears. User scans it.  
6. User reads **6 digits**. Type into **Code from Authenticator app**.  
7. **Confirm Authenticator**.  

If you skip Confirm, login will **not** offer Authenticator.

To enroll YubiKey: same username field â†’ **Click here, then touch YubiKey** â†’ **+ Register YubiKey**. This does **not** remove TOTP.

### 5.3 Admin / RDP / SSH lists

On User Setup, tick names independently:

| List | Meaning |
|------|---------|
| Admin | Settings, Host Setup, User Setup, â€¦ |
| RDP | Windows **RDP** button / web desktop |
| SSH | Linux **Terminal** button |

Do not make every AD user Admin. Copy this site: three admins; SSH may be a slightly larger set.

---

## 6. Host Setup â€” add a machine (slow, exact)

**MENU â†’ Host Setup**. You see a **table**. Buttons on the right of the header: **+ Linux**, **+ Windows**, **+ SMA**, **+ PVE**, **+ PBS**, **+ FortiGate**, **Save**, **Close**.

**Blank Password / API key = keep what is already saved.** If you type a space you may overwrite. Leave the box empty unless you intend to change the secret.

Deleting an SMA row must also clear legacy **Syslog** `sma_url` / `sma_name` (the example template used HK `192.168.3.18`). Old builds resurrect that host after Save. v1.4.96+ clears it; on an old binary empty those fields in **Syslog Setup** or in `linmon.json`.

### 6.1 Add a Linux SSH host

1. **+ Linux**.  
2. **Kind** = linux.  
3. **Name** = short label (dashboard card).  
4. **IP / Host** = IPv4, e.g. `192.168.3.10`.  
5. **Port** = SSH port (`22` or `7788` like 3.200 itself).  
6. **User** = SSH user.  
7. **Key path** â€” **dropdown** of files in `/keys/` (Upload above first if empty). Target host must already trust the matching public key.  
8. **Password** = only if you do not use a key (blank = keep saved).  
9. **On** = ticked.  
10. **Log** = ticked only if you want **SSH journal warning+** on the card (â€œSSH journal errorsâ€). This is **not** rsyslog and **not** Windows Event Log. Syslog lines still appear under Logs â†’ **linux (error)** and on the cardâ€™s **Linux Syslog** box when the client forwards to :514.  
11. Click **Save**. Wait for **Hosts saved**.  

The card appears after the next poll (up to **10 minutes**, Settings poll seconds = 600 here). **Doubleâ€‘click** the card (v1.4.109+) to open that hostâ€™s syslog Logs â€” see **Â§3h**.

**Do not use this linmon serverâ€™s own LAN IP** (21.4: `192.168.21.4`, 11.4: `192.168.11.4`, 3.200: `192.168.3.200`). collect-log runs **inside Docker**; `dial tcp â€¦:22: i/o timeout` is hairpin, not a bad password. **Other hosts on the LAN keep their real IPs** and work. The hint `HostKey +ssh-rsa` only matters **after** TCP connects (old OpenSSH) â€” do not tick it for a timeout. You do not need that tick on hosts that already SSH OK.

For the box that **runs** linmon:

| Host Setup IP | When |
|---------------|------|
| `host.docker.internal` | Preferred. collect-log needs `extra_hosts: host.docker.internal:host-gateway` (compose). |
| `172.17.0.1` | Docker bridge to the host (often works without compose change). |
| Own LAN IP | **Never** â€” timeout |

Or **omit** this machine from Host Setup and only collect rsyslog â†’ `172.16.0.20:514` (see install guide Â§6b). Key path e.g. `/keys/id_ed25519` if you SSH with a key.

### 6.2 Add a Windows host (for RDP + Winlog matching)

1. **+ Windows**. Port **3389**. User `DOMAIN\user` or Domain column.  
2. Save.  
3. On the PC, install **Winlog** (public `linmon-winlog-setup.exe`). In Winlog Settings, syslog host = **`192.168.3.200`**, port 514.  
4. User who should click **RDP** must be in **User Setup â†’ RDP**.

**Winlog send filter (v1.0.91+):** default sends **Critical + Error + Warning** (plus logon/service/audit failures). **Information** stays off. Older agents only sent Critical/Error â€” tray **Update from GitHub** (or reinstall setup) migrates once and ticks Warning. To stop Warnings again, uncheck **Warning** in Settings and Save.

### 6.3 Add FortiGate API (CPU/RAM bars)

Create the API user **on the FortiGate**, then paste into linmon.

1. FortiGate GUI: **System â†’ Administrators â†’ Create New â†’ REST API Admin**.  
   Username e.g. `linmon`. Profile **`super_admin_readonly`**. Trusted Host = **linmon server LAN IP**.  
2. Copy the **API key** (once).  
   CLI: `config system api-user` / `execute api-user generate-key linmon`.  
3. **Host Setup â†’ + FortiGate**. Port **443**. User = API admin name. Password = API key. IP = **management** IP. Save.

Syslog still needs **Syslog Setup** `devname=IP` (e.g. `abhk-cpc-91=192.168.98.2`). Display name and syslog name may differ.

Full steps: **`docs/INSTALL-LINMON-SYSLOG-SERVER.md` Â§5b**.

### 6.4 SMA / PVE / PBS

**PVE and PBS have public scripts** â€” run those, do not create the token by hand. SMA has **no** script (GUI API Keys). Full wget: **`docs/INSTALL-LINMON-SYSLOG-SERVER.md` Â§5b**.

| Button | Create on the device | Port | Host Setup User | Password |
|--------|----------------------|------|-----------------|----------|
| + SMA | FortiAuthenticator **Administrators â†’ API Keys** (not Services). Username **`API-USER`**. | 8443 | `API-USER` | AMC API key |
| + PVE | **Script** on the node: `install-pve-linmon-api.sh` â†’ `linmon@pve!linmon` | 8006 | **full** `linmon@pve!linmon` | token secret (once) |
| + PBS | **Script** on PBS: `install-pbs-linmon-api.sh` â†’ `linmon@pbs!linmon` | 8007 | `linmon@pbs!linmon` | token secret (once) |

```bash
wget -qO /tmp/install-pve-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
bash /tmp/install-pve-linmon-api.sh

wget -qO /tmp/install-pbs-linmon-api.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
bash /tmp/install-pbs-linmon-api.sh
```

`--recreate` issues a **new** secret (old token deleted). Paste Token ID into Host Setup **User** (must include `!tokenid`). Blank password on later Save keeps the secret.

Full GUI/CLI and Pass/Fail: **`docs/INSTALL-LINMON-SYSLOG-SERVER.md` Â§5b**.

---

## 7. Syslog Setup â€” when the IP looks like 172.16.0.1

**MENU â†’ Syslog Setup**.

Docker rewrites the sender. Map **device name = real LAN IP**, one per line:

```
Name=192.168.x.x
```

This site includes:

```
athenabest-91g-hk=192.168.3.253
abhk-cpc-91=192.168.98.2
athenabest-214=192.168.3.214
sma-8200v=192.168.3.18
```

**QNAP:** exact hostname only. `metis-sg` must **not** match `Metis-SG-BDC`.

Click **Save**. Devices must already send to **192.168.3.200:514**, not to the website URL.

---

## 8. Linux client in another office (not this server)

You are **not** installing LINMON. You only point rsyslog at the linmon **LAN IP**. Run INSTALL on the **client**, not on the linmon Docker host.

Installer **v1.0.2+** (public `andylee03/linmon-winlog`): default `--min err` forwards err/crit/alert/emerg **plus** `auth,authpriv.info` (sshd **Failed password** / **Invalid user**) and `kern.err`. Older clients that used `authpriv.notice` miss SSH login failures â€” **UPDATE** them.

### INSTALL (public wget â€” preferred)

Public **shell** (no PowerShell, no deploy key):

```bash
wget -qO /tmp/INSTALL.sh https://raw.githubusercontent.com/andylee03/linmon-winlog/main/INSTALL.sh
# HK:
sudo bash /tmp/INSTALL.sh --host 192.168.3.200 --port 514 --proto udp --min err
# SG (another Linux box, not 11.4 itself):
sudo bash /tmp/INSTALL.sh --host 192.168.11.4 --port 514 --proto udp --min err
# syslog-4 LAN clients (not on 21.4 itself):
sudo bash /tmp/INSTALL.sh --host 192.168.21.4 --port 514 --proto udp --min err
logger -p user.err 'linmon-syslog-test'
```

### UPDATE (public wget â€” preferred)

Always wget a **fresh** `UPDATE.sh` (do not reuse an old copy on disk):

```bash
wget -qO /tmp/UPDATE.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh
sudo bash /tmp/UPDATE.sh

# or one line:
wget -qO- https://raw.githubusercontent.com/andylee03/linmon-winlog/main/UPDATE.sh | sudo bash
```

That re-downloads `install-linux-syslog.sh` and re-applies `/etc/linmon-syslog.conf`.

If `/etc/linmon/github_deploy` exists but is **corrupt**, public `UPDATE.sh` may try private `--update` and fail with `Load key ... error in libcrypto` / `Permission denied (publickey)`. Fix:

```bash
sudo mv /etc/linmon/github_deploy /etc/linmon/github_deploy.bad
wget -qO /tmp/install-linux-syslog.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-linux-syslog.sh
sudo bash /tmp/install-linux-syslog.sh
sudo /usr/local/sbin/install-linux-syslog.sh --show   # expect script v1.0.2 + authpriv.info
```

Replace the deploy key later only if you still use the private USB pack / `linmon-syslog-update`.

If you install **on the linmon Docker host itself** (3.200 / 11.4 / **21.4**), `--host` = that machineâ€™s LAN IP **drops** UDP (hairpin). Use `--host 172.16.0.20 --proto tcp`. Same for Host Setup SSH: never the own LAN IP (`192.168.21.4` on 21.4) â€” use `172.17.0.1`. Other hosts keep real IPs.

In **Logs**, pick **`linux (error)`**, not `linux`.

Full text: [INSTALL-LINUX-HOST-CLIENT.md](https://github.com/andylee03/linmon-winlog/blob/main/INSTALL-LINUX-HOST-CLIENT.md).

---

## 9. Deploy this server (when a developer says â€œnew versionâ€)

**GitHub only.** Do not `git pull` `vide`. Do not scp bins from the office PC. Do not `sudo`.

Use the public **`SERVER-UPDATE.sh`** (this is the server update script â€” **not** the Linux client `UPDATE.sh`):

```bash
wget -qO /tmp/SERVER-UPDATE.sh \
  https://raw.githubusercontent.com/andylee03/linmon-winlog/main/SERVER-UPDATE.sh
bash /tmp/SERVER-UPDATE.sh --dir /data/linmon
curl -skS https://127.0.0.1/api/version
# expect e.g. "1.4.102" â€” HTTP-only: curl -sS http://127.0.0.1/api/version
```

| Site | SSH | `--dir` | Check |
|------|-----|---------|--------|
| 3.200 | `athenabest` :7788 | `/data/linmon` | HTTPS `/api/version` |
| 11.4 | `athenabest` :22 | `/data/linmon` | |
| 21.4 | `metis` :22 | `/data/linmon` | |

Uses `~/.linmon/bin_deploy` to clone private `andylee03/linmon-bin`. When the stack is already up, UPDATE mainly **`docker cp`**s `linmon` / `collect-log` into the running containers (does not rebuild images).

**Compose / `/keys` (v1.4.102+ Upload SSH key):** pack compose uses `/keys:rw`. Stock UPDATE may leave an old `/keys:ro` on disk. If Host Setup **Upload** fails to write keys, sync compose from the pack clone and recreate, then UPDATE **again** (recreate resets the binary overlay):

```bash
cp -f ~/.linmon/bin-repo/docker-compose.yml /data/linmon/docker-compose.yml
mkdir -p /data/linmon/keys
cd /data/linmon && bash scripts/dc.sh up -d
bash /tmp/SERVER-UPDATE.sh --dir /data/linmon   # re-apply bins after recreate
grep keys /data/linmon/docker-compose.yml             # expect /keys:rw
```

HTTPS needs `ENABLE_HTTPS=1` and cert files; missing certs â†’ nginx dies.

RDP record path: Settings saves `configs/rdp-record.env` only. Then `./scripts/dc.sh up -d`. Do **not** restart dockerd. Live folder: **`/data/docker/rdp-recording`** (same disk as `/mnt/data1t/docker/rdp-recording`).

---

## 10. New country LINMON **server** (copy process, new secrets)

1. New Ubuntu + Docker. wget **`SERVER-INSTALL.sh`** from `linmon-winlog` (install guide). New `LINMON_SECRET_KEY`. Copy **example** json, not 3.200 live json. First login **`admin` / `change-me`**.  
2. Put certs, enable HTTPS (or stay HTTP :80 until certs).  
3. Settings: OTP, SMTP, alerts **95% / 60s / 60m** like HK.  
4. Website To **separate** from IT To. SSL email optional (HK **off**).  
5. User Setup: few Admins; RDP/SSH as needed. Fill Yubico if you use Yubi.  
6. Host Setup + Syslog Setup with **that countryâ€™s IPs**. Do not SSH-poll the linmon host via its own LAN IP.  
7. Browser URL = that countryâ€™s HTTPS name. Devices :514 = that countryâ€™s linmon IP.  
8. Linux senders: public `INSTALL.sh --host THAT.IP` (not on the linmon host itself).

---

## 11. Do not

| Donâ€™t | Why |
|-------|-----|
| `git pull` / `sudo git pull` on the server | Source stays on GitHub `vide`; servers wget **`SERVER-UPDATE.sh`** |
| scp bins from the office PC | Pack is private `linmon-bin` via deploy key |
| `git add -f configs/linmon.json` | Secrets in GitHub |
| Copy 3.200 `.env` to 11.4 / 21.4 | Wrong crypto key |
| Host Setup IP = this linmonâ€™s LAN IP | Docker hairpin SSH timeout (`192.168.21.4` on 21.4) |
| Tick HostKey +ssh-rsa to â€œfixâ€ i/o timeout | TCP never connected |
| Expose 514 on the public internet | Log injection / noise |
| Ship Go `winlog-setup` as the Windows installer | Use Inno pack |
| `taskkill` Winlog Settings from inside the form | UI hangs |
| Think Host Setup **Log** = Windows Event Log | Winlog â†’ syslog |
| Think Host Setup **Log** = Logs â†’ linux (error) | **Log** tick = SSH journal only; rsyslog = **linux_error** / Linux Syslog box (Â§3h) |
| Expect card SSH errors = syslog volume | Journal warning+ can be 0 while syslog info lines fill Logs |
| Put `.ps1` on a Linux client | Public install is **INSTALL.sh** |

---

## 12. Publish Windows vs Linux clients

| Product | Repo | Command (on a Windows office PC) |
|---------|------|-----------------------------------|
| Winlog | public `andylee03/linmon-winlog` | `.\scripts\pack-winlog-syslog.ps1` then `.\scripts\release-winlog.ps1` (**GitHub Latest**) |
| Linux **INSTALL.sh / UPDATE.sh** | same public repo | source in `cmd/linux-syslog/pack/public/` + `scripts/install-linux-syslog.sh` â€” clients **wget** from `linmon-winlog` (no private key) |
| **Android APK** | same public repo | see **Â§12b** â€” tag `linmon-apk-v*` (**not** Latest; Winlog stays Latest) |
| Linux country USB (optional) | private `andylee03/linmon-syslog` | `.\scripts\pack-linux-syslog.ps1` â†’ `dist\linmon-syslog\` (+ read-only deploy key). Prefer public wget for updates. |

### 12b. Android APK (sideload)

| | |
|--|--|
| **Current** | **1.0.12** Â· `linmon-apk-v1.0.12` |
| **Download** | https://github.com/andylee03/linmon-winlog/releases/download/linmon-apk-v1.0.12/linmon.apk |
| **Package** | `com.abagile.linmon` |
| **Needs server** | â‰¥ **1.4.101** for fingerprint / face device login |
| **Build** | `.\scripts\build-linmon-apk.ps1` â†’ `dist\linmon.apk` |
| **Signing** | stable `android/linmon/keystore/linmon-release.jks` (v1.0.9+) |

**Default sites in the APK:** Prod Â· Metis SG (`syslog.metisgl.com.sg`) Â· CPC NET (`syslog.metisgl.com`).

**Behaviour (admin should know):**

- Open â†’ check GitHub for newer `linmon-apk-v*` â†’ **Update / Not now** â†’ site picker.  
- Long-press **Sites** also has **Check for APK updateâ€¦**.  
- Update downloads APK, **fully exits** the app, then opens the system installer.  
- Login footer shows server version **Â· APK x.y.z**.  
- Face unlock: many OEMs only allow lock-screen face â€” apps need Classâ€‘2 biometric or fingerprint.  
- **Package conflict** installing over 1.0.8 or older: uninstall once, then install 1.0.12+ (signing key changed).  
- After releasing a new APK: `gh release edit linmon-apk-vX.Y.Z --latest=false` and keep **Winlog** as Latest.

---

## 13. If something is wrong (admin)

| Symptom | Check |
|---------|--------|
| No Host Setup in MENU | Your user is not in Admin list |
| Test email fails | SMTP Enable, host, To, firewall 587 |
| Disk mail missing | Threshold 95%; cooldown; Test HD email |
| Web mail in wrong inbox | Website To vs SMTP To |
| FortiGate â€œno APIâ€ | Host Setup + FortiGate row; syslog name â‰  display name; match by IP |
| FortiGate CPU always 0 | Need linmon **v1.4.92+** (resource/usage) |
| UPDATE `Permission denied (publickey)` | **Server:** `~/.linmon/bin_deploy` is `linmon-bin-deploy`, not `id_ed25519`. **Linux client:** broken `/etc/linmon/github_deploy` â†’ move it aside and wget public `install-linux-syslog.sh` (Â§8) |
| Linux client misses SSH Failed password | Need installer **v1.0.2+** (`authpriv.info`); wget public `UPDATE.sh` |
| Linux card â€œSSH journal errors (0)â€ but Logs full | Normal if journal is quiet â€” use **Linux Syslog** box / doubleâ€‘click card (Â§3h); check client â†’ `:514` |
| Doubleâ€‘click Linux card does nothing useful | Need server **v1.4.109+**; Ctrl+F5; doubleâ€‘click card body (not only the name) |
| nginx down | Certs + `ENABLE_HTTPS=1` |
| Android APK â€œpackage conflictâ€ on update | Uninstall once; install **1.0.12+** (stable key). Later updates should overwrite |
| Android APK update leaves blank / stuck | Need **1.0.10+** (exit before installer). Cancel on Add/Manage before login â†’ back to site picker (**1.0.5+**) |
| Android â€œbiometric unavailableâ€ but phone has face | Lock-screen-only face; use fingerprint or password/OTP |
| APK release became GitHub **Latest** | `gh release edit linmon-apk-vâ€¦ --latest=false`; set Winlog tag `--latest` |
