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
# Evidence is copied out unconditionally, because the entrypoint's wipe clears /tmp on every
# boot and that is where the extension writes its screenshots - so a walk whose evidence is
# not copied out loses it at the next -r, and -r is the first thing the next repro does.

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

session_id=""     # -s: resume this session instead of starting fresh
tag="drive"       # -t: label for the usage log line and the evidence folder
map_file=""       # -f: walk-map file whose content is prepended to the prompt
evidence_dir=""   # -e: where the evidence lands (default ~/repro-evidence/<date>-<tag>)
reboot="0"        # -r: restart the container first, for a guaranteed fresh browser
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
        -e | --evidence)
            evidence_dir="$2"
            shift 2
            ;;
        -r | --reboot)
            reboot="1"
            shift
            ;;
        -h | --help)
            echo "Usage: ./drive.sh [-s | --session <id>] [-t | --tag <name>] [-f | --file <map>] [-e | --evidence <dir>] [-r | --reboot] \"<prompt>\""
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
### VARIABLES (See end of script for execution) ##
##################################################

script_dir="$(cd "$(dirname "$0")" && pwd)"
log_file="${script_dir}/artifacts/drive.log"
# Outside the kit on purpose: a walk over a real instance photographs whatever the page holds,
# and ~/claude-kit has a public remote. Same reasoning as state-dir.sh.
evidence_dir="${evidence_dir:-${HOME}/repro-evidence/$(date '+%Y-%m-%d')-${tag}}"
stamp="$(date '+%H-%M-%S')"
# shellcheck source=state-dir.sh
. "${script_dir}/state-dir.sh"   # sets state_dir (the saved logins live outside the kit)

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking a prompt was given..."
[ -n "${prompt}" ] || { echo "No prompt - usage: ./drive.sh [-s <id>] [-t <tag>] [-f <map>] \"<prompt>\""; exit 1; }
echo "[OK]"

echo "Checking the saved logins exist..."
if [ ! -f "${state_dir}/claude-credentials.json" ] || [ ! -f "${state_dir}/extension-state.json" ]; then
    echo "No saved logins in ${state_dir}"
    echo "The walker needs a one-time CLI /login and extension sign-in before it can drive."
    echo "Generate them now with the guided first run:  ${script_dir}/setup-walker.sh"
    echo "(or, if you have already signed in inside a running container, just ${script_dir}/save-state.sh)"
    exit 1
fi
echo "[OK]"

echo "Checking the agent container is running..."
container="$(docker ps -q --filter "name=^claude-chrome$" | head -n1)"
[ -n "${container}" ] || { echo "claude-chrome container not running - run ${script_dir}/setup-walker.sh, or docker compose up -d"; exit 1; }
echo "[OK]"

if [ -n "${map_file}" ]; then
    echo "Checking the walk-map file exists..."
    [ -f "${map_file}" ] || { echo "Walk-map file not found: ${map_file}"; exit 1; }
    echo "[OK]"
fi

if [ "${reboot}" == "1" ]; then
    echo "Checking --reboot was not combined with --session..."
    [ -z "${session_id}" ] || { echo "-r wipes the container's ~/.claude, which is where session ${session_id} lives - pick one"; exit 1; }
    echo "[OK]"
fi

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

buildPrompt() {
    # The address is prepended to every prompt because the walker cannot be relied on to find
    # OE by itself: Claude in Chrome works inside a tab group, a session that has none creates
    # one and lands on a blank New Tab, and the pre-existing OE tab the boot opened is not in
    # it. Told only "the page in front of you", the walk stalls on chrome://newtab; left to
    # guess a URL, it guesses a public openeyes site and the navigation lockdown blocks it.
    local oe_url
    oe_url="$(docker exec "${container}" printenv OE_URL 2>/dev/null || true)"
    [ -n "${oe_url}" ] && echo "The OpenEyes instance under test is at ${oe_url} and the browser is already logged into it. Navigate there first if the current tab is not already showing it." && echo
    [ -n "${map_file}" ] && { cat "${map_file}"; echo; echo "---"; echo; }
    printf '%s' "${prompt}"
}

rebootContainer() {
    # A restart, not a recreate: the entrypoint's wipeContainerState runs on both, so the
    # Chrome profile, ~/.claude and /tmp are all laid down fresh either way, and a restart
    # reuses the built layer. Waits for two markers, because the entrypoint backgrounds the
    # OE auto-login and exec's the CLI - so "noVNC ready" alone still leaves the walk starting
    # on the login page. Non-fatal on timeout: the walk is still worth attempting.
    local waited=0
    local started
    echo "  restarting ${container}..."
    docker restart "${container}" > /dev/null
    # Read the log through --since this boot's start, not --tail: docker keeps the previous
    # boot's output, and Chrome starts flooding stderr with dbus and gcm errors the moment it
    # comes up - so within seconds the ready line is no longer in any fixed-size tail, and a
    # tail-based probe waits out its whole timeout on a container that is already up.
    started="$(docker inspect -f '{{.State.StartedAt}}' "${container}")"
    while [ "${waited}" -lt 90 ]; do
        docker logs --since "${started}" "${container}" 2>&1 | grep -q 'noVNC ready' && break
        sleep 2
        waited=$((waited + 2))
    done
    [ "${waited}" -lt 90 ] || echo "  WARNING: no 'noVNC ready' after ${waited}s - driving anyway"
    while [ "${waited}" -lt 120 ]; do
        docker exec "${container}" sh -c 'grep -q "landed on\|already logged in" "${HOME}/oe-login.log" 2>/dev/null' && break
        sleep 2
        waited=$((waited + 2))
    done
    echo "  fresh browser after ${waited}s: $(docker exec "${container}" sh -c 'head -n1 "${HOME}/oe-login.log" 2>/dev/null' || echo 'no OE login line')"
}

collectEvidence() {
    # The extension writes screenshots into a /tmp/claude-chrome-* directory, and /tmp is
    # cleared by the entrypoint on every boot - so this is the only thing standing between a
    # walk's evidence and the next --reboot. The narration is evidence too, hence the result json.
    local files
    mkdir -p "${evidence_dir}"
    printf '%s\n' "${output}" > "${evidence_dir}/result-${stamp}.json"
    files="$(docker exec "${container}" find /tmp -maxdepth 2 -path '/tmp/claude-chrome-*' -type f 2>/dev/null || true)"
    [ -n "${files}" ] || { echo "  no screenshots this walk - narration saved to ${evidence_dir}"; return 0; }
    while read -r f; do
        [ -n "${f}" ] || continue
        docker cp "${container}:${f}" "${evidence_dir}/" < /dev/null > /dev/null
    done <<< "${files}"
    echo "  $(printf '%s\n' "${files}" | wc -l) file(s) copied to ${evidence_dir}"
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

if [ "${reboot}" == "1" ]; then
    echo "Rebooting the container for a fresh browser..."
    rebootContainer
    echo -e "[Done]\n"
else
    echo "Resetting the browser to a single tab on the OE landing page..."
    resetTabs
    echo -e "[Done]\n"
fi

echo "Running prompt (session: ${session_id:-fresh})..."
output="$(runPrompt)"
echo -e "[Done]\n"

echo "Copying the evidence out of the container..."
collectEvidence
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
echo -e "\nEVIDENCE: ${evidence_dir}"

trap : 0
