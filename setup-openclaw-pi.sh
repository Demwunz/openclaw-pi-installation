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
# WARNING: This erases the target disk.
###############################################################################

# -----------------------------
# User-configurable variables
# -----------------------------
PI_HOST="${PI_HOST:-onepi.local}"          # e.g. onepi.local or an IP
PI_USER="${PI_USER:-openclaw}"             # username configured in Pi Imager advanced settings
PI_SSH_PORT="${PI_SSH_PORT:-22}"
SSH_PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}"

# Raspberry Pi Imager settings
RPI_IMAGER_BIN="${RPI_IMAGER_BIN:-rpi-imager}"   # ensure Raspberry Pi Imager is installed
RPI_OS_PRESET="${RPI_OS_PRESET:-raspios_arm64}"  # preset name varies; we will prompt if needed
RPI_STORAGE_DISK=""                               # will prompt
RPI_OS_IMAGE_PATH="${RPI_OS_IMAGE_PATH:-}"        # optional .img/.zip path; if empty, use preset
RPI_SET_WIFI="${RPI_SET_WIFI:-0}"                 # 1 to attempt wifi config via imager (optional)

# OpenClaw settings
OPENCLAW_NPM_PKG="${OPENCLAW_NPM_PKG:-openclaw@latest}"
OPENCLAW_SERVICE_NAME="${OPENCLAW_SERVICE_NAME:-openclaw}"
OPENCLAW_BIND_ADDR="${OPENCLAW_BIND_ADDR:-127.0.0.1}"

# -----------------------------
# Helpers
# -----------------------------
die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

