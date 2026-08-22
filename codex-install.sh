#!/bin/bash -l
# Manpreet 10/08/2026
# claude-kit installer for standalone, containerised Codex - the Codex-side twin
# of install.sh. Builds the claude-kit-codex image, symlinks ~/.codex/AGENTS.md
# and ~/.agents/skills/* back into this kit, generates each skill's Codex
# metadata, and saves the non-secret agent defaults to generated/.codex.env
# (shared with `install.sh -x`). Idempotent: safe to re-run.
#
# Flag-for-flag with install.sh where the feature exists on both sides - see -h
# for what maps and what is deliberately Claude-Code-only.

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
ASSUME_YES=0                                    # -y: take saved/default answers non-interactively
DO_VERIFY=1                                     # -n: skip the verification checks
DO_UPDATE=1                                     # -U: don't rebuild the image when it already exists
DO_RESET=0                                      # -r: archive ~/.codex bloat, then install
DO_FRESH=0                                      # -F: back up auth+history, wipe ~/.codex + ~/.agents, reinstall
SKILLS_AUTO=""                                  # -s on|off: flip disable-model-invocation across kit skills; "" = leave as authored
DO_LOGOUT=0                                     # -l: clear the stored ChatGPT session and exit (standalone action)
QUICK=0                                         # -q: non-interactive defaults run (implies -y)

# Usage ---------------------------------------------------------------------
usage() {
    cat <<'USAGE'
Usage: codex-install.sh [-q] [-s <on|off>] [-r] [-F] [-n] [-U] [-y] [-l]

  Standalone Codex twin of install.sh. Every option has a single-letter (-x) and
  a long (--word) form, and short flags bundle: -yU == -y -U (a value-taking flag
  like -s must be last in the bundle).
  Run with no flags at all and this prints the help and exits with an error -
  pass -q for the no-questions run with defaults.

  -q, --quick         Quick run: non-interactive, saved answers or built-in
                      defaults for every prompt (implies -y). Otherwise
                      identical to a plain install run.
  -s, --skills-auto   on|off. Set the model-invocation gate on every kit skill
                      in place - the SAME switch, snapshot file and semantics as
                      install.sh -s, because both agents read the same
                      skills/<name>/SKILL.md frontmatter:
                      on   snapshots each skill's current value to
                           generated/skills-auto.state (append-only, so a repeat
                           -s on never overwrites the pre-flip values), then
                           rewrites 'disable-model-invocation: true' -> 'false'.
                      off  restores every skill to its snapshotted value and
                           clears the snapshot. With no snapshot it sets all
                           flagged skills to 'true' (everything manual).
                      Skills that never carried the flag are untouched in both
                      directions. Omitting -s changes nothing and only reports
                      the current tally. Restart Codex to pick up a change.
  -r, --reset         Archive Codex's auto-generated state (cache, log,
                      shell_snapshots, tmp, thread-writer-locks, plugins, the
                      *.sqlite stores and models_cache.json) into
                      ~/.claude-backups/<timestamp>-codex/, then run the
                      install. auth.json, config.toml, history.jsonl and
                      sessions/ are preserved in place.
  -F, --fresh         NUKE AND PAVE. Back up auth.json, config.toml,
                      history.jsonl and sessions/ to
                      ~/.claude-backups/<timestamp>-codex-fresh/, DELETE
                      ~/.codex and ~/.agents, then reinstall and restore those
                      four so you keep your sessions and stay signed in.
                      Everything else regenerates clean. Interactive runs ask
                      you to type 'fresh' to confirm; -y skips that prompt.
                      Supersedes --reset.
  -l, --logout        Delete ~/.codex/auth.json (the stored ChatGPT session) and
                      EXIT - a standalone action, nothing else runs, exactly like
                      install.sh -l codex. Sign back in and Codex works again;
                      revoke server-side at chatgpt.com under authorized apps.
  -y, --yes           Non-interactive; take the saved values in
                      generated/.codex.env (or the built-in defaults) instead of
                      prompting, and skip the --fresh confirmation.
  -n, --no-verify     Skip the verification checks after writing.
  -U, --no-update     Don't rebuild the claude-kit-codex image when it already
                      exists. By default every run rebuilds it with
                      --pull --no-cache so the containerised Codex CLI is
                      refreshed to the latest - the analogue of install.sh's
                      `claude update`. A missing image is always built.
  -h, --help          This message.

