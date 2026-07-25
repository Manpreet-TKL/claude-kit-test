#!/bin/bash -l
# Manpreet 23/07/2026
# Reset the chrome-agent between OE sessions.
#
# For a clean browser this script is optional: the entrypoint wipes the container's state on
# every start, so `docker compose restart` already gives a walk with no trace of the last one.
# Reach for this when you want the container itself gone - a different OE deployment, a
# different network, or a handover.
#
# Default: destroy the container, keeping the two saved logins in ~/.claude/oe-chrome-agent/ -
# a same-day, same-user reset that needs no re-authentication afterwards.
# -f/--full: also delete those saved logins, for a shared host or a handover. The next
# boot then needs an interactive /login and extension sign-in again.

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

assume_yes=0    # -y skips the confirmation prompt
full_reset=0    # -f also drops the saved logins

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y | --yes)
            assume_yes=1
            shift
            ;;
        -f | --full)
            full_reset=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./reset-session.sh [-y | --yes] [-f | --full]"
            trap : 0
            exit 1
            ;;
    esac
done

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=state-dir.sh
. "${script_dir}/state-dir.sh"   # sets state_dir, exports OE_CHROME_STATE_DIR for compose down
container="${CHROME_CONTAINER:-claude-chrome}"
# down needs the compose file to interpolate; the real values don't matter for teardown.
export OE_NETWORK="${OE_NETWORK:-bridge}"
export UID GID

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking docker is available..."
command -v docker > /dev/null || { echo "docker not found"; exit 1; }
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

confirmReset() {
    [ "${assume_yes}" == "1" ] && return 0
    if [ "${full_reset}" == "1" ]; then
        echo "This destroys the container AND the saved logins in ${state_dir} - the next boot needs /login and an extension sign-in again."
        read -r -p "Type RESET to continue: " answer
        [ "${answer}" == "RESET" ] || { echo "Not confirmed - nothing done."; trap : 0; exit 1; }
    else
        echo "This destroys the container and its whole Chrome profile (cookies, history, caches, session grants). The two saved logins are kept, so the next boot needs no re-authentication."
        read -r -p "Continue? [y/N] " answer
        [ "${answer}" == "y" ] || [ "${answer}" == "Y" ] || { echo "Not confirmed - nothing done."; trap : 0; exit 1; }
    fi
}

syncSavedLogins() {
    # down destroys the writable layer, and with it any token the container refreshed since the
    # last drive. The -f path skips this on purpose: it is about to delete the saved logins.
    docker ps --format '{{.Names}}' | grep -qx "${container}" || { echo "  ${container} is not running - nothing to sync"; return 0; }
    docker exec "${container}" /usr/local/bin/sync-state.sh -s \
        || echo "  state sync failed - the saved logins in ${state_dir} are unchanged"
}

downStack() {
    docker compose -f "${script_dir}/docker-compose.yml" down --remove-orphans
}

dropSavedLogins() {
    rm -f "${state_dir}/claude-credentials.json" "${state_dir}/extension-state.json"
}

##################################################
################# EXECUTION ######################
##################################################

confirmReset

if [ "${full_reset}" != "1" ]; then
    echo "Syncing the logins into the kit before the container goes..."
    syncSavedLogins
    echo -e "[Done]\n"
fi

echo "Destroying the container (and with it the Chrome profile)..."
downStack
echo -e "[Done]\n"

if [ "${full_reset}" == "1" ]; then
    echo "Dropping the saved logins..."
    dropSavedLogins
    echo -e "[Done]\n"
fi

trap : 0
if [ "${full_reset}" == "1" ]; then
    echo "Full reset complete. Next boot needs /login + an extension sign-in: export UID GID OE_NETWORK=<net> OE_URL=<url> then docker compose up -d, and ./save-state.sh once signed in."
else
    echo "Reset complete - saved logins kept. Next boot: export UID GID OE_NETWORK=<net> OE_URL=<url> then docker compose up -d (no /login needed)."
fi
echo '
**************************
*** RESET SUCCESSFULLY ***
**************************
'
