# Claude Code Multi-Model Switcher

A modular, subshell-isolated Bash utility for seamlessly switching between different AI model providers (like Anthropic, Kimi, and Z.AI) within the [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview).

## Features

- **Environment Isolation**: Executes configurations in a subshell, preventing API keys and base URLs from leaking into your main terminal session.
- **Environment Variable Driven**: Keeps secrets out of the main logic using a `.env` file.
- **Dynamic Routing**: Automatically maps `claude <provider>` to specific configurations.

## Installation

```bash
git clone <your-repo-url> ~/.dotfiles/claude_switcher
cd ~/.dotfiles/claude_switcher
./install.sh
```

Or manually:

1. Clone or copy this directory to `~/.claude_switcher`
2. Ensure the script is executable: `chmod +x ~/.claude_switcher/claude_switcher.sh`
3. Source the module in your `~/.bashrc` or `~/.zshrc`:
   ```bash
   echo "source ~/.claude_switcher/claude_switcher.sh" >> ~/.bashrc
   ```

## Configuration

1. Edit your `.env` file:
   ```bash
   nano ~/.claude_switcher/.env
   ```
2. Add your API keys:
   ```bash
   KIMI_API_KEY="your_api_key_here"
   ZAI_API_KEY="your_api_key_here"
   ```

## Usage

```bash
claude glm             # Launches Claude Code using Z.AI's GLM models
claude kimi            # Launches Claude Code using Kimi-for-coding
claude                 # Launches the default Anthropic Claude configuration
claude kimi --help     # Passes standard flags directly to the CLI
```

## Adding New Providers

Add a new setup function prefixed with `_cc_setup_`:

```bash
_cc_setup_openai() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.openai-proxy.example.com"
    export ANTHROPIC_AUTH_TOKEN="$OPENAI_API_KEY"
}
```

Then call it with: `claude openai`

## Security

- The `.env` file contains secrets and is excluded from version control via `.gitignore`
- The `install.sh` script sets `chmod 600` on the `.env` file
- API keys are only loaded in subshells, preventing environment pollution
