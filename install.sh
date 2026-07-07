#!/bin/bash -l
# Manpreet 24/05/2026
# claude-kit installer — configures Claude Code per the handoff brief.
# Merges ~/.claude/settings.json (statusLine, env, permissions) and symlinks
# ~/.claude/CLAUDE.md (plus statusline.sh and skills) back into this kit.
# Idempotent: safe to re-run. settings.json is backed up to *.bak only when the
# merged content actually differs, so a no-op re-run never clobbers a good backup;
# a real CLAUDE.md/statusline.sh is backed up once when first replaced by its
# symlink. Your auth, history.jsonl and projects/ are never touched.
# Skill symlinks are torn down and rebuilt every run: links for skills that were
# removed from the kit are pruned (tracked in ~/.claude/.claude-kit-skills, so a
# removal propagates even if the kit has since moved), while real directories and
# any hand-added links are left alone. If ~/.claude is absent, Claude Code is
# installed from scratch; otherwise `claude update` refreshes the CLI to the
# latest (skippable with --no-update). Then this kit's config is laid down on top.

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

# Defaults (overridable via env or flag) ------------------------------------
PERMISSIONS=""                                  # ultra-safe | standard | trusted | yolo (the allow/ask/deny rule-set)
MODE=""                                         # default|plan|acceptEdits|auto|dontAsk|bypassPermissions; "" = DEFAULT_MODE
DEFAULT_MODE="${DEFAULT_MODE:-auto}"            # fallback session start mode when -m is omitted (env-overridable)
AUTOCOMPACT_PCT="${AUTOCOMPACT_PCT:-100}"       # compact trigger %; 100 = no reduction (only lowers, clamped to ~83)
AUTOCOMPACT_WINDOW="${AUTOCOMPACT_WINDOW:-200000}"  # effective window (tokens)
FIVE_HOUR_BUDGET="${FIVE_HOUR_BUDGET:-}"        # tokens/5h, surfaced as % in status line; unset = raw count
WEEKLY_BUDGET="${WEEKLY_BUDGET:-}"              # tokens/week (rolling 7d), surfaced as % in status line; unset = raw count
ASSUME_YES=0                                    # -y: accept default tier non-interactively
DO_VERIFY=1                                     # --no-verify: skip the verification checks
DO_UPDATE=1                                     # --no-update: skip `claude update`
FRESH_INSTALL=0                                 # set to 1 if we curl-install from scratch this run
DO_RESET=0                                      # --reset: archive bloat then install
DO_FRESH=0                                       # --fresh: back up data, wipe ~/.claude, reinstall
JIRA_MODE=""                                    # -j / --with-jira / "" (leave alone)
CONFLUENCE_MODE=""                              # -c / --with-confluence / "" (leave alone)
ATLASSIAN_REMOVE=0                              # --without-atlassian sets to 1
GITHUB_MODE=""                                  # -g / --with-github / "" (leave alone)
GITHUB_REMOVE=0                                 # --without-github sets to 1
CODEX_MODE=""                                   # -x / --with-codex / "" (leave alone)
CODEX_REMOVE=0                                  # --without-codex sets to 1
SKILLS_AUTO=""                                  # -s on|off: flip disable-model-invocation across kit skills; "" → off (plain runs restore true)
LOGOUT_MCP=""                                   # -l codex|github|atlassian|all: clear stored MCP credentials and exit (standalone action)
PRUNE_BEFORE=""                                 # -d <days|date>: archive+delete sessions last active before the cutoff; "" = off
CLEANUP_PERIOD_DAYS="${CLEANUP_PERIOD_DAYS:-365}"  # settings.json cleanupPeriodDays — Claude Code's own transcript retention
STATUSLINE_REFRESH="${STATUSLINE_REFRESH:-5}"   # statusLine.refreshInterval (seconds) — timer re-runs on top of event-driven updates; 0 = events only
QUICK=0                                         # -q: non-interactive defaults run — yolo tier unless -p given, implies -y

# Usage ---------------------------------------------------------------------
usage() {
    cat <<'USAGE'
Usage: install.sh [-q] [-p <ultra-safe|standard|trusted|yolo>]
                  [-m <default|plan|acceptEdits|auto|dontAsk|bypassPermissions>]
                  [-s <on|off>] [-d <days|YYYY-MM-DD>]
                  [-r] [-F] [-n] [-U] [-y] [-j] [-c] [-a | -A] [-g | -G] [-x | -X]

  Every option has a single-letter (-x) and a long (--word) form.
  Short flags may be bundled: -jc == -j -c (value-taking -p / -m / -s / -d must be last).
  Run with no flags at all, install.sh prints this help and exits with an
  error — pass -q for the no-questions-asked run with defaults.

  -q, --quick         Quick run: non-interactive with defaults — the yolo tier
                      unless -p says otherwise, every prompt suppressed
                      (implies -y). Otherwise identical to a plain install run.
  -p, --permissions   Permission rule-set to install (default: standard) — the
                      allow/ask/deny lists, independent of -m (the start mode):
                      ultra-safe  tightest allow-list; ask before edits/writes/shell.
                      standard    broad allow-list for common dev/test commands.
                      trusted     broad allow-list + extra rm -rf denies.
                      yolo        like trusted but secret reads ALLOWED. Container/VM
                                  only — see docs/sandbox.md.
                      (git push/commit denied on every tier — a hard floor.)
  -m, --mode          Session start mode (permissions.defaultMode), independent of the
                      rule-set. One of:
                      default            evaluate rules; unmatched tool calls prompt.
                      plan               read-only; no edits/exec until you approve a plan.
                      acceptEdits        auto-accept Edit/Write; everything else per rules.
                      auto               LLM classifier judges each call — auto-approves the
                                         safe ones, asks on the rest; shell routes through it.
                      dontAsk            no prompts; deny + ask rules still apply.
                      bypassPermissions  skip ALL checks — widest mode; sandbox/VM only.
                      Omitted → DEFAULT_MODE (auto); never prompted for — interactive
                      runs only ask for the tier.
  -r, --reset         Archive Claude Code's auto-generated state directories
                      (file-history, paste-cache, backups, shell-snapshots,
                      stats-cache, session-env, plugins, tasks) into
                      ~/.claude-backups/<timestamp>/, then run the install.
                      Auth (.credentials.json), history.jsonl, and projects/
                      are preserved in place.
  -F, --fresh         NUKE AND PAVE. Back up projects/ (conversations),
                      history.jsonl, and .credentials.json to
                      ~/.claude-backups/<timestamp>-fresh/, DELETE the whole
                      ~/.claude, reinstall Claude Code from scratch, then restore
                      those three so you keep your conversations and stay logged
                      in — everything else (settings, caches, plugins, MCP
                      state) is regenerated clean. The kit is re-applied on top.
                      Interactive runs ask you to type 'fresh' to confirm; -y
                      skips that prompt. Supersedes --reset.
  -j, --with-jira     Configure the Jira section of the mcp-atlassian stdio
                      server. Prompts for JIRA_URL, JIRA_USERNAME,
                      JIRA_API_TOKEN, JIRA_PROJECTS_FILTER; saves to
                      generated/.atlassian.env (gitignored). With -y, reads the
                      env file silently instead of prompting.
  -c, --with-confluence
                      Configure the Confluence section of the mcp-atlassian
                      stdio server. Prompts for CONFLUENCE_URL,
                      CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN,
                      CONFLUENCE_SPACES_FILTER; defaults to Jira values where
                      they match. Saves to generated/.atlassian.env.
  -a, --with-atlassian
                      Shorthand for -j -c (configure both).
  -A, --without-atlassian
                      Deregister the atlassian MCP server (claude mcp remove,
                      user scope). Credentials file is left in place.
  -g, --with-github   Configure the read-only github-mcp-server stdio server.
                      Prompts for GITHUB_PERSONAL_ACCESS_TOKEN (a fine-grained
                      read-only PAT) and an optional GITHUB_TOOLSETS filter;
                      saves to generated/.github.env (gitignored). Read-only is
                      enforced (GITHUB_READ_ONLY=1) and is NOT configurable —
                      the server never exposes write tools. With -y, reads the
                      env file silently instead of prompting.
  -G, --without-github
                      Deregister the github MCP server (claude mcp remove,
                      user scope). Credentials file is left in place.
  -x, --with-codex    Register OpenAI Codex as an MCP server (codex mcp-server)
                      at user scope, so Claude can spawn one or more autonomous
                      Codex coding agents (mcp__codex tools). Docker-first:
                      builds a local claude-kit-codex image (docker/codex/) and
                      runs the server containerised — nothing is installed on
                      the host; a host `codex` binary is used only if Docker is
                      absent. Sign in once via `... claude-kit-codex login` (the
                      exact command is printed; auth lands in ~/.codex). Pins
                      the flagship model + high reasoning effort and a
                      workspace-write, no-network sandbox; tweakable in
                      generated/.codex.env. With -y, reads that file silently.
  -X, --without-codex
                      Deregister the codex MCP server (claude mcp remove, user
                      scope). generated/.codex.env and ~/.codex are left alone.
  -s, --skills-auto   on|off (default off). Set the model-invocation gate on
                      every kit skill in place (the SKILL.md files are live
                      symlink targets):
                      on   rewrites 'disable-model-invocation: true' → 'false',
                           so Claude may auto-pull any skill whose description
                           matches the task.
                      off  rewrites 'false' → 'true', restoring the exact
                           per-skill state 'on' started from. Skills that never
                           carried the flag (the deliberate auto-load set) are
                           untouched in both directions. Restart Claude Code to
                           pick up the change.
                      Omitting -s means off: every plain run restores the
                      canonical mostly-true state, so -s on only lasts until
                      the next install.
  -d, --prune-sessions
                      <days|date>. Archive-then-delete conversations whose last
                      activity is older than the cutoff — a bare number means
                      that many days ago; anything else is parsed by date -d
                      (e.g. 2025-01-31). For each stale session the transcript
                      (projects/<proj>/<id>.jsonl), its sidecar dir, and the
                      matching session-env/, file-history/ and tasks/ entries
                      are MOVED to ~/.claude-backups/<timestamp>-pruned/ — they
                      vanish from claude --resume but nothing is destroyed
                      (delete the archive yourself to free the disk).
                      Interactive runs show a summary and ask y/N; -y skips.
  -l, --logout        <codex|github|atlassian|all>. Log out of an MCP and EXIT —
                      a standalone action, nothing else runs (which is why the
                      permission tiers can always-allow `install.sh -l *`).
                      Removes the stored credentials: ~/.codex/auth.json for
                      codex; for github/atlassian also the generated/ env file
                      AND the ~/.claude.json registration (it embeds the token).
                      codex stays registered — sign back in and it works again.
                      Local only: the printed pointers tell you where to revoke
                      each token server-side.
  -y, --yes           Non-interactive; accept default tier if not provided.
                      With -j/-c, reads generated/.atlassian.env instead of
                      prompting (errors if the file or required vars are absent).
                      With -g, reads generated/.github.env the same way.
                      With -x, reads generated/.codex.env the same way (or uses
                      built-in defaults if absent).
  -n, --no-verify     Skip the verification checks after writing.
  -U, --no-update     Skip the `claude update` step (don't refresh the Claude
                      Code CLI to the latest version). By default install.sh
                      runs `claude update` on an existing install; a fresh
                      curl-install already pulls the latest, so it's skipped there.
  -h, --help          This message.

Env overrides:
  DEFAULT_MODE         (default auto)    session start mode used when -m is omitted (the mode
                                         is never prompted for).
  CLEANUP_PERIOD_DAYS  (default 365)     settings.json cleanupPeriodDays — how long Claude Code
                                         itself retains conversation transcripts (its built-in
                                         default is only 30 days). Written on every run.
  STATUSLINE_REFRESH   (default 5)       statusLine.refreshInterval in seconds — re-runs the
                                         status line on a timer on top of the event-driven
                                         updates, so token counts stay fresh through long
                                         turns. 0 = event-driven only.
  AUTOCOMPACT_PCT      (default 100)     % capacity at which auto-compact triggers (100 = no reduction).
  AUTOCOMPACT_WINDOW   (default 200000)  effective context window in tokens.
  FIVE_HOUR_BUDGET     (unset)           tokens/5h budget — status line shows 5h N%
                                         instead of a raw count. e.g. FIVE_HOUR_BUDGET=2000000
  WEEKLY_BUDGET        (unset)           tokens/week (rolling 7d) — status line shows wk N%
                                         instead of a raw count. e.g. WEEKLY_BUDGET=20000000
USAGE
}

