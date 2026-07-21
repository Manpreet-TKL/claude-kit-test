#!/bin/bash -l
# Manpreet 20/07/2026
# Download every ticket of a Jira filter (or raw JQL) to disk: keys.txt, full
# issue JSON with all comments, and optionally the attachment binaries.
# Credentials come from claude-kit generated/.atlassian.env (classic API token).
# Usage: ./jira_filter_download.sh -f 19720 -a
#        ./jira_filter_download.sh -j 'project = TKLS AND status = "In Progress"' -o /home/toukan/tkls-corpus

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

jql=""        # Raw JQL to download
filter_id=""  # Saved filter id (becomes jql=filter=<id>)
out_folder="" # Output folder (default: ~/jira-corpus_<timestamp>)
attachments=0 # Flag to also download attachment binaries

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -j | --jql)
        jql="${2}"
        shift
        ;;
    -f | --filter)
        filter_id="${2}"
        shift
        ;;
    -o | --output)
        out_folder="${2}"
        shift
        ;;
    -a | --attachments)
        attachments=1
        ;;
    *)
        echo "Invalid Parameter ... exiting" && exit 1
        ;;
    esac
    shift # move to next parameter
done

kit_folder=$(dirname "$(dirname "$(realpath "$0")")")
env_file="${kit_folder}/generated/.atlassian.env"

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

echo "Checking a filter or JQL was given..."
[ -z "${jql}" ] && [ -z "${filter_id}" ] && echo "Give -f <filter id> or -j '<jql>' ... exiting" && exit 1
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

timeStamp="$(date '+%Y%m%d_%H-%M')"
[ -n "${filter_id}" ] && jql="filter=${filter_id}"
[ -z "${out_folder}" ] && out_folder="${HOME}/jira-corpus_${timeStamp}"
api="${JIRA_URL}/rest/api/3"
# --retry covers 429 rate limiting and transient 5xx, honouring Retry-After
curl_opts=(-fsS --retry 3 -u "${JIRA_USERNAME}:${JIRA_API_TOKEN}")

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

searchKeys() {
    local token="" response
    local -a extra
    : >"${out_folder}/keys.txt"
    while :; do
        extra=()
        [ -n "${token}" ] && extra=(--data-urlencode "nextPageToken=${token}")
        response=$(curl "${curl_opts[@]}" -G "${api}/search/jql" --data-urlencode "jql=${jql}" --data-urlencode "fields=key" --data-urlencode "maxResults=100" "${extra[@]}")
        echo "${response}" | jq -r '.issues[].key' >>"${out_folder}/keys.txt"
        token=$(echo "${response}" | jq -r '.nextPageToken // empty')
        [ -z "${token}" ] && break
    done
}

fetchAllComments() {
    local key="$1" start=0 page
    while :; do
        page=$(curl "${curl_opts[@]}" "${api}/issue/${key}/comment?startAt=${start}&maxResults=100")
        echo "${page}" | jq -c '.comments[]'
        start=$((start + $(echo "${page}" | jq '.comments | length')))
        [ "${start}" -ge "$(echo "${page}" | jq '.total')" ] && break
    done
}

fetchIssue() {
    local key="$1" got total
    local issue_file="${out_folder}/issues/${key}.json"
    curl "${curl_opts[@]}" "${api}/issue/${key}?fields=*all" -o "${issue_file}"
    got=$(jq '.fields.comment.comments | length' "${issue_file}")
    total=$(jq '.fields.comment.total // 0' "${issue_file}")
    # The inline comment block is one page only - top up tickets with more
    if [ "${total}" -gt "${got}" ]; then
        fetchAllComments "${key}" | jq -s '.' >"${out_folder}/.comments.tmp"
        jq --slurpfile c "${out_folder}/.comments.tmp" '.fields.comment.comments = $c[0] | .fields.comment.maxResults = ($c[0] | length)' "${issue_file}" >"${issue_file}.tmp"
        mv "${issue_file}.tmp" "${issue_file}"
        rm -f "${out_folder}/.comments.tmp"
    fi
}

fetchAttachments() {
    local key="$1" att id name url
    local issue_file="${out_folder}/issues/${key}.json"
    [ "$(jq '.fields.attachment | length' "${issue_file}")" == "0" ] && return 0
    mkdir -p "${out_folder}/attachments/${key}"
    jq -c '.fields.attachment[]' "${issue_file}" | while IFS= read -r att; do
        id=$(echo "${att}" | jq -r '.id')
        name=$(echo "${att}" | jq -r '.filename')
        url=$(echo "${att}" | jq -r '.content')
        # Prefix the attachment id - Jira allows duplicate filenames on one ticket
        curl "${curl_opts[@]}" -L "${url}" -o "${out_folder}/attachments/${key}/${id}_${name}"
    done
}

##################################################
################# EXECUTION ######################
##################################################

startSeconds=$(date +%s)
mkdir -p "${out_folder}/issues"

echo "Searching: ${jql}..."
searchKeys
issueCount=$(wc -l <"${out_folder}/keys.txt")
echo -e "[Done] ${issueCount} issues\n"

echo "Downloading ${issueCount} issues to ${out_folder}/issues..."
n=0
while IFS= read -r key; do
    n=$((n + 1))
    echo "Fetching ${key} (${n}/${issueCount})..."
    fetchIssue "${key}"
    [ "${attachments}" == "1" ] && fetchAttachments "${key}"
done <"${out_folder}/keys.txt"
echo -e "[Done]\n"

elapsedSeconds=$(($(date +%s) - startSeconds))
echo "Downloaded ${issueCount} issues in ${elapsedSeconds}s ($(du -sh "${out_folder}" | cut -f1))"

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "***************DOWNLOAD COMPLETE******************"
echo "**************************************************"
echo "**************************************************"
