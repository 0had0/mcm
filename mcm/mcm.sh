#!/usr/bin/env bash

set -e

# ==========================================
# MCM - Multi-Provider Claude Code Manager
# ==========================================

VERSION="0.1.0"
MCM_DIR="${MCM_DIR:-$HOME/.mcm}"
MCM_KEYS="$MCM_DIR/.keys.enc"
MCM_CONFIG="$MCM_DIR/config.json"
MCM_PROVIDERS="$MCM_DIR/providers.json"
MCM_LOG="$MCM_DIR/mcm.log"

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
# Encryption Helpers
# ==========================================
_encrypt() {
    local key="$1"
    local data="$2"
    echo "$data" | openssl enc -aes-256-cbc -A -a -salt -pbkdf2 -pass pass:"$key" 2>/dev/null
}

_decrypt() {
    local key="$1"
    local data="$2"
    echo "$data" | openssl enc -aes-256-cbc -A -a -d -pbkdf2 -pass pass:"$key" 2>/dev/null
}

_get_encryption_key() {
    if [[ -f "$MCM_DIR/.key" ]]; then
        cat "$MCM_DIR/.key"
    fi
}

_save_keys() {
    local data="$1"
    local key="$(_get_encryption_key)"
    if [[ -z "$key" ]]; then
        echo "Error: Encryption key not found"
        exit 1
    fi
    _encrypt "$key" "$data" > "$MCM_KEYS"
    chmod 600 "$MCM_KEYS"
}

_load_keys() {
    local key="$(_get_encryption_key)"
    if [[ -z "$key" || ! -f "$MCM_KEYS" ]]; then
        echo "{}"
        return
    fi
    local encrypted=$(cat "$MCM_KEYS")
    _decrypt "$key" "$encrypted" || echo "{}"
}

# ==========================================
# Provider Management
# ==========================================
_load_providers() {
    if [[ -f "$MCM_PROVIDERS" ]]; then
        cat "$MCM_PROVIDERS"
    else
        cat << 'EOF'
{"providers": []}
EOF
    fi
}

_save_providers() {
    cat > "$MCM_PROVIDERS"
    chmod 600 "$MCM_PROVIDERS"
}

_get_current_provider() {
    if [[ -f "$MCM_CONFIG" ]]; then
        python3 -c "
import json
with open('$MCM_CONFIG') as f:
    config = json.load(f)
print(config.get('current', 'none'))
" 2>/dev/null || echo "none"
}

_set_current_provider() {
    local provider="$1"
    local config='{"current": "'"$provider"'", "version": "'"$VERSION"'"}'
    echo "$config" > "$MCM_CONFIG"
    chmod 600 "$MCM_CONFIG"
}

# ==========================================
# Logger
# ==========================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$MCM_LOG"
}

# ==========================================
# Print Helpers
# ==========================================
print_banner() {
    cat << EOF

${CYAN}    ╔═══════════════════════════════════════════════════════╗
    ║  ${BOLD}MCM${RESET}${CYAN}  -  Multi-Provider Claude Code Manager      ║
    ║  ${DIM}Version $VERSION${RESET}${CYAN}                                            ║
    ╚═══════════════════════════════════════════════════════╝${RESET}

EOF
}

print_error() {
    echo -e "${RED}Error:${RESET} $*" >&2
}

print_success() {
    echo -e "${GREEN}✓${RESET} $*"
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $*"
}

print_info() {
    echo -e "${CYAN}ℹ${RESET} $*"
}