# Argument parsing ---------------------------------------------------------
requireValue() {   # $1=flag $2=its value (may be absent) — abort with a message instead of a bare set -e death
    if [ $# -lt 2 ] || [ -z "${2}" ]; then
        echo "install.sh: ${1} requires a value — see -h for accepted forms" >&2
        trap : 0
        exit 1
    fi
}

if [ $# -eq 0 ]; then
    usage >&2
    echo >&2
    echo "install.sh: no flags given — nothing assumed. Use -q to run non-interactively" >&2
    echo "with defaults (yolo tier), or pick options from the list above." >&2
    trap : 0
    exit 1
fi

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -[!-]?*)
        # Bundled short flags: explode -jc into -j -c (a single dash followed
        # by 2+ chars, never a --long form). A value-taking flag (-p, -m) must be
        # last in the bundle, per getopt convention.
        rest="${p#-}"
        exploded=()
        for ((i = 0; i < ${#rest}; i++)); do
            exploded+=("-${rest:i:1}")
        done
        set -- "${exploded[@]}" "${@:2}"
        continue
        ;;
    -p | --permissions)
        requireValue "$@"
        PERMISSIONS="${2}"
        shift
        ;;
    -m | --mode)
        requireValue "$@"
        MODE="${2}"
        shift
        ;;
    -q | --quick)
        QUICK=1
        ;;
    -y | --yes)
        ASSUME_YES=1
        ;;
    -n | --no-verify)
        DO_VERIFY=0
        ;;
    -U | --no-update)
        DO_UPDATE=0
        ;;
    -r | --reset)
        DO_RESET=1
        ;;
    -F | --fresh)
        DO_FRESH=1
        ;;
    -j | --with-jira)
        JIRA_MODE="on"
        ;;
    -c | --with-confluence)
        CONFLUENCE_MODE="on"
        ;;
    -a | --with-atlassian)
        JIRA_MODE="on"
        CONFLUENCE_MODE="on"
        ;;
    -A | --without-atlassian)
        ATLASSIAN_REMOVE=1
        ;;
    -g | --with-github)
        GITHUB_MODE="on"
        ;;
    -G | --without-github)
        GITHUB_REMOVE=1
        ;;
    -x | --with-codex)
        CODEX_MODE="on"
        ;;
    -X | --without-codex)
        CODEX_REMOVE=1
        ;;
    -s | --skills-auto)
        requireValue "$@"
        SKILLS_AUTO="${2}"
        shift
        ;;
    -d | --prune-sessions)
        requireValue "$@"
        PRUNE_BEFORE="${2}"
        shift
        ;;
    -l | --logout)
        requireValue "$@"
        LOGOUT_MCP="${2}"
        shift
        ;;
    -h | --help)
        usage
        trap : 0
        exit 0
        ;;
    *)
        echo "Invalid Parameter '${p}' ... exiting" && exit 1
        ;;
    esac
    shift
done

if [ "${QUICK}" = "1" ]; then
    PERMISSIONS="${PERMISSIONS:-yolo}"
    ASSUME_YES=1
fi

# Portable paths -----------------------------------------------------------
kit_root="$(dirname "$(realpath "$0")")"
permissions_dir="${kit_root}/settings/permissions"
shift_enter_file="${kit_root}/settings/shift-enter.json"
# All machine-local generated config lives under one folder (gitignored wholesale),
# so it can be backed up and restored across a `git reset --hard` + `git clean -fdx`.
generated_dir="${kit_root}/generated"
atlassian_secrets="${generated_dir}/.atlassian.env"
github_secrets="${generated_dir}/.github.env"
codex_secrets="${generated_dir}/.codex.env"
codex_docker_dir="${kit_root}/docker/codex"
skills_src_dir="${kit_root}/skills"
memory_src_dir="${kit_root}/memory"
claude_md_src="${kit_root}/claude-md/CLAUDE.md"
statusline_src="${kit_root}/settings/statusline.sh"
claude_dir="${HOME}/.claude"
claude_skills_dir="${claude_dir}/skills"
skills_manifest="${claude_dir}/.claude-kit-skills"   # names of skills install.sh symlinked, for prune-on-removal
settings_file="${claude_dir}/settings.json"
settings_bak="${settings_file}.bak"
claude_md_file="${claude_dir}/CLAUDE.md"
claude_md_bak="${claude_md_file}.bak"
statusline_file="${claude_dir}/statusline.sh"
statusline_bak="${statusline_file}.bak"

# -l/--logout: clear stored MCP credentials, then exit — deliberately standalone,
# BEFORE any pre-flight prompt or install step, so the permission tiers can
# always-allow `install.sh -l *` knowing it can only ever log out. Local-only:
# each block prints where to revoke the token server-side. The atlassian/github
# registrations embed their tokens in ~/.claude.json, so those are deregistered
# too; codex's registration holds no secret and stays — a fresh container login
# brings it straight back without a re-run.
logoutMcp() {
    local target="${1}" did
    if [ "${target}" = "codex" ] || [ "${target}" = "all" ]; then
        if [ -f "${HOME}/.codex/auth.json" ]; then
            rm -f "${HOME}/.codex/auth.json"
            echo "codex: logged out (~/.codex/auth.json removed); to revoke server-side, remove Codex from your ChatGPT account's authorized apps"
            echo "codex: sign back in with: docker run --rm -it --network host --user \"\$(id -u):\$(id -g)\" -v \"\$HOME/.codex:/home/codex/.codex\" claude-kit-codex login"
        else
            echo "codex: no stored login (~/.codex/auth.json absent)"
        fi
    fi
    if [ "${target}" = "github" ] || [ "${target}" = "all" ]; then
        did=0
        if command -v claude >/dev/null 2>&1; then
            if claude mcp remove github -s user >/dev/null 2>&1; then
                echo "github: deregistered from ~/.claude.json (the registration embeds the PAT)"
                did=1
            fi
        else
            echo "github: claude CLI not found — check ~/.claude.json for a leftover github registration (it embeds the PAT)" >&2
        fi
        if [ -f "${github_secrets}" ]; then
            rm -f "${github_secrets}"
            echo "github: removed ${github_secrets}"
            did=1
        fi
        if [ "${did}" = "1" ]; then
            echo "github: revoke the PAT itself at https://github.com/settings/tokens"
        else
            echo "github: nothing stored"
        fi
    fi
    if [ "${target}" = "atlassian" ] || [ "${target}" = "all" ]; then
        did=0
        if command -v claude >/dev/null 2>&1; then
            if claude mcp remove atlassian -s user >/dev/null 2>&1; then
                echo "atlassian: deregistered from ~/.claude.json (the registration embeds the API tokens)"
                did=1
            fi
        else
            echo "atlassian: claude CLI not found — check ~/.claude.json for a leftover atlassian registration (it embeds the API tokens)" >&2
        fi
        if [ -f "${atlassian_secrets}" ]; then
            rm -f "${atlassian_secrets}"
            echo "atlassian: removed ${atlassian_secrets}"
            did=1
        fi
        if [ "${did}" = "1" ]; then
            echo "atlassian: revoke the API token itself at https://id.atlassian.com/manage-profile/security/api-tokens"
        else
            echo "atlassian: nothing stored"
        fi
    fi
    echo "restart Claude Code to drop any live MCP connection"
}

if [ -n "${LOGOUT_MCP}" ]; then
    case "${LOGOUT_MCP}" in
        codex | github | atlassian | all) : ;;
        *)
            echo "Invalid --logout target '${LOGOUT_MCP}' — use codex, github, atlassian or all" >&2
            trap : 0
            exit 1
            ;;
    esac
    logoutMcp "${LOGOUT_MCP}"
    trap : 0
    exit 0
fi

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking for jq..."
command -v jq >/dev/null 2>&1 || { echo "jq not found. Install jq (apt install jq) and retry." >&2; exit 1; }
echo "[OK]"

# Resolve + validate the permission tier FIRST — before any destructive step
# (notably --fresh's wipe), so a bad -p aborts cleanly and never leaves a
# half-torn-down ~/.claude.
echo "Resolving permission tier..."
if [ -z "${PERMISSIONS}" ]; then
    if [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ]; then
        PERMISSIONS="standard"
    else
        echo "Choose permission tier: [1] ultra-safe  [2] standard (default)  [3] trusted  [4] yolo"
        read -r -p "Selection [2]: " choice
        case "${choice}" in
            1|ultra-safe) PERMISSIONS="ultra-safe" ;;
            3|trusted)    PERMISSIONS="trusted" ;;
            4|yolo)       PERMISSIONS="yolo" ;;
            *)            PERMISSIONS="standard" ;;
        esac
    fi
