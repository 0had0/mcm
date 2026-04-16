#!/usr/bin/env bash

set -e

# ==========================================
# Colors
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ==========================================
# Provider Definitions
# ==========================================
declare -A PROVIDERS=(
    ["1"]="kimi"
    ["2"]="glm"
    ["3"]="minimax"
)

declare -A PROVIDER_NAMES=(
    ["kimi"]="Kimi"
    ["glm"]="GLM (Z.AI)"
    ["minimax"]="MiniMax"
)

declare -A PROVIDER_MODELS=(
    ["kimi"]="Kimi-for-Coding"
    ["glm"]="GLM-4.7 / GLM-4.5-Air"
    ["minimax"]="MiniMax-Text-01"
)

declare -A PROVIDER_BASE_URLS=(
    ["kimi"]="https://api.kimi.com/coding/"
    ["glm"]="https://api.z.ai/api/anthropic"
    ["minimax"]="https://api.minimax.chat/v1"
)

declare -A PROVIDER_LINKS=(
    ["kimi"]="https://platform.moonshot.cn/docs/api/chat"
    ["glm"]="https://z.ai/zh-ai/welcome"
    ["minimax"]="https://www.minimax.io/"
)

declare -A PROVIDER_API_KEYS=(
    ["kimi"]="KIMI_API_KEY"
    ["glm"]="ZAI_API_KEY"
    ["minimax"]="MINIMAX_API_KEY"
)

# ==========================================
# Helper Functions
# ==========================================
clear_screen() {
    printf "\033[2J\033[H"
}

print_banner() {
    cat << 'EOF'

    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │   ██████╗ ████████╗ ██████╗██████╗  ██████╗                 │
    │   ██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗                │
    │   ██████╔╝   ██║   ██║     ██████╔╝██║   ██║                │
    │   ██╔══██╗   ██║   ██║     ██╔══██╗██║   ██║                │
    │   ██║  ██║   ██║   ╚██████╗██║  ██║╚██████╔╝                │
    │   ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝ ╚═════╝                 │
    │                                                             │
    │           ┌──────────────────────────────┐                   │
    │           │   Multi-Provider Switcher   │                   │
    │           └──────────────────────────────┘                   │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘

EOF
}

print_step() {
    echo -e "${CYAN}[$1/${TOTAL_STEPS}]${RESET} ${BOLD}$2${RESET}"
    echo
}

print_provider_card() {
    local num=$1
    local name=$2
    local model=$3
    local link=$4
    
    echo -e "  ${MAGENTA}[$num]${RESET} ${BOLD}$name${RESET}"
    echo -e "      ${DIM}Model:${RESET} $model"
    echo -e "      ${DIM}API:${RESET} ${CYAN}$link${RESET}"
    echo
}

wait_for_enter() {
    echo
    echo -e "${DIM}Press ${BOLD}Enter${RESET}${DIM} to continue...${RESET}"
    read -r
}

