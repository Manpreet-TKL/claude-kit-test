#!/bin/bash -l
# Manpreet 22/08/2026
set -e
script_dir="$(dirname "$(realpath "$0")")"
. "${script_dir}/../../scripts/codex-mcp-gate.sh"
codexMcpGate playwright
exec docker exec -i codex-chrome playwright-mcp --cdp-endpoint http://127.0.0.1:9222