fi
case "${PERMISSIONS}" in
    ultra-safe|standard|trusted|yolo) echo "Tier: ${PERMISSIONS} [OK]" ;;
    *) echo "Invalid tier '${PERMISSIONS}' — must be ultra-safe|standard|trusted|yolo" >&2; exit 1 ;;
esac
if [ "${PERMISSIONS}" = "yolo" ]; then
    echo "  WARNING: 'yolo' tier allows reads of .env/.ssh without prompting."
    echo "           (git push/commit + rm -rf are still denied — hard floor.)"
    echo "           Run only inside a throwaway container/VM. See docs/sandbox.md."
fi

# Resolve + validate the session start MODE (permissions.defaultMode), fully
# independent of the rule-set tier. Defaults to DEFAULT_MODE (auto) when -m is
# omitted — never prompted for, so interactive runs only ask for the tier.
# Resolved before --fresh's wipe (like the tier) so a bad -m aborts without
# half-tearing-down ~/.claude. writeSettings writes MODE verbatim into
# permissions.defaultMode (overriding whatever the tier file carries).
echo "Resolving session start mode..."
if [ -z "${MODE}" ]; then
    MODE="${DEFAULT_MODE}"
fi
case "${MODE}" in
    default|plan|acceptEdits|auto|dontAsk|bypassPermissions) echo "Mode: ${MODE} [OK]" ;;
    *) echo "Invalid mode '${MODE}' — must be default|plan|acceptEdits|auto|dontAsk|bypassPermissions" >&2; exit 1 ;;
esac
if [ "${MODE}" = "bypassPermissions" ]; then
    echo "  WARNING: 'bypassPermissions' skips ALL permission checks — the widest mode"
    echo "           Claude Code has, wider than any kit tier. Don't count on deny rules"
    echo "           (git push/commit, secret reads) to save you. Run only inside a"
    echo "           throwaway container/VM. See docs/sandbox.md."
fi

# Validate the retention / skills / prune options before anything destructive,
# same rationale as the tier and mode checks above.
echo "Validating retention / skills / prune options..."
case "${CLEANUP_PERIOD_DAYS}" in
    ''|*[!0-9]*|0)
        echo "Invalid CLEANUP_PERIOD_DAYS '${CLEANUP_PERIOD_DAYS}' — must be a positive integer (days)" >&2
        exit 1
        ;;
esac
case "${STATUSLINE_REFRESH}" in
    ''|*[!0-9]*)
        echo "Invalid STATUSLINE_REFRESH '${STATUSLINE_REFRESH}' — must be a whole number of seconds (0 = event-driven only)" >&2
        exit 1
        ;;
esac
# No -s → off: a plain run always restores the canonical mostly-true state, so
# a previous -s on never lingers past the next install.
case "${SKILLS_AUTO}" in
    '')     SKILLS_AUTO="off" ;;
    on|off) ;;
    *) echo "Invalid --skills-auto '${SKILLS_AUTO}' — must be on|off" >&2; exit 1 ;;
esac
# Resolve the prune cutoff to an epoch now: a bare number is days-ago, anything
# else goes through date -d (so 2025-01-31, 'last month' etc. all work).
PRUNE_CUTOFF_EPOCH=""
if [ -n "${PRUNE_BEFORE}" ]; then
    case "${PRUNE_BEFORE}" in
        *[!0-9]*) _prune_spec="${PRUNE_BEFORE}" ;;
        *)        _prune_spec="${PRUNE_BEFORE} days ago" ;;
    esac
    if ! PRUNE_CUTOFF_EPOCH="$(date -d "${_prune_spec}" +%s 2>/dev/null)"; then
        echo "Invalid --prune-sessions cutoff '${PRUNE_BEFORE}' — use a day count or a date like 2025-01-31" >&2
        exit 1
    fi
    echo "Prune cutoff: sessions last active before $(date -d "@${PRUNE_CUTOFF_EPOCH}" '+%Y-%m-%d %H:%M')"
fi
echo "Retention: cleanupPeriodDays=${CLEANUP_PERIOD_DAYS} [OK]"

# --fresh: NUKE AND PAVE. Archive conversations + auth, then delete the whole
# ~/.claude so the existing-install check below reinstalls into a clean dir; the
# archived data is restored right after. fresh_archive stays empty when there's
# nothing to wipe (never-installed machine), so --fresh degrades to a clean install.
fresh_archive=""
if [ "${DO_FRESH}" = "1" ]; then
    if [ -d "${claude_dir}" ]; then
        if [ "${ASSUME_YES}" != "1" ] && [ -t 0 ]; then
            echo ""
            echo "  --fresh will back up projects/, history.jsonl and .credentials.json,"
            echo "  then DELETE all of ${claude_dir} and reinstall Claude Code from scratch."
            read -r -p "  Type 'fresh' to proceed (anything else aborts): " _confirm
            [ "${_confirm}" = "fresh" ] || { echo "  aborted --fresh — no changes made"; trap : 0; exit 1; }
        fi
        fresh_archive="${HOME}/.claude-backups/$(date +%Y%m%d-%H%M%S)-fresh"
        mkdir -p "${fresh_archive}"
        for _e in projects history.jsonl .credentials.json; do
            if [ -e "${claude_dir}/${_e}" ]; then
                cp -a "${claude_dir}/${_e}" "${fresh_archive}/${_e}"
                echo "  backed up → ${fresh_archive}/${_e}"
            fi
        done
        rm -rf "${claude_dir}"
        echo "  wiped ${claude_dir}"
    else
        echo "  --fresh: no existing ${claude_dir} — nothing to back up; installing fresh"
    fi
fi

echo "Checking for an existing Claude install (~/.claude)..."
if [ ! -d "${claude_dir}" ]; then
    echo "  ~/.claude not found — installing Claude Code from scratch..."
    command -v curl >/dev/null 2>&1 || { echo "curl not found. Install curl (apt install curl) and retry." >&2; exit 1; }
    curl -fsSL https://claude.ai/install.sh | bash
    FRESH_INSTALL=1
    echo "  [OK] Claude Code installed"
else
    echo "  found — leaving existing ~/.claude (auth, history, projects/) untouched"
fi
echo "[OK]"

# --fresh: restore the archived conversations + auth into the clean install.
if [ "${DO_FRESH}" = "1" ] && [ -n "${fresh_archive}" ]; then
    mkdir -p "${claude_dir}"
    for _e in projects history.jsonl .credentials.json; do
        if [ -e "${fresh_archive}/${_e}" ]; then
            cp -a "${fresh_archive}/${_e}" "${claude_dir}/${_e}"
            echo "  restored → ${claude_dir}/${_e}"
        fi
    done
    echo "  --fresh complete — full archive kept at ${fresh_archive}"
fi

echo "Ensuring ${claude_dir} exists..."
mkdir -p "${claude_dir}"
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

# Ensure settings.json exists as valid JSON so jq always has a base to merge into.
# The backup happens in writeSettings — and only when the content really changes —
# so a no-op re-run never overwrites a good .bak (preserves your prior settings).
ensureSettings() {
    if [ ! -f "${settings_file}" ]; then
        # Seed with an empty object so jq operations always start from valid JSON.
        echo '{}' > "${settings_file}"
        echo "  created fresh → ${settings_file}"
    fi
}

# Ensure the single generated-config folder exists and relocate any pre-consolidation
# secrets (settings/.atlassian.env, settings/.github.env) into it. The whole folder is
# gitignored, so a `git reset --hard` + `git clean -fdx` followed by restoring this one
# folder is all that's needed to reset the kit while keeping local creds.
ensureGenerated() {
    mkdir -p "${generated_dir}"
    chmod 700 "${generated_dir}"
    local legacy
    for legacy in .atlassian.env .github.env .codex.env; do
        if [ -f "${kit_root}/settings/${legacy}" ] && [ ! -f "${generated_dir}/${legacy}" ]; then
            mv "${kit_root}/settings/${legacy}" "${generated_dir}/${legacy}"
            echo "  migrated → ${generated_dir}/${legacy} (was settings/${legacy})"
        fi
    done
}

# --reset: move Claude Code's auto-generated bloat into ~/.claude-backups/<ts>/.
# Preserves auth (.credentials.json), shell history (history.jsonl), and
# projects/ in place — the install steps that follow restore the rest.
resetBloat() {
    local ts archive
    ts="$(date +%Y%m%d-%H%M%S)"
    archive="${HOME}/.claude-backups/${ts}"
    mkdir -p "${archive}"
    local entry moved=0
    for entry in file-history paste-cache backups shell-snapshots stats-cache session-env plugins tasks; do
        if [ -e "${claude_dir}/${entry}" ]; then
            mv "${claude_dir}/${entry}" "${archive}/${entry}"
            echo "  archived → ${archive}/${entry}"
            moved=$((moved+1))
        fi
    done
    if [ "${moved}" -eq 0 ]; then
        rmdir "${archive}" 2>/dev/null || true
        echo "  nothing to archive — ~/.claude was already clean"
    else
        echo "  preserved in place: .credentials.json, history.jsonl, projects/"
        echo "  archive root: ${archive}"
    fi
}

