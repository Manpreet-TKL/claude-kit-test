#!/bin/bash -l
# Manpreet 16/09/2026
# Download, verify and index portable corpora using a container.

abort() {
    echo >&2 'Corpus command failed. Read the phase and corrective action above; completed files are retained.'
    exit 1
}
trap 'abort' 0
set -e
set -o pipefail

kitFolder="$(dirname "$(dirname "$(realpath "$0")")")"
jiraRoot="${HOME}/jira-corpus" # Default Jira corpus
confluenceRoot="${HOME}/confluence-corpus" # Default Confluence corpus
indexRoot="${HOME}/corpus-index" # Derived, rebuildable data
credentialFile="${HOME}/.claude/mcp-env/.atlassian.env" # Machine-local credentials
sourceName="jira" # Download source
rootOverride="" # Selected source root
commandName="${1:-help}"
arguments=("$@")

while [[ $# -gt 0 ]]; do
    case "$1" in
    -R | --root | -J | --jira-root | -C | --confluence-root | -I | --index-root | -E | --credential-file | -s | --source)
        [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 1; }
        case "$1" in
        -R | --root) rootOverride="$2" ;;
        -J | --jira-root) jiraRoot="$2" ;;
        -C | --confluence-root) confluenceRoot="$2" ;;
        -I | --index-root) indexRoot="$2" ;;
        -E | --credential-file) credentialFile="$2" ;;
        -s | --source) sourceName="$2" ;;
        esac
        shift
        ;;
    esac
    shift
done
if [ -n "${rootOverride}" ]; then
    if [ "${sourceName}" == "confluence" ]; then confluenceRoot="${rootOverride}"; else jiraRoot="${rootOverride}"; fi
fi
jiraRoot="$(realpath -m "${jiraRoot}")"
confluenceRoot="$(realpath -m "${confluenceRoot}")"
indexRoot="$(realpath -m "${indexRoot}")"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

[ -x "$(command -v docker)" ] || { echo 'Docker is required. Start or install Docker using your normal machine setup.' >&2; exit 1; }
docker info --format '{{.ServerVersion}}' >/dev/null || { echo 'Docker is unavailable. Start the daemon and check your Docker group permissions.' >&2; exit 1; }
mounts=()
for corpusRoot in "${jiraRoot}" "${confluenceRoot}" "${indexRoot}"; do
    corpusRoot="$(realpath -m "${corpusRoot}")"
    case "${corpusRoot}/" in
    "${kitFolder}/"*) echo 'Corpus and index data must be outside the kit repository.' >&2; exit 1 ;;
    esac
    case "${kitFolder}/" in
    "${corpusRoot}/"*) echo 'Choose a dedicated corpus directory, not an ancestor of the kit repository.' >&2; exit 1 ;;
    esac
    mkdir -p "${corpusRoot}"
    mounts+=(--mount "type=bind,src=${corpusRoot},dst=${corpusRoot}")
done
networkArgs=(--network none)
case "${commandName}" in
sync | estimate | spaces | auth)
    [ -r "${credentialFile}" ] || { echo "Missing credential file: ${credentialFile}. Refresh it locally; do not paste credentials into chat." >&2; exit 1; }
    credentialFile="$(realpath "${credentialFile}")"
    case "${credentialFile}" in "${kitFolder}/"*) echo 'Credentials must be stored outside the kit repository.' >&2; exit 1 ;; esac
    mounts+=(--mount "type=bind,src=${credentialFile},dst=${credentialFile},readonly")
    networkArgs=()
    ;;
esac

##################################################
################# EXECUTION ######################
##################################################

imageHash="$(sha256sum "${kitFolder}/docker/corpus-tools/Dockerfile")"
imageName="corpus-tools:${imageHash:0:12}"
if ! docker image inspect "${imageName}" >/dev/null 2>&1; then
    echo 'Building the corpus runtime (Python and PDF extraction, inside Docker)...' >&2
    docker build -q -t "${imageName}" "${kitFolder}/docker/corpus-tools" >&2
fi
trap : 0
exec docker run --rm --init --user "$(id -u):$(id -g)" --read-only --cap-drop ALL --security-opt no-new-privileges --tmpfs /tmp:rw,nosuid,nodev,size=1g "${networkArgs[@]}" "${mounts[@]}" --mount "type=bind,src=${kitFolder}/scripts/corpus,dst=/opt/corpus,readonly" -e "CORPUS_HOME=${HOME}" -e "CORPUS_JIRA_ROOT=${jiraRoot}" -e "CORPUS_CONFLUENCE_ROOT=${confluenceRoot}" -e "CORPUS_INDEX_ROOT=${indexRoot}" -e "CORPUS_CREDENTIAL_PATH=${credentialFile}" "${imageName}" "${arguments[@]}"
