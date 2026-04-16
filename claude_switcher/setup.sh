#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.claude_switcher"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Claude Code Multi-Provider Switcher - Setup          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

read -p "Install directory [$DEST_DIR]: " input
DEST_DIR="${input:-$DEST_DIR}"

mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

echo
echo "Available providers:"
echo "  1) Kimi     - Kimi-for-coding"
echo "  2) GLM      - Z.AI (GLM models)"
echo "  3) MiniMax  - MiniMax-Text-01"
echo

read -p "Select providers to enable (comma-separated, e.g. 1,3) [all]: " input
SELECTION="${input:-all}"

SELECTED=()
if [[ "$SELECTION" == "all" ]]; then
    SELECTED=(1 2 3)
else
    IFS=',' read -ra SELECTED <<< "$SELECTION"
fi

cat > "$DEST_DIR/.env" << 'ENVHEADER'
# Claude Code Multi-Provider Configuration
# DO NOT commit this file to version control.
ENVHEADER

for num in "${SELECTED[@]}"; do
    case $num in
        1)
            echo "Configuring Kimi..."
            read -p "  Enter Kimi API Key: " -s api_key
            echo
            echo "KIMI_API_KEY=\"$api_key\"" >> "$DEST_DIR/.env"
            ;;
        2)
            echo "Configuring GLM (Z.AI)..."
            read -p "  Enter Z.AI API Key: " -s api_key
            echo
            echo "ZAI_API_KEY=\"$api_key\"" >> "$DEST_DIR/.env"
            ;;
        3)
            echo "Configuring MiniMax..."
            read -p "  Enter MiniMax API Key: " -s api_key
            echo
            echo "MINIMAX_API_KEY=\"$api_key\"" >> "$DEST_DIR/.env"
            ;;
    esac
done

chmod 600 "$DEST_DIR/.env"

echo
echo "Generating provider script..."

cat > "$DEST_DIR/ccswitch.sh" << 'SCRIPTEOF'
#!/usr/bin/env bash

CONFIG_FILE="$HOME/.claude_switcher/.env"
if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
else
    echo "Warning: Claude Switcher config not found at $CONFIG_FILE"
fi

SCRIPTEOF

for num in "${SELECTED[@]}"; do
    case $num in
        1)
            cat >> "$DEST_DIR/ccswitch.sh" << 'KIMIEOF'

_cc_setup_kimi() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
    export ANTHROPIC_MODEL="kimi-for-coding"
    export ANTHROPIC_SMALL_FAST_MODEL="kimi-for-coding"
}
KIMIEOF
            ;;
        2)
            cat >> "$DEST_DIR/ccswitch.sh" << 'GLMEOF'

_cc_setup_glm() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
}
GLMEOF
            ;;
        3)
            cat >> "$DEST_DIR/ccswitch.sh" << 'MINIMAXEOF'

_cc_setup_minimax() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.minimax.chat/v1"
    export ANTHROPIC_AUTH_TOKEN="$MINIMAX_API_KEY"
    export ANTHROPIC_MODEL="MiniMax-Text-01"
    export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-Text-01"
}
MINIMAXEOF
            ;;
    esac
done

cat >> "$DEST_DIR/ccswitch.sh" << 'DISPATCHER'

cc() {
    local provider=""
    local args=()

    if [[ $# -gt 0 && "$1" != --* ]]; then
        provider="$1"
        shift
    fi
    
    args=("$@")

    if [[ -n "$provider" ]] && typeset -f "_cc_setup_$provider" > /dev/null; then
        ( _cc_setup_$provider; command claude "${args[@]}" )
    else
        if [[ -n "$provider" ]]; then
             command claude --model "$provider" "${args[@]}"
        else
             command claude "${args[@]}"
        fi
    fi
}
DISPATCHER

chmod +x "$DEST_DIR/ccswitch.sh"

echo
echo "Updating shell configuration..."
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

MARKER="# Claude Code Multi-Provider Switcher"
if ! grep -qF "$MARKER" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "$MARKER" >> "$SHELL_RC"
    echo "source $DEST_DIR/ccswitch.sh" >> "$SHELL_RC"
fi

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      Setup Complete!                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo
echo "Usage:"
for num in "${SELECTED[@]}"; do
    case $num in
        1) echo "  cc kimi            # Launch with Kimi" ;;
        2) echo "  cc glm             # Launch with GLM" ;;
        3) echo "  cc minimax         # Launch with MiniMax" ;;
    esac
done
echo "  cc                  # Launch default (Anthropic)"
echo
echo "Restart your shell or run: source $SHELL_RC"
