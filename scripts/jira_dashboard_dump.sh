#!/bin/bash -l
# Manpreet 08/08/2026
# Read-only dump of a Jira dashboard: metadata, gadget list, each gadget's saved
# config, and the id/name/JQL of every saved filter those configs reference.
# Credentials come from ~/.claude/mcp-env/.atlassian.env (classic API token) - the kit's
# credential store, kept outside the repo so it can never be pushed.
# Usage: ./jira_dashboard_dump.sh -d 11651

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

dashboard_id="" # Dashboard id to dump

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -d | --dashboard)
        dashboard_id="${2}"
        shift
        ;;
    *)
        echo "Invalid Parameter ... exiting" && exit 1
        ;;
    esac
    shift # move to next parameter
done

env_file="${HOME}/.claude/mcp-env/.atlassian.env"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking curl and jq are installed..."
[ -x "$(command -v curl)" ] || { echo "curl is required ... exiting" && exit 1; }
[ -x "$(command -v jq)" ] || { echo "jq is required ... exiting" && exit 1; }
echo "[OK]"

echo "Checking Jira credentials..."
[ ! -f "${env_file}" ] && echo "Missing ${env_file} - run install.sh -j first ... exiting" && exit 1
source "${env_file}"
requiredVariables="JIRA_URL JIRA_USERNAME JIRA_API_TOKEN"
for var in $requiredVariables; do
    value="$(eval "echo \$$var")"
    [ -z "${value}" ] && echo "The variable ${var} is empty..." && exit 1
done
echo "[OK]"

echo "Checking a dashboard id was given..."
[ -z "${dashboard_id}" ] && echo "Give -d <dashboard id> ... exiting" && exit 1
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

api="${JIRA_URL%/}/rest/api/3"
auth="${JIRA_USERNAME}:${JIRA_API_TOKEN}"
configs_file="$(mktemp)"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

apiGet() {
    local path="${1}"
    curl -s -u "${auth}" "${api}${path}"
}

dumpDashboard() {
    apiGet "/dashboard/${dashboard_id}" | jq '{name, description, owner: .owner.displayName, viewShare: [.sharePermissions[]?.type], editShare: [.editPermissions[]?.type]}'
}

dumpGadgets() {
    apiGet "/dashboard/${dashboard_id}/gadget" | jq -c '.gadgets[] | {id, title, moduleKey, position}'
}

dumpGadgetConfigs() {
    local gadget_id key
    for gadget_id in $(apiGet "/dashboard/${dashboard_id}/gadget" | jq -r '.gadgets[].id'); do
        for key in $(apiGet "/dashboard/${dashboard_id}/items/${gadget_id}/properties" | jq -r '.keys[]?.key'); do
            echo "-- gadget ${gadget_id} / ${key}"
            apiGet "/dashboard/${dashboard_id}/items/${gadget_id}/properties/${key}" | jq -c '.value'
        done
    done
}

dumpReferencedFilters() {
    local filter_id
    for filter_id in $(grep -oE 'filter-?[0-9]{4,}|"filterId": *"?[0-9]{4,}' "${configs_file}" | grep -oE '[0-9]{4,}' | sort -u); do
        apiGet "/filter/${filter_id}" | jq -c 'select(.id != null) | {id, name, jql}'
    done
}

##################################################
################# EXECUTION ######################
##################################################

echo "=== dashboard ${dashboard_id} ==="
dumpDashboard
echo "=== gadgets ==="
dumpGadgets
echo "=== gadget configs ==="
dumpGadgetConfigs | tee "${configs_file}"
echo "=== referenced filters ==="
dumpReferencedFilters
rm -f "${configs_file}"

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "*****************DASHBOARD DUMPED*****************"
echo "**************************************************"
echo "**************************************************"
