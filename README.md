# Claude Code Multi-Provider Tools

This repository contains tools for managing multiple AI provider configurations for Claude Code CLI.

## MCM - Multi-Provider Claude Code Manager (Recommended)

A modern CLI tool inspired by nvm for managing provider configurations.

```bash
git clone <repo-url> mcm
cd mcm
./mcm.sh install
source ~/.bashrc
```

```bash
mcm add kimi        # Add provider
mcm list            # List providers
mcm use kimi        # Switch provider
cc                  # Launch with active provider
```

### Features
- **Encrypted API key storage** (AES-256)
- **Auto-generated encryption key** on install
- **Provider management**: add, list, switch, remove
- **Diagnostics**: `mcm doctor`

## claude_switcher (Legacy)

The original shell-based switcher. Kept for reference.

### Installation (Legacy)
```bash
./claude_switcher/setup.sh
```

## Adding Providers

Providers are defined in `providers.json`. Community contributions welcome!

```json
{
  "id": "newprovider",
  "name": "Provider Name",
  "models": "Model-Name",
  "base_url": "https://api.example.com",
  "api_key_var": "PROVIDER_API_KEY",
  "api_link": "https://example.com/docs",
  "env_vars": {}
}
```

## Security

- API keys are **never committed** to version control
- MCM encrypts keys with AES-256-CBC
- **Backup your encryption key at `~/.mcm/.key`**

## Supported Providers

| Provider | ID | API Docs |
|----------|-----|----------|
| Kimi | `kimi` | [Moonshot](https://platform.moonshot.cn/docs/api/chat) |
| GLM (Z.AI) | `glm` | [Z.AI](https://z.ai/zh-ai/welcome) |
| MiniMax | `minimax` | [MiniMax](https://www.minimax.io/) |
