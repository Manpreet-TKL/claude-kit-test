#!/bin/bash -l
# Manpreet 22/08/2026
# Install and configure host Codex with claude-kit parity and native controls.

abort() {
    echo >&2 '
****************************
*** ABORTED DUE TO ERROR ***
****************************
'
    date
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0
set -e

ASSUME_YES=0
DO_VERIFY=1
DO_UPDATE=1
DO_RESET=0
DO_FRESH=0
QUICK=0
PERMISSION_TIER=""
SESSION_MODE=""
AGENT_THREADS=""
SKILLS_AUTO=""
PRUNE_BEFORE=""
LOGOUT_TARGET=""
JIRA_MODE=""
CONFLUENCE_MODE=""
ATLASSIAN_REMOVE=0
GITHUB_MODE=""
GITHUB_REMOVE=0
AWS_MODE=""
AWS_REMOVE=0
WALKER_SETUP=0
CODEX_FLAG=""
CODEX_WAS_INSTALLED=0

usage() {
    cat <<'USAGE'
Usage: codex-install.sh [-q] [-p <ultra-safe|standard|trusted|yolo>]
                        [-m <default|plan|acceptEdits|auto|dontAsk|bypassPermissions>]
                        [-t <positive integer>] [-s <on|off>] [-d <days|YYYY-MM-DD>]
                        [-r] [-F] [-n] [-U] [-y] [-j] [-c] [-J] [-g | -G]
                        [-x | -X] [-a | -A] [-w] [-l <codex|github|atlassian|aws|all>]

Standalone host Codex twin of install.sh. Short flags bundle; value-taking flags
must be last. Run with no flags to see this help, or use -q for saved/defaults.

  -q, --quick              Non-interactive defaults; yolo unless -p is given.
  -p, --permissions        Codex permission tier: ultra-safe|standard|trusted|yolo.
  -m, --mode               Session mode: default|plan|acceptEdits|auto|dontAsk|bypassPermissions.
  -t, --agent-threads      Maximum concurrent native subagents per session.
  -s, --skills-auto        on|off; shared skill implicit-invocation switch.
  -d, --prune-sessions     Archive Codex sessions older than days or YYYY-MM-DD.
  -r, --reset              Archive regenerable state; preserve auth, sessions and memories.
  -F, --fresh              Back up, recreate and restore auth, config, sessions and memories.
  -j, --with-jira          Register the containerized Atlassian MCP using saved credentials.
  -c, --with-confluence    Register the same MCP with saved Confluence credentials.
  -J, --without-atlassian  Remove the Codex Atlassian MCP registration.
  -g, --with-github        Register the read-only containerized GitHub MCP.
  -G, --without-github     Remove the Codex GitHub MCP registration.
  -a, --with-aws           Start the shared read-only AWS CLI container and
                           pre-arm one agent session. Its first read consumes
                           the gate, so new sessions are gated again. Not an
                           MCP - Codex reads AWS with
                           scripts/agent-aws-cli.sh run <args>, the same script
                           and container Claude Code uses.
  -A, --without-aws        Stop the AWS CLI container and clear its gate.
  -x, --with-codex         Accepted no-op: this installer already configures Codex.
  -X, --without-codex      Accepted no-op: standalone Codex wiring remains installed.
  -w, --setup-walker       Build and register the dual-driver Codex Chrome walker.
  -l, --logout             Clear codex|github|atlassian|aws|all credentials and exit.
  -n, --no-verify          Skip post-install checks.
  -U, --no-update          Skip codex update.
  -y, --yes                Use saved/default answers and skip destructive confirmation.
  -h, --help               Show this help.
USAGE
}

requireValue() {
    if [ $# -lt 2 ] || [ -z "${2}" ]; then
        echo "codex-install.sh: ${1} requires a value" >&2
        trap : 0
        exit 1
    fi
}

installCodex() {
    local install_dir installer
    command -v curl >/dev/null 2>&1 || { echo "curl is required to install Codex" >&2; return 1; }
    echo "Downloading the official Codex installer..."
    install_dir="$(mktemp -d)"
    installer="${install_dir}/install.sh"
    if ! curl -fsSL https://chatgpt.com/codex/install.sh -o "${installer}"; then
        rm -f "${installer}"
        rmdir "${install_dir}"
        return 1
    fi
    if ! CODEX_NON_INTERACTIVE=1 sh "${installer}"; then
        rm -f "${installer}"
        rmdir "${install_dir}"
        return 1
    fi
    rm -f "${installer}"
    rmdir "${install_dir}"
    export PATH="${HOME}/.local/bin:${PATH}"
    hash -r
    command -v codex >/dev/null 2>&1 || { echo "Codex was installed but is not on PATH" >&2; return 1; }
    CODEX_WAS_INSTALLED=1
}

if [ $# -eq 0 ]; then
    usage >&2
    trap : 0
    exit 1
fi

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -[!-]?*)
        rest="${p#-}"
        exploded=()
        for ((i = 0; i < ${#rest}; i++)); do exploded+=("-${rest:i:1}"); done
        set -- "${exploded[@]}" "${@:2}"
        continue
        ;;
    -q | --quick) QUICK=1 ;;
    -p | --permissions) requireValue "$@"; PERMISSION_TIER="$2"; shift ;;
    -m | --mode) requireValue "$@"; SESSION_MODE="$2"; shift ;;
    -t | --agent-threads) requireValue "$@"; AGENT_THREADS="$2"; shift ;;
    -s | --skills-auto) requireValue "$@"; SKILLS_AUTO="$2"; shift ;;
    -d | --prune-sessions) requireValue "$@"; PRUNE_BEFORE="$2"; shift ;;
    -r | --reset) DO_RESET=1 ;;
    -F | --fresh) DO_FRESH=1 ;;
    -n | --no-verify) DO_VERIFY=0 ;;
    -U | --no-update) DO_UPDATE=0 ;;
    -y | --yes) ASSUME_YES=1 ;;
    -j | --with-jira) JIRA_MODE="on" ;;
    -c | --with-confluence) CONFLUENCE_MODE="on" ;;
    -J | --without-atlassian) ATLASSIAN_REMOVE=1 ;;
    -g | --with-github) GITHUB_MODE="on" ;;
    -G | --without-github) GITHUB_REMOVE=1 ;;
    -x | --with-codex) CODEX_FLAG="on" ;;
    -X | --without-codex) CODEX_FLAG="off" ;;
    -a | --with-aws) AWS_MODE="on" ;;
    -A | --without-aws) AWS_REMOVE=1 ;;
    -w | --setup-walker) WALKER_SETUP=1 ;;
    -l | --logout) requireValue "$@"; LOGOUT_TARGET="$2"; shift ;;
    -h | --help) usage; trap : 0; exit 0 ;;
    *) echo "Invalid Parameter '${p}' ... exiting" >&2; trap : 0; exit 1 ;;
    esac
    shift
