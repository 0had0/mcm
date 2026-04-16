#!/usr/bin/env bash

# MCM Shell Completions

_mcm_providers() {
    local providers_file="${MCM_PROVIDERS:-$HOME/.mcm/providers.conf}"
    [[ -f "$providers_file" ]] && grep "^[^#].*|" "$providers_file" | cut -d'|' -f1 | grep -v '_' | sort -u
}

_mcm() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    local commands="install add list use rm remove doctor help version"
    
    case "${prev}" in
        mcm)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return 0
            ;;
        add|a|use|switch|u|rm|remove)
            COMPREPLY=($(compgen -W "$(_mcm_providers)" -- "${cur}"))
            return 0
            ;;
    esac
    
    return 0
}

complete -F _mcm mcm
