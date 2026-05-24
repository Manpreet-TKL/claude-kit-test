#!/bin/bash -l
# Manpreet 24/05/2026
# claude-kit installer — configures Claude Code per the handoff brief.
# Writes ~/.claude/settings.json (statusLine, env, permissions) and
# wholesale-writes ~/.claude/CLAUDE.md from claude-md/CLAUDE.md in this kit.
# Idempotent: safe to re-run; existing settings.json + CLAUDE.md are backed up
# to *.bak before overwriting.

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
AUTOCOMPACT_PCT="${AUTOCOMPACT_PCT:-60}"        # compact trigger %, clamped to ~83
AUTOCOMPACT_WINDOW="${AUTOCOMPACT_WINDOW:-200000}"  # effective window (tokens)
FIVE_HOUR_BUDGET="${FIVE_HOUR_BUDGET:-}"        # tokens/5h, surfaced as % in status line; unset = raw count
WEEKLY_BUDGET="${WEEKLY_BUDGET:-}"              # tokens/week (rolling 7d), surfaced as % in status line; unset = raw count
ASSUME_YES=0                                    # -y: accept default tier non-interactively
DO_VERIFY=1                                     # --no-verify: skip the 6 checks
DO_RESET=0                                      # --reset: archive bloat then install
ATLASSIAN_MODE=""                               # --with-atlassian / --without-atlassian / "" (leave alone)

# Argument parsing ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -p | --permissions)
        PERMISSIONS="${2}"
        shift
        ;;
    -y | --yes)
        ASSUME_YES=1
        ;;
    --no-verify)
        DO_VERIFY=0
        ;;
    --reset)
        DO_RESET=1
        ;;
    --with-atlassian)
        ATLASSIAN_MODE="on"
        ;;
    --without-atlassian)
        ATLASSIAN_MODE="off"
        ;;
    -h | --help)
        cat <<'USAGE'
Usage: install.sh [--permissions <safe|standard|trusted|yolo>] [--reset]
                  [--with-atlassian | --without-atlassian] [-y] [--no-verify]

  --permissions, -p   Permission tier to install (default: standard).
                      safe      = read-mostly; ask before edits/writes/shell.
                      standard  = day-to-day; auto-accept edits; ask for shell.
                      trusted   = dontAsk; nothing prompts but deny still wins.
                      yolo      = dontAsk; only git push/commit + rm -rf
                                  denies remain (secrets reads ALLOWED).
                                  Container/VM only — see docs/sandbox.md.
  --reset             Archive Claude Code's auto-generated state directories
                      (file-history, paste-cache, backups, shell-snapshots,
                      stats-cache, session-env, plugins, tasks) into
                      ~/.claude-backups/<timestamp>/, then run the install.
                      Auth (.credentials.json), history.jsonl, and projects/
                      are preserved in place.
  --with-atlassian    Merge settings/mcp-atlassian.json into settings.json so
                      Claude Code talks to the Atlassian Remote MCP (Jira +
                      Confluence). You authenticate once via /mcp inside Claude
                      Code. See docs/atlassian.md.
  --without-atlassian Remove the atlassian MCP server entry from settings.json
                      (does not log you out — clear the OAuth cache separately).
  --yes, -y           Non-interactive; accept default tier if not provided.
  --no-verify         Skip the 6 verification checks after writing.
  --help, -h          This message.

Env overrides:
  AUTOCOMPACT_PCT      (default 60)      % capacity at which auto-compact triggers.
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
atlassian_fragment="${kit_root}/settings/mcp-atlassian.json"
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

# Backup the existing settings.json (overwrites previous .bak to track latest pre-run state).
backupSettings() {
    if [ -f "${settings_file}" ]; then
        cp -p "${settings_file}" "${settings_bak}"
        echo "  backed up → ${settings_bak}"
    else
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
# and the shift-enter fragment are merged so unrelated keys survive.
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
        ' "${settings_file}" > "${tmp}"

    # Validate before overwrite — never leave settings.json half-written.
    jq -e . "${tmp}" >/dev/null
    mv "${tmp}" "${settings_file}"
    echo "  merged → ${settings_file}"
}

# Merge or remove the Atlassian MCP server entry in settings.json based on
# ATLASSIAN_MODE: "on" merges settings/mcp-atlassian.json; "off" deletes the
# atlassian entry; "" leaves whatever's already there.
applyAtlassian() {
    case "${ATLASSIAN_MODE}" in
        on)
            [ -f "${atlassian_fragment}" ] || { echo "  missing fragment: ${atlassian_fragment}" >&2; return 1; }
            jq -e . "${atlassian_fragment}" >/dev/null || { echo "  invalid JSON: ${atlassian_fragment}" >&2; return 1; }
            local tmp frag
            tmp="$(mktemp)"
            frag="$(cat "${atlassian_fragment}")"
            jq --argjson frag "${frag}" '
                .mcpServers = ((.mcpServers // {}) + ($frag.mcpServers // {}))
            ' "${settings_file}" > "${tmp}"
            jq -e . "${tmp}" >/dev/null
            mv "${tmp}" "${settings_file}"
            echo "  added atlassian MCP → ${settings_file}"
            echo "  next step: run /mcp inside Claude Code to OAuth-authenticate (see docs/atlassian.md)"
            ;;
        off)
            local tmp
            tmp="$(mktemp)"
            jq 'if .mcpServers? then .mcpServers |= del(.atlassian) else . end
                | if (.mcpServers? // {}) == {} then del(.mcpServers) else . end
            ' "${settings_file}" > "${tmp}"
            jq -e . "${tmp}" >/dev/null
            mv "${tmp}" "${settings_file}"
            echo "  removed atlassian MCP from ${settings_file}"
            echo "  note: this does not log you out — see docs/atlassian.md for the OAuth cache"
            ;;
        "")
            : # unchanged
            ;;
    esac
}

# Symlink each kit skill into ~/.claude/skills/<name>. Skips destinations that
# already exist as real directories (not symlinks) — never clobbers hand-edits.
syncSkills() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit — skipped"; return 0; }
    mkdir -p "${claude_skills_dir}"
    local src name dst
    for src in "${skills_src_dir}"/*/; do
        [ -d "${src}" ] || continue
        name="$(basename "${src}")"
        dst="${claude_skills_dir}/${name}"
        if [ -L "${dst}" ]; then
            ln -sfn "${src%/}" "${dst}"
            echo "  link  → ${dst}"
        elif [ -e "${dst}" ]; then
            echo "  skip  → ${dst} (real dir, not a symlink — leaving alone)"
        else
            ln -s "${src%/}" "${dst}"
            echo "  link  → ${dst}"
        fi
    done
}

# Wholesale-write ~/.claude/CLAUDE.md from the kit's claude-md/CLAUDE.md.
# If a pre-existing CLAUDE.md exists, copy it to CLAUDE.md.bak first (overwritten
# on each run, same convention as settings.json.bak).
writeClaudeMd() {
    [ -f "${claude_md_src}" ] || { echo "  missing kit source: ${claude_md_src}" >&2; return 1; }
    if [ -f "${claude_md_file}" ]; then
        if ! cmp -s "${claude_md_file}" "${claude_md_src}"; then
            cp -p "${claude_md_file}" "${claude_md_bak}"
            echo "  backed up → ${claude_md_bak}"
        fi
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

echo "Backing up settings.json..."
backupSettings
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

if [ -n "${ATLASSIAN_MODE}" ]; then
    echo "Applying Atlassian MCP setting (${ATLASSIAN_MODE})..."
    applyAtlassian
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
