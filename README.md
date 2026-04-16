# MCM - Multi-Provider Claude Code Manager

A CLI tool for managing multiple AI provider configurations for Claude Code CLI, inspired by nvm.

## Features

- **Pure Bash** - No Python or external dependencies
- **Encrypted Storage** - API keys encrypted with AES-256
- **System-wide Install** - Works with Homebrew, MacPorts, pacman, apt
- **macOS & Linux** - Tested on both platforms

## Quick Install

### User Install (Recommended)
```bash
git clone <repo-url>
cd mcm
make user-install
source ~/.bashrc
```

### System-wide Install (requires sudo)
```bash
git clone <repo-url>
cd mcm
sudo make install
```

## Usage

```bash
mcm install              # Install MCM
mcm add kimi             # Add Kimi
mcm add minimax           # Add MiniMax
mcm list                 # List providers
mcm use kimi             # Switch to Kimi
cc                       # Launch Claude Code
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

## Package Manager Installation

### Homebrew
```bash
# Clone, then:
sudo make install PREFIX=$(brew --prefix)
```

### pacman (Arch)
```bash
# Use PKGBUILD:
makepkg -si
```

### apt
```bash
# Create deb from Makefile
```

## Adding Providers

Edit `providers.conf`:

```
# Format: id|name|models|base_url|api_key_var|api_link
# id|ENV_VAR|value

kimi|Kimi|Kimi-for-Coding|https://api.kimi.com/coding/|KIMI_API_KEY|https://platform.moonshot.cn
kimi|KIMI_ANTHROPIC_MODEL|kimi-for-coding

minimax|MiniMax|MiniMax-Text-01|https://api.minimax.chat/v1|MINIMAX_API_KEY|https://minimax.io
minimax|MINIMAX_ANTHROPIC_MODEL|MiniMax-Text-01
```

## Supported Providers

| Provider | ID |
|----------|-----|
| Kimi | `kimi` |
| GLM (Z.AI) | `glm` |
| MiniMax | `minimax` |

## Security

API keys encrypted with AES-256. **Backup `~/.mcm/.key`** - without it, keys cannot be recovered.
