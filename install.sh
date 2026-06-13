#!/bin/bash -l
# Manpreet 24/05/2026
# claude-kit installer — configures Claude Code per the handoff brief.
# Writes ~/.claude/settings.json (statusLine, env, permissions) and
# wholesale-writes ~/.claude/CLAUDE.md from claude-md/CLAUDE.md in this kit.
# Idempotent: safe to re-run. settings.json/CLAUDE.md are backed up to *.bak
# only when the new content actually differs, so a no-op re-run never clobbers a
# good backup — your auth, history.jsonl and projects/ are never touched.
# Skill symlinks are torn down and rebuilt every run (stale/renamed links pruned;
# real directories left alone). If ~/.claude is absent, Claude Code is installed
# from scratch first, then this kit's config is laid down on top.

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
PERMISSIONS=""                                  # safe | standard | trusted | yolo
AUTOCOMPACT_PCT="${AUTOCOMPACT_PCT:-90}"        # compact trigger %, clamped to ~83
AUTOCOMPACT_WINDOW="${AUTOCOMPACT_WINDOW:-200000}"  # effective window (tokens)
FIVE_HOUR_BUDGET="${FIVE_HOUR_BUDGET:-}"        # tokens/5h, surfaced as % in status line; unset = raw count
WEEKLY_BUDGET="${WEEKLY_BUDGET:-}"              # tokens/week (rolling 7d), surfaced as % in status line; unset = raw count
ASSUME_YES=0                                    # -y: accept default tier non-interactively
DO_VERIFY=1                                     # --no-verify: skip the 6 checks
DO_RESET=0                                      # --reset: archive bloat then install
JIRA_MODE=""                                    # -j / --with-jira / "" (leave alone)
CONFLUENCE_MODE=""                              # -c / --with-confluence / "" (leave alone)
ATLASSIAN_REMOVE=0                              # --without-atlassian sets to 1
GITHUB_MODE=""                                  # -g / --with-github / "" (leave alone)
GITHUB_REMOVE=0                                 # --without-github sets to 1

# Argument parsing ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -[!-]?*)
        # Bundled short flags: explode -jc into -j -c (a single dash followed
        # by 2+ chars, never a --long form). A value-taking flag like -p must be
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
        PERMISSIONS="${2}"
        shift
        ;;
    -y | --yes)
        ASSUME_YES=1
        ;;
    -n | --no-verify)
        DO_VERIFY=0
        ;;
    -r | --reset)
        DO_RESET=1
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
    -h | --help)
        cat <<'USAGE'
Usage: install.sh [-p <safe|standard|trusted|yolo>] [-r] [-n] [-y]
                  [-j] [-c] [-a | -A] [-g | -G]

  Every option has a single-letter (-x) and a long (--word) form.
  Short flags may be bundled: -jc == -j -c (value-taking -p must be last).

  -p, --permissions   Permission tier to install (default: standard).
                      safe      = read-mostly; ask before edits/writes/shell.
                      standard  = day-to-day; auto-accept edits; ask for shell.
                      trusted   = dontAsk; nothing prompts but deny still wins.
                      yolo      = dontAsk; only git push/commit + rm -rf
                                  denies remain (secrets reads ALLOWED).
                                  Container/VM only — see docs/sandbox.md.
  -r, --reset         Archive Claude Code's auto-generated state directories
                      (file-history, paste-cache, backups, shell-snapshots,
                      stats-cache, session-env, plugins, tasks) into
                      ~/.claude-backups/<timestamp>/, then run the install.
                      Auth (.credentials.json), history.jsonl, and projects/
                      are preserved in place.
  -j, --with-jira     Configure the Jira section of the mcp-atlassian stdio
                      server. Prompts for JIRA_URL, JIRA_USERNAME,
                      JIRA_API_TOKEN, JIRA_PROJECTS_FILTER; saves to
                      settings/.atlassian.env (gitignored). With -y, reads the
                      env file silently instead of prompting.
  -c, --with-confluence
                      Configure the Confluence section of the mcp-atlassian
                      stdio server. Prompts for CONFLUENCE_URL,
                      CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN,
                      CONFLUENCE_SPACES_FILTER; defaults to Jira values where
                      they match. Saves to settings/.atlassian.env.
  -a, --with-atlassian
                      Shorthand for -j -c (configure both).
  -A, --without-atlassian
                      Deregister the atlassian MCP server (claude mcp remove,
                      user scope). Credentials file is left in place.
  -g, --with-github   Configure the read-only github-mcp-server stdio server.
                      Prompts for GITHUB_PERSONAL_ACCESS_TOKEN (a fine-grained
                      read-only PAT) and an optional GITHUB_TOOLSETS filter;
                      saves to settings/.github.env (gitignored). Read-only is
                      enforced (GITHUB_READ_ONLY=1) and is NOT configurable —
                      the server never exposes write tools. With -y, reads the
                      env file silently instead of prompting.
  -G, --without-github
                      Deregister the github MCP server (claude mcp remove,
                      user scope). Credentials file is left in place.
  -y, --yes           Non-interactive; accept default tier if not provided.
                      With -j/-c, reads settings/.atlassian.env instead of
                      prompting (errors if the file or required vars are absent).
                      With -g, reads settings/.github.env the same way.
  -n, --no-verify     Skip the 6 verification checks after writing.
  -h, --help          This message.

