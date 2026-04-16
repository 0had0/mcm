#!/usr/bin/env bash

set -e

VERSION="0.2.0"
MCM_DIR="${MCM_DIR:-$HOME/.mcm}"
MCM_KEYS="$MCM_DIR/.keys.enc"
MCM_CONFIG="$MCM_DIR/config.sh"
MCM_CACHE="$MCM_DIR/providers.cache"
MCM_LOG="$MCM_DIR/mcm.log"

MCM_REGISTRY="${MCM_REGISTRY:-https://raw.githubusercontent.com/hadih/mcm/main/mcm/providers.json}"
CACHE_AGE_MAX="${CACHE_AGE_MAX:-86400}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
UNDERLINE='\033[4m'

_mcm_err() { echo -e "${RED}Error:${RESET} $*" >&2; }
_mcm_ok() { echo -e "${GREEN}✓${RESET} $*"; }
_mcm_warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
_mcm_info() { echo -e "${CYAN}ℹ${RESET} $*"; }

_mcm_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$MCM_LOG" 2>/dev/null || true; }

_mcm_has_py() { command -v python3 >/dev/null 2>&1; }

_mcm_get_local_providers() {
    local local_file="${BASH_SOURCE[0]%/*}/providers.json"
    [[ -f "$local_file" ]] && cat "$local_file"
}