# ==========================================
# Command: install
# ==========================================
cmd_install() {
    echo
    echo -e "${BOLD}Installing MCM...${RESET}"
    echo
    
    if [[ -d "$MCM_DIR" ]]; then
        echo -e "${YELLOW}MCM is already installed at $MCM_DIR${RESET}"
        read -p "Reinstall? This will reset your configuration. [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
        rm -rf "$MCM_DIR"
    fi
    
    mkdir -p "$MCM_DIR"
    chmod 700 "$MCM_DIR"
    
    local encryption_key=$(openssl rand -hex 32)
    echo "$encryption_key" > "$MCM_DIR/.key"
    chmod 600 "$MCM_DIR/.key"
    
    echo "{}" > "$MCM_KEYS"
    chmod 600 "$MCM_KEYS"
    
    echo '{"current": "none", "version": "'"$VERSION"'"}' > "$MCM_CONFIG"
    chmod 600 "$MCM_CONFIG"
    
    local shell_rc=""
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    
    local install_line="export MCM_DIR=\"$MCM_DIR\""
    local source_line="[ -f \"\$MCM_DIR/mcm.sh\" ] && source \"\$MCM_DIR/mcm.sh\""
    
    if ! grep -qF "$install_line" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << SHELLRC

# MCM - Multi-Provider Claude Code Manager
$install_line
$source_line
SHELLRC
    fi
    
    print_success "MCM installed to $MCM_DIR"
    echo
    echo -e "${DIM}Your encryption key has been saved to:${RESET}"
    echo -e "  ${BOLD}$MCM_DIR/.key${RESET}"
    echo
    echo -e "${DIM}⚠️  ${BOLD}BACKUP YOUR ENCRYPTION KEY!${RESET}${DIM}"
    echo "   Without it, your API keys cannot be recovered."
    echo
    echo -e "Run ${CYAN}mcm add <provider>${RESET} to add a provider."
    echo
    echo -e "${DIM}Restart your shell or run:${RESET}"
    echo -e "  ${BOLD}source $shell_rc${RESET}"
    echo
}