done

[ "${QUICK}" == "1" ] && ASSUME_YES=1
[ "${QUICK}" == "1" ] && [ -z "${PERMISSION_TIER}" ] && PERMISSION_TIER="yolo"

kit_root="$(dirname "$(realpath "$0")")"
generated_dir="${kit_root}/generated"
skills_src_dir="${kit_root}/skills"
skills_auto_state="${generated_dir}/skills-auto.state"
codex_env="${generated_dir}/.codex.env"
codex_home="${HOME}/.codex"
codex_auth="${codex_home}/auth.json"
codex_agents_md="${codex_home}/AGENTS.md"
codex_agents_dir="${codex_home}/agents"
codex_planner_agent="${codex_agents_dir}/claude-kit-planner.toml"
codex_profile="${codex_home}/claude-kit.config.toml"
codex_rules="${codex_home}/rules/claude-kit.rules"
agents_home="${HOME}/.agents"
agents_skills_dir="${agents_home}/skills"
agents_manifest="${agents_home}/.claude-kit-skills"
codex_skills_dir="${codex_home}/skills"
codex_skills_manifest="${codex_home}/.claude-kit-skills"
claude_md_src="${kit_root}/claude-md/CLAUDE.md"
planner_agent_src="${kit_root}/settings/codex/agents/planner.toml"
backup_root="${HOME}/.claude-backups"
mcp_env_dir="${HOME}/.claude/mcp-env"
atlassian_secrets="${mcp_env_dir}/.atlassian.env"
github_secrets="${mcp_env_dir}/.github.env"
aws_secrets="${mcp_env_dir}/.aws.env"

