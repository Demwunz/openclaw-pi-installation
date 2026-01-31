#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-openclaw-pi.sh  (run on macOS)
#
# Automates:
#  - SSD wipe + flash Raspberry Pi OS (via Raspberry Pi Imager CLI)
#  - Secure provisioning over SSH
#  - Node.js 22 install + OpenClaw install (non-Docker)
#  - systemd service + basic host hardening
#
# DANGEROUS: This script can ERASE a disk.
# Safety features:
#   - Lists disks and forces explicit disk selection (e.g. disk4)
#   - Shows disk details before erasing
#   - Refuses to erase internal disks
#   - Requires a "type-to-confirm" phrase: ERASE diskX
###############################################################################

# -----------------------------
# Config (override via env vars)
# -----------------------------
PI_HOST="${PI_HOST:-onepi.local}"
PI_USER="${PI_USER:-openclaw}"
PI_SSH_PORT="${PI_SSH_PORT:-22}"
SSH_PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"

# Optional: if you want to skip the flash step and do only provisioning, set:
SKIP_FLASH="${SKIP_FLASH:-0}"

# Pi Imager CLI (optional). If missing, script will tell you to flash via GUI.
RPI_IMAGER_BIN="${RPI_IMAGER_BIN:-rpi-imager}"
RPI_OS_PRESET="${RPI_OS_PRESET:-raspios_arm64}"   # preset name varies by imager version
RPI_OS_IMAGE_PATH="${RPI_OS_IMAGE_PATH:-}"        # optional local .img/.zip

OPENCLAW_NPM_PKG="${OPENCLAW_NPM_PKG:-openclaw@latest}"
OPENCLAW_SERVICE_NAME="${OPENCLAW_SERVICE_NAME:-openclaw}"

# -----------------------------
# Helpers
# -----------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

confirm_phrase() {
  local phrase="$1"
  echo ""
  echo "Type exactly to confirm: ${phrase}"
  read -r -p "> " ans
  [[ "$ans" == "$phrase" ]] || die "Confirmation did not match. Aborting."
}

wait_for_ssh() {
  local host="$1" port="$2"
  echo "Waiting for SSH on ${host}:${port} ..."
  for _ in $(seq 1 180); do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      echo "SSH is reachable."
      return 0
    fi
    sleep 2
  done
  die "Timed out waiting for SSH on ${host}:${port}"
}

run_ssh() {
  local cmd="$1"
  ssh -p "$PI_SSH_PORT" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
    "${PI_USER}@${PI_HOST}" "$cmd"
}

run_ssh_sudo() {
  local cmd="$1"
  run_ssh "sudo bash -lc $(printf '%q' "$cmd")"
}

# -----------------------------
# Preflight
# -----------------------------
need_cmd diskutil
need_cmd ssh
need_cmd nc

[[ -f "$SSH_PUBKEY" ]] || die "SSH public key not found at: $SSH_PUBKEY (set SSH_PUBKEY=...)"

echo "=================================================="
echo "OpenClaw Pi Bootstrap (macOS) — DESTRUCTIVE ACTIONS"
echo "=================================================="
echo "This script can ERASE a disk. Read carefully."
echo ""

# -----------------------------
# Step 1: Choose target disk
# -----------------------------
echo "Available disks:"
diskutil list
echo ""

read -r -p "Enter target SSD disk identifier (e.g. disk4): " TARGET_DISK
[[ "$TARGET_DISK" =~ ^disk[0-9]+$ ]] || die "Invalid disk identifier: $TARGET_DISK"

# Show disk details and enforce "external" (not internal/system)
echo ""
echo "Disk details for /dev/${TARGET_DISK}:"
diskutil info "/dev/${TARGET_DISK}" || die "Could not read disk info."

# Refuse internal disks (extra safety)
INTERNAL="$(diskutil info "/dev/${TARGET_DISK}" | awk -F': ' '/Device Location|Internal/ {print tolower($2)}' | head -n 1)"
# Many macs show "Device Location: Internal" or "Internal: Yes"
if diskutil info "/dev/${TARGET_DISK}" | grep -qiE 'Device Location:\s*Internal|Internal:\s*Yes'; then
  die "Refusing to erase an INTERNAL disk (/dev/${TARGET_DISK}). Choose the external SSD."
fi

echo ""
echo "WARNING: Next step may ERASE /dev/${TARGET_DISK} بالكامل."
confirm_phrase "ERASE ${TARGET_DISK}"

# -----------------------------
# Step 2: Erase disk
# -----------------------------
echo "Erasing /dev/${TARGET_DISK} ..."
diskutil eraseDisk FAT32 RPI "/dev/${TARGET_DISK}"

# -----------------------------
# Step 3: Flash Raspberry Pi OS (optional)
# -----------------------------
if [[ "$SKIP_FLASH" == "1" ]]; then
  echo ""
  echo "SKIP_FLASH=1 set — skipping OS flash step."
else
  echo ""
  echo "======================================"
  echo "Flashing Raspberry Pi OS to /dev/${TARGET_DISK}"
  echo "======================================"

  if command -v "$RPI_IMAGER_BIN" >/dev/null 2>&1; then
    if [[ -n "$RPI_OS_IMAGE_PATH" ]]; then
      [[ -f "$RPI_OS_IMAGE_PATH" ]] || die "RPI_OS_IMAGE_PATH not found: $RPI_OS_IMAGE_PATH"
      echo "Using local OS image: $RPI_OS_IMAGE_PATH"
      "$RPI_IMAGER_BIN" --cli --image "$RPI_OS_IMAGE_PATH" --storage "/dev/${TARGET_DISK}" || {
        echo "Pi Imager CLI failed. Flash via GUI and re-run with SKIP_FLASH=1."
        exit 1
      }
    else
      echo "Using OS preset: $RPI_OS_PRESET"
      echo "If this fails, flash via Raspberry Pi Imager GUI, then re-run with SKIP_FLASH=1."
      "$RPI_IMAGER_BIN" --cli --os "$RPI_OS_PRESET" --storage "/dev/${TARGET_DISK}" || {
        echo "Pi Imager CLI failed. Flash via GUI and re-run with SKIP_FLASH=1."
        exit 1
      }
    fi
  else
    echo "Pi Imager CLI not found (${RPI_IMAGER_BIN})."
    echo "Please flash the SSD using Raspberry Pi Imager GUI, then re-run with:"
    echo "  SKIP_FLASH=1 ./setup-openclaw-pi.sh"
    exit 1
  fi