Agent defaults (prompted, or read with -y):
  Saved non-secretly to generated/.codex.env and SHARED with `install.sh -x`, so
  the standalone runner and the MCP agents run the same model. There is no secret
  here - Codex authenticates with your ChatGPT login, stored in ~/.codex.

  CODEX_MODEL             flagship model                    (default gpt-5.6-sol)
  CODEX_REASONING_EFFORT  minimal|low|medium|high|xhigh     (default xhigh)
  CODEX_SANDBOX           read-only|workspace-write|danger-full-access
                                                            (default workspace-write)
  CODEX_APPROVAL          untrusted|on-failure|on-request|never
                                                            (default on-request)

  CODEX_SANDBOX / CODEX_APPROVAL are the Codex analogue of install.sh's -p (rule
  set) and -m (session start mode). NOTE: codex.sh runs Codex inside Docker,
  where codex's own bwrap sandbox cannot start - the CONTAINER is the sandbox, so
  the inner mode is pinned to danger-full-access at launch and CODEX_SANDBOX only
  takes effect on a host run. Writes stay confined to the mounted workspace and
  the container carries no git credentials, so a push fails auth.

Claude-Code-only (deliberately not ported):
  Permission tiers, settings.json, the status line, shift-enter, autocompact env
  vars, conversation pruning + cleanupPeriodDays, and project-memory adoption are
  all Claude Code concepts with no Codex counterpart. MCP server registration
  (-j/-c/-g/-a/-x) is not ported either: install.sh registers those through the
  `claude` CLI into ~/.claude.json, whereas Codex declares them in config.toml
  [mcp_servers] - a separate mechanism, not a flag translation.
USAGE
}

# Argument parsing ---------------------------------------------------------
requireValue() {   # $1=flag $2=its value (may be absent) - abort with a message instead of a bare set -e death
    if [ $# -lt 2 ] || [ -z "${2}" ]; then
        echo "codex-install.sh: ${1} requires a value - see -h for accepted forms" >&2
        trap : 0
        exit 1
    fi
}

if [ $# -eq 0 ]; then
    usage >&2
    echo >&2
    echo "codex-install.sh: no flags given - nothing assumed. Use -q to run non-interactively" >&2
    echo "with defaults, or pick options from the list above." >&2
    trap : 0
    exit 1
fi

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -[!-]?*)
        # Bundled short flags: explode -yU into -y -U. A value-taking flag (-s)
        # must be last in the bundle, per getopt convention.
        rest="${p#-}"
        exploded=()
        for ((i = 0; i < ${#rest}; i++)); do
            exploded+=("-${rest:i:1}")
        done
        set -- "${exploded[@]}" "${@:2}"
        continue
        ;;
    -q | --quick)       QUICK=1 ;;
    -y | --yes)         ASSUME_YES=1 ;;
    -n | --no-verify)   DO_VERIFY=0 ;;
    -U | --no-update)   DO_UPDATE=0 ;;
    -r | --reset)       DO_RESET=1 ;;
    -F | --fresh)       DO_FRESH=1 ;;
    -l | --logout)      DO_LOGOUT=1 ;;
    -s | --skills-auto)
        requireValue "$@"
        SKILLS_AUTO="${2}"
        shift
        ;;
    -h | --help)
        usage
        trap : 0
        exit 0
        ;;
    *)
        echo "Invalid Parameter '${p}' ... exiting" >&2
        trap : 0
        exit 1
        ;;
    esac
    shift
done

[ "${QUICK}" = "1" ] && ASSUME_YES=1