. "${kit_root}/lib/skills.sh"
. "${kit_root}/scripts/codex-mcp-gate.sh"

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"
if ! command -v codex >/dev/null 2>&1; then
    echo "Codex was not found - installing it with the official standalone installer..."
    installCodex
fi
[ -f "${claude_md_src}" ] || { echo "Missing ${claude_md_src} ... exiting" >&2; exit 1; }
case "${PERMISSION_TIER:-standard}" in ultra-safe|standard|trusted|yolo) ;; *) echo "Invalid permissions tier ... exiting" >&2; exit 1 ;; esac
case "${SESSION_MODE:-auto}" in default|plan|acceptEdits|auto|dontAsk|bypassPermissions) ;; *) echo "Invalid session mode ... exiting" >&2; exit 1 ;; esac
case "${AGENT_THREADS}" in ''|*[!0-9]*|0) [ -z "${AGENT_THREADS}" ] || { echo "Invalid agent thread limit ... exiting" >&2; exit 1; } ;; esac
case "${SKILLS_AUTO}" in ''|on|off) ;; *) echo "Invalid skills-auto value ... exiting" >&2; exit 1 ;; esac
case "${LOGOUT_TARGET}" in ''|codex|github|atlassian|aws|all) ;; *) echo "Invalid logout target ... exiting" >&2; exit 1 ;; esac
mkdir -p "${generated_dir}" "${codex_home}/rules" "${codex_agents_dir}" "${agents_skills_dir}" "${codex_skills_dir}" "${backup_root}" "${mcp_env_dir}"
chmod 700 "${codex_home}" "${agents_home}" "${mcp_env_dir}"
echo "$(codex --version) [OK]"
echo "Checks complete ..."
echo "-------------------------------"

clearMcpGate() {
    local name="${1}"
    rm -f "${generated_dir}/mcp-on/${name}" "${generated_dir}/mcp-on/${name}.win"
    rm -f "${generated_dir}"/mcp-on/"${name}".session.* 2>/dev/null || true
}

logoutTarget() {
    local target="$1"
    case "${target}" in
        codex) codex logout >/dev/null 2>&1 || true ;;
        github) rm -f "${github_secrets}"; clearMcpGate github; codex mcp remove github >/dev/null 2>&1 || true ;;
        atlassian) rm -f "${atlassian_secrets}"; clearMcpGate atlassian; codex mcp remove atlassian >/dev/null 2>&1 || true ;;
        aws) rm -f "${aws_secrets}"; clearMcpGate aws; bash "${kit_root}/scripts/agent-aws-cli.sh" down >/dev/null 2>&1 || true; codex mcp remove aws >/dev/null 2>&1 || true ;;
        all) logoutTarget github; logoutTarget atlassian; logoutTarget aws; codex logout >/dev/null 2>&1 || true ;;
    esac
}

backupMemories() {
    local archive="$1" file name
    mkdir -p "${archive}/memory"
    [ -d "${codex_home}/memories" ] && cp -a "${codex_home}/memories" "${archive}/memory/"
    for file in "${codex_home}"/memories_*.sqlite; do
        [ -f "${file}" ] || continue
        name="$(basename "${file}")"
        if command -v sqlite3 >/dev/null 2>&1; then
            sqlite3 "${file}" ".backup '${archive}/memory/${name}'"
        else
            cp -a "${file}" "${archive}/memory/${name}"
            [ -f "${file}-wal" ] && cp -a "${file}-wal" "${archive}/memory/${name}-wal"
            [ -f "${file}-shm" ] && cp -a "${file}-shm" "${archive}/memory/${name}-shm"
        fi
    done
}

restoreMemories() {
    local archive="$1" item
    [ -d "${archive}/memory" ] || return 0
    [ -d "${archive}/memory/memories" ] && cp -a "${archive}/memory/memories" "${codex_home}/"
    for item in "${archive}/memory"/memories_*.sqlite*; do
        [ -f "${item}" ] && cp -a "${item}" "${codex_home}/"
    done
}

