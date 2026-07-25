#!/bin/bash -l
# Manpreet 25/07/2026
# Runs INSIDE the walker: lifts the two logins out of this container into the mounted state
# dir (~/state, which is generated/oe-chrome-agent/ on the host), so the next container comes
# up already signed in. save-state.sh is the host-side wrapper around this.
#
# It runs on a schedule of events rather than a timer: the entrypoint calls it at boot before
# wiping the container, drive.sh calls it after every prompt, and reset-session.sh calls it
# before `down`. That is because the CLI's refresh token ROTATES ON USE and expires 28 days
# after it was minted - a copy saved once and never updated goes stale on its own, and the
# only thing that makes the CLI touch it is a prompt.
#
# Safe to run at any point in the container's life. The extension store is always read from a
# copy, since Chrome holds the original's LOCK whenever it is up, and each file is written to
# a temp name and moved into place only once the source has validated - so a read taken mid
# write can never clobber a good save.

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

silent=0    # -s: no progress output; failures still print. Used by every automatic caller.

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s | --silent)
            silent=1
            shift
            ;;
        -h | --help)
            echo "Usage: sync-state.sh [-s | --silent]"
            trap : 0
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: sync-state.sh [-s | --silent]"
            trap : 0
            exit 1
            ;;
    esac
done

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

state_dir="${HOME}/state"
claude_credential="${HOME}/.claude/.credentials.json"
extension_id="fcoeoabgfenejglbffodgkkbkcdhcgfn"
ext_db="${HOME}/chrome-profile/Default/Local Extension Settings/${extension_id}"
work_dir="/tmp/sync-state.$$"

say() {
    [ "${silent}" == "1" ] || echo -e "$1"
}

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

say "\nStarting Pre-flight checks ..."
say "-------------------------------"

say "Checking the state dir is mounted and writable..."
[ -d "${state_dir}" ] || { echo "${state_dir} is not mounted - nothing to sync into" >&2; exit 1; }
[ -w "${state_dir}" ] || { echo "${state_dir} is not writable by this uid" >&2; exit 1; }
say "[OK]"

say "Checks complete ..."
say "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

saveCredentials() {
    # 0600 on the way out: this is a live OAuth credential, same as ~/.claude/.credentials.json.
    [ -f "${claude_credential}" ] || { say "  no CLI credential in this container - run /login inside it first"; return 0; }
    local tmp="${state_dir}/.claude-credentials.json.$$"
    cp "${claude_credential}" "${tmp}"
    chmod 0600 "${tmp}"
    mv -f "${tmp}" "${state_dir}/claude-credentials.json"
    say "  saved claude-credentials.json"
}

saveExtensionState() {
    # Copy the store aside before reading it - Chrome holds the original's LOCK for its whole
    # lifetime, so opening it in place fails while the browser is up. LOCK itself must not come
    # along. dump-extension-state.mjs refuses to emit anything unless both tokens came back.
    [ -d "${ext_db}" ] || { say "  no extension storage in the profile yet - sign in over noVNC first"; return 0; }
    local dumped tmp="${state_dir}/.extension-state.json.$$"
    rm -rf "${work_dir}"
    cp -r "${ext_db}" "${work_dir}"
    rm -f "${work_dir}/LOCK"
    if dumped="$(DB_PATH="${work_dir}" node /usr/local/lib/oe-chrome-agent/dump-extension-state.mjs)"; then
        printf '%s\n' "${dumped}" > "${tmp}"
        chmod 0600 "${tmp}"
        mv -f "${tmp}" "${state_dir}/extension-state.json"
        say "  saved extension-state.json"
    else
        say "  extension state NOT saved - see the reason above; any previous save is untouched"
    fi
    rm -rf "${work_dir}"
}

##################################################
################# EXECUTION ######################
##################################################

say "Saving the CLI /login credential..."
saveCredentials
say "[Done]\n"

say "Saving the extension's claude.ai sign-in and site grants..."
saveExtensionState
say "[Done]\n"

trap : 0
say "State kept in ${state_dir} - the next container restores it into a fresh profile."