Env overrides:
  AUTOCOMPACT_PCT      (default 90)      % capacity at which auto-compact triggers.
  AUTOCOMPACT_WINDOW   (default 200000)  effective context window in tokens.
  FIVE_HOUR_BUDGET     (unset)           tokens/5h budget — status line shows 5h N%
                                         instead of a raw count. e.g. FIVE_HOUR_BUDGET=2000000
  WEEKLY_BUDGET        (unset)           tokens/week (rolling 7d) — status line shows wk N%
                                         instead of a raw count. e.g. WEEKLY_BUDGET=20000000
USAGE
        trap : 0
        exit 0
        ;;
    *)
        echo "Invalid Parameter '${p}' ... exiting" && exit 1
        ;;
    esac
    shift
done

# Portable paths -----------------------------------------------------------
kit_root="$(dirname "$(realpath "$0")")"
permissions_dir="${kit_root}/settings/permissions"
shift_enter_file="${kit_root}/settings/shift-enter.json"
atlassian_secrets="${kit_root}/settings/.atlassian.env"
github_secrets="${kit_root}/settings/.github.env"
skills_src_dir="${kit_root}/skills"
claude_md_src="${kit_root}/claude-md/CLAUDE.md"
claude_dir="${HOME}/.claude"
claude_skills_dir="${claude_dir}/skills"
settings_file="${claude_dir}/settings.json"
settings_bak="${settings_file}.bak"
claude_md_file="${claude_dir}/CLAUDE.md"
claude_md_bak="${claude_md_file}.bak"
statusline_file="${claude_dir}/statusline.sh"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking for jq..."
command -v jq >/dev/null 2>&1 || { echo "jq not found. Install jq (apt install jq) and retry." >&2; exit 1; }
echo "[OK]"

echo "Checking for an existing Claude install (~/.claude)..."
if [ ! -d "${claude_dir}" ]; then
    echo "  ~/.claude not found — this looks like a fresh machine."
    echo "  Installing Claude Code from scratch..."
    command -v curl >/dev/null 2>&1 || { echo "curl not found. Install curl (apt install curl) and retry." >&2; exit 1; }
    curl -fsSL https://claude.ai/install.sh | bash
    echo "  [OK] Claude Code installed"
else
    echo "  found — leaving existing ~/.claude (auth, history, projects/) untouched"
fi
echo "[OK]"

echo "Ensuring ${claude_dir} exists..."
mkdir -p "${claude_dir}"
echo "[OK]"

echo "Resolving permission tier..."
if [ -z "${PERMISSIONS}" ]; then
    if [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ]; then
        PERMISSIONS="standard"
    else
        echo "Choose permission tier: [1] safe  [2] standard (default)  [3] trusted  [4] yolo"
        read -r -p "Selection [2]: " choice
        case "${choice}" in
            1|safe)     PERMISSIONS="safe" ;;
            3|trusted)  PERMISSIONS="trusted" ;;
            4|yolo)     PERMISSIONS="yolo" ;;
            *)          PERMISSIONS="standard" ;;
        esac
    fi