# ==========================================
# Command: add
# ==========================================
cmd_add() {
    local provider_id="$1"
    
    if [[ -z "$provider_id" ]]; then
        print_error "Usage: mcm add <provider-id>"
        echo
        echo "Available providers:"
        _list_available_providers
        exit 1
    fi
    
    local providers_json=$(_load_providers)
    local provider_exists=$(echo "$providers_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('yes' if any(p['id'] == '$provider_id' for p in data['providers']) else 'no')
" 2>/dev/null)
    
    if [[ "$provider_exists" == "no" ]]; then
        print_error "Unknown provider: $provider_id"
        echo "Run 'mcm add' without arguments to see available providers."
        exit 1
    fi
    
    local provider_info=$(echo "$providers_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data['providers']:
    if p['id'] == '$provider_id':
        print(json.dumps(p))
        break
")
    
    local api_link=$(echo "$provider_info" | python3 -c "import json,sys; print(json.load(sys.stdin)['api_link'])")
    local api_key_var=$(echo "$provider_info" | python3 -c "import json,sys; print(json.load(sys.stdin)['api_key_var'])")
    local name=$(echo "$provider_info" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    
    echo
    echo -e "${BOLD}Adding ${MAGENTA}$name${RESET}"
    
    if [[ -x "$BROWSER" ]] || which open > /dev/null 2>&1; then
        echo -e "  ${CYAN}→ API docs:${RESET} ${UNDERLINE}$api_link${RESET}"
        echo
        read -p "Press Enter when you have your API key, or 's' to skip: " skip
        [[ "$skip" == "s" || "$skip" == "S" ]] && exit 0
    else
        echo -e "  ${CYAN}→ Get your API key at:${RESET} $api_link"
    fi
    
    echo
    echo -n "  Enter API Key: "
    read -s api_key
    echo
    
    if [[ -z "$api_key" ]]; then
        print_warning "No API key provided. Skipped."
        exit 0
    fi
    
    local keys_json=$(_load_keys)
    local new_keys=$(echo "$keys_json" | python3 -c "
import json, sys
keys = json.load(sys.stdin)
keys['$provider_id'] = '$api_key'
print(json.dumps(keys, indent=2))
")
    
    _save_keys "$new_keys"
    print_success "$name added successfully"
    log "Added provider: $provider_id"
}

# ==========================================
# Command: list
# ==========================================
cmd_list() {
    local keys_json=$(_load_keys)
    local providers_json=$(_load_providers)
    local current=$(_get_current_provider)
    
    echo
    echo -e "${BOLD}Configured Providers:${RESET}"
    echo
    
    local has_any=false
    local idx=1
    
    echo "$providers_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys_data = json.loads('$keys_json')
current = '$current'

for p in data['providers']:
    pid = p['id']
    has_key = pid in keys_data and keys_data[pid]
    marker = '→' if pid == current else ' '
    key_status = '🔑' if has_key else '✗'
    print(f'{marker}|{pid}|{p[\"name\"]}|{p[\"models\"]}|{key_status}')
" 2>/dev/null | while IFS='|' read -r marker pid name models status; do
        if [[ "$marker" == "→" ]]; then
            echo -e "  ${CYAN}${BOLD}$marker${RESET} ${MAGENTA}$pid${RESET}  $name"
            echo -e "       ${DIM}Models: $models${RESET}"
            echo -e "       ${status} API key configured"
        else
            echo -e "  $marker ${MAGENTA}$pid${RESET}  $name"
            echo -e "       ${DIM}Models: $models${RESET}"
            echo -e "       ${status} API key configured"
        fi
        echo
    done
    
    echo -e "${DIM}→ = currently active${RESET}"
}

# ==========================================
# Command: use
# ==========================================
cmd_use() {
    local provider_id="$1"
    
    if [[ -z "$provider_id" ]]; then
        print_error "Usage: mcm use <provider-id>"
        exit 1
    fi
    
    local keys_json=$(_load_keys)
    local has_key=$(echo "$keys_json" | python3 -c "
import json, sys
keys = json.load(sys.stdin)
print('yes' if '$provider_id' in keys and keys['$provider_id'] else 'no')
")
    
    if [[ "$has_key" == "no" ]]; then
        print_error "Provider '$provider_id' is not configured."
        echo "Run 'mcm add $provider_id' first."
        exit 1
    fi
    
    _set_current_provider "$provider_id"
    print_success "Now using: $provider_id"
    log "Switched to: $provider_id"
    
    echo
    echo -e "${DIM}Run ${CYAN}cc${RESET}${DIM} to launch Claude Code with this provider.${RESET}"
}

# ==========================================
# Command: rm
# ==========================================
cmd_rm() {
    local provider_id="$1"
    
    if [[ -z "$provider_id" ]]; then
        print_error "Usage: mcm rm <provider-id>"
        exit 1
    fi
    
    local keys_json=$(_load_keys)
    local has_key=$(echo "$keys_json" | python3 -c "
import json, sys
keys = json.load(sys.stdin)
print('yes' if '$provider_id' in keys and keys['$provider_id'] else 'no')
")
    
    if [[ "$has_key" == "no" ]]; then
        print_error "Provider '$provider_id' is not configured."
        exit 1
    fi
    
    echo
    read -p "Remove API key for '$provider_id'? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    local new_keys=$(echo "$keys_json" | python3 -c "
import json, sys
keys = json.load(sys.stdin)
del keys['$provider_id']
print(json.dumps(keys, indent=2))
")
    
    _save_keys "$new_keys"
    print_success "Removed: $provider_id"
    log "Removed provider: $provider_id"
    
    local current=$(_get_current_provider)
    if [[ "$current" == "$provider_id" ]]; then
        _set_current_provider "none"
        print_info "Active provider reset to none"
    fi
}

# ==========================================
# Command: doctor
# ==========================================
cmd_doctor() {
    echo
    echo -e "${BOLD}Running diagnostics...${RESET}"
    echo
    
    local issues=0
    
    if [[ ! -d "$MCM_DIR" ]]; then
        echo -e "${RED}✗${RESET} MCM not installed"
        echo "  Run 'mcm install' to install"
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓${RESET} MCM directory exists: $MCM_DIR"
        
        if [[ -f "$MCM_DIR/.key" ]]; then
            echo -e "${GREEN}✓${RESET} Encryption key exists"
        else
            echo -e "${RED}✗${RESET} Encryption key missing!"
            issues=$((issues + 1))
        fi
        
        if [[ -f "$MCM_KEYS" ]]; then
            echo -e "${GREEN}✓${RESET} Encrypted keys file exists"
        else
            echo -e "${YELLOW}⚠${RESET} No keys file (add providers to create)"
        fi
    fi
    
    if command -v openssl > /dev/null 2>&1; then
        echo -e "${GREEN}✓${RESET} OpenSSL available"
    else
        echo -e "${RED}✗${RESET} OpenSSL not found"
        issues=$((issues + 1))
    fi
    
    if command -v claude > /dev/null 2>&1; then
        echo -e "${GREEN}✓${RESET} Claude Code CLI installed"
    else
        echo -e "${YELLOW}⚠${RESET} Claude Code CLI not found"
    fi
    
    if command -v python3 > /dev/null 2>&1; then
        echo -e "${GREEN}✓${RESET} Python 3 available"
    else
        echo -e "${RED}✗${RESET} Python 3 not found"
        issues=$((issues + 1))
    fi
    
    echo
    if [[ $issues -eq 0 ]]; then
        print_success "All checks passed!"
    else
        print_warning "$issues issue(s) found"
    fi
}

# ==========================================
# Command: help
# ==========================================
cmd_help() {
    print_banner
    
    cat << EOF
${BOLD}USAGE:${RESET}
    mcm <command> [options]

${BOLD}COMMANDS:${RESET}
    ${CYAN}install${RESET}             Install MCM and generate encryption key
    ${CYAN}add <provider>${RESET}       Add API key for a provider
    ${CYAN}list${RESET}                 List all providers and their status
    ${CYAN}use <provider>${RESET}       Set active provider
    ${CYAN}rm <provider>${RESET}        Remove provider's API key
    ${CYAN}doctor${RESET}               Run diagnostics
    ${CYAN}help${RESET}                 Show this help message
    ${CYAN}version${RESET}              Show version

${BOLD}EXAMPLES:${RESET}
    mcm install              # Install MCM
    mcm add kimi             # Add Kimi API key
    mcm add minimax          # Add MiniMax API key
    mcm list                 # Show all providers
    mcm use kimi             # Switch to Kimi
    cc                       # Launch Claude Code with Kimi

${BOLD}AVAILABLE PROVIDERS:${RESET}
EOF
    _list_available_providers
}

_list_available_providers() {
    echo "$(_load_providers)" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys_data = json.loads(open('$MCM_DIR/.keys.enc').read()) if __name__ == '__main__' else {}

# Load providers
providers_data = data.get('providers', [])

# Try to load keys (will fail without key but that's ok)
try:
    import subprocess
    key = open('$MCM_DIR/.key').read().strip()
    encrypted = open('$MCM_KEYS').read()
    decrypted = subprocess.check_output(['openssl', 'enc', '-aes-256-cbc', '-A', '-a', '-d', '-pbkdf2', '-pass', f'pass:{key}'], input=encrypted.encode())
    keys_data = json.loads(decrypted)
except:
    keys_data = {}

for p in providers_data:
    pid = p['id']
    has_key = pid in keys_data and keys_data[pid]
    key_icon = '🔑' if has_key else '○'
    print(f'    {MAGENTA}{pid}{RESET}  {p[\"name\"]} - {key_icon} {\"configured\" if has_key else \"not configured\"}')
" 2>/dev/null || echo "    (Run 'mcm install' first to see providers)"
}

# ==========================================
# CLI Dispatcher
# ==========================================
main() {
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "$command" in
        install|i)
            cmd_install
            ;;
        add|a)
            cmd_add "$@"
            ;;
        list|ls|l)
            cmd_list
            ;;
        use|switch|u)
            cmd_use "$@"
            ;;
        rm|remove)
            cmd_rm "$@"
            ;;
        doctor)
            cmd_doctor
            ;;
        version|v|--version)
            echo "MCM version $VERSION"
            ;;
        help|h|--help)
            cmd_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Run 'mcm help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
