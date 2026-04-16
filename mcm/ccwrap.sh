#!/usr/bin/env bash

export MCM_DIR="${MCM_DIR:-$HOME/.mcm}"
export MCM_KEYS="$MCM_DIR/.keys.enc"
export MCM_CONFIG="$MCM_DIR/config.sh"
export MCM_CACHE="$MCM_DIR/providers.cache"

_cc_err() { echo -e "\033[0;31mError:\033[0m $*"; }

_cc_load_provider() {
    local id="$1"
    
    local key_file="$MCM_DIR/.key"
    local providers_file="$MCM_DIR/providers.conf"
    
    [[ ! -f "$key_file" || ! -f "$MCM_KEYS" ]] && { _cc_err "MCM not configured"; return 1; }
    
    local key=$(cat "$key_file")
    local keys=$(openssl enc -aes-256-cbc -A -a -d -pbkdf2 -pass "pass:$key" -in "$MCM_KEYS" 2>/dev/null)
    local api_key=$(echo "$keys" | grep -o "\"$id\": *\"[^\"]*\"" | sed 's/.*"\([^"]*\)"$/\1/')
    
    [[ -z "$api_key" ]] && { _cc_err "Provider '$id' not configured. Run 'mcm add $id'"; return 1; }
    
    local base_url=""
    local env_vars="{}"
    
    if [[ -f "$providers_file" ]]; then
        base_url=$(grep "^$id|" "$providers_file" 2>/dev/null | head -1 | cut -d'|' -f4)
        env_vars=$(grep "^$id|" "$providers_file" 2>/dev/null | grep '^{' | cut -d'|' -f7)
    fi
    
    if [[ -z "$base_url" && -f "$MCM_CACHE" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            base_url=$(python3 - "$id" < "$MCM_CACHE" << 'PYEOF'
import json, sys
pid = sys.argv[1]
data = json.load(sys.stdin)
for p in data.get("providers", []):
    if p.get("id") == pid:
        print(p.get("base_url", ""))
        break
PYEOF
)
            env_vars=$(python3 - "$id" < "$MCM_CACHE" << 'PYEOF'
import json, sys
pid = sys.argv[1]
data = json.load(sys.stdin)
for p in data.get("providers", []):
    if p.get("id") == pid:
        print(json.dumps(p.get("env_vars", {})))
        break
PYEOF
)
        fi
    fi
    
    [[ -z "$base_url" ]] && { _cc_err "Provider '$id' not found in registry"; return 1; }
    
    unset ANTHROPIC_API_KEY
    export ANTHROPIC_BASE_URL="$base_url"
    export ANTHROPIC_AUTH_TOKEN="$api_key"
    
    if [[ -n "$env_vars" && "$env_vars" != "{}" ]]; then
        echo "$env_vars" | python3 -c "import json,sys; [print(f'export {k}=\"{v}\"') for k,v in json.load(sys.stdin).items()]" 2>/dev/null | while read -r line; do
            eval "$line" 2>/dev/null || true
        done
    fi
    
    return 0
}

cc() {
    local provider=""
    local args=()
    
    [[ $# -gt 0 && "$1" != --* ]] && { provider="$1"; shift; }
    args=("$@")
    
    [[ -z "$provider" ]] && provider=$(grep "^MCM_CURRENT=" "$MCM_CONFIG" 2>/dev/null | cut -d'"' -f2)
    [[ -z "$provider" || "$provider" == "none" ]] && { command claude "${args[@]}"; return $?; }
    
    _cc_load_provider "$provider" && command claude "${args[@]}"
}