fi
case "${PERMISSIONS}" in
    safe|standard|trusted|yolo) echo "Tier: ${PERMISSIONS} [OK]" ;;
    *) echo "Invalid tier '${PERMISSIONS}' — must be safe|standard|trusted|yolo" >&2; exit 1 ;;
esac
if [ "${PERMISSIONS}" = "yolo" ]; then
    echo "  WARNING: 'yolo' tier allows reads of .env/.ssh without prompting."
    echo "           (git push/commit + rm -rf are still denied — hard floor.)"
    echo "           Run only inside a throwaway container/VM. See docs/sandbox.md."
fi

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

# Write ~/.claude/statusline.sh (chmod +x).
# Segments: ⛭ model · dir · 5h <pct|count> · wk <pct|count>
# 5h + wk are computed by summing token usage in ~/.claude/projects/*.jsonl over
# a 5-hour and 7-day rolling window (UTC). Budgets in settings.json.env turn the
# segments into percentages; unset = raw count. The figures are a LOCAL PROXY —
# Claude Code's GUI percentage comes from Anthropic rate-limit headers held
# in-memory and won't match exactly; this bar is the best a status-line
# subprocess can do without API access.
writeStatusline() {
    cat > "${statusline_file}" <<'SL_EOF'
#!/usr/bin/env bash
# Renders the Claude Code status line.
# Bar: ⛭ <model> · <dir> · [<effort> · ] 5h <pct|count> · wk <pct|count>
# Token usage is summed from JSONL transcripts under ~/.claude/projects.
# This is a local proxy; Claude Code's GUI figure (from Anthropic rate-limit
# headers) won't match exactly.
# Effort comes from $CLAUDE_EFFORT (in-session current) or the persisted
# .effortLevel in ~/.claude/settings.json; segment is omitted if neither is set.
# Optional budgets (set in settings.json.env by install.sh):
#   CLAUDE_5H_TOKEN_BUDGET      → 5h segment shows percentage instead of raw count
#   CLAUDE_WEEKLY_TOKEN_BUDGET  → wk segment shows percentage instead of raw count

set -u
input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"')
dir=$(printf '%s' "$input"  | jq -r '.workspace.current_dir // .cwd // "."')
dir=$(basename "$dir")

projects_dir="${HOME}/.claude/projects"

# Sum input + output + cache_creation for assistant lines whose timestamp is
# >= the ISO cutoff. Cache *reads* are intentionally excluded — they're billed
# at ~10% rate and would inflate the tally past anything actionable. The
# find-prefilter (-mmin/-mtime) keeps the walk cheap; jq errors on malformed
# lines are swallowed so a single bad line never breaks the status line.
sum_tokens_since() {
    local cutoff_iso="$1" find_filter="$2"
    [ -d "${projects_dir}" ] || { echo 0; return; }
    # shellcheck disable=SC2086
    find "${projects_dir}" -type f -name '*.jsonl' ${find_filter} -print0 2>/dev/null \
      | xargs -0 -r cat 2>/dev/null \
      | jq -r --arg since "${cutoff_iso}" '
          select(.type == "assistant"
                 and (.timestamp // "") >= $since
                 and (.message.usage? // null) != null)
          | (.message.usage.input_tokens // 0)
            + (.message.usage.output_tokens // 0)
            + (.message.usage.cache_creation_input_tokens // 0)
        ' 2>/dev/null \
      | awk '{s+=$1} END {print s+0}'
}

# Cached recompute: avoid scanning hundreds of MB of JSONLs on every render.
# 5h window refreshes every 30s; weekly every 5min — both vastly shorter
# than the windows themselves, so freshness loss is negligible.
cached_tokens_since() {
    local cutoff_iso="$1" find_filter="$2" cache_key="$3" ttl_sec="$4"
    local cache_file="/tmp/claude-statusline-${cache_key}-$(id -u).cache"
    if [ -f "${cache_file}" ]; then
        local age
        age=$(( $(date +%s) - $(stat -c %Y "${cache_file}" 2>/dev/null || echo 0) ))
        if [ "${age}" -lt "${ttl_sec}" ]; then
            cat "${cache_file}"
            return
        fi
    fi
    local val
    val=$(sum_tokens_since "${cutoff_iso}" "${find_filter}")
    printf '%s' "${val}" > "${cache_file}"
    printf '%s' "${val}"
}

cutoff_5h=$(date -u -d '5 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '')
cutoff_wk=$(date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '')

tokens_5h=0
tokens_wk=0
[ -n "${cutoff_5h}" ] && tokens_5h=$(cached_tokens_since "${cutoff_5h}" "-mmin -310" "5h" 30)
[ -n "${cutoff_wk}" ] && tokens_wk=$(cached_tokens_since "${cutoff_wk}" "-mtime -8"  "wk" 300)

humanise() {
    awk -v n="$1" 'BEGIN {
        if (n+0 >= 1000000)   printf "%.1fM", n/1000000
        else if (n+0 >= 1000) printf "%.0fk", n/1000
        else                  printf "%d", n
    }'
}

# Segment renderer: percentage if budget is a positive integer, raw count otherwise.
seg() {
    local label="$1" tokens="$2" budget="${3:-}"
    if [ -n "${budget}" ] && [ "${budget}" -gt 0 ] 2>/dev/null; then
        local pct
        pct=$(awk -v t="${tokens}" -v b="${budget}" 'BEGIN {
            p = (t / b) * 100
            if (p > 999) p = 999
            printf "%.0f", p
        }')
        printf '%s %s%%' "${label}" "${pct}"
    else
        printf '%s %s' "${label}" "$(humanise "${tokens}")"
    fi
}

effort="${CLAUDE_EFFORT:-}"
if [ -z "${effort}" ] && [ -f "${HOME}/.claude/settings.json" ]; then
    effort=$(jq -r '.effortLevel // empty' "${HOME}/.claude/settings.json" 2>/dev/null)
fi

bar="⛭ ${model} · ${dir}"
[ -n "${effort}" ] && bar="${bar} · ${effort}"
bar="${bar} · $(seg 5h "${tokens_5h}" "${CLAUDE_5H_TOKEN_BUDGET:-}")"
bar="${bar} · $(seg wk "${tokens_wk}" "${CLAUDE_WEEKLY_TOKEN_BUDGET:-}")"
printf '%s' "$bar"
SL_EOF
    chmod +x "${statusline_file}"
    echo "  wrote → ${statusline_file}"
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
        --argjson perms "${perms_json}" \
        --argjson shift "${shift_json}" \
        '
        (.env // {}) as $env
        | . + $shift + {
            statusLine: { type: "command", command: "bash ~/.claude/statusline.sh" },
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
            echo "  Jira credentials (saved to settings/.atlassian.env, gitignored)"
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

    # Docker args: one bare "-e VAR" per set env key (docker reads the value from
    # its own env, which Claude Code populates from the "env" block — so tokens
    # never appear on the command line), then the image.
    local image="ghcr.io/sooperset/mcp-atlassian:latest"
    local args_json
    args_json="$(jq -n --argjson env "${env_json}" --arg img "${image}" \
        '["run","-i","--rm"] + [$env | keys[] | ("-e", .)] + [$img]')"

    # Register at user scope via the claude CLI (writes ~/.claude.json so the
    # server auto-loads in every session/project). Remove any prior registration
    # first so re-runs are idempotent — add-json errors if the name already exists.
    local server_json
    server_json="$(jq -n --argjson args "${args_json}" --argjson env "${env_json}" \
        '{command: "docker", args: $args, env: $env}')"
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
        echo "  GitHub credentials (saved to settings/.github.env, gitignored)"
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

    # Docker args: one bare "-e VAR" per set env key (docker reads the value from
    # its own env, which Claude Code populates from the "env" block — so the token
    # never appears on the command line), then the image.
    local image="ghcr.io/github/github-mcp-server"
    local args_json
    args_json="$(jq -n --argjson env "${env_json}" --arg img "${image}" \
        '["run","-i","--rm"] + [$env | keys[] | ("-e", .)] + [$img]')"

    # Register at user scope (writes ~/.claude.json). Remove any prior registration
    # first so re-runs are idempotent — add-json errors if the name already exists.
    local server_json
    server_json="$(jq -n --argjson args "${args_json}" --argjson env "${env_json}" \
        '{command: "docker", args: $args, env: $env}')"
    claude mcp remove github -s user >/dev/null 2>&1 || true
    claude mcp add-json github "${server_json}" -s user >/dev/null
    echo "  registered github MCP (docker/${image##*/}, read-only) at user scope (~/.claude.json)"
    echo "  GitHub toolsets: ${gh_toolsets:-server default}"
    echo "  restart Claude Code to pick up the new MCP server"
}

# Rebuild ~/.claude/skills/<name> symlinks from scratch on every run.
# Step 1 tears down every kit-managed symlink (including dangling ones left by
# renamed/removed kit skills) so stale links never linger. Step 2 recreates a
# fresh symlink for each skill currently in the kit. Real directories (not
# symlinks) are never touched — hand-edited skills are safe.
syncSkills() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit — skipped"; return 0; }
    mkdir -p "${claude_skills_dir}"

    # 1. Prune kit-managed symlinks (matched by where they point, so dangling
    #    links to since-renamed skills like oe_deploy/oe_imagebuilder are caught).
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

    # 2. (Re)create a symlink for every skill currently in the kit.
    local src name
    for src in "${skills_src_dir}"/*/; do
        [ -d "${src}" ] || continue
        name="$(basename "${src}")"
        dst="${claude_skills_dir}/${name}"
        # A leftover here is either a real dir or a foreign symlink (not ours,
        # since step 1 removed all kit-managed ones) — leave it untouched.
        if [ -L "${dst}" ] || [ -e "${dst}" ]; then
            echo "  skip  → ${dst} (exists and not kit-managed — leaving alone)"
            continue
        fi
        ln -s "${src%/}" "${dst}"
        echo "  link  → ${dst}"
    done
}

# Wholesale-write ~/.claude/CLAUDE.md from the kit's claude-md/CLAUDE.md.
# If a pre-existing CLAUDE.md exists, copy it to CLAUDE.md.bak first (overwritten
# on each run, same convention as settings.json.bak).
writeClaudeMd() {
    [ -f "${claude_md_src}" ] || { echo "  missing kit source: ${claude_md_src}" >&2; return 1; }
    # Idempotent: already matches the kit → leave it (and its .bak) alone.
    if [ -f "${claude_md_file}" ] && cmp -s "${claude_md_file}" "${claude_md_src}"; then
        echo "  ~/.claude/CLAUDE.md already current — no change"
        return 0
    fi
    if [ -f "${claude_md_file}" ]; then
        cp -p "${claude_md_file}" "${claude_md_bak}"
        echo "  backed up → ${claude_md_bak}"
    fi
    cp "${claude_md_src}" "${claude_md_file}"
    echo "  wrote     → ${claude_md_file}  (from ${claude_md_src})"
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

# Verification block — runs the 6 checks from the brief.
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

    # 3. permissions tier present with correct defaultMode
    local mode expected_mode
    mode="$(jq -r '.permissions.defaultMode // empty' "${settings_file}")"
    case "${PERMISSIONS}" in
        safe)     expected_mode="default" ;;
        standard) expected_mode="acceptEdits" ;;
        trusted)  expected_mode="dontAsk" ;;
        yolo)     expected_mode="dontAsk" ;;
    esac
    if [ "${mode}" = "${expected_mode}" ]; then
        echo "[PASS] (3) permissions tier '${PERMISSIONS}' applied (defaultMode=${mode})"
    else
        echo "[FAIL] (3) permissions tier mismatch (have='${mode}', want='${expected_mode}')"; failed=1
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
    echo "  tier        : ${PERMISSIONS}"
    echo "  settings    : ${settings_file}  (backup: ${settings_bak})"
    echo "  statusline  : ${statusline_file}"
    echo "  guidelines  : ${claude_md_file}  (backup: ${claude_md_bak})"
    echo "  skills      : ${claude_skills_dir}/  (symlinked from ${skills_src_dir})"
    echo "  autocompact : ${AUTOCOMPACT_PCT}% / ${AUTOCOMPACT_WINDOW} tokens"
    echo "-------------------------------"
}

##################################################
################# EXECUTION ######################
##################################################

echo ""
if [ "${DO_RESET}" = "1" ]; then
    echo "Resetting ~/.claude (archiving bloat, preserving auth/history/projects)..."
    resetBloat
    echo -e "[Done]\n"
fi

echo "Ensuring settings.json exists..."
ensureSettings
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

echo "Linking skills into ~/.claude/skills/..."
syncSkills
echo -e "[Done]\n"

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
