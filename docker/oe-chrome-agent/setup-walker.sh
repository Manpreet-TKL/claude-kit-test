#!/bin/bash -l
# Manpreet 23/07/2026
# Interactive first-boot setup for the oe-chrome-agent walker: asks for the OE
# deployment's docker network (URL defaults to http://web - see docker-compose.yml),
# boots the stack, and pauses for the two manual sign-ins (CLI /login + the extension's
# claude.ai login), then saves both into the kit with save-state.sh. They are one-time per
# host, not per session or per container (see docs/chrome-agent.md) - re-running once they
# are saved skips straight past the pause. Callable directly (verbose build) or via
# install.sh -w | --setup-walker,
# which always adds -q so the build stays out of install.sh's terse output - on a
# build failure it still tells you to re-run this script directly to see why.

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

assume_yes=0     # -y: non-interactive, use saved/env config, never prompt
quiet_build=0    # -q: silence the docker build output (errors still shown) - install.sh always passes this
oe_network=""    # -n: override the OE deployment's docker network
oe_url=""        # -u: override the OE web container's URL (default: http://web, see loadSavedConfig/EXECUTION)

usage() {
    echo "Usage: ./setup-walker.sh [-y | --yes] [-q | --quiet-build] [-n | --network <docker-network>] [-u | --url <oe-url>]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y | --yes)
            assume_yes=1
            shift
            ;;
        -q | --quiet-build)
            quiet_build=1
            shift
            ;;
        -n | --network)
            oe_network="$2"
            shift 2
            ;;
        -u | --url)
            oe_url="$2"
            shift 2
            ;;
        -h | --help)
            usage
            trap : 0
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            trap : 0
            exit 1
            ;;
    esac
done

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

script_dir="$(cd "$(dirname "$0")" && pwd)"
kit_root="$(dirname "$(dirname "${script_dir}")")"
generated_dir="${kit_root}/generated"
state_dir="${generated_dir}/oe-chrome-agent"
config_file="${generated_dir}/.oe-chrome-agent.env"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking docker is available..."
command -v docker > /dev/null || { echo "docker not found"; exit 1; }
echo "[OK]"

echo "Checking the state dir exists (created empty on first run)..."
mkdir -p "${state_dir}"
echo "[OK]"

echo "Checking docker-compose.yml is present..."
[ -f "${script_dir}/docker-compose.yml" ] || { echo "docker-compose.yml not found next to this script"; exit 1; }
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

loadSavedConfig() {
    [ -f "${config_file}" ] || return 0
    # shellcheck source=/dev/null
    . "${config_file}"
    [ -n "${oe_network}" ] || oe_network="${OE_NETWORK:-}"
    [ -n "${oe_url}" ] || oe_url="${OE_URL:-}"
}

askConfig() {
    if [ "${assume_yes}" == "1" ]; then
        [ -n "${oe_network}" ] || { echo "No OE_NETWORK (saved config, -n, or env) - pass -n | --network or drop -y"; exit 1; }
        return 0
    fi
    echo ""
    echo "  oe-chrome-agent setup - one question (Enter keeps the bracketed value)"
    read -r -p "  OE deployment's docker network [${oe_network}]: " answer
    oe_network="${answer:-${oe_network}}"
    [ -n "${oe_network}" ] || { echo "A docker network is required"; exit 1; }
    echo "  OE URL: ${oe_url} (override with -u | --url if this deployment's web service isn't reachable there)"
}

saveConfig() {
    mkdir -p "${generated_dir}"
    chmod 700 "${generated_dir}"
    {
        echo "OE_NETWORK=${oe_network}"
        echo "OE_URL=${oe_url}"
    } > "${config_file}"
    chmod 600 "${config_file}"
    echo "  saved -> ${config_file} (reused as the default on the next run)"
}

