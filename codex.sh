#!/bin/bash -l
# Manpreet 10/08/2026
# Run Codex in Docker with its state, skills, kit, and workspace mounted.
set -e
kit_root="$(dirname "$(realpath "$0")")"
workspace="$(pwd -P)"
image="claude-kit-codex"
status_line='tui.status_line=["model-with-reasoning","current-dir","five-hour-limit","weekly-limit"]'
command -v docker >/dev/null 2>&1 || { echo "Docker is required. Run ./install-codex.sh first." >&2; exit 1; }
[ -d "${HOME}/.codex" ] && [ -d "${HOME}/.agents" ] || { echo "Run ./install-codex.sh first." >&2; exit 1; }
docker image inspect "${image}" >/dev/null 2>&1 || { echo "Run ./install-codex.sh first." >&2; exit 1; }
args=(run --rm --user "$(id -u):$(id -g)" -v "${HOME}/.codex:/home/codex/.codex" -v "${HOME}/.agents:/home/codex/.agents:ro")
case "${workspace}/" in
    "${kit_root}/"*) args+=(-v "${kit_root}:${kit_root}" -w "${workspace}") ;;
    *) args+=(-v "${workspace}:${workspace}" -w "${workspace}" -v "${kit_root}:${kit_root}:ro") ;;
esac
[ -t 0 ] && [ -t 1 ] && args+=(-it) || args+=(-i)
exec docker "${args[@]}" "${image}" -c "${status_line}" "$@"
