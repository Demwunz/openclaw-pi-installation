<!--
OpenClaw Raspberry Pi Secure Setup Guide
Comprehensive security-first setup (no Pi-Imager CLI required)

Template inspiration:
https://github.com/othneildrew/Best-README-Template/blob/main/BLANK_README.md
-->

<a name="readme-top"></a>

<br />
<div align="center">

  <h3 align="center">OpenClaw Raspberry Pi Secure Setup Guide</h3>

  <p align="center">
    A comprehensive, security-first guide to install and run OpenClaw on Raspberry Pi OS (SSD or SD), using SSH keys, UFW, Fail2ban, and safe-by-default gateway settings.
    <br />
    <br />
    <a href="#quick-start"><strong>Quick Start »</strong></a>
    <br />
    <br />
    <a href="#security-baseline">Security Baseline</a>
    ·
    <a href="#raspberry-pi-os-install">Raspberry Pi OS Install</a>
    ·
    <a href="#pi-hardening">Pi Hardening</a>
    ·
    <a href="#openclaw-install">OpenClaw Install</a>
    ·
    <a href="#onboarding-settings">Onboarding Settings</a>
    ·
    <a href="#verification">Verification</a>
  </p>
</div>

---

## Table of Contents

- [Quick Start](#quick-start)
- [About](#about)
- [Security Baseline](#security-baseline)
- [Prerequisites](#prerequisites)
- [Raspberry Pi OS Install](#raspberry-pi-os-install)
- [First Boot Checklist](#first-boot-checklist)
- [Pi Hardening](#pi-hardening)
  - [SSH Key Authentication](#ssh-key-authentication)
  - [Firewall (UFW)](#firewall-ufw)
  - [Fail2ban](#fail2ban)
  - [Swap](#swap)
- [Install Node.js 22+](#install-nodejs-22)
- [Install OpenClaw](#install-openclaw)
- [OpenClaw Onboarding Settings](#openclaw-onboarding-settings)
- [Run as a Service](#run-as-a-service)
- [Security Audit](#security-audit)
- [Common Issues](#common-issues)
- [Links](#links)
- [Disclaimer](#disclaimer)

---

## Quick Start

If you already have Raspberry Pi OS running and SSH access working:

```bash
# update base OS
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y git curl ca-certificates ufw fail2ban unzip openssl

# enable firewall (SSH only)
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose

# enable fail2ban
sudo systemctl enable --now fail2ban

# install Node.js 22+
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# install OpenClaw
sudo npm install -g openclaw@latest
openclaw --version

# run onboarding
openclaw onboard
```

During onboarding, **bind the gateway to localhost only**:

- ✅ `127.0.0.1`
- ❌ not `0.0.0.0`

Then install the Gateway service and run a security audit:

```bash
openclaw security audit --deep
```

---

## About

This guide installs OpenClaw on a Raspberry Pi using a security-first baseline:

- SSH keys-only access
- Firewall enabled (deny inbound by default)
- Fail2ban enabled (SSH brute-force protection)
- OpenClaw Gateway bound to localhost (no LAN exposure)
- Gateway auth token set to a strong random value
- Credential directory permissions locked down

The goal is to build a stable “appliance-like” Pi host: boring, predictable, and safe.

---

## Security Baseline

### Non-negotiable defaults (recommended)

- Do NOT expose OpenClaw Control UI directly to the internet.
- Do NOT port-forward your router to the Raspberry Pi.
- Bind OpenClaw gateway to `127.0.0.1` (localhost only).
- Keep UFW enabled with default deny incoming.

### Why “localhost only” matters

If the gateway binds to `0.0.0.0`, anything on your network can attempt to connect.
If misconfigured further, you could accidentally expose an admin surface externally.

Binding to `127.0.0.1` makes it private by default.

---

## Prerequisites

### Hardware

- Raspberry Pi (Pi 4 recommended)
- SD card OR USB SSD
- Power supply
- Ethernet or Wi-Fi

### Your workstation

- macOS / Linux / Windows machine
- SSH client
- Raspberry Pi Imager installed (GUI)

---

## Raspberry Pi OS Install

### Recommended OS

✅ Raspberry Pi OS Lite (64-bit)

It’s stable and minimal, and you can add only what you need later.

### Flash OS with Raspberry Pi Imager (GUI)

1. Open **Raspberry Pi Imager**
2. Select:
   - OS: **Raspberry Pi OS Lite (64-bit)**
   - Storage: your SD card or SSD
3. Open **Advanced settings** (gear icon) and set:
   - Hostname: e.g. `clawpi`
   - Enable SSH: ✅
   - Authentication: ✅ use password (temporary is fine)
   - Username: choose a dedicated user (example: `openclaw`)
   - Wi-Fi: configure if needed
   - Locale/timezone: optional

4. Write image
5. Boot your Pi

> Tip: If you can’t SSH after boot, it’s usually Wi-Fi settings, hostname mismatch, or the wrong username.

---

## First Boot Checklist

Once the Pi boots, SSH in:

```bash
ssh <user>@<hostname>.local
```

If `.local` does not resolve, use the IP from your router:

```bash
ssh <user>@192.168.x.x
```

Then confirm basics:

```bash
whoami
hostname
uname -a
```

---

## Pi Hardening

### SSH Key Authentication

On your workstation (Mac/Linux), create a key if needed:

```bash
ssh-keygen -t ed25519 -C "pi-admin"
```

Copy your public key to the Pi:

```bash
ssh-copy-id <user>@<pi-ip-or-hostname>
```

Verify it works:

```bash
ssh <user>@<pi-ip-or-hostname>
```

### Disable password SSH (recommended once keys work)

Edit:

```bash
sudo nano /etc/ssh/sshd_config
```

Set:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

---

### Firewall (UFW)

Install + enable:

```bash
sudo apt install -y ufw
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose
```

Expected:
- Default deny incoming
- SSH allowed

---

### Fail2ban

Install + enable:

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban --no-pager
```

---

### Swap

Raspberry Pi OS may use **zram** by default.

Check swap:

```bash
swapon --show
free -h
```

If swap exists (zram or swapfile), you're good.

---

## Install Node.js 22+

Install Node.js 22 from NodeSource:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
```

You should see Node v22.x.

---

## Install OpenClaw

Install globally:

```bash
sudo npm install -g openclaw@latest
openclaw --version
openclaw --help
```

---

## OpenClaw Onboarding Settings

Run onboarding:

```bash
openclaw onboard
```

If `onboard` is not available:

```bash
openclaw configure
```

### Recommended secure choices

- Gateway bind: ✅ `127.0.0.1`
- Gateway port: ✅ default is fine
- Gateway auth: ✅ Token
- Gateway token: ✅ long random token
- Tailscale exposure: ✅ Off
- Hooks: ✅ Skip for now
- Skills: ✅ Skip for now (start minimal)

### Fix short token warning (if audit reports it)

Generate a strong token:

```bash
openssl rand -hex 32
```

Set it:

```bash
openclaw config set gateway.auth.token "<PASTE_TOKEN_HERE>"
```

Restart gateway service after changes:

```bash
systemctl --user restart openclaw-gateway
```

---

## Run as a Service

Onboarding will typically install the **Gateway user service**:

- `openclaw-gateway.service` (systemd user service)

Check status:

```bash
systemctl --user status openclaw-gateway --no-pager
```

View logs:

```bash
journalctl --user -u openclaw-gateway -n 200 --no-pager
```

Restart service:

```bash
systemctl --user restart openclaw-gateway
```

---

## Verification

### Confirm the gateway is running

```bash
systemctl --user status openclaw-gateway --no-pager
```

### Confirm it is localhost-only

```bash
ss -lntp | grep 18789 || true
```

Expected output includes:

- `127.0.0.1:18789`
- `[::1]:18789`

If you see `0.0.0.0:18789`, your gateway is exposed to LAN and must be fixed.

---

## Security Audit

Run the deep audit:

```bash
openclaw security audit --deep
```

Expected:
- 0 critical

Note:
- `gateway.trusted_proxies_missing` is safe to ignore if you keep the UI local-only.
- If you expose a Control UI through a reverse proxy later, configure `gateway.trustedProxies`.

---

## Common Issues

### Permission denied (publickey) when SSH'ing into the Pi

You are using the wrong username, or your public key was not copied to the Pi.

Fix:

```bash
ssh-copy-id <user>@<pi-ip-or-hostname>
```

---

### UFW enable warning about disrupting SSH

This is normal.

Always allow SSH before enabling UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
```

---

### Skills failing to install with EACCES permission errors

This usually means npm is trying to write to a system directory.
For a minimal secure setup, skip skills until your base install is stable.

---

## 🦞 Supplemental Setup Guides


For detailed, step-by-step setup of specific features, refer to these reference guides:

- [Detailed AI Model & Web Setup](CLAUDE_SETUP.md) — Comprehensive guide for Anthropic API and Brave Search integration.
- [Secure Telegram Integration](TELEGRAM_SETUP.md) — Instructions for bot creation, privacy settings, and whitelisting.
- [Web Search & Skill Management](WEB_SEARCH.md) — How to extend your bot's capabilities and perform security audits.

---

## Links

- OpenClaw:
  https://github.com/openclaw/openclaw

- OpenClaw Docs:
  https://docs.openclaw.ai

---

## Disclaimer

This guide is provided **as-is**.
You are responsible for reviewing and understanding commands before running them.

- Disk flashing wipes data.
- Security settings must be validated in your environment.
- Do not expose admin/control surfaces to the internet without additional protections.
