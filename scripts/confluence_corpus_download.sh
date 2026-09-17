#!/bin/bash -l
# Manpreet 16/09/2026
# Refresh all Confluence spaces or the supplied space keys.

abort() {
    echo >&2 'Confluence download failed. Follow the corrective action above, then use --mode resume.'
    exit 1
}
trap 'abort' 0
set -e

scriptFolder="$(dirname "$(realpath "$0")")"

##################################################
################# EXECUTION ######################
##################################################

bash "${scriptFolder}/corpus.sh" sync --source confluence "$@"
trap : 0
