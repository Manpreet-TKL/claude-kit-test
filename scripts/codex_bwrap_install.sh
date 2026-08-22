#!/bin/bash -l
# Manpreet 22/08/2026
# Install and verify system bubblewrap for the host Codex Linux sandbox.

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

show_help=0 # Flag to print usage and exit

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -h | --help)
        show_help=1
        ;;
    *)
        echo "Invalid Parameter '${p}' ... exiting" >&2
        exit 1
        ;;
    esac
    shift
done

if [ "${show_help}" == "1" ]; then
    echo "Usage: bash $(realpath "$0") [-h|--help]"
    echo "Installs Ubuntu bubblewrap and the restrictive AppArmor profile only when needed."
    trap : 0
    exit 0
fi

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking we are not running as root..."
[ "${EUID}" == "0" ] && echo "Run as your normal user - sudo is called only where needed ... exiting" && exit 1
echo "[OK]"

echo "Checking operating system..."
. /etc/os-release
[ "${ID:-}" != "ubuntu" ] && echo "This installer supports Ubuntu only ... exiting" && exit 1
command -v apt-get >/dev/null 2>&1 || { echo "apt-get is required ... exiting"; exit 1; }
echo "${PRETTY_NAME} [OK]"

echo "Checking Codex exists..."
command -v codex >/dev/null 2>&1 || { echo "Install Codex separately before running this script ... exiting"; exit 1; }
echo "$(codex --version) [OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

apparmor_profile_source="/usr/share/apparmor/extra-profiles/bwrap-userns-restrict"
apparmor_profile_target="/etc/apparmor.d/bwrap-userns-restrict"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

testBubblewrap() {
    command -v bwrap >/dev/null 2>&1 || return 1
    bwrap --ro-bind / / --unshare-user --unshare-pid /usr/bin/true >/dev/null 2>&1
}

testCodexSandbox() {
    codex sandbox -- /usr/bin/true >/dev/null 2>&1
}

checkProfileCollision() {
    local profile matches
    matches=0
    for profile in /etc/apparmor.d/*; do
        [ -f "${profile}" ] || continue
        grep -qE '(^|[[:space:]])/usr/bin/bwrap([[:space:]]|$)' "${profile}" || continue
        case "${profile}" in
            "${apparmor_profile_target}") ;;
            *) echo "Conflicting bwrap AppArmor attachment: ${profile}" >&2; matches=$((matches+1)) ;;
        esac
    done
    [ "${matches}" -eq 0 ] || { echo "Resolve the conflicting profile before continuing ... exiting" >&2; exit 1; }
}

installBubblewrap() {
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy -o=Dpkg::Use-Pty=0 bubblewrap
}

installAppArmorProfile() {
    checkProfileCollision
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy -o=Dpkg::Use-Pty=0 apparmor-profiles apparmor-utils
    [ -f "${apparmor_profile_source}" ] || { echo "Ubuntu did not provide ${apparmor_profile_source} ... exiting" >&2; exit 1; }
    sudo install -m 0644 "${apparmor_profile_source}" "${apparmor_profile_target}"
    sudo apparmor_parser -r "${apparmor_profile_target}"
}

##################################################
################# EXECUTION ######################
##################################################

echo "Installing system bubblewrap..."
installBubblewrap
echo -e "[Done]\n"

if testBubblewrap; then
    echo "Bubblewrap works without an AppArmor change - leaving AppArmor untouched."
else
    restriction="$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || printf 0)"
    [ "${restriction}" != "1" ] && echo "Bubblewrap failed for a reason other than Ubuntu's AppArmor user-namespace restriction ... exiting" && exit 1
    echo "Installing the restrictive AppArmor bubblewrap profile..."
    installAppArmorProfile
    echo -e "[Done]\n"
fi

##################################################
################ POST-CHECKS #####################
##################################################

echo "Checking system bubblewrap is selected..."
[ "$(command -v bwrap)" != "/usr/bin/bwrap" ] && echo "Expected /usr/bin/bwrap, found $(command -v bwrap) ... exiting" && exit 1
echo "[OK]"

echo "Checking bubblewrap namespace isolation..."
testBubblewrap || { echo "System bubblewrap still cannot create its sandbox ... exiting"; exit 1; }
echo "[OK]"

echo "Checking the Codex sandbox..."
testCodexSandbox || { echo "Codex still cannot start its Linux sandbox ... exiting"; exit 1; }
echo "[OK]"

echo "Checking Ubuntu's global AppArmor restriction was not disabled..."
[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || printf 1)" == "0" ] && echo "WARNING: the global AppArmor user-namespace restriction was already disabled" >&2
echo "[OK]"

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "*************CODEX BWRAP INSTALLED****************"
echo "**************************************************"
echo "**************************************************"