_mcm_fetch_providers() {
    local data=""
    
    if [[ "$MCM_REGISTRY" =~ ^file:// ]]; then
        local file="${MCM_REGISTRY#file://}"
        [[ -f "$file" ]] && data=$(cat "$file")
    elif [[ -n "$MCM_REGISTRY" ]]; then
        data=$(curl -sSL --max-time 10 "$MCM_REGISTRY" 2>/dev/null)
    fi
    
    if [[ -z "$data" ]]; then
        data=$(_mcm_get_local_providers)
    fi
    
    echo "$data"
}

_mcm_cache_valid() {
    [[ -f "$MCM_CACHE" ]] || return 1
    local age=$(($(date +%s) - $(stat -f %m "$MCM_CACHE" 2>/dev/null || stat -c %Y "$MCM_CACHE" 2>/dev/null || echo 0)))
    [[ $age -lt $CACHE_AGE_MAX ]]
}

_mcm_load_providers() {
    local data=""
    
    mkdir -p "$MCM_DIR"
    
    if [[ -f "$MCM_DIR/providers.conf" ]]; then
        data=$(cat "$MCM_DIR/providers.conf")
    elif _mcm_cache_valid; then
        data=$(cat "$MCM_CACHE")
    else
        data=$(_mcm_fetch_providers)
        if [[ -n "$data" ]]; then
            echo "$data" > "$MCM_CACHE"
            chmod 600 "$MCM_CACHE"
        fi
    fi
    
    [[ -z "$data" && -f "$MCM_CACHE" ]] && data=$(cat "$MCM_CACHE")
    echo "$data"
}

_mcm_parse_providers() {
    local action="$1"
    local filter="${2:-}"
    
    if ! _mcm_has_py; then
        _mcm_err "Python3 required for provider management"
        return 1
    fi
    
    local data=$(_mcm_load_providers)
    [[ -z "$data" ]] && _mcm_err "No provider data available" && return 1
    
    python3 - "$action" "$filter" "$data" << 'PYEOF'
import json, sys

action = sys.argv[1]
filter_id = sys.argv[2] if len(sys.argv) > 2 else None

try:
    data = json.loads(sys.argv[3])
except:
    print("{}", file=sys.stderr)
    sys.exit(1)

providers = data.get("providers", [])
version = data.get("version", "1")

if action == "list":
    for p in providers:
        pid = p.get("id", "")
        if filter_id and pid != filter_id:
            continue
        name = p.get("name", "")
        models = p.get("models", "")
        desc = p.get("description", "")
        link = p.get("api_link", "")
        base_url = p.get("base_url", "")
        api_var = p.get("api_key_var", "")
        envs = json.dumps(p.get("env_vars", {}))
        print(f"{pid}|{name}|{models}|{base_url}|{api_var}|{link}|{envs}")

elif action == "info":
    for p in providers:
        if p.get("id") == filter_id:
            print(json.dumps(p))
            break

elif action == "ids":
    for p in providers:
        print(p.get("id", ""))

PYEOF
}

_mcm_get_env_vars() {
    local id="$1"
    
    if ! _mcm_has_py; then
        return
    fi
    
    local data=$(_mcm_load_providers)
    python3 - "$id" "$data" << 'PYEOF'
import json, sys
provider_id = sys.argv[1]
try:
    data = json.loads(sys.argv[2])
    for p in data.get("providers", []):
        if p.get("id") == provider_id:
            for k, v in p.get("env_vars", {}).items():
                print(f"{k}|{v}")
            break
except:
    pass
PYEOF
}

_mcm_encrypt() {
    local data="$1"
    local key="$2"
    echo "$data" | openssl enc -aes-256-cbc -A -a -salt -pbkdf2 -pass "pass:$key" 2>/dev/null
}

_mcm_decrypt() {
    local data="$1"
    local key="$2"
    echo "$data" | openssl enc -aes-256-cbc -A -a -d -pbkdf2 -pass "pass:$key" 2>/dev/null
}

_mcm_get_key() { [[ -f "$MCM_DIR/.key" ]] && cat "$MCM_DIR/.key"; }

_mcm_save_keys() {
    local data="$1"
    local key="$(_mcm_get_key)"
    [[ -z "$key" ]] && _mcm_err "No encryption key" && exit 1
    _mcm_encrypt "$data" "$key" > "$MCM_KEYS"
    chmod 600 "$MCM_KEYS"
}

_mcm_load_keys() {
    local key="$(_mcm_get_key)"
    [[ -z "$key" || ! -f "$MCM_KEYS" ]] && echo "{}" && return
    _mcm_decrypt "$(cat "$MCM_KEYS")" "$key" || echo "{}"
}

_mcm_get_current() {
    [[ -f "$MCM_CONFIG" ]] && grep "^MCM_CURRENT=" "$MCM_CONFIG" 2>/dev/null | cut -d'"' -f2 || echo "none"
}

_mcm_set_current() {
    mkdir -p "$MCM_DIR"
    echo "MCM_CURRENT=\"$1\"" > "$MCM_CONFIG"
    chmod 600 "$MCM_CONFIG"
}

cmd_install() {
    echo
    echo -e "${BOLD}Installing MCM $VERSION...${RESET}"
    echo
    
    if [[ -d "$MCM_DIR" ]]; then
        echo -e "${YELLOW}MCM already installed at $MCM_DIR${RESET}"
        read -p "Reinstall? This will reset your config. [y/N]: " c
        [[ ! "$c" =~ ^[Yy]$ ]] && exit 0
        rm -rf "$MCM_DIR"
    fi
    
    mkdir -p "$MCM_DIR"
    chmod 700 "$MCM_DIR"
    
    openssl rand -hex 32 > "$MCM_DIR/.key"
    chmod 600 "$MCM_DIR/.key"
    
    echo "{}" > "$MCM_KEYS"
    chmod 600 "$MCM_KEYS"
    
    _mcm_set_current "none"
    
    echo -e "${DIM}Fetching providers...${RESET}"
    _mcm_parse_providers "list" >/dev/null 2>&1 || true
    
    local shell_rc="$HOME/.bashrc"
    [[ -n "$ZSH_VERSION" ]] && shell_rc="$HOME/.zshrc"
    
    local marker="# MCM"
    if ! grep -qF "$marker" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << SHELLRC

$marker
export MCM_DIR="\$HOME/.mcm"
export PATH="\$MCM_DIR:\$PATH"
SHELLRC
    fi
    
    echo
    _mcm_ok "Installed to $MCM_DIR"
    echo
    echo -e "${YELLOW}${BOLD}⚠️  BACKUP YOUR ENCRYPTION KEY:${RESET}"
    echo -e "  ${BOLD}$MCM_DIR/.key${RESET}"
    echo
    echo -e "${DIM}Run ${CYAN}mcm list${RESET}${DIM} to see available providers${RESET}"
    echo -e "${DIM}Run ${CYAN}mcm add <provider>${RESET}${DIM} to add a provider${RESET}"
}

cmd_add() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        _mcm_err "Usage: mcm add <provider-id>"
        echo
        echo "Available providers:"
        cmd_list
        exit 1
    fi
    
    local info=$(_mcm_parse_providers "info" "$id")
    if [[ -z "$info" ]]; then
        _mcm_err "Unknown provider: $id"
        _mcm_info "Run 'mcm update' to refresh provider list"
        exit 1
    fi
    
    local name=$(echo "$info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
    local api_link=$(echo "$info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('api_link',''))" 2>/dev/null)
    
    echo
    echo -e "${BOLD}Adding ${CYAN}$name${RESET}"
    echo -e "  ${CYAN}→ Docs:${RESET} ${UNDERLINE}$api_link${RESET}"
    echo
    
    if [[ -x "$BROWSER" || -f /usr/bin/open || -f /usr/bin/xdg-open ]]; then
        read -p "Press Enter when ready, or 's' to skip: " c
        [[ "$c" == "s" || "$c" == "S" ]] && exit 0
    else
        echo -e "  ${DIM}Get your API key at: $api_link${RESET}"
    fi
    
    echo
    echo -n "  API Key: "
    read -s api_key
    echo
    
    [[ -z "$api_key" ]] && _mcm_warn "No key provided, skipped" && exit 0
    
    local keys=$(_mcm_load_keys)
    local new_keys=$(echo "$keys" | sed "s/}$/, \"$id\": \"$api_key\"}/")
    [[ "$new_keys" == "$keys" ]] && new_keys="{\"$id\": \"$api_key\"}"
    
    _mcm_save_keys "$new_keys"
    _mcm_ok "$name added"
    _mcm_log "Added: $id"
}

cmd_list() {
    if ! _mcm_has_py; then
        _mcm_err "Python3 required"
        return 1
    fi
    
    local keys=$(_mcm_load_keys)
    local current=$(_mcm_get_current)
    
    echo
    echo -e "${BOLD}Providers:${RESET}"
    
    local providers=$(_mcm_parse_providers "list")
    
    if [[ -z "$providers" ]]; then
        echo -e "${DIM}  No providers available${RESET}"
        echo -e "${DIM}  Run ${CYAN}mcm update${RESET}${DIM} to fetch${RESET}"
        return
    fi
    
    echo
    
    local cached_age=""
    if [[ -f "$MCM_CACHE" ]]; then
        local age=$(($(date +%s) - $(stat -f %m "$MCM_CACHE" 2>/dev/null || stat -c %Y "$MCM_CACHE" 2>/dev/null || echo 0)))
        local hours=$((age / 3600))
        cached_age=" (cached ${hours}h ago)"
    fi
    
    echo -e "${DIM}Registry: $MCM_REGISTRY${cached_age}${RESET}"
    echo
    
    while IFS='|' read -r id name models base_url api_var api_link envs; do
        [[ -z "$id" ]] && continue
        
        local has_key=$(echo "$keys" | grep -q "\"$id\"" && echo "yes" || echo "no")
        local marker=" "
        local key_icon="${DIM}○${RESET}"
        
        [[ "$id" == "$current" ]] && marker="${CYAN}→${RESET}" && key_icon="${GREEN}🔑${RESET}"
        [[ "$has_key" == "yes" ]] && key_icon="${GREEN}🔑${RESET}"
        
        echo -e "  ${MAGENTA}$id${RESET}  $name ${key_icon}"
        echo -e "       ${DIM}$models${RESET}"
        echo
    done <<< "$providers"
    
    echo -e "${DIM}→ = active  🔑 = configured${RESET}"
}

cmd_use() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        _mcm_err "Usage: mcm use <provider-id>"
        exit 1
    fi
    
    local info=$(_mcm_parse_providers "info" "$id")
    [[ -z "$info" ]] && _mcm_err "Unknown provider: $id" && exit 1
    
    local keys=$(_mcm_load_keys)
    [[ ! "$keys" =~ "\"$id\"" ]] && _mcm_err "$id not configured. Run 'mcm add $id'" && exit 1
    
    _mcm_set_current "$id"
    _mcm_ok "Now using: $id"
    _mcm_log "Switched to: $id"
    echo
    echo -e "${DIM}Run ${CYAN}cc${RESET}${DIM} to launch Claude Code with $id${RESET}"
}

cmd_rm() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        _mcm_err "Usage: mcm rm <provider-id>"
        exit 1
    fi
    
    local keys=$(_mcm_load_keys)
    [[ ! "$keys" =~ "\"$id\"" ]] && _mcm_err "$id not configured" && exit 1
    
    echo
    read -p "Remove '$id'? [y/N]: " c
    [[ ! "$c" =~ ^[Yy]$ ]] && exit 0
    
    local new_keys=$(echo "$keys" | sed "s/, *\"$id\": *\"[^\"]*\"//" | sed 's/{"\s*"/{"/')
    [[ "$new_keys" == "$keys" ]] && new_keys=$(echo "$keys" | sed "s/{\"$id\": \"[^\"]*\"}/{}/")
    
    _mcm_save_keys "$new_keys"
    _mcm_ok "Removed: $id"
    _mcm_log "Removed: $id"
    
    [[ "$(_mcm_get_current)" == "$id" ]] && _mcm_set_current "none" && _mcm_warn "Active provider reset"
}

