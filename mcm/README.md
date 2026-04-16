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
git clone <repo-url> mcm
cd mcm
make user-install
source ~/.bashrc  # or ~/.zshrc
```

### System-wide Install (requires sudo)
```bash
git clone <repo-url> mcm
cd mcm
sudo make install
```

## Usage

```bash
mcm install              # Install MCM (user mode)
mcm add kimi             # Add Kimi provider
mcm add minimax           # Add MiniMax provider
mcm list                 # List providers
mcm use kimi             # Switch to Kimi
cc                       # Launch Claude Code with Kimi
mcm doctor               # Run diagnostics
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

## Installation Methods

### Homebrew (macOS)
```bash
# Clone repo, then:
cd mcm
# Edit Makefile to set PREFIX=/opt/homebrew
sudo make install
```

### MacPorts (macOS)
```bash
# Create port file from Makefile
sudo port install mcm
```

### pacman (Arch Linux)
```bash
# Create PKGBUILD from provided template
makepkg -si
```

### apt (Debian/Ubuntu)
```bash
# Create deb package from Makefile
dpkg-deb --build mcm.deb
sudo dpkg -i mcm.deb
```

### Manual System-wide
```bash
sudo make install PREFIX=/usr/local
```

## Custom Installation Paths

```bash
# Install to custom location
make install PREFIX=/opt/mcm SBINDIR=/usr/bin

# User install to custom location
make user-install HOME=/home/user
```

## Adding Providers

Edit `providers.conf` to add new providers:

```
# Format: id|name|models|base_url|api_key_var|api_link
# Environment vars follow on separate lines:
# id|VAR_NAME|value

kimi|Kimi|Kimi-for-Coding|https://api.kimi.com/coding/|KIMI_API_KEY|https://platform.moonshot.cn
kimi|KIMI_ANTHROPIC_MODEL|kimi-for-coding

minimax|MiniMax|MiniMax-Text-01|https://api.minimax.chat/v1|MINIMAX_API_KEY|https://minimax.io
minimax|MINIMAX_ANTHROPIC_MODEL|MiniMax-Text-01
```

## Files

```
~/.mcm/
├── .key           # Encryption key (BACKUP THIS!)
├── .keys.enc     # Encrypted API keys
├── config.sh     # Current provider
└── providers.conf # Local provider overrides
```

## Security

- API keys encrypted with AES-256-CBC
- Encryption key stored in `~/.mcm/.key`
- **ALWAYS backup your encryption key**
- Without it, keys cannot be recovered

## Supported Providers

| Provider | ID | API Docs |
|----------|-----|----------|
| Kimi | `kimi` | [Moonshot](https://platform.moonshot.cn/docs/api/chat) |
| GLM (Z.AI) | `glm` | [Z.AI](https://z.ai/zh-ai/welcome) |
| MiniMax | `minimax` | [MiniMax](https://www.minimax.io/) |
