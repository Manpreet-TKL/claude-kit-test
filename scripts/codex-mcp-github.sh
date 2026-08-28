#!/bin/bash -l
set -e
script_dir="$(dirname "$(realpath "$0")")"
. "${script_dir}/codex-mcp-gate.sh"
codexMcpGate github
secrets="${HOME}/.claude/mcp-env/.github.env"
[ -f "${secrets}" ] || { echo "Missing ${secrets}" >&2; exit 1; }
set -a
. "${secrets}"
set +a
export GITHUB_READ_ONLY=1
exec docker run -i --rm --name "codex-mcp-github-$$" -e GITHUB_PERSONAL_ACCESS_TOKEN -e GITHUB_TOOLSETS -e GITHUB_READ_ONLY ghcr.io/github/github-mcp-server stdio
