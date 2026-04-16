#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_FILE="$SCRIPT_DIR/providers.json"

if [[ ! -f "$PROVIDERS_FILE" ]]; then
    echo "Error: providers.json not found at $PROVIDERS_FILE"
    exit 1
fi

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
UNDERLINE='\033[4m'

# ==========================================
# Load Providers from JSON
# ==========================================
load_providers() {
    local json=$(cat "$PROVIDERS_FILE")
    
    PROVIDER_IDS=()
    declare -A PROVIDER_NAMES
    declare -A PROVIDER_MODELS
    declare -A PROVIDER_BASE_URLS
    declare -A PROVIDER_LINKS
    declare -A PROVIDER_API_KEYS
    declare -A PROVIDER_ENV_VARS
    
    local count=0
    while IFS= read -r line; do
        count=$((count + 1))
        
        local id=$(echo "$line" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local name=$(echo "$line" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local models=$(echo "$line" | grep -o '"models"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local base_url=$(echo "$line" | grep -o '"base_url"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local api_link=$(echo "$line" | grep -o '"api_link"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local api_key_var=$(echo "$line" | grep -o '"api_key_var"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local env_vars=$(echo "$line" | grep -o '"env_vars"[[:space:]]*:[[:space:]]*{[^}]*}' | sed 's/"env_vars"[[:space:]]*:[[:space:]]*//')
        
        if [[ -n "$id" ]]; then
            PROVIDER_IDS+=("$id")
            PROVIDER_NAMES[$id]="$name"
            PROVIDER_MODELS[$id]="$models"
            PROVIDER_BASE_URLS[$id]="$base_url"
            PROVIDER_LINKS[$id]="$api_link"
            PROVIDER_API_KEYS[$id]="$api_key_var"
            PROVIDER_ENV_VARS[$id]="$env_vars"
        fi
    done <<< "$(echo "$json" | grep -E '^\s*{' -A 20 | grep -E '^\s*{|^\s*}')"
}

# Simpler JSON parsing using python if available
load_providers_python() {
    if command -v python3 > /dev/null 2>&1; then
        python3 << 'PYEOF'
import json
import sys
import os

providers_file = os.path.join(os.path.dirname(__file__) if '__file__' in dir() else os.getcwd(), 'providers.json')

try:
    with open(providers_file) as f:
        data = json.load(f)
    
    for i, p in enumerate(data.get('providers', [])):
        print(f"PROVIDER_{i}_ID={p['id']}")
        print(f"PROVIDER_{i}_NAME={p['name']}")
        print(f"PROVIDER_{i}_MODELS={p['models']}")
        print(f"PROVIDER_{i}_BASE_URL={p['base_url']}")
        print(f"PROVIDER_{i}_API_LINK={p['api_link']}")
        print(f"PROVIDER_{i}_API_KEY_VAR={p['api_key_var']}")
        
        env_vars_str = json.dumps(p.get('env_vars', {}))
        print(f"PROVIDER_{i}_ENV_VARS={env_vars_str}")
        print("---")
except Exception as e:
    sys.exit(1)
PYEOF
        return 0
    fi
    return 1
}

load_providers_simple() {
    local json_content=$(cat "$PROVIDERS_FILE")
    
    local count=$(echo "$json_content" | grep -o '"id"' | wc -l)
    
    for ((i=0; i<count; i++)); do
        local id=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$i]['id'])
" 2>/dev/null || echo "unknown")
        
        if [[ "$id" != "unknown" ]]; then
            PROVIDER_IDS+=("$id")
        fi
    done
    
    for id in "${PROVIDER_IDS[@]}"; do
        local idx=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for i, p in enumerate(data['providers']):
    if p['id'] == '$id':
        print(i)
        break
" 2>/dev/null)
        
        if [[ -n "$idx" ]]; then
            PROVIDER_NAMES[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$idx]['name'])
" 2>/dev/null)
            PROVIDER_MODELS[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$idx]['models'])
" 2>/dev/null)
            PROVIDER_BASE_URLS[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$idx]['base_url'])
" 2>/dev/null)
            PROVIDER_LINKS[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$idx]['api_link'])
" 2>/dev/null)
            PROVIDER_API_KEYS[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['providers'][$idx]['api_key_var'])
" 2>/dev/null)
            PROVIDER_ENV_VARS[$id]=$(echo "$json_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)
import json as j
print(j.dumps(data['providers'][$idx].get('env_vars', {})))
" 2>/dev/null)
        fi
    done
}

declare -a PROVIDER_IDS
declare -A PROVIDER_NAMES
declare -A PROVIDER_MODELS
declare -A PROVIDER_BASE_URLS
declare -A PROVIDER_LINKS
declare -A PROVIDER_API_KEYS
declare -A PROVIDER_ENV_VARS

load_providers_simple

# ==========================================
# Helper Functions
# ==========================================
clear_screen() {
    printf "\033[2J\033[H"
}

print_banner() {
    cat << EOF

${CYAN}    ┌─────────────────────────────────────────────────────────────┐
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
    └─────────────────────────────────────────────────────────────┘${RESET}

EOF
}

print_step() {
    echo -e "${CYAN}[$1/${TOTAL_STEPS}]${RESET} ${BOLD}$2${RESET}"
    echo
}

print_provider_card() {
    local num=$1
    local id=$2
    local name="${PROVIDER_NAMES[$id]}"
    local model="${PROVIDER_MODELS[$id]}"
    local link="${PROVIDER_LINKS[$id]}"
    
    echo -e "  ${MAGENTA}[$num]${RESET} ${BOLD}$name${RESET}"
    echo -e "      ${DIM}Model:${RESET} $model"
    echo -e "      ${DIM}API:${RESET} ${CYAN}${UNDERLINE}$link${RESET}"
    echo
}