cmd_update() {
    echo -e "${DIM}Fetching providers from registry...${RESET}"
    
    local data=$(_mcm_fetch_providers)
    
    if [[ -z "$data" ]]; then
        _mcm_err "Failed to fetch providers"
        [[ -f "$MCM_CACHE" ]] && _mcm_info "Using cached providers"
        exit 1
    fi
    
    echo "$data" > "$MCM_CACHE"
    chmod 600 "$MCM_CACHE"
    
    _mcm_ok "Providers updated"
    echo
    cmd_list
}

cmd_doctor() {
    echo
    echo -e "${BOLD}Running diagnostics...${RESET}"
    echo
    
    local issues=0
    
    if [[ -d "$MCM_DIR" ]]; then
        _mcm_ok "MCM installed: $MCM_DIR"
        [[ -f "$MCM_DIR/.key" ]] && _mcm_ok "Encryption key exists" || { _mcm_err "Key missing"; ((issues++)); }
        [[ -f "$MCM_KEYS" ]] && _mcm_ok "Keys file exists" || _mcm_warn "No keys file"
    else
        _mcm_err "MCM not installed"
        echo "  Run 'mcm install'"
        ((issues++))
    fi
    
    if command -v openssl >/dev/null 2>&1; then
        _mcm_ok "OpenSSL available"
    else
        _mcm_err "OpenSSL not found"
        ((issues++))
    fi
    
    if command -v curl >/dev/null 2>&1; then
        _mcm_ok "curl available"
    else
        _mcm_warn "curl not found (can't update providers)"
    fi
    
    if _mcm_has_py; then
        _mcm_ok "Python3 available"
    else
        _mcm_warn "Python3 not found (limited functionality)"
    fi
    
    command -v claude >/dev/null 2>&1 && _mcm_ok "Claude Code CLI installed" || _mcm_warn "Claude Code CLI not found"
    
    if [[ -f "$MCM_CACHE" ]]; then
        local age=$(($(date +%s) - $(stat -f %m "$MCM_CACHE" 2>/dev/null || stat -c %Y "$MCM_CACHE" 2>/dev/null || echo 0)))
        local hours=$((age / 3600))
        echo -e "${DIM}Provider cache: ${hours}h old${RESET}"
    fi
    
    echo
    [[ $issues -eq 0 ]] && _mcm_ok "All checks passed!" || _mcm_warn "$issues issue(s)"
}