# ==========================================
# Main Setup Flow
# ==========================================
main() {
    clear_screen
    print_banner
    
    echo -e "${DIM}Welcome! Let's set up Claude Code Multi-Provider Switcher.${RESET}"
    echo
    echo -e "This will help you switch between different AI providers when using"
    echo -e "Claude Code CLI. Each provider runs in an isolated environment."
    echo
    
    wait_for_enter
    clear_screen
    
    # ==========================================
    # Step 1: Choose Install Location
    # ==========================================
    print_step 1 4 "Choose Install Location"
    
    DEST_DIR="$HOME/.claude_switcher"
    echo -e "Default location: ${CYAN}$DEST_DIR${RESET}"
    echo
    read -p "Press Enter to use default or enter custom path: " input
    
    if [[ -n "$input" ]]; then
        DEST_DIR="$input"
    fi
    
    if [[ -d "$DEST_DIR" ]]; then
        echo
        echo -e "${YELLOW}Directory already exists.${RESET}"
        read -p "Overwrite existing configuration? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 0
        fi
    fi
    
    mkdir -p "$DEST_DIR"
    chmod 700 "$DEST_DIR"
    
    echo
    echo -e "${GREEN}✓${RESET} Install location set to: $DEST_DIR"
    
    wait_for_enter
    clear_screen
    
    # ==========================================
    # Step 2: Select Providers
    # ==========================================
    print_step 2 4 "Select Providers"
    
    echo -e "Choose which providers to configure:"
    echo
    
    for key in 1 2 3; do
        print_provider_card "$key" "${PROVIDER_NAMES[$key]}" "${PROVIDER_MODELS[$key]}" "${PROVIDER_LINKS[$key]}"
    done
    
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo -e "  ${MAGENTA}[a]${RESET} ${BOLD}Select All${RESET}"
    echo -e "  ${MAGENTA}[n]${RESET} ${BOLD}None${RESET} (skip provider setup)"
    echo
    read -p "Enter your selection (e.g., 1,3 or a): " selection
    
    SELECTED_PROVIDERS=()
    
    if [[ "$selection" == "a" || "$selection" == "A" || "$selection" == "" ]]; then
        SELECTED_PROVIDERS=(1 2 3)
    elif [[ "$selection" == "n" || "$selection" == "N" ]]; then
        echo
        echo -e "${YELLOW}No providers selected.${RESET}"
    else
        IFS=',' read -ra TEMP <<< "$selection"
        for item in "${TEMP[@]}"; do
            item=$(echo "$item" | tr -d ' ')
            if [[ -n "${PROVIDERS[$item]}" ]]; then
                SELECTED_PROVIDERS+=("$item")
            fi
        done
    fi
    
    wait_for_enter
    clear_screen
    
    # ==========================================
    # Step 3: Configure API Keys
    # ==========================================
    print_step 3 4 "Configure API Keys"
    
    if [[ ${#SELECTED_PROVIDERS[@]} -eq 0 ]]; then
        echo -e "${DIM}Skipping API key configuration.${RESET}"
    else
        echo -e "You'll need API keys for each provider."
        echo -e "Click the links above to get your keys."
        echo
        
        {
            echo "# Claude Code Multi-Provider Configuration"
            echo "# DO NOT commit this file to version control."
            echo ""
        } > "$DEST_DIR/.env"
        chmod 600 "$DEST_DIR/.env"
        
        for num in "${SELECTED_PROVIDERS[@]}"; do
            local name="${PROVIDERS[$num]}"
            local display_name="${PROVIDER_NAMES[$name]}"
            local link="${PROVIDER_LINKS[$name]}"
            local api_key_var="${PROVIDER_API_KEYS[$name]}"
            
            clear_screen
            print_step 3 4 "Configure API Keys"
            
            echo -e "${BOLD}Provider: ${MAGENTA}$display_name${RESET}"
            echo
            
            if [[ -x "$BROWSER" ]] || which open > /dev/null 2>&1; then
                echo -e "  ${CYAN}→ Get your API key:${RESET} ${UNDERLINE}$link${RESET}"
                echo
                read -p "  Press Enter after getting your key (or 's' to skip): " skip
                
                if [[ "$skip" == "s" || "$skip" == "S" ]]; then
                    echo
                    echo -e "${YELLOW}Skipped $display_name${RESET}"
                    continue
                fi
            else
                echo -e "  ${CYAN}→ Get your API key at:${RESET}"
                echo -e "  ${UNDERLINE}$link${RESET}"
                echo
            fi
            
            echo -n "  Enter API Key: "
            read -s api_key
            echo
            
            if [[ -n "$api_key" ]]; then
                echo "$api_key_var=\"$api_key\"" >> "$DEST_DIR/.env"
                echo -e "${GREEN}✓${RESET} $display_name configured"
            else
                echo -e "${YELLOW}Skipped $display_name${RESET}"
            fi
        done
    fi
    
    wait_for_enter
    clear_screen
    
    # ==========================================
    # Step 4: Generate Scripts
    # ==========================================
    print_step 4 4 "Generate Scripts"
    
    echo "Creating provider script..."
    echo
    
    {
        echo '#!/usr/bin/env bash'
        echo ''
        echo 'CONFIG_FILE="$HOME/.claude_switcher/.env"'
        echo 'if [ -f "$CONFIG_FILE" ]; then'
        echo '    set -a'
        echo '    source "$CONFIG_FILE"'
        echo '    set +a'
        echo 'else'
        echo '    echo "Warning: Claude Switcher config not found"'
        echo 'fi'
        echo ''
    } > "$DEST_DIR/ccswitch.sh"
    
    for num in "${SELECTED_PROVIDERS[@]}"; do
        local name="${PROVIDERS[$num]}"
        local base_url="${PROVIDER_BASE_URLS[$name]}"
        local model="${PROVIDER_MODELS[$name]}"
        local api_key_var="${PROVIDER_API_KEYS[$name]}"
        
        case $name in
            kimi)
                cat >> "$DEST_DIR/ccswitch.sh" << EOF

_cc_setup_kimi() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="\$$api_key_var"
    export ANTHROPIC_MODEL="kimi-for-coding"
    export ANTHROPIC_SMALL_FAST_MODEL="kimi-for-coding"
}
EOF
                ;;
            glm)
                cat >> "$DEST_DIR/ccswitch.sh" << EOF

_cc_setup_glm() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="\$$api_key_var"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.5-air"
}
EOF
                ;;
            minimax)
                cat >> "$DEST_DIR/ccswitch.sh" << EOF

