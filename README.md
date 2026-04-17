# MCM - Multi-Provider Claude Code Manager

[![][ci-badge]][ci] [![][release-badge]][releases]

[ci-badge]: https://github.com/0had0/mcm/workflows/CI/badge.svg
[release-badge]: https://img.shields.io/github/v/release/0had0/mcm

A CLI tool for managing multiple AI provider configurations for Claude Code CLI, inspired by nvm.

## Features

- **Provider Registry** - Providers fetched from GitHub, community-contributed
- **Local Caching** - Works offline with cached providers
- **Encrypted Storage** - API keys encrypted with AES-256
- **macOS & Linux** - Pure bash + Python

## Quick Install

```bash
git clone https://github.com/hadih/mcm.git
cd mcm
./mcm.sh install
source ~/.bashrc  # or ~/.zshrc
```

## Usage

```bash
mcm install              # Install MCM (first time)
mcm update               # Fetch latest providers
mcm list                 # List providers
mcm add kimi             # Add Kimi
mcm add minimax          # Add MiniMax
mcm use kimi             # Switch to Kimi
cc                       # Launch Claude Code with Kimi
mcm rm kimi              # Remove provider
mcm doctor               # Diagnostics
```

## Commands

| Command | Description |
|---------|-------------|
| `mcm install` | Install MCM and generate encryption key |
| `mcm update` | Fetch latest providers from registry |
| `mcm add <id>` | Add API key for a provider |
| `mcm list` | List all providers |
| `mcm use <id>` | Switch to provider |
| `mcm rm <id>` | Remove provider |
| `mcm doctor` | Run diagnostics |

## System-wide Install

### Homebrew

```bash
git clone https://github.com/hadih/mcm.git
cd mcm
sudo make install PREFIX=$(brew --prefix)
```

### pacman (Arch)

```bash
git clone https://github.com/hadih/mcm.git
cd mcm
makepkg -si
```

## Provider Registry

Providers are stored in `providers.json` and fetched from:
```
https://raw.githubusercontent.com/hadih/mcm/refs/heads/main/mcm/providers.json
```

To add a new provider, submit a PR to [`mcm/providers.json`](mcm/providers.json).

## Security

- API keys encrypted with AES-256-CBC
- Encryption key stored in `~/.mcm/.key`
- **ALWAYS backup your encryption key**

## Supported Providers

| Provider | ID | API Docs |
|----------|-----|----------|
| Kimi | `kimi` | [Moonshot](https://platform.moonshot.cn/docs/api/chat) |
| GLM (Z.AI) | `glm` | [Z.AI](https://z.ai/zh-ai/welcome) |
| MiniMax | `minimax` | [MiniMax](https://www.minimax.io/) |

## License

MIT