cmd_help() {
    cat << EOF

${CYAN}    ╔═══════════════════════════════════════════════╗
    ║  ${BOLD}MCM${RESET}${CYAN}  -  Multi-Provider Claude Code Manager  ║
    ║  ${DIM}Version $VERSION${RESET}${CYAN}                                  ║
    ╚═══════════════════════════════════════════════╝${RESET}

${BOLD}USAGE:${RESET}
    mcm <command> [options]

${BOLD}COMMANDS:${RESET}
    ${CYAN}install${RESET}             Install MCM and generate encryption key
    ${CYAN}update${RESET}              Fetch latest providers from registry
    ${CYAN}add <id>${RESET}           Add API key for a provider
    ${CYAN}list${RESET}                List all providers
    ${CYAN}use <id>${RESET}            Set active provider
    ${CYAN}rm <id>${RESET}             Remove provider
    ${CYAN}doctor${RESET}              Run diagnostics
    ${CYAN}help${RESET}                Show this help

${BOLD}EXAMPLES:${RESET}
    mcm install              Install MCM
    mcm update               Fetch latest providers
    mcm add kimi             Add Kimi
    mcm list                 Show providers
    mcm use kimi             Switch to Kimi
    cc                       Launch Claude Code

${BOLD}ENVIRONMENT:${RESET}
    MCM_REGISTRY             Provider registry URL
    MCM_DIR                  Installation directory
    MCM_PROVIDERS            Local providers file (override)

EOF
}

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        install|i) cmd_install ;;
        update|refresh) cmd_update ;;
        add|a) cmd_add "$@" ;;
        list|ls|l) cmd_list ;;
        use|switch|u) cmd_use "$@" ;;
        rm|remove) cmd_rm "$@" ;;
        doctor) cmd_doctor ;;
        help|h|--help) cmd_help ;;
        version|v) echo "MCM version $VERSION" ;;
        *) _mcm_err "Unknown: $cmd"; echo "Run 'mcm help'"; exit 1 ;;
    esac
}

[[ "${MCM_SOURCED:-}" != "1" ]] && main "$@"
