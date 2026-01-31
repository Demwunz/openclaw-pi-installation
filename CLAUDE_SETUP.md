# 🤖 AI Model & Web Search Setup

This guide covers getting your API keys and giving your bot internet access.

### 1. Claude (Anthropic) Setup
* **Sign up:** Create an account at [console.anthropic.com](https://console.anthropic.com/).
* **API Key:** Generate a new API key and save it.
* **Recommended Model:** Use `Claude 3.5 Sonnet` or `Claude 3 Opus` for the best performance.
* **Input Key:** When running the `onboard` wizard, paste this key when prompted for the Anthropic provider.

### 2. Enable Web Search (Brave Search)
By default, the bot does not have internet access. To enable it:
1.  Sign up for the **Brave Search API** at [api.brave.com](https://api.brave.com/).
2.  Subscribe to the **Free Tier** (currently allows 2,000 queries per month).
3.  Generate an API Key and copy it.
4.  Run the configuration command in your terminal:
    ```bash
    openclaw configure --section web
    ```
5.  Select **Brave Search**, enable "web fetch," and paste your key.

### 3. Security Maintenance
* **Audit:** Run `openclaw security-audit` regularly to scan for exposed API keys or unauthenticated gateways.
* **Health Check:** Use `openclaw doctor` to verify your configuration and fix common permission issues.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