_cc_setup_minimax() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="\$$api_key_var"
    export ANTHROPIC_MODEL="MiniMax-Text-01"
    export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-Text-01"
}
EOF
                ;;
        esac
    done
    
    cat >> "$DEST_DIR/ccswitch.sh" << 'EOF'

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
EOF

    chmod +x "$DEST_DIR/ccswitch.sh"
    
    echo -e "${GREEN}✓${RESET} Script generated: $DEST_DIR/ccswitch.sh"
    
    # Update shell config
    SHELL_RC="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
    
    MARKER="# Claude Code Multi-Provider Switcher"
    if ! grep -qF "$MARKER" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "$MARKER" >> "$SHELL_RC"
        echo "source $DEST_DIR/ccswitch.sh" >> "$SHELL_RC"
        echo -e "${GREEN}✓${RESET} Updated: $SHELL_RC"
    else
        echo -e "${DIM}○${RESET} Already configured in: $SHELL_RC"
    fi
    
    wait_for_enter
    clear_screen
    
    # ==========================================
    # Complete
    # ==========================================
    cat << EOF

    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │                      ${GREEN}✓ Setup Complete!${RESET}                      │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘

EOF

    echo -e "${BOLD}Configured Providers:${RESET}"
    echo
    
    if [[ ${#SELECTED_PROVIDERS[@]} -eq 0 ]]; then
        echo -e "  ${DIM}None (run setup again to add providers)${RESET}"
    else
        for num in "${SELECTED_PROVIDERS[@]}"; do
            local name="${PROVIDERS[$num]}"
            local display_name="${PROVIDER_NAMES[$name]}"
            echo -e "  ${GREEN}✓${RESET} $display_name"
        done
    fi
    
    echo
    echo -e "${BOLD}Usage:${RESET}"
    
    for num in "${SELECTED_PROVIDERS[@]}"; do
        local name="${PROVIDERS[$num]}"
        echo -e "  ${CYAN}cc $name${RESET}          # Launch with ${PROVIDER_NAMES[$name]}"
    done
    echo -e "  ${CYAN}cc${RESET}                # Launch with default (Anthropic)"
    
    echo
    echo -e "${DIM}Restart your shell or run:${RESET}"
    echo -e "  ${BOLD}source $SHELL_RC${RESET}"
    echo
}

TOTAL_STEPS=4

main "$@"