# Portable paths -----------------------------------------------------------
kit_root="$(dirname "$(realpath "$0")")"
generated_dir="${kit_root}/generated"
skills_src_dir="${kit_root}/skills"
skills_auto_state="${generated_dir}/skills-auto.state"      # shared with install.sh -s
codex_secrets="${generated_dir}/.codex.env"                 # model/sandbox knobs only, no secret
claude_md_src="${kit_root}/claude-md/CLAUDE.md"
codex_home="${HOME}/.codex"
codex_agents_md="${codex_home}/AGENTS.md"
codex_auth="${codex_home}/auth.json"
agents_home="${HOME}/.agents"
agents_skills_dir="${agents_home}/skills"
agents_manifest="${agents_home}/.claude-kit-skills"
backup_root="${HOME}/.claude-backups"
image="claude-kit-codex"
codex_docker_dir="${kit_root}/docker/codex"

# Skill plumbing shared with install.sh (gate flip + snapshot, openai.yaml
# generation, the symlink/prune linker). Reads the globals set above at call time.
# shellcheck source=lib/skills.sh
. "${kit_root}/lib/skills.sh"

# -l/--logout: clear the stored ChatGPT session, then exit - deliberately
# standalone, before any other step, so it can only ever log out.
if [ "${DO_LOGOUT}" = "1" ]; then
    if [ -f "${codex_auth}" ]; then
        rm -f "${codex_auth}"
        echo "Removed ${codex_auth} - Codex is signed out."
    else
        echo "No ${codex_auth} - Codex was not signed in."
    fi
    echo "The claude-kit-codex image and skill links are untouched; sign back in with:"
    echo "  bash ${kit_root}/codex-install.sh -q"
    echo "Revoke server-side at https://chatgpt.com/#settings/ConnectedApps if you also want the grant gone."
    trap : 0
    exit 0
fi

# Pre-flight ---------------------------------------------------------------
echo ""
echo "Starting pre-flight checks ..."
echo "-------------------------------"

case "${SKILLS_AUTO}" in
    ''|on|off) ;;
    *) echo "Invalid --skills-auto '${SKILLS_AUTO}' - must be on|off" >&2; exit 1 ;;
esac

command -v docker >/dev/null 2>&1 || {
    echo "Docker is required - standalone Codex runs containerised. Install Docker, then re-run." >&2
    exit 1
}
echo "Docker: $(docker --version 2>/dev/null | head -1) [OK]"

[ -f "${claude_md_src}" ] || { echo "Missing kit source: ${claude_md_src}" >&2; exit 1; }
[ -d "${skills_src_dir}" ] || { echo "Missing kit source: ${skills_src_dir}" >&2; exit 1; }
mkdir -p "${generated_dir}" "${codex_home}" "${agents_skills_dir}"
chmod 700 "${generated_dir}"
echo "Checks complete ..."
echo "-------------------------------"

##################################################
################# FUNCTIONS ######################
##################################################

# -r/--reset: move Codex's regenerable state out to a timestamped archive, keeping
# the things you would actually miss (auth, config, prompt history, sessions).
resetBloat() {
    local stamp archive item moved=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    archive="${backup_root}/${stamp}-codex"
    mkdir -p "${archive}"
    for item in cache log shell_snapshots tmp thread-writer-locks plugins rules \
                models_cache.json logs_2.sqlite state_5.sqlite queue_1.sqlite \
                thread_history_1.sqlite goals_1.sqlite memories_1.sqlite; do
        if [ -e "${codex_home}/${item}" ]; then
            mv "${codex_home}/${item}" "${archive}/"
            echo "  archived -> ${archive}/${item}"
            moved=$((moved+1))
        fi
    done
    if [ "${moved}" -eq 0 ]; then
        rmdir "${archive}" 2>/dev/null || true
        echo "  nothing to archive - ~/.codex is already clean"
    else
        echo "  ${moved} item(s) archived to ${archive}"
        echo "  auth.json, config.toml, history.jsonl and sessions/ were left in place"
    fi
}

