# MCM - Multi-Provider Claude Code Manager

A CLI tool for managing multiple AI provider configurations for Claude Code CLI, inspired by nvm.

## Features

- **Secure Storage**: API keys encrypted with AES-256
- **Provider Management**: Add, list, switch between providers
- **Auto-generated Encryption Key**: Secure key created on install
- **macOS & Linux Compatible**: Pure bash with Python for JSON

## Installation

```bash
git clone <repo-url> mcm
cd mcm
./mcm.sh install
source ~/.bashrc  # or ~/.zshrc
```

## Usage

```bash
mcm add kimi        # Add Kimi provider
mcm add minimax     # Add MiniMax provider
mcm list            # List all providers
mcm use kimi        # Switch to Kimi
cc                  # Launch Claude Code with Kimi
mcm doctor          # Run diagnostics
```

## Commands

| Command | Description |
|---------|-------------|
| `mcm install` | Install MCM and generate encryption key |
| `mcm add <id>` | Add API key for a provider |
| `mcm list` | List all providers |
| `mcm use <id>` | Switch to provider |
| `mcm rm <id>` | Remove provider |
| `mcm doctor` | Run diagnostics |

## Adding Providers

Edit `providers.json` to add new providers:

```json
{
  "id": "newprovider",
  "name": "New Provider",
  "models": "Model-Name",
  "base_url": "https://api.example.com",
  "api_key_var": "NEWPROV_API_KEY",
  "api_link": "https://example.com/api",
  "env_vars": {}
}
```

## Security

- API keys stored in `$MCM_DIR/.keys.enc` (AES-256 encrypted)
- Encryption key in `$MCM_DIR/.key`
- **Backup your encryption key!** Without it, keys cannot be recovered

## Files

```
~/.mcm/
├── .key           # Encryption key (keep private!)
├── .keys.enc      # Encrypted API keys
├── config.json    # Current provider config
└── providers.json # Provider definitions
```
