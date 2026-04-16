#!/usr/bin/env bash

# Load environment variables securely
CONFIG_FILE="$HOME/.claude_switcher/.env"
if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
else
    echo "Warning: Claude Switcher config not found at $CONFIG_FILE"
fi

# ==========================================
# Provider Configurations
# ==========================================

_cc_setup_kimi() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.kimi.com/coding/"
    export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
    export ANTHROPIC_MODEL="kimi-for-coding"
    export ANTHROPIC_SMALL_FAST_MODEL="kimi-for-coding"
}

_cc_setup_glm() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
}

# ==========================================
# Main Dispatcher
# ==========================================

claude() {
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