# -F/--fresh: nuke ~/.codex and ~/.agents, keeping auth + config + history +
# sessions across the wipe. Everything else regenerates on the way back up.
freshInstall() {
    local stamp archive item restored=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    archive="${backup_root}/${stamp}-codex-fresh"

    if [ "${ASSUME_YES}" != "1" ]; then
        echo "  This DELETES ${codex_home} and ${agents_home}."
        echo "  auth.json, config.toml, history.jsonl and sessions/ are archived first and restored after."
        read -r -p "  Type 'fresh' to confirm: " _in
        [ "${_in}" = "fresh" ] || { echo "  not confirmed - aborting the --fresh run" >&2; exit 1; }
    fi

    mkdir -p "${archive}"
    for item in auth.json config.toml history.jsonl sessions; do
        [ -e "${codex_home}/${item}" ] || continue
        cp -a "${codex_home}/${item}" "${archive}/"
        echo "  backed up -> ${archive}/${item}"
    done

    rm -rf "${codex_home}" "${agents_home}"
    mkdir -p "${codex_home}" "${agents_skills_dir}"
    echo "  wiped ${codex_home} and ${agents_home}"

    for item in auth.json config.toml history.jsonl sessions; do
        [ -e "${archive}/${item}" ] || continue
        cp -a "${archive}/${item}" "${codex_home}/"
        restored=$((restored+1))
    done
    echo "  restored ${restored} item(s); full pre-wipe copy kept at ${archive}"
}

# Build (or rebuild) the containerised Codex CLI. A missing image is always built;
# an existing one is refreshed with --pull --no-cache unless -U says otherwise,
# which is what actually pulls a newer @openai/codex (the npm layer is cached).
buildImage() {
    if ! docker image inspect "${image}" >/dev/null 2>&1; then
        echo "  image ${image} absent - building..."
        docker build -t "${image}" "${codex_docker_dir}"
        echo "  built -> ${image}"
        return 0
    fi
    if [ "${DO_UPDATE}" != "1" ]; then
        echo "  image ${image} present, --no-update given - skipping rebuild"
        return 0
    fi
    echo "  refreshing ${image} (--pull --no-cache)..."
    if docker build --pull --no-cache -t "${image}" "${codex_docker_dir}"; then
        echo "  rebuilt -> ${image} (latest @openai/codex)"
    else
        echo "  WARNING: rebuild failed (offline?) - keeping the existing ${image}" >&2
    fi
}

# Prompt for (or read) the non-secret agent defaults and save them to
# generated/.codex.env. Same file and same keys install.sh -x uses, so the two
# entry points cannot drift onto different models.
writeCodexEnv() {
    local cx_model cx_effort cx_sandbox cx_approval
    if [ -f "${codex_secrets}" ]; then
        # shellcheck source=/dev/null
        . "${codex_secrets}"
        cx_model="${CODEX_MODEL:-}"
        cx_effort="${CODEX_REASONING_EFFORT:-}"
        cx_sandbox="${CODEX_SANDBOX:-}"
        cx_approval="${CODEX_APPROVAL:-}"
    fi
    cx_model="${cx_model:-gpt-5.6-sol}"
    cx_effort="${cx_effort:-xhigh}"
    cx_sandbox="${cx_sandbox:-workspace-write}"
    cx_approval="${cx_approval:-on-request}"

    local noninteractive=0
    if [ "${ASSUME_YES}" = "1" ] || [ ! -t 0 ]; then
        noninteractive=1
    fi

    if [ "${noninteractive}" = "1" ]; then
        echo "  model=${cx_model} effort=${cx_effort} sandbox=${cx_sandbox} approval=${cx_approval} (from ${codex_secrets#"${kit_root}"/} / defaults)"
    else
        echo ""
        echo "  Codex agent defaults (non-secret; saved to generated/.codex.env)"
        read -r -p "  CODEX_MODEL [${cx_model}]: " _in
        cx_model="${_in:-${cx_model}}"
        read -r -p "  CODEX_REASONING_EFFORT (minimal|low|medium|high|xhigh) [${cx_effort}]: " _in
        cx_effort="${_in:-${cx_effort}}"
        read -r -p "  CODEX_SANDBOX (read-only|workspace-write|danger-full-access) [${cx_sandbox}]: " _in
        cx_sandbox="${_in:-${cx_sandbox}}"
        read -r -p "  CODEX_APPROVAL (untrusted|on-failure|on-request|never) [${cx_approval}]: " _in
        cx_approval="${_in:-${cx_approval}}"
    fi

    {
        echo "CODEX_MODEL=${cx_model}"
        echo "CODEX_REASONING_EFFORT=${cx_effort}"
        echo "CODEX_SANDBOX=${cx_sandbox}"
        echo "CODEX_APPROVAL=${cx_approval}"
    } > "${codex_secrets}"
    chmod 600 "${codex_secrets}"
    echo "  saved -> ${codex_secrets#"${kit_root}"/}"
}

