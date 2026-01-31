# FULL WIPE + Fresh Install + Secure OpenClaw on Raspberry Pi 4 (SSD + Touchscreen)

## GOAL
Wipe the SSD, install Raspberry Pi OS 64-bit from scratch, harden the Pi, install OpenClaw (non-Docker),
bind the gateway to localhost (127.0.0.1), securely pair Telegram, and run as a systemd service.

---

## IMPORTANT RULES
- This WILL ERASE the SSD completely. No recovery.
- Do NOT run OpenClaw as root.
- Do NOT expose OpenClaw to the internet.
- Bind gateway to 127.0.0.1 only.
- Use Telegram long polling (no router ports needed).

---

## PART A — WIPE SSD + FLASH OS (from Mac/PC)

### A1) Identify the SSD (macOS)
    diskutil list

Find the external SSD disk path (example: /dev/disk4). Double-check.

### A2) Wipe SSD (DANGER)
    diskutil eraseDisk FAT32 RPI /dev/disk4

### A3) Flash Raspberry Pi OS (64-bit)
Use Raspberry Pi Imager:
- OS: Raspberry Pi OS (64-bit)
  - If using touchscreen UI: choose “with Desktop”
  - If headless: choose “Lite”
- Storage: select your SSD
- Advanced settings:
  - Hostname: onepi
  - Enable SSH: ✅
  - Username: openclaw
  - Password: set temporary password ✅
  - Configure Wi-Fi: ✅ (only if needed)
  - Locale/timezone: ✅

Boot Pi from SSD.

---

## PART B — FIRST BOOT + UPDATE EVERYTHING

On the Pi (keyboard/touchscreen or SSH):
    sudo apt update
    sudo apt full-upgrade -y
    sudo reboot

After reboot:
    sudo apt update
    sudo apt install -y git curl wget unzip ca-certificates ufw fail2ban openssl

---

## PART C — OS SECURITY HARDENING (DO THIS BEFORE BOT INSTALL)

### C1) Confirm you are NOT root
    whoami
    id

### C2) SSH keys only (disable password login)
On your Mac:
    ssh-keygen -t ed25519 -C "onepi-admin"
    ssh-copy-id openclaw@onepi.local

On the Pi:
    sudo nano /etc/ssh/sshd_config

Set/ensure these lines:
    PermitRootLogin no
    PasswordAuthentication no
    PubkeyAuthentication yes

Restart SSH:
    sudo systemctl restart ssh

IMPORTANT: Confirm you can SSH in from your Mac BEFORE continuing.

### C3) Firewall (UFW)
    sudo ufw allow OpenSSH
    sudo ufw enable
    sudo ufw status verbose

### C4) Fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    sudo systemctl status fail2ban --no-pager

---

## PART D — ADD SWAP (PREVENTS INSTALL CRASHES)

Check swap:
    free -h
    swapon --show

Create 2GB swapfile:
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

Verify:
    swapon --show
    free -h

---

## PART E — INSTALL NODE.JS 22+ (REQUIRED)

    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
    node -v
    npm -v

---

## PART F — INSTALL OPENCLAW (NON-DOCKER)

    sudo npm install -g openclaw@latest
    openclaw --version
    openclaw --help

Run onboarding/config wizard (depending on version):
    openclaw onboard

If that command doesn’t exist:
    openclaw configure

If neither exists, list commands and pick the closest “setup/onboard” option:
    openclaw --help

---

## PART G — CONFIGURE GATEWAY SECURITY (CRITICAL)

During setup/config wizard, ensure:
- Gateway bind address: 127.0.0.1
- Do NOT bind to: 0.0.0.0
- No port forwarding on router
- No public domain exposure

Keep tools minimal:
- Avoid enabling “full system access” until everything is stable.

---

## PART H — CONFIGURE LLM PROVIDER

Pick ONE:
- Anthropic (Claude) API key recommended
- Local Ollama only if you accept slower performance and want full privacy

Set API keys only via OpenClaw secret handling / wizard prompts.
Do NOT hardcode keys into files/scripts.

---

## PART I — TELEGRAM SETUP (SAFE DEFAULTS)

### I1) BotFather settings
- Enable privacy mode (so bot only responds to direct messages)
- Don’t add bot to groups (for now)

### I2) Pairing
- Start OpenClaw gateway
- Message the bot privately
- Bot returns a pairing code
- Enter pairing code on the Pi terminal to authorize ONLY your Telegram user

---

## PART J — RUN DOCTOR + SECURITY AUDIT (IF AVAILABLE)

    openclaw doctor

Try auto-fix mode if supported:
    openclaw doctor --fix

Security audit (if available):
    openclaw security-audit

---

## PART K — RUN AS A SYSTEMD SERVICE

### K1) If OpenClaw supports installing a daemon automatically
    openclaw onboard --install-daemon

### K2) If not available, create a manual systemd unit
Create service file:
    sudo nano /etc/systemd/system/openclaw.service

Paste this exactly:

    [Unit]
    Description=OpenClaw Agent Gateway
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=openclaw
    WorkingDirectory=/home/openclaw
    ExecStart=/usr/bin/openclaw gateway
    Restart=always
    RestartSec=3
    Environment=NODE_ENV=production

    # Basic systemd hardening:
    NoNewPrivileges=true
    PrivateTmp=true
    ProtectSystem=full
    ProtectHome=true
    ReadWritePaths=/home/openclaw

    [Install]
    WantedBy=multi-user.target

Enable + start:
    sudo systemctl daemon-reload
    sudo systemctl enable openclaw
    sudo systemctl start openclaw
    sudo systemctl status openclaw --no-pager

Logs:
    journalctl -u openclaw -n 200 --no-pager

---

## PART L — FINAL VERIFICATION

Confirm gateway is localhost only:
    ss -lntp | grep -i openclaw

Expected: 127.0.0.1:PORT
NOT expected: 0.0.0.0:PORT

Confirm firewall:
    sudo ufw status verbose

Reboot test:
    sudo reboot

After reboot:
    systemctl status openclaw --no-pager
    journalctl -u openclaw -n 100 --no-pager

---

## NON-NEGOTIABLE SECURITY NOTES
- Do NOT expose OpenClaw admin/UI to the internet.
- Do NOT open ports on your router.
- Always restrict chat integrations to allowlisted senders.
- Be cautious adding email integrations (prompt injection risk).
- Start minimal, then add skills/tools gradually.