resetBloat() {
    local stamp archive item moved=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    archive="${backup_root}/${stamp}-codex"
    mkdir -p "${archive}"
    for item in cache log shell_snapshots tmp thread-writer-locks plugins models_cache.json; do
        [ -e "${codex_home}/${item}" ] || continue
        mv "${codex_home}/${item}" "${archive}/"
        moved=$((moved+1))
    done
    [ "${moved}" -eq 0 ] && rmdir "${archive}" 2>/dev/null || true
    echo "  memories, auth, config, history and sessions were preserved"
}

freshInstall() {
    local stamp archive item
    stamp="$(date +%Y%m%d-%H%M%S)"
    archive="${backup_root}/${stamp}-codex-fresh"
    if [ "${ASSUME_YES}" != "1" ]; then
        read -r -p "Type 'fresh' to back up and recreate ~/.codex and ~/.agents: " answer
        [ "${answer}" == "fresh" ] || { echo "Not confirmed ... exiting" >&2; exit 1; }
    fi
    mkdir -p "${archive}"
    for item in auth.json config.toml history.jsonl sessions; do
        [ -e "${codex_home}/${item}" ] && cp -a "${codex_home}/${item}" "${archive}/"
    done
    backupMemories "${archive}"
    rm -rf "${codex_home}" "${agents_home}"
    mkdir -p "${codex_home}/rules" "${codex_agents_dir}" "${agents_skills_dir}" "${codex_skills_dir}"
    for item in auth.json config.toml history.jsonl sessions; do
        [ -e "${archive}/${item}" ] && cp -a "${archive}/${item}" "${codex_home}/"
    done
    restoreMemories "${archive}"
    echo "  restored state; backup retained at ${archive}"
}

writeCodexEnv() {
    local model effort tier mode threads
    [ -f "${codex_env}" ] && . "${codex_env}"
    model="${CODEX_MODEL:-gpt-6-astra}"
    effort="${CODEX_REASONING_EFFORT:-xhigh}"
    tier="${PERMISSION_TIER:-${CODEX_PERMISSION_TIER:-standard}}"
    mode="${SESSION_MODE:-${CODEX_MODE:-auto}}"
    threads="${AGENT_THREADS:-${CODEX_AGENT_THREADS:-}}"
    case "${threads}" in ''|*[!0-9]*|0) [ -z "${threads}" ] || { echo "CODEX_AGENT_THREADS must be a positive integer" >&2; return 1; } ;; esac
    if [ "${ASSUME_YES}" != "1" ] && [ -t 0 ]; then
        read -r -p "CODEX_MODEL [${model}]: " answer; model="${answer:-${model}}"
        read -r -p "CODEX_REASONING_EFFORT [${effort}]: " answer; effort="${answer:-${effort}}"
        read -r -p "CODEX_AGENT_THREADS (blank = Codex default) [${threads}]: " answer; threads="${answer:-${threads}}"
        case "${threads}" in ''|*[!0-9]*|0) [ -z "${threads}" ] || { echo "CODEX_AGENT_THREADS must be a positive integer" >&2; return 1; } ;; esac
    fi
    {
        echo "CODEX_MODEL=${model}"
        echo "CODEX_REASONING_EFFORT=${effort}"
        echo "CODEX_PERMISSION_TIER=${tier}"
        echo "CODEX_MODE=${mode}"
        echo "CODEX_AGENT_THREADS=${threads}"
    } > "${codex_env}"
    chmod 600 "${codex_env}"
    PERMISSION_TIER="${tier}"
    SESSION_MODE="${mode}"
    CODEX_AGENT_THREADS="${threads}"
    CODEX_MODEL="${model}"
    CODEX_REASONING_EFFORT="${effort}"
}

