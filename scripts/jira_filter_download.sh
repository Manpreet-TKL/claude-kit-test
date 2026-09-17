#!/bin/bash -l
# Manpreet 16/09/2026
# Compatibility entrypoint for Jira filter/JQL downloads using the corpus container.

abort() {
    echo >&2 'Jira download failed. Follow the corrective action above; use -r to resume completed work.'
    exit 1
}
trap 'abort' 0
set -e

jql="" # Raw JQL
filterId="" # Saved filter
outFolder="${HOME}/jira-corpus_$(date '+%Y%m%d_%H-%M')" # Single query destination
mode="full" # Empty destination by default
attachments="--no-attachments" # Preserve the original opt-in attachment behavior
scriptFolder="$(dirname "$(realpath "$0")")"

while [[ $# -gt 0 ]]; do
    case "$1" in
    -j | --jql | -f | --filter | -o | --output | -m | --mode)
        [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 1; }
        case "$1" in
        -j | --jql) jql="$2" ;;
        -f | --filter) filterId="$2" ;;
        -o | --output) outFolder="$2" ;;
        -m | --mode) mode="$2" ;;
        esac
        shift
        ;;
    -a | --attachments) attachments="--attachments" ;;
    -r | --resume) mode="resume" ;;
    -h | --help)
        echo 'Usage: bash jira_filter_download.sh -j "project = EXAMPLE" -o /path/corpus -a -r'
        echo 'Use -f/--filter instead of -j/--jql, or -m/--mode delta to reconcile changes.'
        trap : 0
        exit 0
        ;;
    *) echo "Invalid parameter: $1" >&2; exit 1 ;;
    esac
    shift
done

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

[ -n "${jql}" ] || [ -n "${filterId}" ] || { echo 'Give -j/--jql or -f/--filter.' >&2; exit 1; }
queryArgs=(--jql "${jql}")
[ -n "${filterId}" ] && queryArgs=(--filter "${filterId}")

##################################################
################# EXECUTION ######################
##################################################

bash "${scriptFolder}/corpus.sh" sync --source jira --root "${outFolder}" --mode "${mode}" "${queryArgs[@]}" "${attachments}"
trap : 0
