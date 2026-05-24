---
name: bash-style
description: Apply Manpreet's house style when authoring or substantially editing bash scripts (.sh files) — section banners (CHECKS/VARIABLES/FUNCTIONS/EXECUTION), abort()+trap error handling, portable-path block, [OK]/[Done] echo conventions, mirrored star banners. Trigger whenever the user asks for a new bash script, a rewrite of an existing one, or any non-trivial edit to a .sh file. Skip for one-line shell commands or quick patches.
---

# Bash script style

House style for new and edited bash scripts. Follow it unless there's a concrete reason not to — and stay consistent with neighbouring scripts in the same folder (in `ace/scripts/`, `db_backup.sh`, `proxy.sh`, `disable_ipv6.sh` are good references).

## File layout (top → bottom)

```
1. Shebang + header comment
2. abort()  +  trap 'abort' 0  +  set -e
3. Default flag values (one per line, with inline `# comment`)
4. Argument parsing  (while + case)
5. Portable-path block (oe_deploy_folder / environment / secrets_folder)
6. ### CHECKS ###       — pre-flight gates, each followed by [OK]
7. ### VARIABLES ###    — derived/computed vars (after parsing + checks)
8. ### FUNCTIONS ###    — all logic factored into functions
9. ### EXECUTION ###    — the only place anything actually *runs*
10. trap : 0  +  closing banner
```

Banners separate sections — every banner is exactly 50 characters wide, 3 lines, top and bottom rules are 50 `#`. Two forms:

**Setup sections** (`CHECKS`, `VARIABLES`, `FUNCTIONS`) — left-aligned, annotated with `(See end of script for execution)`, padded with spaces before a trailing `##` so the line is 50 wide:

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

**Action sections** (`EXECUTION`, `POST-CHECKS`) — centered, no annotation, hashes on both sides padded to 50 wide:

```bash
##################################################
################# EXECUTION ######################
##################################################

##################################################
################ POST-CHECKS #####################
##################################################
```

Skip a section if empty rather than leaving a stub. Reference: `ace/scripts/disable_ipv6.sh` lines 42–115.

## Header

```bash
#!/bin/bash -l
# Manpreet DD/MM/YYYY
# One-line description of what the script does
# Extra lines for warnings / pre-reqs if needed
```

Use `#!/bin/bash -l` (login shell) so `.bash_aliases` / `.bashrc` env is in scope. Use plain `#!/bin/bash` only if the script must not pick up the login profile.

## Error handling

Every script opens with:

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

Disarm before normal exit: `trap : 0` just before the success banner. Early successful exits also need `trap : 0` before `exit 0`.

## Argument parsing

`while [[ $# -gt 0 ]]` + `case` with both short and long flags. Default values declared *above* the loop with inline comments. Unknown flags exit:

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

## Portable paths

When a script lives in `<env>/scripts/`, derive the env root from `$0`, not from `$PWD`:

```bash
oe_deploy_folder=$(dirname "$(dirname "$(realpath "$0")")")
environment="$(basename "${oe_deploy_folder}")"
secrets_folder="${oe_deploy_folder}/secrets"
```

Source `.oedeploy` and pull individual keys out of `.env` via process substitution:

```bash
source "${oe_deploy_folder}/.oedeploy" || { echo "Something went wrong"; exit 1; }
source <(cat ${oe_deploy_folder}/.env | grep '^DB_TAG\|^DATABASE_HOST')
```

Read secrets from files, never from env vars: `MYSQL_ROOT_PASSWORD="$(cat ${secrets_folder}/MYSQL_ROOT_PASSWORD)"`.

## Pre-flight checks

Each check is its own block: announce → run → `[OK]`. Wrap the whole section in a header/footer rule.

```bash
echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking version of MariaDB client..."
[ "$(...)" != "${DB_TAG}" ] && echo "You need to update..." && exit 1
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"
```

For required vars, iterate and fail fast:

```bash
requiredVariables="DB_TAG DATABASE_HOST DB_PORT MYSQL_ROOT_PASSWORD"
for var in $requiredVariables; do
    value="$(eval "echo \$$var")"
    [ -z "${value}" ] && echo "The variable ${var} is empty..." && exit 1
done
```

## Functions

- camelCase names (`createProxyInScreen`, `setProxyForGit`, `uninstallSwap`, `runOnOpeneyesDB`).
- All non-trivial work goes in a function; `EXECUTION` is a thin orchestrator.
- Use `local` for parameters: `local database_name="${1}"`.
- For `sudo` writes, prefer `tee` with a `<<-HERE … HERE` heredoc over `echo > file`.

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

Branch on the flags parsed earlier, one action per line, each wrapped in `echo "Doing X..."` / `echo -e "[Done]\n"`:

```bash
if [ "${install}" == "1" ]; then
    echo "Setting up proxy..."
    [ "${gitp}" == "1" ] && setProxyForGit
    [ "${dockerp}" == "1" ] && setProxyForDockerHub
    echo -e "[Done]\n"
fi
```

For one-shot early exits (e.g. `--size`, `--uninstall`), guard with the flag, run the function, disarm the trap, exit:

```bash
[ "${SIZE_ONLY}" == "1" ] && echo "$(dbsizegb ${DATABASE_NAME})" && trap : 0 && exit 0
```

## Closing banner

```bash
trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "*****************SWAP SET UP**********************"
echo "**************************************************"
echo "**************************************************"
```

Mirror the `abort` banner — same width, same star style. Different message per outcome when the script has install/uninstall modes.

## Conventions cheatsheet

- **Quoting**: always `"${var}"`, never bare `$var`. Defaults via `${var:-default}`.
- **Conditionals**: prefer `[ "${flag}" == "1" ] && action` one-liners over multi-line `if` for short guards.
- **Silent / quiet flag**: gate echoes with `[ "${silent}" != "1" ] && echo …` rather than redirecting to `/dev/null`.
- **`sudo` lives inside the script** — don't require the caller to be root.
- **MariaDB / MySQL portability**: pick the binary at call time: `$( [ -x "$(command -v mariadb)" ] && printf %s mariadb || printf %s mysql )`.
- **Timestamps for backups**: `timeStamp="$(date '+%Y%m%d_%H-%M')"`; suffix backup filenames with `${environment}` and date.
- **Inline comments above the line they describe**, not trailing — except for flag-default declarations where trailing `# comment` is the norm.
- **`sleep 3s` at the very end** when the script ends with a banner the operator should see (used in long-running scripts like `db_backup.sh`).
- **No `set -u`** — scripts rely on unset-as-empty behaviour throughout.
