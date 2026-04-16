#!/usr/bin/env zsh

# MCM Zsh Completions

_mcm_providers() {
    local providers_file="${MCM_PROVIDERS:-$HOME/.mcm/providers.conf}"
    [[ -f "$providers_file" ]] && grep "^[^#].*|" "$providers_file" | cut -d'|' -f1 | grep -v '_' | sort -u
}

_mcm() {
    local -a commands
    commands=(
        'install:Install MCM and generate encryption key'
        'add:Add API key for a provider'
        'list:List all providers'
        'use:Switch to a provider'
        'rm:Remove a provider'
        'doctor:Run diagnostics'
        'help:Show help'
    )
    
    _describe 'command' commands
}

compdef _mcm mcm
