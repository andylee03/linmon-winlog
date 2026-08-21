#!/bin/bash
# Run ON each Proxmox VE node/cluster (as root).
# Creates user linmon@pve (PVEAuditor) + API token "linmon".
# Paste Token ID + Secret into linmon Host Setup (Kind=pve, Port=8006).
#
# Public wget (no token):
#   wget -qO /tmp/install-pve-linmon-api.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
#   bash /tmp/install-pve-linmon-api.sh
#
#   curl -fsSL -o /tmp/install-pve-linmon-api.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pve-linmon-api.sh
#   bash /tmp/install-pve-linmon-api.sh
#
#   bash /tmp/install-pve-linmon-api.sh --recreate   # new secret (old token deleted)
#
set -eu

USER_ID="${LINMON_PVE_USER:-linmon@pve}"
TOKEN_NAME="${LINMON_PVE_TOKEN:-linmon}"
RECREATE=0

for a in "$@"; do
  case "$a" in
    --recreate|-f) RECREATE=1 ;;
    -h|--help)
      echo "Usage: $0 [--recreate]"
      echo "  Creates ${USER_ID}!${TOKEN_NAME} with PVEAuditor on /"
      exit 0
      ;;
  esac
done

if ! command -v pveum >/dev/null 2>&1; then
  echo "ERROR: pveum not found. Run this on a Proxmox VE host." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

if ! pveum user list | awk '{print $1}' | grep -qx "$USER_ID"; then
  pveum user add "$USER_ID" --comment "linmon dashboard (read-only)"
  echo "Created user $USER_ID"
else
  echo "User $USER_ID already exists"
fi

pveum acl modify / --users "$USER_ID" --roles PVEAuditor
echo "ACL: $USER_ID → PVEAuditor on /"

TOKEN_ID="${USER_ID}!${TOKEN_NAME}"
if pveum user token list "$USER_ID" 2>/dev/null | grep -q "$TOKEN_NAME"; then
  if [[ "$RECREATE" -eq 1 ]]; then
    pveum user token remove "$USER_ID" "$TOKEN_NAME"
    echo "Removed old token $TOKEN_ID"
  else
    echo "Token $TOKEN_ID already exists (secret cannot be shown again)."
    echo "Re-run with --recreate for a new secret, or paste the saved secret in Host Setup."
    echo
    echo "Host Setup:"
    echo "  Kind     pve"
    echo "  Name     $(hostname -s)"
    echo "  IP/Host  $(hostname -I 2>/dev/null | awk '{print $1}')"
    echo "  Port     8006"
    echo "  User     $TOKEN_ID"
    echo "  Password (saved token secret)"
    exit 0
  fi
fi

echo
echo "=== Creating token (secret is shown ONCE) ==="
pveum user token add "$USER_ID" "$TOKEN_NAME" --comment "linmon" --privsep 0
echo
echo "Host Setup → + PVE:"
echo "  Kind          pve"
echo "  Name          $(hostname -s)"
echo "  IP / Host     $(hostname -I 2>/dev/null | awk '{print $1}')"
echo "  Port          8006"
echo "  User / Token  $TOKEN_ID"
echo "  Password      <value from the table above>"
echo
echo "GUI: Datacenter → Permissions → API Tokens"
echo "Auth header: Authorization: PVEAPIToken=${TOKEN_ID}=<secret>"
