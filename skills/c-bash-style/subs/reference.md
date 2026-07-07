# Bash style - verbatim templates

## Header

```bash
#!/bin/bash -l
# Manpreet DD/MM/YYYY
# One-line description of what the script does
# Extra lines for warnings / pre-reqs if needed
```

`-l` (login shell) so `.bash_aliases`/`.bashrc` env is in scope; plain `#!/bin/bash` only if the script must not pick up the login profile.

## Error handling

```bash
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
```

## Section banners - exactly 50 chars wide, 3 lines

Setup sections (CHECKS, VARIABLES, FUNCTIONS) - left-aligned, annotated, space-padded before a trailing `##`:

```bash
##################################################
### VARIABLES (See end of script for execution) ##
##################################################

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################
```

Action sections (EXECUTION, POST-CHECKS) - centred, hashes both sides:

```bash
##################################################
################# EXECUTION ######################
##################################################

##################################################
################ POST-CHECKS #####################
##################################################
```

Reference: `ace/scripts/disable_ipv6.sh` lines 42-115.

## Argument parsing

```bash
uninstall=0 # Flag to turn off swap file

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -u | -uninstall | --uninstall )
        uninstall=1
        ;;
    -D | --database)
        DATABASE_NAME="${2}"
        shift
        ;;
    *)
        echo "Invalid Parameter ... exiting" && exit 1
        ;;
    esac
    shift # move to next parameter
done
```

## Portable paths (script in `<env>/scripts/`)

```bash
oe_deploy_folder=$(dirname "$(dirname "$(realpath "$0")")")
environment="$(basename "${oe_deploy_folder}")"
secrets_folder="${oe_deploy_folder}/secrets"

source "${oe_deploy_folder}/.oedeploy" || { echo "Something went wrong"; exit 1; }
source <(cat ${oe_deploy_folder}/.env | grep '^DB_TAG\|^DATABASE_HOST')

MYSQL_ROOT_PASSWORD="$(cat ${secrets_folder}/MYSQL_ROOT_PASSWORD)"
```

## Pre-flight checks

```bash
echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking version of MariaDB client..."
[ "$(...)" != "${DB_TAG}" ] && echo "You need to update..." && exit 1
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"
```

Required vars, fail fast:

```bash
requiredVariables="DB_TAG DATABASE_HOST DB_PORT MYSQL_ROOT_PASSWORD"
for var in $requiredVariables; do
    value="$(eval "echo \$$var")"
    [ -z "${value}" ] && echo "The variable ${var} is empty..." && exit 1
done
```

## Functions - camelCase, `local` params, sudo writes via tee+heredoc

```bash
setProxyForApt() {
    sudo tee "/etc/apt/apt.conf.d/oed_proxy.conf" >/dev/null <<-HERE
Acquire {
  HTTP::proxy "${protocol}${ip}:${port}/";
}
HERE
}
```

## Execution section

```bash
if [ "${install}" == "1" ]; then
    echo "Setting up proxy..."
    [ "${gitp}" == "1" ] && setProxyForGit
    [ "${dockerp}" == "1" ] && setProxyForDockerHub
    echo -e "[Done]\n"
fi
```

One-shot early exits - guard, run, disarm trap, exit:

```bash
[ "${SIZE_ONLY}" == "1" ] && echo "$(dbsizegb ${DATABASE_NAME})" && trap : 0 && exit 0
```

## Closing banner - mirror the abort banner

```bash
trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "*****************SWAP SET UP**********************"
echo "**************************************************"
echo "**************************************************"
```

Different message per outcome when the script has install/uninstall modes. Add `sleep 3s` at the very end of long-running scripts so the operator sees the banner (`db_backup.sh` does).

## MariaDB/MySQL portability

```bash
$( [ -x "$(command -v mariadb)" ] && printf %s mariadb || printf %s mysql )
```

Backup timestamps: `timeStamp="$(date '+%Y%m%d_%H-%M')"`; suffix backup filenames with `${environment}` and the date.
