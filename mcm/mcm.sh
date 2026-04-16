#!/usr/bin/env bash

set -e

VERSION="0.1.0"
MCM_DIR="${MCM_DIR:-$HOME/.mcm}"
MCM_KEYS="$MCM_DIR/.keys.enc"
MCM_CONFIG="$MCM_DIR/config.sh"
MCM_LOG="$MCM_DIR/mcm.log"

_get_providers_file() {
    if [[ -n "$MCM_PROVIDERS" && -f "$MCM_PROVIDERS" ]]; then
        echo "$MCM_PROVIDERS"
    elif [[ -f "$MCM_DIR/providers.conf" ]]; then
        echo "$MCM_DIR/providers.conf"
    elif [[ -f "${BASH_SOURCE[0]%/*}/providers.conf" ]]; then
        echo "${BASH_SOURCE[0]%/*}/providers.conf"
    else
        echo "$HOME/.mcm/providers.conf"
    fi
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
UNDERLINE='\033[4m'

_mcm_err() { echo -e "${RED}Error:${RESET} $*" >&2; }
_mcm_ok() { echo -e "${GREEN}✓${RESET} $*"; }
_mcm_warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
_mcm_info() { echo -e "${CYAN}ℹ${RESET} $*"; }

_mcm_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$MCM_LOG" 2>/dev/null || true; }

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

_mcm_list_providers() {
    local filter="${1:-all}"
    local found=0
    
    while IFS='|' read -r id name models base_url api_key_var api_link; do
        [[ -z "$id" || "$id" =~ ^# ]] && continue
        [[ -z "$base_url" ]] && continue
        [[ "$filter" != "all" && "$id" != "$filter" ]] && continue
        echo "$id|$name|$models|$base_url|$api_key_var|$api_link"
        found=1
    done < "$(_get_providers_file)"
    
    return $found
}

_mcm_get_provider_info() {
    local id="$1"
    local field="$2"
    _mcm_list_providers | while IFS='|' read -r i n m b a l; do
        [[ "$i" == "$id" ]] || continue
        case "$field" in
            name) echo "$n" ;;
            models) echo "$m" ;;
            base_url) echo "$b" ;;
            api_key_var) echo "$a" ;;
            api_link) echo "$l" ;;
        esac
        break
    done
}

_mcm_get_env_vars() {
    local id="$1"
    while IFS='|' read -r i n v; do
        [[ -z "$i" || "$i" =~ ^# ]] && continue
        [[ "$i" == "${id}|"* ]] && echo "${i##*|}|${v}"
    done < "$(_get_providers_file)"
}

install() {
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
    echo -e "${DIM}Without it, your API keys cannot be recovered.${RESET}"
    echo
    echo -e "Run ${CYAN}mcm add <provider>${RESET} to add a provider."
    echo
    echo -e "${DIM}Restart shell or run:${RESET}"
    echo -e "  ${BOLD}source $shell_rc${RESET}"
}

add_provider() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        _mcm_err "Usage: mcm add <provider-id>"
        echo
        echo "Available providers:"
        list_providers
        exit 1
    fi
    
    local info=$(_mcm_list_providers "$id")
    if [[ -z "$info" ]]; then
        _mcm_err "Unknown provider: $id"
        exit 1
    fi
    
    local name=$(echo "$info" | cut -d'|' -f2)
    local api_link=$(echo "$info" | cut -d'|' -f6)
    
    echo
    echo -e "${BOLD}Adding ${CYAN}$name${RESET}"
    echo -e "  ${CYAN}→ Docs:${RESET} ${UNDERLINE}$api_link${RESET}"
    echo
    
    if [[ -x "$BROWSER" || -f /usr/bin/open || -f /usr/bin/xdg-open ]]; then
        read -p "Press Enter when ready, or 's' to skip: " c
        [[ "$c" == "s" || "$c" == "S" ]] && exit 0
    fi
    
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

list_providers() {
    local keys=$(_mcm_load_keys)
    local current=$(_mcm_get_current)
    local idx=0
    
    echo
    echo -e "${BOLD}Providers:${RESET}"
    echo
    
    while IFS='|' read -r id name models base_url api_key_var api_link; do
        [[ -z "$id" || "$id" =~ ^# ]] && continue
        [[ -z "$base_url" ]] && continue
        
        idx=$((idx + 1))
        local has_key=$(echo "$keys" | grep -q "\"$id\"" && echo "yes" || echo "no")
        local marker=" "
        local key_icon="○"
        
        [[ "$id" == "$current" ]] && marker="${CYAN}→${RESET}" && key_icon="🔑"
        [[ "$has_key" == "yes" ]] && key_icon="${GREEN}🔑${RESET}"
        
        echo -e "  ${MAGENTA}$id${RESET}  $name"
        echo -e "       ${DIM}$models${RESET} $key_icon"
        echo
    done < "$(_get_providers_file)"
    
    [[ "$current" != "none" ]] && echo -e "${DIM}→ = active ($current)${RESET}"
}

use_provider() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        _mcm_err "Usage: mcm use <provider-id>"
        exit 1
    fi
    
    local info=$(_mcm_list_providers "$id")
    [[ -z "$info" ]] && _mcm_err "Unknown provider: $id" && exit 1
    
    local keys=$(_mcm_load_keys)
    [[ ! "$keys" =~ "\"$id\"" ]] && _mcm_err "$id not configured. Run 'mcm add $id'" && exit 1
    
    _mcm_set_current "$id"
    _mcm_ok "Now using: $id"
    _mcm_log "Switched to: $id"
    echo
    echo -e "${DIM}Run ${CYAN}cc${RESET}${DIM} to launch Claude Code with $id${RESET}"
}

remove_provider() {
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

doctor() {
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
    
    command -v claude >/dev/null 2>&1 && _mcm_ok "Claude Code CLI installed" || _mcm_warn "Claude Code CLI not found"
    
    echo
    [[ $issues -eq 0 ]] && _mcm_ok "All checks passed!" || _mcm_warn "$issues issue(s)"
}

show_help() {
    cat << EOF

${CYAN}    ╔═══════════════════════════════════════════════╗
    ║  ${BOLD}MCM${RESET}${CYAN}  -  Multi-Provider Claude Code Manager  ║
    ║  ${DIM}Version $VERSION${RESET}${CYAN}                                  ║
    ╚═══════════════════════════════════════════════╝${RESET}

${BOLD}USAGE:${RESET}
    mcm <command> [options]

${BOLD}COMMANDS:${RESET}
    ${CYAN}install${RESET}             Install MCM and generate encryption key
    ${CYAN}add <id>${RESET}           Add API key for a provider
    ${CYAN}list${RESET}                List all providers
    ${CYAN}use <id>${RESET}            Set active provider
    ${CYAN}rm <id>${RESET}             Remove provider
    ${CYAN}doctor${RESET}              Run diagnostics
    ${CYAN}help${RESET}                Show this help

${BOLD}EXAMPLES:${RESET}
    mcm install              Install MCM
    mcm add kimi             Add Kimi
    mcm list                 Show providers
    mcm use kimi             Switch to Kimi
    cc                       Launch Claude Code

EOF
}

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        install|i) install ;;
        add|a) add_provider "$@" ;;
        list|ls|l) list_providers ;;
        use|switch|u) use_provider "$@" ;;
        rm|remove) remove_provider "$@" ;;
        doctor) doctor ;;
        help|h|--help) show_help ;;
        version|v) echo "MCM version $VERSION" ;;
        *) _mcm_err "Unknown: $cmd"; echo "Run 'mcm help'"; exit 1 ;;
    esac
}

main "$@"
