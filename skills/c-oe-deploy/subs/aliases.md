# oe-deploy - .bash_aliases house rules

Rules for writing or changing aliases in the repo-root `.bash_aliases`. The live shell sources `~/.bash_aliases`; a checkout copy is tested with `source ~/cat/.bash_aliases` (functions redefine cleanly in the same shell).

## Shape

- **Function, not alias**, for anything with an argument or logic. Plain `alias` only for shorthands onto a real function: `alias ttys=ttyss`, `alias vscodeusers='sshusers vscode'`.
- **Self-contained**: no helper functions defined outside the alias they support - nest them or inline them (the 2026-07-18 cleanup removed `_conns`/`_owner`/`_wrap`). A shared format string variable is the one tolerated exception (`dps_string` for `dpsa`).
- **Short but readable**, never golfed: one pipeline over staged temp variables, correlation/aggregation pushed into a single `awk` instead of bash loops with associative arrays, each function fits on one screen. Comments only for a non-obvious why (e.g. why logs are fed oldest-first).
- Errors are one echoed line + `return 1`: `echo "Cannot find unique db or manager container name..." && return 1`.
- A watch/report that can legitimately return nothing must still print something (see `dbrebuildwatch`'s `UNION ALL ... FROM DUAL WHERE ...` fallback rows) so it never looks broken.

## helpp must be filled in

Every user-facing alias gets a `print_command "name [<project>]" "description"` entry in `helpp`, under the matching `print_heading` section. Shorthands ride in the description: `"Active terminals: cpu/mem used + current command (alias: ttys)"`. An alias without a helpp entry is unfinished work.

## Naming

- Double the trailing letter when the name is an English dictionary word or collides with a real command: `helpp`, `pss`, `versionss`, `secss`, `ttyss`, `weatherr`.
- Compound or coined names stay as-is: `dpsa`, `oeloggedin`, `dbrebuildwatch`.
- Optional first argument is always the compose project filter: `docker ps -aqf name=${1:+$1.*}db.1` (container-name form) or `${1:+--filter 'label=com.docker.compose.project'=$1}` (docker ps form). No argument = the only instance on the host.

## DB query aliases

- **Resolve the db container first; if it does not exist the DB is RDS - fall back to the manager container** and run the client from there:

```bash
local dbcontainer=$(docker ps -aqf name=${1:+$1.*}db.1)
[ -z "${dbcontainer}" ] && dbcontainer=$(docker ps -aqf name=${1:+$1.*}manager.1) # Use Mysql client in manager if db doesn't exist
[ $(echo -n "${dbcontainer}" | grep -c '^') -ne 1 ] && echo "Cannot find unique db or manager container name..." && return 1
```

- Everything expands **in-container**: single-quoted `docker exec -it "${dbcontainer}" bash -c '...'`. The container env carries the RDS pointing: `-h ${DATABASE_HOST:-localhost} -P ${DATABASE_PORT:-3306}`, schema `${DATABASE_NAME:-openeyes}`.
- Client binary differs per image - detect it: `$( [ -x "$(command -v mysql)" ] && printf %s mysql || printf %s mariadb )` (same trick for `mysqlcheck`/`mariadbcheck`, `mysqladmin`/`mariadb-admin`).
- Root credentials come from Docker secrets, never hardcoded: interactive logins use `--defaults-extra-file=<(printf "[client]\nuser = %s\npassword = \"%s\"" "root" "$(cat /run/secrets/MYSQL_ROOT_PASSWORD)")`; watch-style one-liners use `-p$(cat /run/secrets/MYSQL_ROOT_PASSWORD)` (accepted trade-off: visible in `ps` args, same as `myproc`).
- Multi-statement SQL goes in via heredoc: `docker exec -i ... <<SQL` (or `<<'SQL'` when nothing should expand host-side).

## Watch patterns

- **Watch a SQL result**: run `watch` inside the container, `-t` mandatory (the header would echo the whole SQL + password): `docker exec -it "${dbcontainer}" bash -c 'watch -t -n 3 "...client... -e \"SELECT ...\" 2>/dev/null"'` - see `myproc`, `dbrebuildwatch`.
- **Watch another alias**: `watch -d -t -n 1 -x bash -ic "aliasname ${1:-}"` - `bash -ic` re-sources `.bash_aliases` every tick, so the watched alias stays current (`wdpsa`).
