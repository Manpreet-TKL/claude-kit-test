#!/bin/bash -l
# Manpreet 23/07/2026
# Drive one unattended prompt through the chrome-agent and print result + token usage.
# Extension site approvals are profile-wide, not per Claude Code session (validated by
# restarting the container and running a brand-new session with no denial), and the
# entrypoint seeds the grant into every fresh profile, so a fresh session is the default;
# -s/--session opts into resuming a specific one for multi-turn continuity WITHIN a boot -
# transcripts live in the container's ~/.claude, which the entrypoint wipes on every start.
# Each run brackets the prompt: the browser is collapsed back to one tab beforehand, and the
# logins are synced back into the kit afterwards. Usage lines append to artifacts/drive.log.

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

session_id=""    # -s: resume this session instead of starting fresh
tag="drive"      # -t: label for the usage log line
map_file=""      # -f: walk-map file whose content is prepended to the prompt
prompt=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s | --session)
            session_id="$2"
            shift 2
            ;;
        -t | --tag)
            tag="$2"
            shift 2
            ;;
        -f | --file)
            map_file="$2"
            shift 2
            ;;
        -h | --help)
            echo "Usage: ./drive.sh [-s | --session <id>] [-t | --tag <name>] [-f | --file <map>] \"<prompt>\""
            trap : 0
            exit 0
            ;;
        *)
            prompt="$1"
            shift
            ;;
    esac
done

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking a prompt was given..."
[ -n "${prompt}" ] || { echo "No prompt - usage: ./drive.sh [-s <id>] [-t <tag>] [-f <map>] \"<prompt>\""; exit 1; }
echo "[OK]"

echo "Checking the agent container is running..."
container="$(docker ps -q --filter "name=^claude-chrome$" | head -n1)"
[ -n "${container}" ] || { echo "claude-chrome container not running - docker compose up -d first"; exit 1; }
echo "[OK]"

if [ -n "${map_file}" ]; then
    echo "Checking the walk-map file exists..."
    [ -f "${map_file}" ] || { echo "Walk-map file not found: ${map_file}"; exit 1; }
    echo "[OK]"
fi

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

script_dir="$(cd "$(dirname "$0")" && pwd)"
log_file="${script_dir}/artifacts/drive.log"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

buildPrompt() {
    [ -n "${map_file}" ] && { cat "${map_file}"; echo; echo "---"; echo; }
    printf '%s' "${prompt}"
}

resetTabs() {
    # Collapses whatever the last prompt left open back to a single tab on the OE landing page,
    # so tab groups don't pile up across drives. No new code needed: oe-login.mjs already does
    # exactly that in its CDP startup pass, and re-asserts the OE session while it is there.
    # Skipped when resuming, because it also navigates the surviving tab - which would pull a
    # multi-turn session off whatever page it was left on.
    [ -n "${session_id}" ] && return 0
    docker exec "${container}" node /usr/local/bin/oe-login.mjs > /dev/null 2>&1 \
        || echo "  tab reset skipped - oe-login.mjs failed, so the walk starts wherever the last one ended"
}

runPrompt() {
    local resume_flags=()
    [ -n "${session_id}" ] && resume_flags=(--resume "${session_id}")
    buildPrompt | docker exec -i "${container}" claude -p --chrome --allowedTools "mcp__claude-in-chrome" "${resume_flags[@]}" --output-format json 2>&1
}

syncState() {
    # A prompt is the only thing that makes the CLI touch its refresh token, and that token
    # rotates on use with a 28-day fuse - so this is exactly where the kit's saved copy has to
    # be refreshed from. Non-fatal: a sync failure must not lose a walk that already ran.
    docker exec "${container}" /usr/local/bin/sync-state.sh -s \
        || echo "  state sync failed - the saved logins are unchanged"
}

##################################################
################# EXECUTION ######################
##################################################

echo "Resetting the browser to a single tab on the OE landing page..."
resetTabs
echo -e "[Done]\n"

echo "Running prompt (session: ${session_id:-fresh})..."
output="$(runPrompt)"
echo -e "[Done]\n"

echo "Syncing the logins back into the kit..."
syncState
echo -e "[Done]\n"

mkdir -p "${script_dir}/artifacts"
raw_file="$(mktemp)"
printf '%s' "${output}" > "${raw_file}"
python3 - "${tag}" "${log_file}" "${raw_file}" <<'PY'
import json, sys
tag, log_file = sys.argv[1], sys.argv[2]
raw = open(sys.argv[3]).read()
try:
    j = json.loads(raw.strip().splitlines()[-1])
except Exception:
    print("PARSE_FAIL - raw output below:")
    print(raw[-3000:])
    sys.exit(1)
u = j.get("usage", {})
line = {"tag": tag, "session_id": j.get("session_id"), "turns": j.get("num_turns"),
        "in": u.get("input_tokens"), "out": u.get("output_tokens"),
        "cache_read": u.get("cache_read_input_tokens"), "cache_write": u.get("cache_creation_input_tokens"),
        "cost_usd": j.get("total_cost_usd"), "duration_ms": j.get("duration_ms"), "is_error": j.get("is_error")}
open(log_file, "a").write(json.dumps(line) + "\n")
print("USAGE:", json.dumps({k: line[k] for k in ("turns", "in", "out", "cache_read", "cache_write", "cost_usd")}))
print("RESULT:")
print(j.get("result"))
PY
rm -f "${raw_file}"

trap : 0
