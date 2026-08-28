#!/bin/bash -l
# Manpreet 28/08/2026
# Keep standalone Codex MCP processes stopped until their one-shot gate is armed.

codexMcpGate() {
    local name="${1}" kit_root flag win
    kit_root="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
    flag="${kit_root}/generated/mcp-on/${name}"
    win="${flag}.win"
    mkdir -p "${kit_root}/generated/mcp-on"
    if [ -f "${flag}" ]; then
        rm -f "${flag}"
        : > "${win}"
    elif [ -z "$(find "${win}" -newermt '-60 seconds' 2>/dev/null)" ]; then
        echo "${name} MCP gated off - arm it before starting Codex: touch ${flag}" >&2
        exit 1
    fi
}

codexMcpGateArmed() {
    local name="${1}" kit_root flag
    kit_root="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
    flag="${kit_root}/generated/mcp-on/${name}"
    [ -f "${flag}" ]
}

codexMcpConfigured() {
    local name="${1}" config
    config="${CODEX_HOME:-${HOME}/.codex}/config.toml"
    [ -f "${config}" ] && grep -qFx "[mcp_servers.${name}]" "${config}"
}

setCodexMcpEnabled() {
    local name="${1}" enabled="${2}" config section mode temporary
    config="${CODEX_HOME:-${HOME}/.codex}/config.toml"
    section="[mcp_servers.${name}]"
    case "${enabled}" in true|false) ;; *) return 1 ;; esac
    [ -f "${config}" ] && grep -qFx "${section}" "${config}" || return 1
    mode="$(stat -c '%a' "${config}")"
    temporary="$(mktemp "${config}.tmp.XXXXXX")"
    if ! awk -v section="${section}" -v enabled="${enabled}" '
        BEGIN { active = 0; written = 0 }
        /^\[[^]]+\]$/ {
            if (active && !written) {
                print "enabled = " enabled
                written = 1
            }
            active = ($0 == section)
        }
        active && /^[[:space:]]*enabled[[:space:]]*=/ {
            print "enabled = " enabled
            written = 1
            next
        }
        { print }
        END {
            if (active && !written) {
                print "enabled = " enabled
            }
        }
    ' "${config}" > "${temporary}"; then
        rm -f "${temporary}"
        return 1
    fi
    chmod "${mode}" "${temporary}"
    mv "${temporary}" "${config}"
}
