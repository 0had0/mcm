#!/usr/bin/env bash

export MCM_DIR="${MCM_DIR:-$HOME/.mcm}"
export MCM_KEYS="$MCM_DIR/.keys.enc"
export MCM_CONFIG="$MCM_DIR/config.sh"

_cc_providers_file() {
    if [[ -n "$MCM_PROVIDERS" && -f "$MCM_PROVIDERS" ]]; then
        echo "$MCM_PROVIDERS"
    elif [[ -f "$MCM_DIR/providers.conf" ]]; then
        echo "$MCM_DIR/providers.conf"
    elif [[ -f "${CCWRAP_DIR:-/usr/local/bin}/providers.conf" ]]; then
        echo "${CCWRAP_DIR:-/usr/local/bin}/providers.conf"
    else
        echo "$MCM_DIR/providers.conf"
    fi
}

cc() {
    local provider=""
    local args=()
    
    [[ $# -gt 0 && "$1" != --* ]] && { provider="$1"; shift; }
    args=("$@")
    
    [[ -z "$provider" ]] && provider=$(grep "^MCM_CURRENT=" "$MCM_CONFIG" 2>/dev/null | cut -d'"' -f2)
    [[ -z "$provider" || "$provider" == "none" ]] && { command claude "${args[@]}"; return $?; }
    
    local key_file="$MCM_DIR/.key"
    local providers_file=$(_cc_providers_file)
    
    [[ ! -f "$key_file" || ! -f "$MCM_KEYS" ]] && { _cc_err "MCM not configured"; return 1; }
    
    local key=$(cat "$key_file")
    local keys=$(openssl enc -aes-256-cbc -A -a -d -pbkdf2 -pass "pass:$key" -in "$MCM_KEYS" 2>/dev/null)
    local api_key=$(echo "$keys" | grep -o "\"$provider\": *\"[^\"]*\"" | sed 's/.*"\([^"]*\)"$/\1/')
    
    [[ -z "$api_key" ]] && { echo -e "\033[0;31mError:\033[0m Provider '$provider' not configured. Run 'mcm add $provider'"; return 1; }
    
    local base_url=$(grep "^$provider|" "$providers_file" 2>/dev/null | head -1 | cut -d'|' -f4)
    
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="$api_key"
    
    while IFS='|' read -r id var val; do
        [[ "$id" == "$provider|"* ]] && export "${id##*$provider|}"="$val"
    done < "$providers_file" 2>/dev/null
    
    command claude "${args[@]}"
}

_cc_err() { echo -e "\033[0;31mError:\033[0m $*"; }