# Symlink ~/.codex/AGENTS.md -> the kit's claude-md/CLAUDE.md, so Codex reads the
# same global instructions as Claude (AGENTS.md is codex's CLAUDE.md analogue).
# A correct link is left untouched; a real file is backed up once to *.bak.
writeAgentsMd() {
    if [ -L "${codex_agents_md}" ] && [ "$(readlink "${codex_agents_md}")" = "${claude_md_src}" ]; then
        echo "  ~/.codex/AGENTS.md already linked - no change"
        return 0
    fi
    if [ -e "${codex_agents_md}" ] && [ ! -L "${codex_agents_md}" ]; then
        cp -p "${codex_agents_md}" "${codex_agents_md}.bak"
        echo "  backed up -> ${codex_agents_md}.bak"
    fi
    ln -sfn "${claude_md_src}" "${codex_agents_md}"
    echo "  linked    -> ${codex_agents_md} -> ${claude_md_src}"
}

# One-time ChatGPT sign-in, through the container so nothing lands on the host.
codexLogin() {
    if [ -f "${codex_auth}" ]; then
        echo "  already signed in (${codex_auth})"
        return 0
    fi
    local login_cmd
    login_cmd="docker run --rm -it --network host --user \"\$(id -u):\$(id -g)\" -v \"\$HOME/.codex:/home/codex/.codex\" ${image} login --device-auth"
    if [ -t 0 ] && [ -t 1 ] && [ "${QUICK}" != "1" ]; then
        docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "${codex_home}:/home/codex/.codex" "${image}" login --device-auth
    else
        echo "  not signed in and no interactive tty - run this yourself:" >&2
        echo "  ${login_cmd}" >&2
    fi
}

