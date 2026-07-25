#!/bin/bash -l
# Manpreet 25/07/2026
# Host-side wrapper: runs sync-state.sh inside the running walker, which writes the two logins
# into ~/.claude/oe-chrome-agent/ (see state-dir.sh - never into the kit) so the next container
# - which gets a brand-new, empty Chrome profile - comes up already signed in. That is the
# whole persistence story: ~1KB of JSON, not a 280MB Chrome profile.
#
# What is saved:
#   claude-credentials.json  the CLI's /login OAuth credential (~/.claude/.credentials.json)
#   extension-state.json     the extension's claude.ai sign-in + its per-site "always
#                            allow" grants (six keys of its chrome.storage.local)
# Everything else in the profile - caches, history, cookies, the extension bundle itself -
# is regenerable and deliberately not kept.
#
# Calling this by hand is now belt and braces: the entrypoint syncs at boot, drive.sh after
# every prompt, and reset-session.sh before `down`. Run it after the first interactive /login
# and extension sign-in if you don't want to wait for the next drive to pick them up.

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

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=state-dir.sh
. "${script_dir}/state-dir.sh"   # sets state_dir (outside the kit - see that file)
container="${CHROME_CONTAINER:-claude-chrome}"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking docker is available..."
command -v docker > /dev/null || { echo "docker not found"; exit 1; }
echo "[OK]"

echo "Checking the walker is running..."
docker ps --format '{{.Names}}' | grep -qx "${container}" || { echo "${container} is not running - start it before saving state"; exit 1; }
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

saveLogins() {
    docker exec "${container}" /usr/local/bin/sync-state.sh
}

##################################################
################# EXECUTION ######################
##################################################

echo "Saving the two logins out of the walker..."
saveLogins
echo -e "[Done]\n"

trap : 0
echo "State kept in ${state_dir} - the next boot restores it into a fresh profile."
echo '
*************************
*** STATE SAVED ***
*************************
'