confirm() {
  local prompt="$1"
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

wait_for_ssh() {
  local host="$1"
  local port="$2"
  echo "Waiting for SSH on ${host}:${port} ..."
  for i in $(seq 1 120); do
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
# Checks
# -----------------------------
need_cmd diskutil
need_cmd ssh
need_cmd nc

[[ -f "$SSH_PUBKEY" ]] || die "SSH public key not found at: $SSH_PUBKEY (set SSH_PUBKEY=...)"

if ! command -v "$RPI_IMAGER_BIN" >/dev/null 2>&1; then
  die "Raspberry Pi Imager CLI not found ('${RPI_IMAGER_BIN}'). Install Raspberry Pi Imager and ensure rpi-imager is in PATH."
fi

echo "=============================="
echo "STEP 1: Select target SSD disk"
echo "=============================="
diskutil list
echo ""
echo "Enter the target disk identifier (e.g. disk4). THIS WILL BE ERASED."
read -r -p "Target disk: " RPI_STORAGE_DISK
[[ "$RPI_STORAGE_DISK" =~ ^disk[0-9]+$ ]] || die "Invalid disk identifier: $RPI_STORAGE_DISK"

echo ""
echo "About to ERASE: /dev/${RPI_STORAGE_DISK}"
diskutil info "/dev/${RPI_STORAGE_DISK}" | sed -n '1,25p'
echo ""

confirm "Proceed to erase /dev/${RPI_STORAGE_DISK} ?" || die "Aborted."

echo "Erasing disk..."
diskutil eraseDisk FAT32 RPI "/dev/${RPI_STORAGE_DISK}"

echo ""
echo "======================================"
echo "STEP 2: Flash Raspberry Pi OS to SSD"
echo "======================================"
echo "If you have a local OS image (.img/.zip), set RPI_OS_IMAGE_PATH=/path/to/image"
echo "Otherwise we will try to use a Pi Imager OS preset via --cli."
echo ""

if [[ -n "$RPI_OS_IMAGE_PATH" ]]; then
  [[ -f "$RPI_OS_IMAGE_PATH" ]] || die "RPI_OS_IMAGE_PATH does not exist: $RPI_OS_IMAGE_PATH"
  echo "Flashing from local image: $RPI_OS_IMAGE_PATH"
  # Pi Imager CLI usage varies by version; this is a common pattern.
  # If your imager rejects this, run: rpi-imager --help / rpi-imager --cli --help
  "$RPI_IMAGER_BIN" --cli \
    --image "$RPI_OS_IMAGE_PATH" \
    --storage "/dev/${RPI_STORAGE_DISK}"
else
  echo "Flashing using OS preset: ${RPI_OS_PRESET}"
  echo "NOTE: Preset names vary. If this fails, run: rpi-imager --cli --list-os"
  "$RPI_IMAGER_BIN" --cli \
    --os "$RPI_OS_PRESET" \
    --storage "/dev/${RPI_STORAGE_DISK}"
fi

echo ""
echo "=================================================="
echo "STEP 3: Boot Pi from SSD, then provision over SSH"
echo "=================================================="
echo "Now:"
echo "  1) Move SSD to the Pi"
echo "  2) Boot the Pi"
echo "  3) Ensure it is on the same network as this Mac"
echo ""
confirm "Continue once the Pi has booted?" || die "Aborted."

wait_for_ssh "$PI_HOST" "$PI_SSH_PORT"

echo ""
echo "----------------------------------------"
echo "STEP 4: Push SSH key (idempotent)"
echo "----------------------------------------"
PUBKEY_CONTENT="$(cat "$SSH_PUBKEY")"
run_ssh "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qF $(printf '%q' "$PUBKEY_CONTENT") ~/.ssh/authorized_keys || echo $(printf '%q' "$PUBKEY_CONTENT") >> ~/.ssh/authorized_keys"

echo ""
echo "----------------------------------------"
echo "STEP 5: Provision OS + security hardening"
echo "----------------------------------------"

# Update + baseline packages
run_ssh_sudo "
set -euo pipefail
apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
DEBIAN_FRONTEND=noninteractive apt install -y git curl wget unzip ca-certificates ufw fail2ban openssl net-tools
"

# Create swap (2GB) if not present
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

# SSH hardening: disable password auth + root login
# (IMPORTANT: if you rely on password SSH, you will lock yourself out—ensure key works first.)
run_ssh_sudo "
set -euo pipefail
SSHD=/etc/ssh/sshd_config
cp -n \$SSHD \${SSHD}.bak || true

perl -0777 -i -pe 's/^#?\\s*PermitRootLogin\\s+.*/PermitRootLogin no/mg; s/^#?\\s*PasswordAuthentication\\s+.*/PasswordAuthentication no/mg; s/^#?\\s*PubkeyAuthentication\\s+.*/PubkeyAuthentication yes/mg' \$SSHD

systemctl restart ssh
"

# Firewall: allow SSH only
run_ssh_sudo "
set -euo pipefail
ufw allow OpenSSH
ufw --force enable
ufw status verbose
"

# Fail2ban enable
run_ssh_sudo "
set -euo pipefail
systemctl enable fail2ban
systemctl restart fail2ban
systemctl status fail2ban --no-pager
"

echo ""
echo "----------------------------------------"
echo "STEP 6: Install Node.js 22 + OpenClaw"
echo "----------------------------------------"

# Node.js 22 via NodeSource, then OpenClaw
run_ssh_sudo "
set -euo pipefail
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
DEBIAN_FRONTEND=noninteractive apt install -y nodejs
node -v
npm -v
npm install -g ${OPENCLAW_NPM_PKG}
openclaw --version
"

echo ""
echo "----------------------------------------"
echo "STEP 7: Create a systemd service (safe defaults)"
echo "----------------------------------------"
# We do NOT assume openclaw has a stable daemon installer; create service unit.
# You may need to adjust ExecStart depending on your OpenClaw version (we attempt common forms).
run_ssh_sudo "
set -euo pipefail

OPENCLAW_BIN=\$(command -v openclaw)
if [[ -z \"\$OPENCLAW_BIN\" ]]; then
  echo 'openclaw not found in PATH' >&2
  exit 1
fi

# Guess a gateway command:
# Try: openclaw gateway
# Fallback: openclaw start
GATEWAY_CMD=''
if \$OPENCLAW_BIN --help 2>/dev/null | grep -qE '\\bgateway\\b'; then
  GATEWAY_CMD=\"\$OPENCLAW_BIN gateway\"
elif \$OPENCLAW_BIN --help 2>/dev/null | grep -qE '\\bstart\\b'; then
  GATEWAY_CMD=\"\$OPENCLAW_BIN start\"
else
  # last resort: just run openclaw (user must adjust)
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

# Replace placeholder with detected command
sed -i \"s|__GATEWAY_CMD__|\${GATEWAY_CMD//|/\\\\|}|g\" /etc/systemd/system/${OPENCLAW_SERVICE_NAME}.service

systemctl daemon-reload
systemctl enable ${OPENCLAW_SERVICE_NAME}
systemctl restart ${OPENCLAW_SERVICE_NAME}
systemctl status ${OPENCLAW_SERVICE_NAME} --no-pager
"

echo ""
echo "----------------------------------------"
echo "STEP 8: Verify listening sockets"
echo "----------------------------------------"
run_ssh_sudo "
set -euo pipefail
echo 'Listening sockets (expect OpenClaw to be localhost-only after you set bind=127.0.0.1 in its config):'
ss -lntp | head -n 50
"

cat <<EOF

DONE (provisioning complete).

NEXT (manual, important):
  1) Run OpenClaw's onboarding/config wizard on the Pi:
       ssh ${PI_USER}@${PI_HOST}
       openclaw --help
       openclaw onboard   (or openclaw configure)
  2) In the wizard/config, set gateway bind address to: ${OPENCLAW_BIND_ADDR}
     (Do NOT use 0.0.0.0)
  3) Set up Telegram:
     - BotFather privacy mode ON
     - Pair your account using the pairing code flow
  4) After configuration, restart service:
       sudo systemctl restart ${OPENCLAW_SERVICE_NAME}
     and check logs:
       journalctl -u ${OPENCLAW_SERVICE_NAME} -n 200 --no-pager

EOF
