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