bootStack() {
    mkdir -p "${script_dir}/artifacts"
    GID="${GID:-$(id -g)}"
    export UID GID
    export OE_NETWORK="${oe_network}" OE_URL="${oe_url}"
    local build_flags=()
    [ "${quiet_build}" == "1" ] && build_flags=(--quiet-build)
    if ! docker compose -f "${script_dir}/docker-compose.yml" up -d --build "${build_flags[@]}"; then
        [ "${quiet_build}" == "1" ] && echo "  build failed - run ${script_dir}/setup-walker.sh directly (no -q) to see the full error" >&2
        exit 1
    fi
}

waitForBoot() {
    local tries=0
    echo -n "  waiting for the container to boot"
    while [ "${tries}" -lt 40 ]; do
        if docker compose -f "${script_dir}/docker-compose.yml" logs oe-chrome-agent 2>/dev/null | grep -q "noVNC ready"; then
            echo " [OK]"
            return 0
        fi
        echo -n "."
        sleep 2
        tries=$((tries + 1))
    done
    echo ""
    echo "  gave up waiting for 'noVNC ready' in the logs - check: docker compose -f ${script_dir}/docker-compose.yml logs oe-chrome-agent"
    exit 1
}

containerName() {
    docker ps -q --filter "name=^claude-chrome$" | head -n1
}

isPaired() {
    # The saved logins, not the container's copies of them - those are restored from here
    # on every boot, so this is what actually decides whether a first run is needed.
    [ -f "${state_dir}/claude-credentials.json" ] && [ -f "${state_dir}/extension-state.json" ]
}

saveLogins() {
    "${script_dir}/save-state.sh"
}

firstRunPause() {
    # The CLI and the extension are separate OAuth clients with different scopes, so this
    # cannot come down to one sign-in. It can come down to one credential entry: do the CLI
    # first and take its BROWSER flow, which lands a claude.ai session in this container's own
    # Chrome - the extension's sign-in then finds itself already authenticated and reduces to a
    # single Authorize click. Doing it the other way round asks for the password twice.
    echo ""
    echo "  First run on this host - one credential entry and one click, needed once ever."
    echo "  Do these in order:"
    echo ""
    echo "  1. Forward port 6080 (VSCode: Ports panel -> Forward a Port -> 6080) and open"
    echo "     http://localhost:6080 - it auto-connects and scales, no query string needed."
    echo "  2. In another terminal: docker exec -it claude-chrome claude, then /login, and"
    echo "     choose the BROWSER option (not paste-a-code) - the OAuth page opens in the"
    echo "     Chrome you are watching. Sign in there, then exit the CLI with Ctrl-D or"
    echo "     /exit - that won't stop the container."
    echo "  3. Back on the noVNC screen, switch to the extension's options tab (already open)"
    echo "     and click Log in. It should just need one Authorize click now."
    echo ""
    read -r -p "  Press Enter once both are done: " pause
}

verifySteadyState() {
    "${script_dir}/drive.sh" -t walker-setup "Open ${oe_url}, read the page, and report the logged-in user and site. Do this now with tool calls, do not answer from memory."
}

##################################################
################# EXECUTION ######################
##################################################

loadSavedConfig
oe_url="${oe_url:-http://web}"   # matches docker-compose.yml's own default (see there for why it's safe to hardcode)
askConfig
saveConfig

echo "Booting the stack..."
bootStack
echo -e "[Done]\n"

echo "Waiting for boot..."
waitForBoot
echo -e "[Done]\n"

echo "Checking whether the logins are already saved in the kit..."
if ! isPaired; then
    echo "  not yet saved"
    firstRunPause
    echo ""
    echo "  Saving both logins into the kit so every later container restores them..."
    saveLogins
else
    echo "  already saved - skipping the one-time login pause"
fi
echo -e "[Done]\n"

echo "Verifying steady-state driving (one prompt through drive.sh)..."
verifySteadyState
echo -e "[Done]\n"

trap : 0
echo '
***********************
*** WALKER IS READY ***
***********************
'
echo "Drive it:    ${script_dir}/drive.sh \"<prompt>\""
echo "Clean up:    ${script_dir}/reset-session.sh -y   (or -f | --full for a shared host/handover)"
