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