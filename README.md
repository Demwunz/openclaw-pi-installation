<!--
OpenClaw Raspberry Pi SSD Secure Bootstrap
README.md

Template inspiration:
https://github.com/othneildrew/Best-README-Template/blob/main/BLANK_README.md
-->

<a name="readme-top"></a>

<br />
<div align="center">

  <h3 align="center">OpenClaw Raspberry Pi SSD Secure Bootstrap</h3>

  <p align="center">
    Security-first, non-Docker provisioning for OpenClaw on a Raspberry Pi 4 booting from SSD.
    <br />
    <br />
    <a href="#getting-started"><strong>Quick Start »</strong></a>
    <br />
    <br />
    <a href="#about-the-project">About</a>
    ·
    <a href="#installation">Install</a>
    ·
    <a href="#usage">Usage</a>
    ·
    <a href="#security-notes">Security</a>
    ·
    <a href="#troubleshooting">Troubleshooting</a>
  </p>
</div>

---

## Table of Contents

- [About The Project](#about-the-project)
- [Built With](#built-with)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Links](#links)

---

## About The Project

This repo provides a repeatable, security-focused workflow to:

- wipe and re-flash an SSD for Raspberry Pi
- install Raspberry Pi OS (64-bit)
- harden the system (SSH keys-only, firewall, fail2ban)
- install Node.js 22+
- install **OpenClaw** (non-Docker)
- set up a `systemd` service so OpenClaw starts on boot
- keep the OpenClaw gateway **LAN/Internet-inaccessible by default** by binding to `127.0.0.1`

> This is intentionally “secure-by-default”. You can always loosen restrictions later.
> It’s much harder to recover from an exposed bot than it is to open access safely.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Built With

- Raspberry Pi OS (64-bit)
- Bash
- SSH
- `systemd`
- UFW + Fail2ban
- Node.js 22+
- OpenClaw (installed via npm)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Getting Started

### Prerequisites

#### Hardware
- Raspberry Pi 4 (recommended: 4GB+; tested target: 8GB)
- USB SSD (this repo assumes SSD boot)
- Power supply
- Network: Ethernet or Wi-Fi
- Optional: touchscreen display

#### On your Mac (or Linux workstation)
- `ssh`
- `diskutil` (macOS) or equivalent disk tooling
- Raspberry Pi Imager installed
- An SSH public key (recommended):
  - `~/.ssh/id_ed25519.pub`

#### LLM Provider (choose one)
- Anthropic API key (Claude) OR
- Local LLM (e.g., Ollama) if you accept slower Pi inference

---

## Installation

This repo includes a macOS-run provisioning script:

- `setup-openclaw-pi.sh`

It performs:
- SSD erase + OS flash (via Raspberry Pi Imager CLI if available)
- Pi provisioning over SSH:
  - updates & packages
  - swap setup
  - SSH hardening
  - UFW + Fail2ban
  - Node.js 22+
  - OpenClaw install
  - systemd service creation

### 1) Clone the repo

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
chmod +x setup-openclaw-pi.sh
```

### 2) Run the bootstrap script

```bash
./setup-openclaw-pi.sh
```

> ⚠️ WARNING: The script will ask you to choose the target SSD disk identifier.
> Choosing the wrong disk will wipe the wrong device. Review carefully.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Usage

### Recommended first-run flow

1) Run the bootstrap script on your Mac:

```bash
./setup-openclaw-pi.sh
```

2) Boot your Pi from the SSD.

3) SSH into the Pi:

```bash
ssh openclaw@onepi.local
```

4) Run OpenClaw’s setup/onboarding command (varies by version):

```bash
openclaw --help
openclaw onboard
```

If `onboard` is not available:

```bash
openclaw configure
```

5) **CRITICAL SECURITY SETTING: bind gateway to localhost**
During configuration, set the gateway bind address to:

```text
127.0.0.1
```

✅ Correct:
- binds only to the Pi itself

❌ Incorrect:
- `0.0.0.0` (exposes to LAN and potentially the internet)

6) Restart the OpenClaw service:

```bash
sudo systemctl restart openclaw
sudo systemctl status openclaw --no-pager
```

7) View logs:

```bash
journalctl -u openclaw -n 200 --no-pager
```

---

## Security Notes

### 🔒 Non-negotiable defaults (recommended)

- Do NOT expose OpenClaw Admin/UI directly to the internet
- Do NOT port-forward from your router to the Pi
- Bind gateway to:
  - ✅ `127.0.0.1`
  - ❌ not `0.0.0.0`

### Chat integrations (Telegram / WhatsApp / etc.)
If you enable chat channels:
- enable “privacy mode” (Telegram BotFather)
- allowlist your user/number if supported
- do not run a bot that responds to arbitrary strangers

### Prompt injection risk (email integrations)
If you connect email:
- treat incoming content as untrusted input
- avoid giving the agent broad system/file permissions
- keep tools minimal and explicit

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Troubleshooting

### I can’t SSH in after password auth was disabled
You must confirm SSH key auth works *before* disabling passwords.

If you locked yourself out:
- connect a keyboard + monitor to the Pi
- edit:

```bash
sudo nano /etc/ssh/sshd_config
```

Temporarily set:

```text
PasswordAuthentication yes
```

Then:

```bash
sudo systemctl restart ssh
```

### Raspberry Pi Imager CLI flags failed
Pi Imager CLI flags differ by version.

Workarounds:
- flash the SSD using the Raspberry Pi Imager GUI
- rerun provisioning steps manually via SSH

### OpenClaw service fails to start
Check logs:

```bash
journalctl -u openclaw -n 200 --no-pager
```

Also confirm the available OpenClaw commands:

```bash
openclaw --help
```

Your OpenClaw version may use a different gateway/start command, and the systemd `ExecStart=` may need adjustment.

---

## Roadmap

- [ ] Add touchscreen kiosk-mode installer (Pi OS Lite + minimal kiosk browser)
- [ ] Add Cloudflare Tunnel + Access guide for secure remote access
- [ ] Add local metrics/log dashboard (safe buttons + minimal UI)
- [ ] Improve script compatibility and detection for Pi Imager CLI differences

---

## License

Choose a license for your repo (MIT is common). Add a `LICENSE` file to match.

---

## Disclaimer

This project is provided **as-is**.

- It performs destructive disk operations (data loss is expected).
- Review scripts before running.
- You assume all responsibility for the resulting system security and configuration.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Links

OpenClaw:
- https://github.com/openclaw/openclaw

If you want to contribute improvements, open an issue or PR in this repo.