fi

# -----------------------------
# Step 4: Boot Pi and provision via SSH
# -----------------------------
echo ""
echo "=================================================="
echo "Now move the SSD to the Pi and boot it."
echo "Ensure it's on the same network as this Mac."
echo "Then press Enter to continue provisioning over SSH."
echo "=================================================="
read -r -p "Press Enter when Pi is booted... " _

wait_for_ssh "$PI_HOST" "$PI_SSH_PORT"

echo ""
echo "Pushing SSH key (idempotent) ..."
PUBKEY_CONTENT="$(cat "$SSH_PUBKEY")"
run_ssh "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qF $(printf '%q' "$PUBKEY_CONTENT") ~/.ssh/authorized_keys || echo $(printf '%q' "$PUBKEY_CONTENT") >> ~/.ssh/authorized_keys"

echo ""
echo "Provisioning OS packages + security hardening ..."
run_ssh_sudo "
set -euo pipefail
apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
DEBIAN_FRONTEND=noninteractive apt install -y git curl wget unzip ca-certificates ufw fail2ban openssl net-tools perl
"

echo ""
echo "Adding 2GB swapfile if missing ..."
run_ssh_sudo "
set -euo pipefail
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
"

echo ""
echo "Hardening SSH (keys-only, no root login) ..."
echo "NOTE: This will disable SSH password login. Ensure your key works."
run_ssh_sudo "
set -euo pipefail
SSHD=/etc/ssh/sshd_config
cp -n \$SSHD \${SSHD}.bak || true
perl -0777 -i -pe 's/^#?\\s*PermitRootLogin\\s+.*/PermitRootLogin no/mg;
                  s/^#?\\s*PasswordAuthentication\\s+.*/PasswordAuthentication no/mg;
                  s/^#?\\s*PubkeyAuthentication\\s+.*/PubkeyAuthentication yes/mg' \$SSHD
systemctl restart ssh
"

echo ""
echo "Enabling firewall (UFW) ..."
run_ssh_sudo "
set -euo pipefail
ufw allow OpenSSH
ufw --force enable
ufw status verbose
"

echo ""
echo "Enabling fail2ban ..."
run_ssh_sudo "
set -euo pipefail
systemctl enable fail2ban
systemctl restart fail2ban
systemctl status fail2ban --no-pager
"

echo ""
echo "Installing Node.js 22+ ..."
run_ssh_sudo "
set -euo pipefail
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
DEBIAN_FRONTEND=noninteractive apt install -y nodejs
node -v
npm -v
"

echo ""
echo "Installing OpenClaw ..."
run_ssh_sudo "
set -euo pipefail
npm install -g ${OPENCLAW_NPM_PKG}
openclaw --version
"

echo ""
echo "Creating systemd service (${OPENCLAW_SERVICE_NAME}) ..."
run_ssh_sudo "
set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw)
if [[ -z \"\$OPENCLAW_BIN\" ]]; then
  echo 'openclaw not found in PATH' >&2
  exit 1
fi

# Best-effort command detection
GATEWAY_CMD=''
if \$OPENCLAW_BIN --help 2>/dev/null | grep -qE '\\bgateway\\b'; then
  GATEWAY_CMD=\"\$OPENCLAW_BIN gateway\"
elif \$OPENCLAW_BIN --help 2>/dev/null | grep -qE '\\bstart\\b'; then
  GATEWAY_CMD=\"\$OPENCLAW_BIN start\"
else
  GATEWAY_CMD=\"\$OPENCLAW_BIN\"
fi

cat >/etc/systemd/system/${OPENCLAW_SERVICE_NAME}.service <<'UNIT'
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${PI_USER}
WorkingDirectory=/home/${PI_USER}
ExecStart=/usr/bin/env bash -lc '__GATEWAY_CMD__'
Restart=always
RestartSec=3
Environment=NODE_ENV=production

# Basic hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/home/${PI_USER}

[Install]
WantedBy=multi-user.target
UNIT

sed -i \"s|__GATEWAY_CMD__|\${GATEWAY_CMD//|/\\\\|}|g\" /etc/systemd/system/${OPENCLAW_SERVICE_NAME}.service
systemctl daemon-reload
systemctl enable ${OPENCLAW_SERVICE_NAME}
systemctl restart ${OPENCLAW_SERVICE_NAME}
systemctl status ${OPENCLAW_SERVICE_NAME} --no-pager
"

echo ""
echo "DONE."
echo ""
echo "NEXT (manual, important):"
echo "  1) SSH into the Pi: ssh ${PI_USER}@${PI_HOST}"
echo "  2) Run OpenClaw wizard (command varies):"
echo "       openclaw --help"
echo "       openclaw onboard    # or: openclaw configure"
echo "  3) In config, bind gateway to 127.0.0.1 (NOT 0.0.0.0)."
echo "  4) Restart service: sudo systemctl restart ${OPENCLAW_SERVICE_NAME}"
echo "  5) Logs: journalctl -u ${OPENCLAW_SERVICE_NAME} -n 200 --no-pager"