writeProfile() {
    local file
    {
        echo "model = \"${CODEX_MODEL}\""
        echo "model_reasoning_effort = \"${CODEX_REASONING_EFFORT}\""
        echo 'model_verbosity = "medium"'
        echo 'default_permissions = "standard"'
        echo 'approval_policy = "on-request"'
        echo 'approvals_reviewer = "auto_review"'
        echo 'project_doc_max_bytes = 65536'
        echo 'model_auto_compact_token_limit = 200000'
        echo 'plan_mode_reasoning_effort = "max"'
        echo ''
        if [ -n "${CODEX_AGENT_THREADS}" ]; then
            echo '[agents]'
            echo "max_concurrent_threads_per_session = ${CODEX_AGENT_THREADS}"
            echo ''
        fi
        echo '[features]'
        echo 'memories = true'
        echo 'prevent_idle_sleep = true'
        echo ''
        echo '[memories]'
        echo 'generate_memories = true'
        echo 'use_memories = true'
        echo 'disable_on_external_context = true'
        echo ''
        echo '[tui]'
        echo 'alternate_screen = "never"'
        echo 'raw_output_mode = false'
        echo 'terminal_title = []'
        echo 'status_line = ["model-with-reasoning", "current-dir", "model", "run-state", "permissions", "approval-mode", "context-remaining", "five-hour-limit", "weekly-limit", "codex-version", "context-window-size", "total-output-tokens", "task-progress"]'
        echo 'status_line_use_colors = true'
        for file in "${kit_root}"/settings/codex/permissions/*.toml; do echo ''; sed -n '1,$p' "${file}"; done
    } > "${codex_profile}"
    ln -sfn "${kit_root}/settings/codex/rules/${PERMISSION_TIER}.rules" "${codex_rules}"
}

writeAgentsMd() {
    if [ -e "${codex_agents_md}" ] && [ ! -L "${codex_agents_md}" ]; then cp -p "${codex_agents_md}" "${codex_agents_md}.bak"; fi
    ln -sfn "${claude_md_src}" "${codex_agents_md}"
    ln -sfn "${planner_agent_src}" "${codex_planner_agent}"
}

registerMcp() {
    local name="$1" wrapper="$2"
    command -v docker >/dev/null 2>&1 || { echo "Docker is required for ${name} MCP" >&2; return 1; }
    codex mcp remove "${name}" >/dev/null 2>&1 || true
    codex mcp add "${name}" -- bash "${wrapper}" >/dev/null
    setCodexMcpEnabled "${name}" false
    clearMcpGate "${name}"
    echo "  registered ${name} MCP disabled by default"
}

disableRegisteredMcps() {
    local name
    for name in atlassian github chrome-devtools playwright; do
        if codexMcpConfigured "${name}"; then
            setCodexMcpEnabled "${name}" false
        fi
    done
}

promptValue() {
    local label="$1" default="$2" secret="${3:-0}" answer
    if [ "${secret}" == "1" ]; then
        read -r -s -p "${label}: " answer
        echo ""
    else
        read -r -p "${label} [${default}]: " answer
    fi
    printf '%s' "${answer:-${default}}"
}

configureMcpSecrets() {
    local jira_url="" jira_user="" jira_token="" jira_filter="" confluence_url="" confluence_user="" confluence_token="" confluence_filter=""
    local github_token="" github_toolsets="" aws_key="" aws_secret="" aws_region=""
    [ "${ASSUME_YES}" == "1" ] && return 0
    if [ "${JIRA_MODE}" == "on" ] || [ "${CONFLUENCE_MODE}" == "on" ]; then
        [ -f "${atlassian_secrets}" ] && . "${atlassian_secrets}"
        jira_url="${JIRA_URL:-}"; jira_user="${JIRA_USERNAME:-}"; jira_token="${JIRA_API_TOKEN:-}"; jira_filter="${JIRA_PROJECTS_FILTER:-}"
        confluence_url="${CONFLUENCE_URL:-${jira_url}}"; confluence_user="${CONFLUENCE_USERNAME:-${jira_user}}"; confluence_token="${CONFLUENCE_API_TOKEN:-}"; confluence_filter="${CONFLUENCE_SPACES_FILTER:-}"
        if [ "${JIRA_MODE}" == "on" ]; then
            jira_url="$(promptValue JIRA_URL "${jira_url}")"; jira_user="$(promptValue JIRA_USERNAME "${jira_user}")"; jira_token="$(promptValue JIRA_API_TOKEN "${jira_token}" 1)"; jira_filter="$(promptValue JIRA_PROJECTS_FILTER "${jira_filter}")"
        fi
        if [ "${CONFLUENCE_MODE}" == "on" ]; then
            confluence_url="$(promptValue CONFLUENCE_URL "${confluence_url:-${jira_url}}")"; confluence_user="$(promptValue CONFLUENCE_USERNAME "${confluence_user:-${jira_user}}")"; confluence_token="$(promptValue CONFLUENCE_API_TOKEN "${confluence_token:-${jira_token}}" 1)"; confluence_filter="$(promptValue CONFLUENCE_SPACES_FILTER "${confluence_filter}")"
        fi
        printf 'JIRA_URL=%q\nJIRA_USERNAME=%q\nJIRA_API_TOKEN=%q\nJIRA_PROJECTS_FILTER=%q\nCONFLUENCE_URL=%q\nCONFLUENCE_USERNAME=%q\nCONFLUENCE_API_TOKEN=%q\nCONFLUENCE_SPACES_FILTER=%q\n' "${jira_url}" "${jira_user}" "${jira_token}" "${jira_filter}" "${confluence_url}" "${confluence_user}" "${confluence_token}" "${confluence_filter}" > "${atlassian_secrets}"
        chmod 600 "${atlassian_secrets}"
    fi
    if [ "${GITHUB_MODE}" == "on" ]; then
        [ -f "${github_secrets}" ] && . "${github_secrets}"
        github_token="$(promptValue GITHUB_PERSONAL_ACCESS_TOKEN "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" 1)"; github_toolsets="$(promptValue GITHUB_TOOLSETS "${GITHUB_TOOLSETS:-}")"
        printf 'GITHUB_PERSONAL_ACCESS_TOKEN=%q\nGITHUB_TOOLSETS=%q\n' "${github_token}" "${github_toolsets}" > "${github_secrets}"
        chmod 600 "${github_secrets}"
    fi
    if [ "${AWS_MODE}" == "on" ]; then
        [ -f "${aws_secrets}" ] && . "${aws_secrets}"
        aws_key="$(promptValue AWS_ACCESS_KEY_ID "${AWS_ACCESS_KEY_ID:-}")"; aws_secret="$(promptValue AWS_SECRET_ACCESS_KEY "${AWS_SECRET_ACCESS_KEY:-}" 1)"; aws_region="$(promptValue AWS_REGION "${AWS_REGION:-eu-west-2}")"
        printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\nAWS_REGION=%s\n' "${aws_key}" "${aws_secret}" "${aws_region}" > "${aws_secrets}"
        chmod 600 "${aws_secrets}"
    fi
}

applyMcps() {
    [ "${ATLASSIAN_REMOVE}" == "1" ] && codex mcp remove atlassian >/dev/null 2>&1 || true
    [ "${ATLASSIAN_REMOVE}" == "1" ] && clearMcpGate atlassian
    [ "${GITHUB_REMOVE}" == "1" ] && codex mcp remove github >/dev/null 2>&1 || true
    [ "${GITHUB_REMOVE}" == "1" ] && clearMcpGate github
    [ "${AWS_REMOVE}" == "1" ] && codex mcp remove aws >/dev/null 2>&1 || true
    [ "${AWS_REMOVE}" == "1" ] && bash "${kit_root}/scripts/agent-aws-cli.sh" down || true
    [ "${AWS_REMOVE}" == "1" ] && clearMcpGate aws
    if [ "${JIRA_MODE}" == "on" ] || [ "${CONFLUENCE_MODE}" == "on" ]; then
        [ -f "${atlassian_secrets}" ] || { echo "Create ${atlassian_secrets} with the requested Jira/Confluence values first" >&2; return 1; }
        registerMcp atlassian "${kit_root}/scripts/codex-mcp-atlassian.sh"
    fi
    if [ "${GITHUB_MODE}" == "on" ]; then
        [ -f "${github_secrets}" ] || { echo "Create ${github_secrets} from settings/.github.env.example first" >&2; return 1; }
        registerMcp github "${kit_root}/scripts/codex-mcp-github.sh"
    fi
    if [ "${AWS_MODE}" == "on" ]; then
        [ -f "${aws_secrets}" ] || { echo "Create ${aws_secrets} from settings/.aws.env.example first" >&2; return 1; }
        codex mcp remove aws >/dev/null 2>&1 || true
        bash "${kit_root}/scripts/agent-aws-cli.sh" up || return 1
        touch "${generated_dir}/mcp-on/aws"
        echo "  AWS reads: bash ${kit_root}/scripts/agent-aws-cli.sh run <aws arguments> (next session pre-armed; its first read closes the gate to new sessions)"
    fi
}

pruneSessions() {
    local cutoff file id count=0
    [ -n "${PRUNE_BEFORE}" ] || return 0
    case "${PRUNE_BEFORE}" in
        *[!0-9]*) cutoff="${PRUNE_BEFORE}" ;;
        *) cutoff="${PRUNE_BEFORE} days ago" ;;
    esac
    date -d "${cutoff}" >/dev/null 2>&1 || { echo "Invalid prune cutoff '${PRUNE_BEFORE}'" >&2; return 1; }
    while IFS= read -r file; do
        id="$(basename "${file}" | rg -o '[0-9a-f]{8}-[0-9a-f-]{27,}' | tail -1)"
        [ -n "${id}" ] || continue
        codex archive "${id}" >/dev/null 2>&1 || continue
        count=$((count+1))
    done < <(find "${codex_home}/sessions" -type f -name '*.jsonl' ! -newermt "${cutoff}" 2>/dev/null)
    echo "  archived ${count} Codex session(s)"
}

updateCodex() {
    local codex_path package_dir
    codex_path="$(readlink -f "$(command -v codex)")"
    package_dir="$(dirname "$(dirname "$(dirname "${codex_path}")")")"
    if [ -w "${package_dir}" ]; then
        codex update
        return 0
    fi
    command -v npm >/dev/null 2>&1 || { echo "npm is required to update the root-owned Codex installation" >&2; return 1; }
    echo "  Codex is installed under root-owned ${package_dir}; updating with sudo..."
    sudo npm install -g @openai/codex
}

verifyAll() {
    local failed=0 name aws_running config_check
    bash "${kit_root}/scripts/validate-skills.sh" --codex-runtime || { echo "[FAIL] skill compatibility"; failed=1; }
    config_check="$(mktemp -d)"
    if ! cp "${codex_profile}" "${config_check}/config.toml" || ! CODEX_HOME="${config_check}" codex --strict-config app-server --stdio </dev/null >/dev/null 2>&1; then
        echo "[FAIL] strict config"
        failed=1
    fi
    rm -rf "${config_check}"
    [ -L "${codex_agents_md}" ] && [ "$(readlink "${codex_agents_md}")" == "${claude_md_src}" ] || { echo "[FAIL] AGENTS.md link"; failed=1; }
    [ -L "${codex_planner_agent}" ] && [ "$(readlink "${codex_planner_agent}")" == "${planner_agent_src}" ] || { echo "[FAIL] Astra planner link"; failed=1; }
    [ -s "${agents_manifest}" ] && [ -s "${codex_skills_manifest}" ] || { echo "[FAIL] skills manifests"; failed=1; }
    [ -L "${codex_rules}" ] && [ "$(readlink "${codex_rules}")" == "${kit_root}/settings/codex/rules/${PERMISSION_TIER}.rules" ] || { echo "[FAIL] active rules link"; failed=1; }
    grep -qF 'alternate_screen = "never"' "${codex_profile}" || { echo "[FAIL] terminal scrollback"; failed=1; }
    grep -qF 'raw_output_mode = false' "${codex_profile}" || { echo "[FAIL] rich output mode"; failed=1; }
    grep -qF 'terminal_title = []' "${codex_profile}" || { echo "[FAIL] terminal title disabled"; failed=1; }
    grep -qF 'plan_mode_reasoning_effort = "max"' "${codex_profile}" || { echo "[FAIL] plan mode max effort"; failed=1; }
    if [ -n "${CODEX_AGENT_THREADS}" ]; then
        grep -qF "max_concurrent_threads_per_session = ${CODEX_AGENT_THREADS}" "${codex_profile}" || { echo "[FAIL] native subagent limit"; failed=1; }
    fi
    for name in atlassian github chrome-devtools playwright; do
        if codexMcpConfigured "${name}" && ! codex mcp get "${name}" --json 2>/dev/null | grep -Eq '"enabled":[[:space:]]*false'; then
            echo "[FAIL] ${name} MCP starts enabled"
            failed=1
        fi
    done
    codex execpolicy check --rules "${codex_rules}" -- git push origin main 2>/dev/null | grep -q forbidden || { echo "[FAIL] git push rule"; failed=1; }
    aws_running="$(docker ps -q -f 'name=^ai-kit-aws-ro$' 2>/dev/null || true)"
    if [ "${AWS_MODE}" == "on" ]; then
        if [ -n "${aws_running}" ] && [ -f "${generated_dir}/mcp-on/aws" ] && ! codexMcpConfigured aws; then
            echo "[PASS] AWS container running + next-session gate pre-armed"
        else
            echo "[FAIL] AWS -a must start the container, pre-arm the gate and remove the legacy MCP"
            failed=1
        fi
    elif [ "${AWS_REMOVE}" == "1" ]; then
        if [ -z "${aws_running}" ] && [ ! -f "${generated_dir}/mcp-on/aws" ] && [ ! -f "${generated_dir}/mcp-on/aws.win" ] && ! compgen -G "${generated_dir}/mcp-on/aws.session.*" >/dev/null && ! codexMcpConfigured aws; then
            echo "[PASS] AWS container, gates and legacy MCP removed"
        else
            echo "[FAIL] AWS -A left a container, gate or legacy MCP behind"
            failed=1
        fi
    fi
    grep -qsF "alias codex='/usr/local/bin/screen bash ${kit_root}/codex.sh'" "${HOME}/.bash_aliases" || echo "[INFO] run: bash ${kit_root}/scripts/screen5_install.sh"
    command -v bwrap >/dev/null 2>&1 && codex sandbox -- /usr/bin/true >/dev/null 2>&1 || echo "[INFO] run: bash ${kit_root}/scripts/codex_bwrap_install.sh"
    [ "${failed}" -eq 0 ] || return 1
    echo "All Codex checks passed."
}

if [ -n "${LOGOUT_TARGET}" ]; then logoutTarget "${LOGOUT_TARGET}"; trap : 0; exit 0; fi
[ "${DO_FRESH}" == "1" ] && freshInstall
[ "${DO_FRESH}" != "1" ] && [ "${DO_RESET}" == "1" ] && resetBloat

if [ "${DO_UPDATE}" == "1" ] && [ "${CODEX_WAS_INSTALLED}" != "1" ]; then
    echo "Updating Codex..."
    updateCodex
fi

writeCodexEnv
writeProfile
writeAgentsMd
applySkillsInvocation
writeOpenAiSkillMeta
linkKitSkills "${agents_skills_dir}" "${agents_manifest}" codex
linkKitSkills "${codex_skills_dir}" "${codex_skills_manifest}" codex
configureMcpSecrets
applyMcps
pruneSessions

if [ "${WALKER_SETUP}" == "1" ]; then
    bash "${kit_root}/docker/codex-chrome-agent/setup-walker.sh" $([ "${ASSUME_YES}" == "1" ] && printf %s -y)
fi
disableRegisteredMcps

[ -n "${CODEX_FLAG}" ] && echo "  -x/-X accepted: standalone Codex is already active; no registration changed"

echo "Codex profile: ${codex_profile}"
echo "Permission tier: ${PERMISSION_TIER}; mode: ${SESSION_MODE}"
echo "Native subagent limit: ${CODEX_AGENT_THREADS:-Codex default}"
echo "Model route: planner=gpt-6-astra/max; execution=${CODEX_MODEL:-gpt-6-astra}/${CODEX_REASONING_EFFORT:-xhigh}"
echo "Run: bash ${kit_root}/codex.sh"
[ "${DO_VERIFY}" == "1" ] && verifyAll

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "****************CODEX SET UP**********************"
echo "**************************************************"
echo "**************************************************"
