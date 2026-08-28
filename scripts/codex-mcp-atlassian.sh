#!/bin/bash -l
set -e
script_dir="$(dirname "$(realpath "$0")")"
. "${script_dir}/codex-mcp-gate.sh"
codexMcpGate atlassian
secrets="${HOME}/.claude/mcp-env/.atlassian.env"
[ -f "${secrets}" ] || { echo "Missing ${secrets}" >&2; exit 1; }
set -a
. "${secrets}"
set +a
exec docker run -i --rm --name "codex-mcp-atlassian-$$" \
    -e JIRA_URL -e JIRA_USERNAME -e JIRA_API_TOKEN -e JIRA_PROJECTS_FILTER \
    -e CONFLUENCE_URL -e CONFLUENCE_USERNAME -e CONFLUENCE_API_TOKEN -e CONFLUENCE_SPACES_FILTER \
    ghcr.io/sooperset/mcp-atlassian:latest