# -d/--prune-sessions: archive-then-delete conversations last active before the
# cutoff (PRUNE_CUTOFF_EPOCH, resolved in pre-flight). A session is its transcript
# projects/<proj>/<id>.jsonl (mtime = last activity, what claude --resume sorts by)
# plus the artifacts keyed by the same UUID: the sidecar dir next to the transcript
# (subagents/, tool-results/) and the session-env/, file-history/ and tasks/
# entries. Everything is MOVED into ~/.claude-backups/<ts>-pruned/ mirroring the
# live layout (the resetBloat idiom) — nothing is destroyed; delete the archive
# yourself to free the disk. IDs derive only from *.jsonl basenames, so non-session
# content in a project dir (notably memory/) can never match. history.jsonl is
# prompt history, not the resume list — left alone.
pruneSessions() {
    [ -n "${PRUNE_CUTOFF_EPOCH}" ] || return 0
    local projects_dir="${claude_dir}/projects"
    [ -d "${projects_dir}" ] || { echo "  no ${projects_dir} — nothing to prune"; return 0; }

    # Collect stale transcripts, then expand each to its full artifact set.
    local extras="session-env file-history tasks"
    local jsonl id proj_dir extra
    local -a victims=() paths=()
    while IFS= read -r jsonl; do
        victims+=("${jsonl}")
        paths+=("${jsonl}")
        id="$(basename "${jsonl}" .jsonl)"
        proj_dir="$(dirname "${jsonl}")"
        [ -d "${proj_dir}/${id}" ] && paths+=("${proj_dir}/${id}")
        for extra in ${extras}; do
            [ -e "${claude_dir}/${extra}/${id}" ] && paths+=("${claude_dir}/${extra}/${id}")
        done
    done < <(find "${projects_dir}" -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' ! -newermt "@${PRUNE_CUTOFF_EPOCH}" | sort)

    if [ "${#victims[@]}" -eq 0 ]; then
        echo "  no sessions last active before $(date -d "@${PRUNE_CUTOFF_EPOCH}" '+%Y-%m-%d') — nothing to prune"
        return 0
    fi

    local nprojects total
    nprojects="$(printf '%s\n' "${victims[@]}" | xargs -r -n1 dirname | sort -u | wc -l)"
    total="$(du -shc -- "${paths[@]}" 2>/dev/null | tail -1 | cut -f1)"
    echo "  ${#victims[@]} session(s) across ${nprojects} project(s), ${total} total,"
    echo "  last active before $(date -d "@${PRUNE_CUTOFF_EPOCH}" '+%Y-%m-%d %H:%M')"
    if [ "${ASSUME_YES}" != "1" ] && [ -t 0 ]; then
        read -r -p "  Archive and remove them? [y/N]: " _ans
        case "${_ans}" in
            y|Y|yes) ;;
            *) echo "  prune skipped — no changes made"; return 0 ;;
        esac
    fi

    local ts archive slug
    ts="$(date +%Y%m%d-%H%M%S)"
    archive="${HOME}/.claude-backups/${ts}-pruned"
    for jsonl in "${victims[@]}"; do
        id="$(basename "${jsonl}" .jsonl)"
        proj_dir="$(dirname "${jsonl}")"
        slug="$(basename "${proj_dir}")"
        mkdir -p "${archive}/projects/${slug}"
        mv -- "${jsonl}" "${archive}/projects/${slug}/"
        [ -d "${proj_dir}/${id}" ] && mv -- "${proj_dir}/${id}" "${archive}/projects/${slug}/"
        for extra in ${extras}; do
            if [ -e "${claude_dir}/${extra}/${id}" ]; then
                mkdir -p "${archive}/${extra}"
                mv -- "${claude_dir}/${extra}/${id}" "${archive}/${extra}/"
            fi
        done
    done
    echo "  archived ${#victims[@]} session(s) → ${archive}"
    echo "  they no longer appear in claude --resume; rm -rf the archive to free the disk"
}

# Refresh the Claude Code CLI to the latest version via `claude update`. Non-fatal:
# a fresh curl-install already pulled the latest (skipped), --no-update opts out,
# and any failure (offline, or a package-manager-managed install that defers the
# update to npm/brew) only warns — it never aborts the install.
updateClaude() {
    if [ "${DO_UPDATE}" != "1" ]; then
        echo "  --no-update set — skipping 'claude update'"
        return 0
    fi
    if [ "${FRESH_INSTALL}" = "1" ]; then
        echo "  fresh install already pulled the latest — skipping 'claude update'"
        return 0
    fi
    command -v claude >/dev/null 2>&1 || { echo "  claude CLI not on PATH — skipping update"; return 0; }
    echo "  running 'claude update'..."
    if claude update; then
        echo "  [OK] Claude Code CLI up to date"
    else
        echo "  WARNING: 'claude update' failed (offline, or package-manager-managed install?) — continuing" >&2
    fi
}

# Symlink ~/.claude/statusline.sh → the kit's settings/statusline.sh, so the live
# status line always tracks the kit (its source of truth) and can never drift from
# a stale copy. Same idiom as the skill symlinks. A pre-existing real file (e.g.
# from an older copy-install or a hand-written status line) is backed up to *.bak
# before being replaced by the link; an already-correct link is left untouched.
# This assumes the kit stays put — a moved or deleted repo leaves a dangling link.
writeStatusline() {
    [ -f "${statusline_src}" ] || { echo "  missing kit source: ${statusline_src}" >&2; return 1; }
    chmod +x "${statusline_src}"
    # Idempotent: already the right symlink → nothing to do.
    if [ -L "${statusline_file}" ] && [ "$(readlink "${statusline_file}")" = "${statusline_src}" ]; then
        echo "  statusline.sh already linked — no change"
        return 0
    fi
    # Replacing a real file (older copy-install or hand-written) — back it up first.
    if [ -e "${statusline_file}" ] && [ ! -L "${statusline_file}" ]; then
        cp -p "${statusline_file}" "${statusline_bak}"
        echo "  backed up → ${statusline_bak}"
    fi
    ln -sfn "${statusline_src}" "${statusline_file}"
    echo "  linked    → ${statusline_file} → ${statusline_src}"
}

# Read the permissions JSON for the chosen tier from settings/permissions/<tier>.json
# and emit it on stdout. The tier files are the source of truth; nothing is constructed inline.
permissionsJsonFor() {
    local tier="$1"
    local tier_file="${permissions_dir}/${tier}.json"
    [ -f "${tier_file}" ] || { echo "Missing tier file: ${tier_file}" >&2; return 1; }
    jq -e . "${tier_file}" >/dev/null || { echo "Invalid JSON in ${tier_file}" >&2; return 1; }
    cat "${tier_file}"
}