wait_for_enter() {
    echo
    echo -e "${DIM}Press ${BOLD}Enter${RESET}${DIM} to continue...${RESET}"
    read -r
}

get_env_vars_block() {
    local id=$1
    local env_vars_json="${PROVIDER_ENV_VARS[$id]}"
    
    local env_block=""
    
    local count=$(echo "$env_vars_json" | grep -o '"' | wc -l)
    count=$((count / 2))
    
    if command -v python3 > /dev/null 2>&1; then
        env_block=$(echo "$env_vars_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, value in data.items():
    print(f'    export {key}=\"{value}\"')
" 2>/dev/null)
    else
        while IFS=': ' read -r key value; do
            [[ -z "$key" || -z "$value" ]] && continue
            key=$(echo "$key" | tr -d '"')
            value=$(echo "$value" | tr -d '", ')
            env_block="${env_block}
    export $key=\"$value\""
        done <<< "$(echo "$env_vars_json" | tr ',' '\n' | tr -d '{}"')"
    fi
    
    echo "$env_block"
}

generate_setup_function() {
    local id=$1
    local base_url="${PROVIDER_BASE_URLS[$id]}"
    local api_key_var="${PROVIDER_API_KEYS[$id]}"
    local env_vars="${PROVIDER_ENV_VARS[$id]}"
    
    local func_name="_cc_setup_$id"
    
    cat << EOF

$func_name() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="\$$api_key_var"
$(echo "$env_vars" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, value in data.items():
    print(f'    export {key}=\"{value}\"')
" 2>/dev/null || echo "    # Configure env vars manually")
}
EOF
}

# ==========================================
# Main Setup Flow
# ==========================================
main() {
    if [[ ${#PROVIDER_IDS[@]} -eq 0 ]]; then
        echo "Error: No providers found in providers.json"
        exit 1
    fi
    
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
    
    local num=1
    for id in "${PROVIDER_IDS[@]}"; do
        print_provider_card "$num" "$id"
        num=$((num + 1))
    done
    
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo -e "  ${MAGENTA}[a]${RESET} ${BOLD}Select All${RESET}"
    echo -e "  ${MAGENTA}[n]${RESET} ${BOLD}None${RESET} (skip provider setup)"
    echo
    read -p "Enter your selection (e.g., 1,3 or a): " selection
    
    SELECTED_PROVIDERS=()
    
    if [[ "$selection" == "a" || "$selection" == "A" || "$selection" == "" ]]; then
        SELECTED_PROVIDERS=("${PROVIDER_IDS[@]}")
    elif [[ "$selection" == "n" || "$selection" == "N" ]]; then
        echo
        echo -e "${YELLOW}No providers selected.${RESET}"
    else
        IFS=',' read -ra TEMP <<< "$selection"
        local idx=0
        for item in "${TEMP[@]}"; do
            item=$(echo "$item" | tr -d ' ')
            idx=$((item - 1))
            if [[ $idx -ge 0 && $idx -lt ${#PROVIDER_IDS[@]} ]]; then
                SELECTED_PROVIDERS+=("${PROVIDER_IDS[$idx]}")
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
        echo -e "Click the links below to get your keys."
        echo
        
        {
            echo "# Claude Code Multi-Provider Configuration"
            echo "# DO NOT commit this file to version control."
            echo ""
        } > "$DEST_DIR/.env"
        chmod 600 "$DEST_DIR/.env"
        
        for id in "${SELECTED_PROVIDERS[@]}"; do
            local display_name="${PROVIDER_NAMES[$id]}"
            local link="${PROVIDER_LINKS[$id]}"
            local api_key_var="${PROVIDER_API_KEYS[$id]}"
            
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
    
    for id in "${SELECTED_PROVIDERS[@]}"; do
        local base_url="${PROVIDER_BASE_URLS[$id]}"
        local api_key_var="${PROVIDER_API_KEYS[$id]}"
        local env_vars_json="${PROVIDER_ENV_VARS[$id]}"
        local func_name="_cc_setup_$id"
        
        cat >> "$DEST_DIR/ccswitch.sh" << EOF

$func_name() {
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="\$$api_key_var"
$(echo "$env_vars_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key, value in data.items():
    print(f'    export {key}=\"{value}\"')
" 2>/dev/null)
}
EOF
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

${GREEN}    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │                      ✓ Setup Complete!                       │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘${RESET}

EOF

    echo -e "${BOLD}Configured Providers:${RESET}"
    echo
    
    if [[ ${#SELECTED_PROVIDERS[@]} -eq 0 ]]; then
        echo -e "  ${DIM}None (run setup again to add providers)${RESET}"
    else
        for id in "${SELECTED_PROVIDERS[@]}"; do
            local name="${PROVIDER_NAMES[$id]}"
            echo -e "  ${GREEN}✓${RESET} $name"
        done
    fi
    
    echo
    echo -e "${BOLD}Usage:${RESET}"
    
    for id in "${SELECTED_PROVIDERS[@]}"; do
        local name="${PROVIDER_NAMES[$id]}"
        echo -e "  ${CYAN}cc $id${RESET}          # Launch with $name"
    done
    echo -e "  ${CYAN}cc${RESET}                # Launch with default (Anthropic)"
    
    echo
    echo -e "${DIM}Restart your shell or run:${RESET}"
    echo -e "  ${BOLD}source $SHELL_RC${RESET}"
    echo
}

TOTAL_STEPS=4

main "$@"
