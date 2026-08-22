#!/bin/bash -l
# Manpreet 10/08/2026
# Run Codex in Docker with its state, skills, kit, and workspace mounted.
set -e
kit_root="$(dirname "$(realpath "$0")")"
workspace="$(pwd -P)"
image="claude-kit-codex"
status_line='tui.status_line=["model-with-reasoning","current-dir","five-hour-limit","weekly-limit"]'
command -v docker >/dev/null 2>&1 || { echo "Docker is required. Run 'bash ${kit_root}/codex-install.sh -q' first." >&2; exit 1; }
[ -d "${HOME}/.codex" ] && [ -d "${HOME}/.agents" ] || { echo "Run 'bash ${kit_root}/codex-install.sh -q' first." >&2; exit 1; }
docker image inspect "${image}" >/dev/null 2>&1 || { echo "Run 'bash ${kit_root}/codex-install.sh -q' first." >&2; exit 1; }

# Agent defaults written by codex-install.sh (and shared with install.sh -x).
if [ -f "${kit_root}/generated/.codex.env" ]; then
    # shellcheck source=/dev/null
    . "${kit_root}/generated/.codex.env"
fi
# The CONTAINER is the sandbox here - codex's own bwrap sandbox cannot start
# inside Docker, so the inner mode is pinned off. Writes are confined to the
# mounted workspace and the container carries no git credentials, so a push
# fails auth. CODEX_SANDBOX only applies to a host run.
cfg=(-c "${status_line}"
     -c "model=\"${CODEX_MODEL:-gpt-5.6-sol}\""
     -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT:-xhigh}\""
     -c 'sandbox_mode="danger-full-access"'
     -c "approval_policy=\"${CODEX_APPROVAL:-on-request}\"")

args=(run --rm --user "$(id -u):$(id -g)" -v "${HOME}/.codex:/home/codex/.codex" -v "${HOME}/.agents:/home/codex/.agents:ro")
case "${workspace}/" in
    "${kit_root}/"*) args+=(-v "${kit_root}:${kit_root}" -w "${workspace}") ;;
    *) args+=(-v "${workspace}:${workspace}" -w "${workspace}" -v "${kit_root}:${kit_root}:ro") ;;
esac
[ -t 0 ] && [ -t 1 ] && args+=(-it) || args+=(-i)
exec docker "${args[@]}" "${image}" "${cfg[@]}" "$@"
