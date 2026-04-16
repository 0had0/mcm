# Claude Code Multi-Provider Switcher

A modular Bash utility for switching between AI model providers (Kimi, GLM, MiniMax) when using [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview).

## Features

- **Subshell Isolation**: API keys stay isolated, never pollute your environment
- **Interactive Setup**: Choose which providers to configure
- **Secrets Protected**: `.env` file excluded from version control

## Installation

```bash
git clone <your-repo-url> ~/.dotfiles/claude_switcher
cd ~/.dotfiles/claude_switcher
./setup.sh
```

## Providers

| Provider | Command | Base URL |
|----------|---------|----------|
| Kimi | `cc kimi` | api.kimi.com |
| GLM (Z.AI) | `cc glm` | api.z.ai |
| MiniMax | `cc minimax` | api.minimax.chat |

## Usage

```bash
cc minimax              # Launch with MiniMax
cc kimi                 # Launch with Kimi
cc glm                  # Launch with GLM
cc                      # Launch default (Anthropic)
cc kimi --help          # Pass flags to CLI
```

## Adding Providers

Edit `setup.sh` to add new providers. Each provider needs:
1. An entry in the provider list
2. An `_cc_setup_<name>()` function in `ccswitch.sh`
3. API key prompt in setup

## Security

- `.env` is never committed (in `.gitignore`)
- API keys loaded in subshells only
- Run `chmod 600 ~/.claude_switcher/.env` to secure
