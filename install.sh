#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.claude_switcher"

echo "Installing Claude Code Multi-Model Switcher..."

mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

ln -sf "$SCRIPT_DIR/claude_switcher.sh" "$DEST_DIR/claude_switcher.sh"
chmod +x "$DEST_DIR/claude_switcher.sh"

if [ ! -f "$DEST_DIR/.env" ]; then
    ln -sf "$SCRIPT_DIR/.env.example" "$DEST_DIR/.env"
    chmod 600 "$DEST_DIR/.env"
    echo "Created .env from template. Please add your API keys."
fi

SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

SOURCE_LINE="source $DEST_DIR/claude_switcher.sh"
if ! grep -qF "$SOURCE_LINE" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Claude Code Multi-Model Switcher" >> "$SHELL_RC"
    echo "$SOURCE_LINE" >> "$SHELL_RC"
    echo "Added to $SHELL_RC"
else
    echo "Already configured in $SHELL_RC"
fi

echo "Done! Restart your shell or run: source $SHELL_RC"