verifyAll() {
    local failed=0
    echo ""
    echo "Verification checks"
    echo "-------------------------------"

    if docker image inspect "${image}" >/dev/null 2>&1; then
        echo "[PASS] (1) ${image} image present"
    else
        echo "[FAIL] (1) ${image} image missing"; failed=1
    fi

    if [ -L "${codex_agents_md}" ] && [ "$(readlink "${codex_agents_md}")" = "${claude_md_src}" ]; then
        echo "[PASS] (2) ~/.codex/AGENTS.md linked to the kit"
    else
        echo "[FAIL] (2) ~/.codex/AGENTS.md not linked to ${claude_md_src}"; failed=1
    fi

    local linked kit_count
    linked="$(find "${agents_skills_dir}" -maxdepth 1 -type l 2>/dev/null | wc -l)"
    kit_count="$(find "${skills_src_dir}" -maxdepth 1 -mindepth 1 -type d | wc -l)"
    if [ -s "${agents_manifest}" ] && [ "${linked}" -ge 1 ]; then
        echo "[PASS] (3) ${linked}/${kit_count} kit skill(s) linked into ${agents_skills_dir}"
    else
        echo "[FAIL] (3) no kit skills linked into ${agents_skills_dir}"; failed=1
    fi

    local missing_yaml=0 d
    for d in "${skills_src_dir}"/*/; do
        [ -f "${d}SKILL.md" ] || continue
        [ -f "${d}agents/openai.yaml" ] || missing_yaml=$((missing_yaml+1))
    done
    if [ "${missing_yaml}" -eq 0 ]; then
        echo "[PASS] (4) every skill has agents/openai.yaml"
    else
        echo "[FAIL] (4) ${missing_yaml} skill(s) missing agents/openai.yaml"; failed=1
    fi

    if [ -f "${codex_secrets}" ] && grep -q '^CODEX_MODEL=' "${codex_secrets}"; then
        echo "[PASS] (5) agent defaults saved ($(grep '^CODEX_MODEL=' "${codex_secrets}" | cut -d= -f2), $(grep '^CODEX_REASONING_EFFORT=' "${codex_secrets}" | cut -d= -f2))"
    else
        echo "[FAIL] (5) ${codex_secrets} missing or incomplete"; failed=1
    fi

    if [ -f "${codex_auth}" ]; then
        echo "[PASS] (6) signed in (${codex_auth})"
    else
        echo "[INFO] (6) not signed in yet - run the login command printed above"
    fi

    if grep -qs "^CODEX_APPROVAL=" "${codex_secrets}"; then
        echo "[PASS] (7) approval policy recorded ($(grep '^CODEX_APPROVAL=' "${codex_secrets}" | cut -d= -f2))"
    else
        echo "[FAIL] (7) CODEX_APPROVAL missing from ${codex_secrets}"; failed=1
    fi

    echo "-------------------------------"
    if [ "${failed}" -eq 0 ]; then
        echo "All scriptable checks passed."
    else
        echo "One or more checks failed - see above." >&2
        return 1
    fi
}

printSummary() {
    # shellcheck source=/dev/null
    [ -f "${codex_secrets}" ] && . "${codex_secrets}"
    echo ""
    echo "Summary"
    echo "-------------------------------"
    echo "  image       : ${image}  (built from ${codex_docker_dir})"
    echo "  model       : ${CODEX_MODEL:-?} at ${CODEX_REASONING_EFFORT:-?} reasoning"
    echo "  sandbox     : ${CODEX_SANDBOX:-?} on a host run; the container itself under codex.sh"
    echo "  approval    : ${CODEX_APPROVAL:-?}  (approval_policy)"
    echo "  guidelines  : ${codex_agents_md}  (symlinked from ${claude_md_src})"
    echo "  skills      : ${agents_skills_dir}/  (symlinked from ${skills_src_dir})"
    echo "  generated   : ${generated_dir}/  (machine-local config, no secrets; gitignored)"
    echo "  auth        : ${codex_auth}  (ChatGPT session, outside the kit)"
    echo "-------------------------------"
    echo "  run it: bash ${kit_root}/codex.sh"
}

##################################################
################# EXECUTION ######################
##################################################

echo ""
if [ "${DO_FRESH}" = "1" ]; then
    echo "Nuke and pave (--fresh)..."
    freshInstall
    echo -e "[Done]\n"
elif [ "${DO_RESET}" = "1" ]; then
    echo "Resetting ~/.codex (archiving bloat, preserving auth/config/history/sessions)..."
    resetBloat
    echo -e "[Done]\n"
fi

echo "Building the containerised Codex CLI..."
buildImage
echo -e "[Done]\n"

echo "Saving Codex agent defaults..."
writeCodexEnv
echo -e "[Done]\n"

echo "Linking ~/.codex/AGENTS.md to the kit..."
writeAgentsMd
echo -e "[Done]\n"

echo "Checking skill auto-invocation state${SKILLS_AUTO:+ (-s ${SKILLS_AUTO})}..."
applySkillsInvocation
echo -e "[Done]\n"

echo "Generating codex skill metadata (agents/openai.yaml)..."
writeOpenAiSkillMeta
echo -e "[Done]\n"

echo "Linking skills into ${agents_skills_dir}/..."
linkKitSkills "${agents_skills_dir}" "${agents_manifest}"
echo -e "[Done]\n"

echo "Checking the ChatGPT sign-in..."
codexLogin
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