# Idempotent merge of statusLine + env + permissions + shift-enter into settings.json.
# permissions is fully replaced (so tier changes drop old keys); env/statusLine
# and the shift-enter fragment are merged so unrelated keys survive. Any stale
# mcpServers block is stripped — Claude Code reads MCP servers from ~/.claude.json
# (claude mcp add), never from settings.json, so a block here is dead config.
writeSettings() {
    local perms_json shift_json
    perms_json="$(permissionsJsonFor "${PERMISSIONS}")"
    # Override the tier's baked-in defaultMode with the separately-resolved MODE.
    perms_json="$(jq --arg m "${MODE}" '.defaultMode = $m' <<< "${perms_json}")"
    if [ -f "${shift_enter_file}" ]; then
        jq -e . "${shift_enter_file}" >/dev/null || { echo "Invalid JSON in ${shift_enter_file}" >&2; return 1; }
        shift_json="$(cat "${shift_enter_file}")"
    else
        shift_json='{}'
    fi

    local tmp
    tmp="$(mktemp)"
    jq \
        --arg pct "${AUTOCOMPACT_PCT}" \
        --arg win "${AUTOCOMPACT_WINDOW}" \
        --arg fivebudget "${FIVE_HOUR_BUDGET}" \
        --arg wkbudget "${WEEKLY_BUDGET}" \
        --arg cleanup "${CLEANUP_PERIOD_DAYS}" \
        --arg slrefresh "${STATUSLINE_REFRESH}" \
        --argjson perms "${perms_json}" \
        --argjson shift "${shift_json}" \
        '
        (.env // {}) as $env
        | . + $shift + {
            statusLine: ({ type: "command", command: "bash ~/.claude/statusline.sh" }
                + (if $slrefresh == "0" then {} else {refreshInterval: ($slrefresh | tonumber)} end)),
            cleanupPeriodDays: ($cleanup | tonumber),
            env: (
                ($env
                  | del(.CLAUDE_MONTHLY_LIMIT_USD)
                  | del(.CLAUDE_MONTHLY_TOKEN_BUDGET)
                  | del(.CLAUDE_5H_TOKEN_BUDGET)
                  | del(.CLAUDE_WEEKLY_TOKEN_BUDGET)
                ) + {
                    CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: $pct,
                    CLAUDE_CODE_AUTO_COMPACT_WINDOW: $win
                }
                + (if $fivebudget == "" then {} else {CLAUDE_5H_TOKEN_BUDGET: $fivebudget} end)
                + (if $wkbudget   == "" then {} else {CLAUDE_WEEKLY_TOKEN_BUDGET: $wkbudget} end)
            ),
            permissions: $perms
        }
        | del(.mcpServers)
        ' "${settings_file}" > "${tmp}"

    # Validate before overwrite — never leave settings.json half-written.
    jq -e . "${tmp}" >/dev/null

    # Idempotent: if the merge is byte-identical to what's already there, do
    # nothing — no backup churn, the existing .bak (your original) is preserved.
    if cmp -s "${tmp}" "${settings_file}"; then
        rm -f "${tmp}"
        echo "  settings.json already current — no change"
        return 0
    fi

    # Back up the about-to-change file (only on a real change).
    cp -p "${settings_file}" "${settings_bak}"
    echo "  backed up → ${settings_bak}"
    mv "${tmp}" "${settings_file}"
    echo "  merged → ${settings_file}"
}

# Configure or remove the atlassian MCP server via the claude CLI at user scope
# (registered in ~/.claude.json, NOT settings.json — Claude Code does not read
# mcpServers from settings.json). Driven by JIRA_MODE, CONFLUENCE_MODE, ATLASSIAN_REMOVE.
applyAtlassian() {
    # --without-atlassian: deregister the server (user scope) and return.
    if [ "${ATLASSIAN_REMOVE}" = "1" ]; then
        command -v claude >/dev/null 2>&1 || {
            echo "  claude CLI not found — cannot remove the atlassian MCP server" >&2
            return 1
        }
        if claude mcp remove atlassian -s user >/dev/null 2>&1; then
            echo "  removed atlassian MCP server (user scope)"
        else
            echo "  atlassian MCP server not registered at user scope — nothing to remove"
        fi
        echo "  credentials file ${atlassian_secrets} left in place — delete manually to clear tokens"
        return
    fi

    [ "${JIRA_MODE}" = "on" ] || [ "${CONFLUENCE_MODE}" = "on" ] || return 0

    command -v docker >/dev/null 2>&1 || {
        echo "  docker not found — the atlassian MCP runs as a container (ghcr.io/sooperset/mcp-atlassian)" >&2
        echo "  install Docker and retry" >&2
        return 1
    }
    command -v claude >/dev/null 2>&1 || {
        echo "  claude CLI not found — needed to register the MCP server (claude mcp add-json)" >&2
        return 1
    }

    # Load whatever is already saved so partial re-runs preserve the other service.
    local jira_url jira_user jira_token jira_filter
    local conf_url conf_user conf_token conf_filter
    if [ -f "${atlassian_secrets}" ]; then
        # shellcheck source=/dev/null
        . "${atlassian_secrets}"
        jira_url="${JIRA_URL:-}"
        jira_user="${JIRA_USERNAME:-}"
        jira_token="${JIRA_API_TOKEN:-}"
        jira_filter="${JIRA_PROJECTS_FILTER:-}"
        conf_url="${CONFLUENCE_URL:-}"
        conf_user="${CONFLUENCE_USERNAME:-}"
        conf_token="${CONFLUENCE_API_TOKEN:-}"
        conf_filter="${CONFLUENCE_SPACES_FILTER:-}"
    fi

    local noninteractive=0
    [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ] && noninteractive=1

    # --- Jira ---
    if [ "${JIRA_MODE}" = "on" ]; then
        if [ "${noninteractive}" = "1" ]; then
            [ -n "${jira_token}" ] || {
                echo "  JIRA_API_TOKEN missing in ${atlassian_secrets} — cannot configure Jira non-interactively" >&2
                return 1
            }
            echo "  Jira: loaded from ${atlassian_secrets}"
        else
            echo ""
            echo "  Jira credentials (saved to generated/.atlassian.env, gitignored)"
            read -r -p "  JIRA_URL [${jira_url:-https://openeyes.atlassian.net}]: " _in
            jira_url="${_in:-${jira_url:-https://openeyes.atlassian.net}}"
            read -r -p "  JIRA_USERNAME [${jira_user:-manpreet.singh@toukanlabs.com}]: " _in
            jira_user="${_in:-${jira_user:-manpreet.singh@toukanlabs.com}}"
            read -r -s -p "  JIRA_API_TOKEN (hidden$([ -n "${jira_token}" ] && echo ', enter to keep existing')): " _in
            echo ""
            [ -n "${_in}" ] && jira_token="${_in}"
            [ -n "${jira_token}" ] || { echo "  JIRA_API_TOKEN cannot be empty" >&2; return 1; }
            read -r -p "  JIRA_PROJECTS_FILTER [${jira_filter:-TKLS,OE}]: " _in
            jira_filter="${_in:-${jira_filter:-TKLS,OE}}"
        fi
    fi

    # --- Confluence ---
    if [ "${CONFLUENCE_MODE}" = "on" ]; then
        if [ "${noninteractive}" = "1" ]; then
            [ -n "${conf_token}" ] || {
                echo "  CONFLUENCE_API_TOKEN missing in ${atlassian_secrets} — cannot configure Confluence non-interactively" >&2
                return 1
            }
            echo "  Confluence: loaded from ${atlassian_secrets}"
        else
            echo ""
            echo "  Confluence credentials (defaults to Jira values where they match)"
            read -r -p "  CONFLUENCE_URL [${conf_url:-${jira_url}}]: " _in
            conf_url="${_in:-${conf_url:-${jira_url}}}"
            read -r -p "  CONFLUENCE_USERNAME [${conf_user:-${jira_user}}]: " _in
            conf_user="${_in:-${conf_user:-${jira_user}}}"
            read -r -s -p "  CONFLUENCE_API_TOKEN (hidden$([ -n "${conf_token}" ] && echo ', enter to keep existing')): " _in
            echo ""
            if [ -n "${_in}" ]; then
                conf_token="${_in}"
            elif [ -z "${conf_token}" ]; then
                conf_token="${jira_token}"
                echo "  (using Jira token for Confluence)"
            fi
            [ -n "${conf_token}" ] || { echo "  CONFLUENCE_API_TOKEN cannot be empty" >&2; return 1; }
            read -r -p "  CONFLUENCE_SPACES_FILTER [${conf_filter:-OPD}]: " _in
            conf_filter="${_in:-${conf_filter:-OPD}}"
        fi
    fi

    # Save all non-empty vars back to the secrets file.
    {
        [ -n "${jira_url}" ]    && echo "JIRA_URL=${jira_url}"
        [ -n "${jira_user}" ]   && echo "JIRA_USERNAME=${jira_user}"
        [ -n "${jira_token}" ]  && echo "JIRA_API_TOKEN=${jira_token}"
        [ -n "${jira_filter}" ] && echo "JIRA_PROJECTS_FILTER=${jira_filter}"
        [ -n "${conf_url}" ]    && echo "CONFLUENCE_URL=${conf_url}"
        [ -n "${conf_user}" ]   && echo "CONFLUENCE_USERNAME=${conf_user}"
        [ -n "${conf_token}" ]  && echo "CONFLUENCE_API_TOKEN=${conf_token}"
        [ -n "${conf_filter}" ] && echo "CONFLUENCE_SPACES_FILTER=${conf_filter}"
    } > "${atlassian_secrets}"
    chmod 600 "${atlassian_secrets}"
    echo "  saved → ${atlassian_secrets}"

    # Build the env object — include whichever service vars are populated.
    local env_json='{}'
    if [ "${JIRA_MODE}" = "on" ]; then
        env_json="$(jq -n \
            --arg url   "${jira_url}" \
            --arg user  "${jira_user}" \
            --arg token "${jira_token}" \
            --arg filt  "${jira_filter}" \
            '{JIRA_URL: $url, JIRA_USERNAME: $user, JIRA_API_TOKEN: $token, JIRA_PROJECTS_FILTER: $filt}')"
    fi
    if [ "${CONFLUENCE_MODE}" = "on" ]; then
        local conf_json
        conf_json="$(jq -n \
            --arg url   "${conf_url}" \
            --arg user  "${conf_user}" \
            --arg token "${conf_token}" \
            --arg filt  "${conf_filter}" \
            '{CONFLUENCE_URL: $url, CONFLUENCE_USERNAME: $user, CONFLUENCE_API_TOKEN: $token, CONFLUENCE_SPACES_FILTER: $filt}')"
        env_json="$(jq -n --argjson a "${env_json}" --argjson b "${conf_json}" '$a + $b')"
    fi
    # Strip empty-string values so mcp-atlassian sees only what's set.
    env_json="$(jq 'with_entries(select(.value != ""))' <<< "${env_json}")"

    # Run via "sh -c" so each new session first force-removes any container left
    # by a prior session of the same fixed name, then exec's its own. At most one
    # mcp-atlassian container ever exists — a new session kills the old one and
    # takes over (newest wins), instead of a fresh random-named container piling
    # up per session. One bare "-e VAR" per set env key (docker reads the value
    # from its own env, which Claude Code populates from the "env" block — so
    # tokens never appear on the command line), then the image.
    local image="ghcr.io/sooperset/mcp-atlassian:latest"
    local cname="claude-mcp-atlassian"
    local run_cmd
    run_cmd="$(jq -rn --argjson env "${env_json}" --arg img "${image}" --arg name "${cname}" \
        '"docker rm -f \($name) >/dev/null 2>&1; exec docker run -i --rm --name \($name) " + ($env | keys | map("-e " + .) | join(" ")) + " " + $img')"

    # Register at user scope via the claude CLI (writes ~/.claude.json so the
    # server auto-loads in every session/project). Remove any prior registration
    # first so re-runs are idempotent — add-json errors if the name already exists.
    local server_json
    server_json="$(jq -n --arg cmd "${run_cmd}" --argjson env "${env_json}" \
        '{command: "sh", args: ["-c", $cmd], env: $env}')"
    claude mcp remove atlassian -s user >/dev/null 2>&1 || true
    claude mcp add-json atlassian "${server_json}" -s user >/dev/null
    echo "  registered atlassian MCP (docker/${image##*/}) at user scope (~/.claude.json)"
    [ "${JIRA_MODE}" = "on" ]       && echo "  Jira projects filter: ${jira_filter}"
    [ "${CONFLUENCE_MODE}" = "on" ] && echo "  Confluence spaces filter: ${conf_filter:-none}"
    echo "  restart Claude Code to pick up the new MCP server"
}

# Configure or remove the github MCP server via the claude CLI at user scope
# (registered in ~/.claude.json, like atlassian). Read-only by construction:
# GITHUB_READ_ONLY=1 is baked in below so the server never exposes write tools —
# the GitHub-API analogue of the never-push/never-commit hard floor. Driven by
# GITHUB_MODE, GITHUB_REMOVE.
applyGitHub() {
    # --without-github: deregister the server (user scope) and return.
    if [ "${GITHUB_REMOVE}" = "1" ]; then
        command -v claude >/dev/null 2>&1 || {
            echo "  claude CLI not found — cannot remove the github MCP server" >&2
            return 1
        }
        if claude mcp remove github -s user >/dev/null 2>&1; then
            echo "  removed github MCP server (user scope)"
        else
            echo "  github MCP server not registered at user scope — nothing to remove"
        fi
        echo "  credentials file ${github_secrets} left in place — delete manually to clear the token"
        return
    fi

    [ "${GITHUB_MODE}" = "on" ] || return 0

    command -v docker >/dev/null 2>&1 || {
        echo "  docker not found — the github MCP runs as a container (ghcr.io/github/github-mcp-server)" >&2
        echo "  install Docker and retry" >&2
        return 1
    }
    command -v claude >/dev/null 2>&1 || {
        echo "  claude CLI not found — needed to register the MCP server (claude mcp add-json)" >&2
        return 1
    }

    # Load whatever is already saved so a re-run can keep the existing token.
    local gh_token gh_toolsets
    if [ -f "${github_secrets}" ]; then
        # shellcheck source=/dev/null
        . "${github_secrets}"
        gh_token="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
        gh_toolsets="${GITHUB_TOOLSETS:-}"
    fi

    local noninteractive=0
    [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ] && noninteractive=1

    if [ "${noninteractive}" = "1" ]; then
        [ -n "${gh_token}" ] || {
            echo "  GITHUB_PERSONAL_ACCESS_TOKEN missing in ${github_secrets} — cannot configure GitHub non-interactively" >&2
            return 1
        }
        echo "  GitHub: loaded from ${github_secrets}"
    else
        echo ""
        echo "  GitHub credentials (saved to generated/.github.env, gitignored)"
        echo "  Use a fine-grained read-only PAT with access to the openeyes org."
        read -r -s -p "  GITHUB_PERSONAL_ACCESS_TOKEN (hidden$([ -n "${gh_token}" ] && echo ', enter to keep existing')): " _in
        echo ""
        [ -n "${_in}" ] && gh_token="${_in}"
        [ -n "${gh_token}" ] || { echo "  GITHUB_PERSONAL_ACCESS_TOKEN cannot be empty" >&2; return 1; }
        read -r -p "  GITHUB_TOOLSETS (optional, blank = server default) [${gh_toolsets}]: " _in
        gh_toolsets="${_in:-${gh_toolsets}}"
    fi

    # Save non-empty vars back to the secrets file.
    {
        [ -n "${gh_token}" ]    && echo "GITHUB_PERSONAL_ACCESS_TOKEN=${gh_token}"
        [ -n "${gh_toolsets}" ] && echo "GITHUB_TOOLSETS=${gh_toolsets}"
    } > "${github_secrets}"
    chmod 600 "${github_secrets}"
    echo "  saved → ${github_secrets}"

    # Build the env object. GITHUB_READ_ONLY=1 is a fixed constant — not sourced
    # from the file — so read-only can never be turned off by editing creds.
    local env_json
    env_json="$(jq -n \
        --arg token "${gh_token}" \
        --arg ts    "${gh_toolsets}" \
        '{GITHUB_PERSONAL_ACCESS_TOKEN: $token, GITHUB_READ_ONLY: "1", GITHUB_TOOLSETS: $ts}')"
    # Strip empty-string values (drops GITHUB_TOOLSETS when unset; READ_ONLY="1" survives).
    env_json="$(jq 'with_entries(select(.value != ""))' <<< "${env_json}")"

    # Run via "sh -c" so each new session first force-removes any container left
    # by a prior session of the same fixed name, then exec's its own. At most one
    # github MCP container ever exists — a new session kills the old one and takes
    # over (newest wins), instead of a fresh random-named container piling up per
    # session. One bare "-e VAR" per set env key (docker reads the value from its
    # own env, which Claude Code populates from the "env" block — so the token
    # never appears on the command line), then the image.
    local image="ghcr.io/github/github-mcp-server"
    local cname="claude-mcp-github"
    local run_cmd
    run_cmd="$(jq -rn --argjson env "${env_json}" --arg img "${image}" --arg name "${cname}" \
        '"docker rm -f \($name) >/dev/null 2>&1; exec docker run -i --rm --name \($name) " + ($env | keys | map("-e " + .) | join(" ")) + " " + $img')"

    # Register at user scope (writes ~/.claude.json). Remove any prior registration
    # first so re-runs are idempotent — add-json errors if the name already exists.
    local server_json
    server_json="$(jq -n --arg cmd "${run_cmd}" --argjson env "${env_json}" \
        '{command: "sh", args: ["-c", $cmd], env: $env}')"
    claude mcp remove github -s user >/dev/null 2>&1 || true
    claude mcp add-json github "${server_json}" -s user >/dev/null
    echo "  registered github MCP (docker/${image##*/}, read-only) at user scope (~/.claude.json)"
    echo "  GitHub toolsets: ${gh_toolsets:-server default}"
    echo "  restart Claude Code to pick up the new MCP server"
}

# Configure or remove the codex MCP server via the claude CLI at user scope
# (registered in ~/.claude.json, like atlassian/github). Docker-first: OpenAI ships
# no official CLI image, so this builds docker/codex/Dockerfile locally as
# claude-kit-codex and runs `codex mcp-server` inside it (~/.codex and the project
# dir bind-mounted, container as the invoking uid so written files stay yours).
# Nothing is ever installed — or suggested for install — on the host; a host
# `codex` binary is used only as the fallback when Docker itself is absent. The
# server exposes the codex / codex-reply tools so Claude can spawn one or more
# autonomous Codex coding agents. Auth is ChatGPT sign-in (stored in ~/.codex),
# so no token is kept here — generated/.codex.env holds only the non-secret model /
# effort / sandbox knobs, baked into the registration as `-c key=value` overrides so
# every spawned agent inherits them. Driven by CODEX_MODE, CODEX_REMOVE.
applyCodex() {
    # --without-codex: deregister the server (user scope) and return.
    if [ "${CODEX_REMOVE}" = "1" ]; then
        command -v claude >/dev/null 2>&1 || {
            echo "  claude CLI not found — cannot remove the codex MCP server" >&2
            return 1
        }
        if claude mcp remove codex -s user >/dev/null 2>&1; then
            echo "  removed codex MCP server (user scope)"
        else
            echo "  codex MCP server not registered at user scope — nothing to remove"
        fi
        echo "  ${codex_secrets}, ~/.codex (your ChatGPT login) and the claude-kit-codex docker image left in place"
        return
    fi

    [ "${CODEX_MODE}" = "on" ] || return 0

    command -v claude >/dev/null 2>&1 || {
        echo "  claude CLI not found — needed to register the MCP server (claude mcp add-json)" >&2
        return 1
    }

    # Docker-first runtime pick. Host codex is only a fallback when Docker itself
    # is missing; when neither exists the fix offered is Docker, never a host install.
    local image="claude-kit-codex" cname="claude-mcp-codex" cx_runtime
    if command -v docker >/dev/null 2>&1; then
        cx_runtime="docker"
    elif command -v codex >/dev/null 2>&1; then
        cx_runtime="host"
        echo "  docker not found — falling back to the host codex binary"
    else
        echo "  docker not found — the codex MCP runs as a container (${image}, built from docker/codex/)" >&2
        echo "  install Docker and re-run with -x" >&2
        return 1
    fi

    if [ "${cx_runtime}" = "docker" ]; then
        # Pre-create ~/.codex user-owned: docker would otherwise create a missing
        # bind-mount source as root and the uid-mapped container couldn't write it.
        mkdir -p "${HOME}/.codex"
        # Local build (no official image) — before the sign-in gate below, which
        # hands out a login command that needs the image. Built once and reused;
        # layer cache makes a rebuild after a Dockerfile edit cheap. --no-cache to
        # pull a newer CLI.
        if docker image inspect "${image}" >/dev/null 2>&1; then
            echo "  docker image ${image} present — reusing (refresh: docker build --no-cache -t ${image} docker/codex/)"
        else
            echo "  building ${image} (node:22-slim + @openai/codex)..."
            docker build -t "${image}" "${codex_docker_dir}" || {
                echo "  docker build failed — codex MCP not registered" >&2
                return 1
            }
        fi
    fi

    # ChatGPT sign-in gate: the server registers regardless, but agent calls fail
    # until ~/.codex holds a login — so on a tty, hand out the login command and
    # wait for the credentials to land before continuing (Enter skips the wait).
    # Checked via the auth file (works for both runtimes); host mode also gets to
    # ask the binary itself.
    local login_cmd="codex login"
    [ "${cx_runtime}" = "docker" ] && login_cmd="docker run --rm -it --network host --user \"\$(id -u):\$(id -g)\" -v \"\$HOME/.codex:/home/codex/.codex\" ${image} login"
    if [ -f "${HOME}/.codex/auth.json" ] || { [ "${cx_runtime}" = "host" ] && codex login status >/dev/null 2>&1; }; then
        echo "  codex: ChatGPT sign-in detected"
    else
        echo "  codex: not signed in — run this in another terminal:" >&2
        echo "    ${login_cmd}" >&2
        if [ -t 0 ]; then
            echo -n "  waiting for ~/.codex/auth.json (Enter = skip and sign in later, Ctrl-C = abort) "
            while [ ! -f "${HOME}/.codex/auth.json" ]; do
                if read -r -t 2 _; then break; fi
                echo -n "."
            done
            if [ -f "${HOME}/.codex/auth.json" ]; then
                echo " detected"
            else
                echo " skipped — agent calls will fail until you sign in"
            fi
        else
            echo "  no tty to wait on — continuing; agent calls will fail until you sign in" >&2
        fi
    fi

    # Load saved knobs (non-secret) so re-runs preserve prior choices.
    local cx_model cx_effort cx_sandbox
    if [ -f "${codex_secrets}" ]; then
        # shellcheck source=/dev/null
        . "${codex_secrets}"
        cx_model="${CODEX_MODEL:-}"
        cx_effort="${CODEX_REASONING_EFFORT:-}"
        cx_sandbox="${CODEX_SANDBOX:-}"
    fi
    # Defaults: flagship model, high reasoning, workspace-write (network off → no push).
    cx_model="${cx_model:-gpt-5.5}"
    cx_effort="${cx_effort:-high}"
    cx_sandbox="${cx_sandbox:-workspace-write}"

    local noninteractive=0
    [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ] && noninteractive=1

    if [ "${noninteractive}" = "1" ]; then
        echo "  Codex: model=${cx_model} effort=${cx_effort} sandbox=${cx_sandbox} (from ${codex_secrets} / defaults)"
    else
        echo ""
        echo "  Codex agent defaults (non-secret; saved to generated/.codex.env)"
        read -r -p "  CODEX_MODEL [${cx_model}]: " _in
        cx_model="${_in:-${cx_model}}"
        read -r -p "  CODEX_REASONING_EFFORT (minimal|low|medium|high|xhigh) [${cx_effort}]: " _in
        cx_effort="${_in:-${cx_effort}}"
        if [ "${cx_runtime}" = "host" ]; then
            read -r -p "  CODEX_SANDBOX (read-only|workspace-write|danger-full-access) [${cx_sandbox}]: " _in
            cx_sandbox="${_in:-${cx_sandbox}}"
        fi
    fi

    # In docker mode the CONTAINER is the sandbox: only the project dir and ~/.codex
    # are mounted (no git creds), the rootfs dies with --rm. codex's own bwrap
    # sandbox cannot start inside Docker (user-namespace/loopback EPERM even
    # privileged), so every inner mode except danger-full-access would break agent
    # runs — pin it at launch. CODEX_SANDBOX is still saved for the host fallback.
    local cx_sandbox_launch="${cx_sandbox}"
    if [ "${cx_runtime}" = "docker" ]; then
        cx_sandbox_launch="danger-full-access"
        echo "  sandbox: the container itself (codex inner sandbox off — writes confined to the mounted project dir)"
    fi

    # Save knobs back (no secrets — auth lives in ~/.codex).
    {
        echo "CODEX_MODEL=${cx_model}"
        echo "CODEX_REASONING_EFFORT=${cx_effort}"
        echo "CODEX_SANDBOX=${cx_sandbox}"
    } > "${codex_secrets}"
    chmod 600 "${codex_secrets}"
    echo "  saved → ${codex_secrets}"

    # Build the launch args: `codex mcp-server` plus `-c key=value` config overrides
    # that become the default for every spawned agent. TOML strings are quoted so the
    # parser treats e.g. gpt-5.5 as a string, not a malformed number. approval_policy
    # =never keeps agents non-interactive; for host workspace-write we also pin network
    # off so an agent can never `git push` (the API analogue of the never-push floor);
    # in docker mode push dies instead on the credential-free container.
    local args_json
    args_json="$(jq -n \
        --arg model   "${cx_model}" \
        --arg effort  "${cx_effort}" \
        --arg sandbox "${cx_sandbox_launch}" \
        '
        ["mcp-server",
         "-c", ("model=\"" + $model + "\""),
         "-c", ("model_reasoning_effort=\"" + $effort + "\""),
         "-c", ("sandbox_mode=\"" + $sandbox + "\""),
         "-c", "approval_policy=\"never\""]
        + (if $sandbox == "workspace-write"
           then ["-c", "sandbox_workspace_write.network_access=false"]
           else [] end)
        ')"

    local run_cmd
    if [ "${cx_runtime}" = "docker" ]; then
        # Same "--name + rm -f" reuse as github/atlassian: one codex MCP container,
        # newest session wins. $HOME/$PWD/$(id …) are escaped so they expand when
        # Claude Code launches the server — the container then runs as the invoking
        # user with only ~/.codex (auth, into the image HOME) and the project dir
        # (same path, as workdir) mounted; codex's own args are @sh-quoted so the
        # TOML string quotes survive.
        run_cmd="$(jq -rn --argjson a "${args_json}" --arg img "${image}" --arg name "${cname}" \
            '"docker rm -f \($name) >/dev/null 2>&1; mkdir -p \"$HOME/.codex\"; exec docker run -i --rm --name \($name) --user \"$(id -u):$(id -g)\" -v \"$HOME/.codex:/home/codex/.codex\" -v \"$PWD:$PWD\" -w \"$PWD\" \($img) " + ($a | map(@sh) | join(" "))')"
    else
        # Host fallback: run via "sh -c" so each new session first reaps any leftover
        # codex MCP server process before exec'ing its own — the process-level
        # analogue of the docker "--name + rm -f" reuse. We match the
        # "codex mcp-server" cmdline and skip our own shell via $$; matching on
        # "mcp-server" leaves an interactive `codex` untouched. Each arg is @sh-quoted
        # so the shell hands codex the exact same argv (TOML string quotes intact).
        run_cmd="$(jq -rn --argjson a "${args_json}" \
            '"for p in $(pgrep -f \"codex mcp-server\"); do [ \"$p\" != \"$$\" ] && kill \"$p\" 2>/dev/null; done; exec codex " + ($a | map(@sh) | join(" "))')"
    fi

    # Register at user scope (writes ~/.claude.json). Remove any prior registration
    # first so re-runs are idempotent — add-json errors if the name already exists.
    local server_json
    server_json="$(jq -n --arg cmd "${run_cmd}" '{command: "sh", args: ["-c", $cmd]}')"
    claude mcp remove codex -s user >/dev/null 2>&1 || true
    claude mcp add-json codex "${server_json}" -s user >/dev/null
    if [ "${cx_runtime}" = "docker" ]; then
        echo "  registered codex MCP (docker/${image}, codex mcp-server) at user scope (~/.claude.json)"
    else
        echo "  registered codex MCP (host codex mcp-server) at user scope (~/.claude.json)"
    fi
    if [ "${cx_runtime}" = "docker" ]; then
        echo "  model=${cx_model}  effort=${cx_effort}  sandbox=container (project dir + ~/.codex mounted, no creds)"
    else
        echo "  model=${cx_model}  effort=${cx_effort}  sandbox=${cx_sandbox}$([ "${cx_sandbox}" = "workspace-write" ] && echo ' (network off)')"
    fi
    echo "  restart Claude Code to pick up the new MCP server"
}

# -s/--skills-auto: flip the model-invocation gate on every kit skill in place.
# The SKILL.md files are live symlink targets, so the change reaches ~/.claude
# with no re-link — but skills bind at session start, so a restart is needed.
# Only an existing disable-model-invocation line inside the frontmatter is
# rewritten (true→false for on, false→true for off); skills that never carried
# the flag (the deliberate auto-load set) are untouched in both directions, so
# 'off' restores exactly the per-skill state 'on' started from. Runs every
# install — SKILLS_AUTO defaults to off, so a plain run undoes a prior -s on.
applySkillsInvocation() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit — skipped"; return 0; }
    local from to
    if [ "${SKILLS_AUTO}" = "on" ]; then
        from="true"; to="false"
    else
        from="false"; to="true"
    fi
    local f changed=0
    for f in "${skills_src_dir}"/*/SKILL.md; do
        [ -f "${f}" ] || continue
        # Restrict matching and rewriting to the frontmatter block (line 2 up to
        # the closing ---), so a literal mention in a skill body is never touched.
        if sed -n "2,/^---\$/p" "${f}" | grep -q "^disable-model-invocation: ${from}\$"; then
            sed -i "2,/^---\$/ s/^disable-model-invocation: ${from}\$/disable-model-invocation: ${to}/" "${f}"
            echo "  ${from}→${to}  ${f#"${kit_root}"/}"
            changed=$((changed+1))
        fi
    done
    if [ "${changed}" -eq 0 ]; then
        if [ "${SKILLS_AUTO}" = "on" ]; then
            echo "  all flagged skills already auto-invokable — no change"
        else
            echo "  all flagged skills already manual — no change"
        fi
    else
        echo "  flipped ${changed} skill(s) to auto-invocation ${SKILLS_AUTO}"
        echo "  restart Claude Code to pick up the change (skills bind at session start)"
    fi
}

# Adopt every real ~/.claude/projects/<slug>/memory dir into the kit
# (memory/<slug>/) and symlink it back, so memories are git-tracked like
# everything else — every commit is a versioned backup, and edits stay live
# through the link. Runs every install, idempotent, mirroring syncSkills'
# safety floors: a correct link is left alone, a foreign symlink is skipped
# with a warning, and when both a real dir and a kit dir exist nothing is
# merged silently. Project slugs start with '-' — hence the -- guards.
syncMemory() {
    mkdir -p "${memory_src_dir}"
    local proj slug live kitmem raw

    # 1. Adoption pass — move real memory dirs into the kit.
    for proj in "${claude_dir}/projects"/*/; do
        [ -d "${proj}" ] || continue
        live="${proj}memory"
        slug="$(basename "${proj}")"
        kitmem="${memory_src_dir}/${slug}"
        if [ -d "${live}" ] && [ ! -L "${live}" ]; then
            if [ -e "${kitmem}" ]; then
                echo "  WARNING: both ${live} and ${kitmem} exist — not merging; resolve by hand" >&2
                continue
            fi
            mv -- "${live}" "${kitmem}"
            echo "  adopted → ${kitmem} (was ${live})"
        fi
    done

    # 2. Link pass — every kit memory dir gets its projects/<slug>/memory link
    # (re-created after --fresh, or on a machine that's never seen the project).
    for kitmem in "${memory_src_dir}"/*/; do
        [ -d "${kitmem}" ] || continue
        kitmem="${kitmem%/}"
        slug="$(basename "${kitmem}")"
        live="${claude_dir}/projects/${slug}/memory"
        if [ -L "${live}" ]; then
            raw="$(readlink "${live}")"
            if [ "${raw}" = "${kitmem}" ]; then
                continue                      # already correct
            elif [ ! -e "${live}" ] || [ "${raw#"${memory_src_dir}"/}" != "${raw}" ]; then
                rm -f -- "${live}"            # dangling, or stale link into this kit
            else
                echo "  skip  → ${live} (foreign symlink — leaving alone)"
                continue
            fi
        elif [ -e "${live}" ]; then
            continue                          # real dir alongside a kit dir — warned in pass 1
        fi
        mkdir -p "${claude_dir}/projects/${slug}"
        ln -s -- "${kitmem}" "${live}"
        echo "  link  → ${live} → ${kitmem}"
    done
}

# Rebuild ~/.claude/skills/<name> symlinks from scratch on every run, and keep an
# explicit record (${skills_manifest}) of which skills install.sh created — so a
# skill deleted from the kit has its link removed from ~/.claude on the next run.
#
# Pruning is two-pronged, and BOTH passes only ever remove symlinks — a real
# directory you dropped in by hand, or a foreign symlink you made yourself, is
# never touched, so skills added directly (outside claude-kit) always survive:
#   1a. Manifest pass — any skill recorded as kit-installed that is no longer in
#       the kit gets its link removed, even if the kit has since moved and the
#       link now dangles to a stale path (which the target pass can't match).
#   1b. Target pass   — also drop any symlink still pointing into this kit's
#       skills/ dir: catches links from installs predating the manifest, and
#       skills renamed within the kit.
# Step 2 then (re)creates a fresh symlink for every skill currently in the kit and
# rewrites the manifest to that exact set (the source of truth for 1a next run).
syncSkills() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit — skipped"; return 0; }
    mkdir -p "${claude_skills_dir}"

    # 1a. Manifest pass — remove links for kit skills that have since been deleted.
    if [ -f "${skills_manifest}" ]; then
        local prev mdst
        while IFS= read -r prev; do
            [ -n "${prev}" ] || continue
            [ -d "${skills_src_dir}/${prev}" ] && continue   # still in the kit → keep (re-linked below)
            mdst="${claude_skills_dir}/${prev}"
            if [ -L "${mdst}" ]; then
                rm -f "${mdst}"
                echo "  unlink→ ${mdst} (removed from kit)"
            fi
        done < "${skills_manifest}"
    fi

    # 1b. Target pass — drop any symlink that points into this kit's skills/.
    local dst raw
    for dst in "${claude_skills_dir}"/*; do
        [ -L "${dst}" ] || continue
        raw="$(readlink "${dst}")"
        case "${raw}" in
            "${skills_src_dir}"/*)
                rm -f "${dst}"
                echo "  unlink→ ${dst}"
                ;;
        esac
    done

    # 2. (Re)create a symlink for every skill currently in the kit, recording the
    #    ones we manage into a freshly-rewritten manifest.
    local src name
    : > "${skills_manifest}"
    for src in "${skills_src_dir}"/*/; do
        [ -d "${src}" ] || continue
        name="$(basename "${src}")"
        dst="${claude_skills_dir}/${name}"
        # A leftover here is a real dir or a foreign symlink (not ours — 1a/1b
        # removed every kit-managed link) — leave it, and don't claim it in the
        # manifest, so a hand-added skill is never pruned on a later run.
        if [ -L "${dst}" ] || [ -e "${dst}" ]; then
            echo "  skip  → ${dst} (exists and not kit-managed — leaving alone)"
            continue
        fi
        ln -s "${src%/}" "${dst}"
        echo "  link  → ${dst}"
        printf '%s\n' "${name}" >> "${skills_manifest}"
    done
}

# Symlink ~/.claude/CLAUDE.md → the kit's claude-md/CLAUDE.md, so the live global
# guidelines always track the kit (their source of truth). Same idiom as the
# statusline and skill symlinks. A pre-existing real file (e.g. from an older
# copy-install or hand edits) is backed up to *.bak before being replaced by the
# link; an already-correct link is left untouched. Assumes the kit stays put — a
# moved or deleted repo leaves a dangling link.
writeClaudeMd() {
    [ -f "${claude_md_src}" ] || { echo "  missing kit source: ${claude_md_src}" >&2; return 1; }
    # Idempotent: already the right symlink → nothing to do.
    if [ -L "${claude_md_file}" ] && [ "$(readlink "${claude_md_file}")" = "${claude_md_src}" ]; then
        echo "  ~/.claude/CLAUDE.md already linked — no change"
        return 0
    fi
    # Replacing a real file (older copy-install or hand-written) — back it up first.
    if [ -e "${claude_md_file}" ] && [ ! -L "${claude_md_file}" ]; then
        cp -p "${claude_md_file}" "${claude_md_bak}"
        echo "  backed up → ${claude_md_bak}"
    fi
    ln -sfn "${claude_md_src}" "${claude_md_file}"
    echo "  linked    → ${claude_md_file} → ${claude_md_src}"
}

# Shift+Enter for newline is now merged from settings/shift-enter.json by writeSettings().
# Some terminals (Apple Terminal.app, certain tmux configs) still need a one-off
# /terminal-setup inside Claude Code to bind the key sequence — print a hint.
shiftEnterHint() {
    cat <<'TS_EOF'
  shift-enter.json fragment merged into settings.json. If Shift+Enter still
  doesn't insert a newline in your terminal, run /terminal-setup once inside
  an interactive Claude Code session, or bind Shift+Enter to send \n in your
  terminal's key settings. \ at end of line or Option/Alt+Enter also work.
TS_EOF
}

# Verification block — the 6 checks from the brief, plus (7) a conditional codex
# MCP check that only asserts when -x/-X was passed this run.
verifyAll() {
    local failed=0
    echo ""
    echo "Verification checks"
    echo "-------------------------------"

    # 1. statusLine
    if [ "$(jq -r '.statusLine // empty' "${settings_file}")" != "" ]; then
        echo "[PASS] (1) statusLine configured"
    else
        echo "[FAIL] (1) statusLine missing"; failed=1
    fi

    # 2. terminal-setup — not script-forceable; mark INFO not FAIL.
    echo "[INFO] (2) /terminal-setup not script-forceable; fallback printed above"

    # 3. rule-set present with the separately-resolved defaultMode (MODE)
    local mode
    mode="$(jq -r '.permissions.defaultMode // empty' "${settings_file}")"
    if [ "${mode}" = "${MODE}" ]; then
        echo "[PASS] (3) tier '${PERMISSIONS}' rules + mode '${MODE}' applied (defaultMode=${mode})"
    else
        echo "[FAIL] (3) defaultMode mismatch (have='${mode}', want='${MODE}')"; failed=1
    fi

    # 4. autocompact env vars
    local pct win
    pct="$(jq -r '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE // empty' "${settings_file}")"
    win="$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // empty' "${settings_file}")"
    if [ -n "${pct}" ] && [ -n "${win}" ]; then
        echo "[PASS] (4) auto-compact env vars set (${pct}%, ${win} tokens)"
    else
        echo "[FAIL] (4) auto-compact env vars missing (pct='${pct}', win='${win}')"; failed=1
    fi

    # 5. git deny rules — required on every tier (hard floor, yolo included)
    local has_push has_commit
    has_push=$(jq '[.permissions.deny[]? | select(. == "Bash(git push *)")] | length' "${settings_file}")
    has_commit=$(jq '[.permissions.deny[]? | select(. == "Bash(git commit *)")] | length' "${settings_file}")
    if [ "${has_push}" -ge 1 ] && [ "${has_commit}" -ge 1 ]; then
        echo "[PASS] (5) git push + git commit denied"
    else
        echo "[FAIL] (5) git deny rules incomplete (push=${has_push}, commit=${has_commit})"; failed=1
    fi

    # 6. CLAUDE.md matches kit source byte-for-byte
    if [ -f "${claude_md_file}" ] && cmp -s "${claude_md_file}" "${claude_md_src}"; then
        echo "[PASS] (6) ~/.claude/CLAUDE.md matches kit source"
    else
        echo "[FAIL] (6) ~/.claude/CLAUDE.md differs from ${claude_md_src}"; failed=1
    fi

    # 7. codex MCP server — only meaningful when -x/-X was passed this run. The
    # registration lives in ~/.claude.json (user scope), so we ask the claude CLI
    # rather than reading settings.json. INFO (not FAIL) when codex wasn't touched.
    local codex_registered=1
    command -v claude >/dev/null 2>&1 && claude mcp get codex >/dev/null 2>&1 || codex_registered=0
    if [ "${CODEX_MODE}" = "on" ]; then
        if [ "${codex_registered}" -eq 1 ]; then
            echo "[PASS] (7) codex MCP server registered (user scope)"
        else
            echo "[FAIL] (7) codex MCP server not registered after -x"; failed=1
        fi
    elif [ "${CODEX_REMOVE}" = "1" ]; then
        if [ "${codex_registered}" -eq 0 ]; then
            echo "[PASS] (7) codex MCP server deregistered after -X"
        else
            echo "[FAIL] (7) codex MCP server still registered after -X"; failed=1
        fi
    else
        echo "[INFO] (7) codex not requested this run (-x/-X); skipping"
    fi

    # 8. cleanupPeriodDays — Claude Code's own transcript retention, written by
    # writeSettings on every run (default 365; its built-in default is only 30).
    local cpd
    cpd="$(jq -r '.cleanupPeriodDays // empty' "${settings_file}")"
    if [ "${cpd}" = "${CLEANUP_PERIOD_DAYS}" ]; then
        echo "[PASS] (8) cleanupPeriodDays=${cpd}"
    else
        echo "[FAIL] (8) cleanupPeriodDays mismatch (have='${cpd}', want='${CLEANUP_PERIOD_DAYS}')"; failed=1
    fi

    # 9. statusLine.refreshInterval — timer refresh on top of event-driven updates
    # (0 = key absent, event-driven only).
    local slr want_slr
    slr="$(jq -r '.statusLine.refreshInterval // "0"' "${settings_file}")"
    want_slr="${STATUSLINE_REFRESH}"
    if [ "${slr}" = "${want_slr}" ]; then
        echo "[PASS] (9) statusLine.refreshInterval=${slr}s"
    else
        echo "[FAIL] (9) statusLine.refreshInterval mismatch (have='${slr}', want='${want_slr}')"; failed=1
    fi

    echo "-------------------------------"
    if [ "${failed}" -eq 0 ]; then
        echo "All scriptable checks passed."
    else
        echo "One or more checks failed — see above." >&2
        return 1
    fi
}

printSummary() {
    echo ""
    echo "Summary"
    echo "-------------------------------"
    echo "  tier        : ${PERMISSIONS}  (allow/ask/deny rule-set)"
    echo "  mode        : ${MODE}  (permissions.defaultMode)"
    echo "  settings    : ${settings_file}  (backup: ${settings_bak})"
    echo "  statusline  : ${statusline_file}  (symlinked from ${statusline_src}; refresh $([ "${STATUSLINE_REFRESH}" = "0" ] && echo 'on events only' || echo "every ${STATUSLINE_REFRESH}s + events"))"
    echo "  guidelines  : ${claude_md_file}  (symlinked from ${claude_md_src})"
    echo "  skills      : ${claude_skills_dir}/  (symlinked from ${skills_src_dir})"
    echo "  memory      : ${claude_dir}/projects/<project>/memory  (symlinked from ${memory_src_dir})"
    echo "  generated   : ${generated_dir}/  (machine-local creds/config; gitignored, back this up)"
    echo "  autocompact : ${AUTOCOMPACT_PCT}% / ${AUTOCOMPACT_WINDOW} tokens"
    echo "  retention   : cleanupPeriodDays=${CLEANUP_PERIOD_DAYS}"
    echo "-------------------------------"
}

##################################################
################# EXECUTION ######################
##################################################

echo ""
if [ "${DO_RESET}" = "1" ] && [ "${DO_FRESH}" != "1" ]; then
    echo "Resetting ~/.claude (archiving bloat, preserving auth/history/projects)..."
    resetBloat
    echo -e "[Done]\n"
fi

echo "Updating Claude Code CLI (claude update)..."
updateClaude
echo -e "[Done]\n"

echo "Ensuring settings.json exists..."
ensureSettings
echo -e "[Done]\n"

echo "Ensuring generated-config folder exists..."
ensureGenerated
echo -e "[Done]\n"

echo "Writing statusline script..."
writeStatusline
echo -e "[Done]\n"

echo "Merging statusLine + env + permissions into settings.json..."
writeSettings
echo -e "[Done]\n"

echo "Writing ~/.claude/CLAUDE.md from kit source..."
writeClaudeMd
echo -e "[Done]\n"

if [ "${JIRA_MODE}" = "on" ] || [ "${CONFLUENCE_MODE}" = "on" ] || [ "${ATLASSIAN_REMOVE}" = "1" ]; then
    echo "Applying Atlassian MCP settings..."
    applyAtlassian
    echo -e "[Done]\n"
fi

if [ "${GITHUB_MODE}" = "on" ] || [ "${GITHUB_REMOVE}" = "1" ]; then
    echo "Applying GitHub MCP settings..."
    applyGitHub
    echo -e "[Done]\n"
fi

if [ "${CODEX_MODE}" = "on" ] || [ "${CODEX_REMOVE}" = "1" ]; then
    echo "Applying Codex MCP settings..."
    applyCodex
    echo -e "[Done]\n"
fi

echo "Ensuring skill auto-invocation state (${SKILLS_AUTO})..."
applySkillsInvocation
echo -e "[Done]\n"

echo "Linking skills into ~/.claude/skills/..."
syncSkills
echo -e "[Done]\n"

echo "Syncing project memory into the kit (memory/)..."
syncMemory
echo -e "[Done]\n"

if [ -n "${PRUNE_BEFORE}" ]; then
    echo "Pruning conversations last active before the cutoff..."
    pruneSessions
    echo -e "[Done]\n"
fi

echo "Shift+Enter / terminal setup..."
shiftEnterHint
echo -e "[Done]\n"

printSummary

if [ "${DO_VERIFY}" = "1" ]; then
    verifyAll
fi

trap : 0
echo >&2 ""
echo >&2 "**************************************************"
echo >&2 "*************** INSTALL COMPLETE *****************"
echo >&2 "**************************************************"
exit 0
