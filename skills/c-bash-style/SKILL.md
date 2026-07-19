---
name: c-bash-style
description: Manpreet's bash script house style
disable-model-invocation: false
---

# Bash script style

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

House style for new or substantially edited `.sh` scripts (skip one-liners). Reference scripts: `ace/scripts/db_backup.sh`, `proxy.sh`, `disable_ipv6.sh`. **Read `subs/reference.md` before authoring** - it has the verbatim templates (banners, abort block, arg parsing, portable paths).

## Layout (top -> bottom)

1. `#!/bin/bash -l` + `# Manpreet DD/MM/YYYY` + one-line description
2. `abort()` + `trap 'abort' 0` + `set -e`
3. Default flag values, trailing `# comment`
4. `while [[ $# -gt 0 ]]` + `case` arg parsing; unknown flag -> exit 1
5. Portable paths: derive env root from `$0`, never `$PWD`
6. `### CHECKS ###` - pre-flight gates: announce -> run -> `[OK]`
7. `### VARIABLES ###` - derived vars
8. `### FUNCTIONS ###` - all logic; camelCase names; `local` params
9. `### EXECUTION ###` - thin orchestrator, the only place anything runs
10. `trap : 0` + mirrored star closing banner

Banners are exactly 50 chars wide, 3 lines. Setup sections left-aligned with `(See end of script for execution)`; action sections (EXECUTION, POST-CHECKS) centred. Skip empty sections.

## Rules

- Always `"${var}"`; defaults via `${var:-default}`; no `set -u`.
- Every option gets both a short and a long flag (`-D | --database`); never a short or long form alone.
- Runnable commands echoed as advice (and in docs) go on ONE line - up to 200 chars is fine; never backslash-wrapped.
- Short guards as `[ "${flag}" == "1" ] && action` one-liners.
- `trap : 0` before every successful exit, including early ones.
- Secrets read from files (`$(cat ${secrets_folder}/NAME)`), never env vars.
- `sudo` inside the script; sudo writes via `tee` + heredoc.
- Pick mariadb/mysql at call time; backup filenames get `${environment}` + `$(date '+%Y%m%d_%H-%M')`.
- Wrap actions in `echo "Doing X..."` / `echo -e "[Done]\n"`; gate echoes on a `silent` flag rather than redirecting.
- Quiet noisy installs/builds per command, not per script: add the tool's quiet flags (`apt-get update -qq`, `DEBIAN_FRONTEND=noninteractive apt-get install -qqy`, `./configure --quiet`, `make -s`) so errors still reach stderr; never blanket-redirect to `/dev/null`.
- Comments above the line; trailing only for flag defaults.
