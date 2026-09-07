#!/bin/bash -l
# Manpreet 07/09/2026
# Validate shared skill metadata and optional Codex runtime discovery.

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

CODEX_RUNTIME=0 # Ask the real Codex runtime to discover the installed skills

usage() {
    cat <<'USAGE'
Usage: bash scripts/validate-skills.sh [-c]

Validate the shared skill schema, invocation policy, client availability and
Codex-compatible instructions.

  -c, --codex-runtime  Also verify installed skills through Codex app-server.
  -h, --help           Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -c | --codex-runtime)
        CODEX_RUNTIME=1
        ;;
    -h | --help)
        usage
        trap : 0
        exit 0
        ;;
    *)
        echo "Invalid Parameter '${p}' ... exiting" >&2
        trap : 0
        exit 1
        ;;
    esac
    shift
done

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

kit_root="$(dirname "$(realpath "$0")")"
kit_root="$(dirname "${kit_root}")"
skills_src_dir="${kit_root}/skills"

source "${kit_root}/lib/skills.sh"

##################################################
################# EXECUTION ######################
##################################################

echo "Validating kit skills..."
validateKitSkills
echo -e "[Done]\n"

if [ "${CODEX_RUNTIME}" == "1" ]; then
    echo "Validating installed skills through Codex app-server..."
    validateCodexSkillDiscovery
    echo -e "[Done]\n"
fi

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "*************** SKILLS VALID *********************"
echo "**************************************************"
echo "**************************************************"
