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
permission="${CODEX_PERMISSION_TIER:-standard}"
approval="on-request"
reviewer="user"
case "${CODEX_MODE:-auto}" in
    default) approval="untrusted" ;;
    plan) permission=":read-only" ;;
    acceptEdits) approval="on-request" ;;
    auto) approval="on-request"; reviewer="auto_review" ;;
    dontAsk) approval="never" ;;
    bypassPermissions)
        exec "${codex_bin}" --profile claude-kit --dangerously-bypass-approvals-and-sandbox "$@"
        ;;
    *) echo "Unknown CODEX_MODE '${CODEX_MODE}'" >&2; exit 1 ;;
esac

if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    export CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1
fi

exec "${codex_bin}" --profile claude-kit \
    -c "model=\"${CODEX_MODEL:-gpt-5.6-sol}\"" \
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT:-xhigh}\"" \
    -c "default_permissions=\"${permission}\"" \
    -c "approval_policy=\"${approval}\"" \
    -c "approvals_reviewer=\"${reviewer}\"" "$@"
