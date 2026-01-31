# Telegram Integration

Follow these steps to securely connect OpenClaw to Telegram.

### 1. Create Your Bot
1. Open Telegram and search for **@BotFather**.
2. Type `/newbot` and follow the instructions to set your bot's name and username.
3. **Save the API Token**: Keep the provided token (e.g., `123456:ABC-DEF...`) safe.
4. **Security Tip**: Use the `/setprivacy` command in @BotFather to ensure **Privacy Mode** is **Enabled**, preventing the bot from reading unauthorized group messages.

### 2. Configure OpenClaw
1. Run `openclaw configure --section channels` on your Raspberry Pi.
2. Select **Telegram** as your communication channel.
3. Paste the API Token you received from BotFather.

### 3. Secure Pairing
OpenClaw uses a mandatory pairing system to ensure only you can control it:
1. Start a chat with your new bot in Telegram and hit **Start**.
2. The bot will reply with a unique **Pairing Code**.
3. In your Raspberry Pi terminal, run:
   ```bash
   openclaw pairing approve telegram [YOUR_CODE]
Once completed, your Telegram account is whitelisted.


#### `WEB_SEARCH.md`
```markdown
# Web Search & Skills

Learn how to give your bot internet access and add new autonomous capabilities.

### 1. Brave Search API
To allow the bot to research topics on the live web:
1. Sign up for the Brave Search API at [api.brave.com](https://api.brave.com/).
2. Create a free-tier API key.
3. Run `openclaw configure --section web` and input your key.

### 2. Installing Skills (ClaudeHub)
Skills allow your bot to perform specific tasks like setting reminders or checking weather.
* **Browse Skills**: Visit [claudehub.ai](https://claudehub.ai) to find new capabilities.
* **Autonomous Install**: You can ask your bot directly in Telegram to install a skill:
  > "Help me install the remind-me skill from ClaudeHub."
* The bot will autonomously find, download, and configure the skill.

### 3. Maintenance Commands
* **Security Audit**: Run `openclaw security-audit` often to check for vulnerabilities.
* **System Fix**: Run `openclaw doctor --fix` if the bot encounters errors or permission issues.