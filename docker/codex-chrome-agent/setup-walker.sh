#!/bin/bash -l
# Manpreet 22/08/2026
set -e

assume_yes=0
oe_network=""
oe_url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y | --yes) assume_yes=1; shift ;;
        -n | --network) oe_network="$2"; shift 2 ;;
        -u | --url) oe_url="$2"; shift 2 ;;
        -h | --help) echo "Usage: bash $(realpath "$0") [-y] [-n <docker-network>] [-u <oe-url>]"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
kit_root="$(dirname "$(dirname "${script_dir}")")"
config_file="${kit_root}/generated/.codex-chrome-agent.env"
state_dir="${CODEX_CHROME_STATE_DIR:-${HOME}/.claude/codex-chrome-agent}"
. "${kit_root}/scripts/codex-mcp-gate.sh"

command -v docker >/dev/null 2>&1 || { echo "docker not found" >&2; exit 1; }
command -v codex >/dev/null 2>&1 || { echo "codex not found" >&2; exit 1; }
[ -f "${config_file}" ] && . "${config_file}"
oe_network="${oe_network:-${OE_NETWORK:-}}"
oe_url="${oe_url:-${OE_URL:-http://web}}"

if [ "${assume_yes}" != "1" ]; then
    read -r -p "OE deployment Docker network [${oe_network}]: " answer
    oe_network="${answer:-${oe_network}}"
fi
[ -n "${oe_network}" ] || { echo "A Docker network is required" >&2; exit 1; }

mkdir -p "${kit_root}/generated" "${state_dir}" "${script_dir}/artifacts"
chmod 700 "${state_dir}"
{
    echo "OE_NETWORK=${oe_network}"
    echo "OE_URL=${oe_url}"
} > "${config_file}"
chmod 600 "${config_file}"

export UID GID OE_NETWORK="${oe_network}" OE_URL="${oe_url}" CODEX_CHROME_STATE_DIR="${state_dir}"
docker compose -f "${script_dir}/docker-compose.yml" up -d --build
codex mcp remove chrome-devtools >/dev/null 2>&1 || true
codex mcp remove playwright >/dev/null 2>&1 || true
codex mcp add chrome-devtools -- bash "${script_dir}/mcp-chrome-devtools.sh" >/dev/null
setCodexMcpEnabled chrome-devtools false
codex mcp add playwright -- bash "${script_dir}/mcp-playwright.sh" >/dev/null
setCodexMcpEnabled playwright false
rm -f "${kit_root}/generated/mcp-on/chrome-devtools" "${kit_root}/generated/mcp-on/chrome-devtools.win"
rm -f "${kit_root}/generated/mcp-on/playwright" "${kit_root}/generated/mcp-on/playwright.win"

echo "Codex Chrome walker is ready. MCPs are disabled by default. noVNC: http://localhost:6081"
echo "Arm them before a new Codex session: touch ${kit_root}/generated/mcp-on/chrome-devtools ${kit_root}/generated/mcp-on/playwright"
