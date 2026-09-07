#!/bin/bash -l
# Manpreet 10/08/2026
# Run the existing host Codex with claude-kit defaults and permission profile.
set -e
kit_root="$(dirname "$(realpath "$0")")"
codex_bin="$(command -v codex || true)"
[ -n "${codex_bin}" ] || { echo "Host Codex is required. Install it outside claude-kit, then run: bash ${kit_root}/codex-install.sh -q" >&2; exit 1; }
[ -f "${HOME}/.codex/claude-kit.config.toml" ] || { echo "Run: bash ${kit_root}/codex-install.sh -q" >&2; exit 1; }

# Agent defaults written by codex-install.sh (and shared with install.sh -x).
if [ -f "${kit_root}/generated/.codex.env" ]; then
    # shellcheck source=/dev/null
    . "${kit_root}/generated/.codex.env"
fi
# shellcheck source=/dev/null
. "${kit_root}/scripts/codex-mcp-gate.sh"
permission="${CODEX_PERMISSION_TIER:-standard}"
approval="on-request"
reviewer="user"
mcp_args=()
for mcp_name in atlassian github chrome-devtools playwright; do
    if codexMcpConfigured "${mcp_name}"; then
        mcp_enabled=false
        codexMcpGateArmed "${mcp_name}" && mcp_enabled=true
        mcp_args+=("-c" "mcp_servers.${mcp_name}.enabled=${mcp_enabled}")
    fi
done
if [ "${permission}" = "yolo" ]; then
    permission=":danger-full-access"
fi
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    export CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1
fi

case "${CODEX_MODE:-auto}" in
    default) approval="untrusted" ;;
    plan) permission=":read-only" ;;
    acceptEdits) approval="on-request" ;;
    auto) approval="on-request"; reviewer="auto_review" ;;
    dontAsk) approval="never" ;;
    bypassPermissions)
        exec "${codex_bin}" --profile claude-kit "${mcp_args[@]}" \
            -c "model=\"${CODEX_MODEL:-gpt-5.6-sol}\"" \
            -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT:-xhigh}\"" \
            -c 'plan_mode_reasoning_effort="max"' \
            --dangerously-bypass-approvals-and-sandbox "$@"
        ;;
    *) echo "Unknown CODEX_MODE '${CODEX_MODE}'" >&2; exit 1 ;;
esac

exec "${codex_bin}" --profile claude-kit "${mcp_args[@]}" \
    -c "model=\"${CODEX_MODEL:-gpt-5.6-sol}\"" \
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT:-xhigh}\"" \
    -c 'plan_mode_reasoning_effort="max"' \
    -c "default_permissions=\"${permission}\"" \
    -c "approval_policy=\"${approval}\"" \
    -c "approvals_reviewer=\"${reviewer}\"" "$@"
