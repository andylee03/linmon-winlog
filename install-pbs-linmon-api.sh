#!/bin/bash
# Run ON the Proxmox Backup Server (as root).
# Creates user linmon@pbs (Audit) + API token "linmon".
# Paste Token ID + Secret into linmon Host Setup (Kind=pbs, Port=8007).
#
# Public wget (no token):
#   wget -qO /tmp/install-pbs-linmon-api.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
#   bash /tmp/install-pbs-linmon-api.sh
#
#   curl -fsSL -o /tmp/install-pbs-linmon-api.sh \
#     https://raw.githubusercontent.com/andylee03/linmon-winlog/main/install-pbs-linmon-api.sh
#   bash /tmp/install-pbs-linmon-api.sh
#
#   bash /tmp/install-pbs-linmon-api.sh --recreate
#
set -eu

USER_ID="${LINMON_PBS_USER:-linmon@pbs}"
TOKEN_NAME="${LINMON_PBS_TOKEN:-linmon}"
RECREATE=0

for a in "$@"; do
  case "$a" in
    --recreate|-f) RECREATE=1 ;;
    -h|--help)
      echo "Usage: $0 [--recreate]"
      echo "  Creates ${USER_ID}!${TOKEN_NAME} with Audit on / and /datastore"
      exit 0
      ;;
  esac
done

if ! command -v proxmox-backup-manager >/dev/null 2>&1; then
  echo "ERROR: proxmox-backup-manager not found. Run this on a PBS host." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

if proxmox-backup-manager user list | awk '{print $1}' | grep -qx "$USER_ID"; then
  echo "User $USER_ID already exists"
else
  proxmox-backup-manager user create "$USER_ID" --comment "linmon dashboard (read-only)"
  echo "Created user $USER_ID"
fi

# PBS tokens need their own ACL (intersected with the user).
proxmox-backup-manager acl update / Audit --auth-id "$USER_ID"
proxmox-backup-manager acl update /datastore DatastoreAudit --auth-id "$USER_ID"
echo "ACL: $USER_ID → Audit / + DatastoreAudit /datastore"

TOKEN_ID="${USER_ID}!${TOKEN_NAME}"
if proxmox-backup-manager user list-tokens "$USER_ID" 2>/dev/null | grep -q "$TOKEN_ID\|$TOKEN_NAME"; then
  if [[ "$RECREATE" -eq 1 ]]; then
    proxmox-backup-manager user delete-token "$USER_ID" "$TOKEN_NAME"
    echo "Removed old token $TOKEN_ID"
  else
    echo "Token $TOKEN_ID already exists (secret cannot be shown again)."
    echo "Re-run with --recreate for a new secret."
    proxmox-backup-manager acl update / Audit --auth-id "$TOKEN_ID" || true
    proxmox-backup-manager acl update /datastore DatastoreAudit --auth-id "$TOKEN_ID" || true
    echo
    echo "Host Setup:"
    echo "  Kind     pbs"
    echo "  Name     $(hostname -s)"
    echo "  IP/Host  $(hostname -I 2>/dev/null | awk '{print $1}')"
    echo "  Port     8007"
    echo "  User     $TOKEN_ID"
    echo "  Password (saved token secret)"
    exit 0
  fi
fi

echo
echo "=== Creating token (secret is shown ONCE) ==="
proxmox-backup-manager user generate-token "$USER_ID" "$TOKEN_NAME"
proxmox-backup-manager acl update / Audit --auth-id "$TOKEN_ID"
proxmox-backup-manager acl update /datastore DatastoreAudit --auth-id "$TOKEN_ID"
echo
echo "Host Setup → + PBS:"
echo "  Kind          pbs"
echo "  Name          $(hostname -s)"
echo "  IP / Host     $(hostname -I 2>/dev/null | awk '{print $1}')"
echo "  Port          8007"
echo "  User / Token  $TOKEN_ID"
echo "  Password      <value from Result above>"
echo
echo "GUI: Configuration → Access Control → API Tokens"
echo "Auth header: Authorization: PBSAPIToken=${TOKEN_ID}:<secret>"
