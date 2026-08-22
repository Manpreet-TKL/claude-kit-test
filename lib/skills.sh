# Manpreet 22/08/2026
# Shared skill plumbing for install.sh (Claude Code) and codex-install.sh
# (standalone Codex). Sourced, never executed: the caller sets kit_root,
# skills_src_dir, skills_auto_state and SKILLS_AUTO first, then calls in.
#
# Both installers link the same skills/ dir into their own agent home and both
# read the same disable-model-invocation gate, so the logic lives here once -
# a second hand-rolled copy is how the two drift apart.

# Read a skill's disable-model-invocation value, or "" if it carries no flag.
# Restricted to the frontmatter block (line 2 up to the closing ---), so a
# literal mention in a skill body is never seen.
skillGateValue() {
    sed -n "2,/^---\$/p" "$1" | sed -n 's/^disable-model-invocation: \(true\|false\)$/\1/p' | head -1
}

# Rewrite a skill's disable-model-invocation value in place, same frontmatter
# restriction. The SKILL.md files are live symlink targets, so the change
# reaches the agent home with no re-link - but skills bind at session start.
setSkillGateValue() {
    sed -i "2,/^---\$/ s/^disable-model-invocation: \(true\|false\)\$/disable-model-invocation: $2/" "$1"
}

# One "<skill> <auto|manual>" line per flagged skill, plus the always-auto count.
reportSkillsInvocation() {
    [ -d "${skills_src_dir}" ] || return 0
    local f v auto=0 manual=0 always=0
    for f in "${skills_src_dir}"/*/SKILL.md; do
        [ -f "${f}" ] || continue
        v="$(skillGateValue "${f}")"
        case "${v}" in
            true)  manual=$((manual+1)) ;;
            false) auto=$((auto+1)) ;;
            *)     always=$((always+1)) ;;
        esac
    done
    echo "  ${auto} auto-invokable, ${manual} manual, ${always} always-auto (no flag)"
}

# -s/--skills-auto: flip the model-invocation gate across kit skills.
#
# 'on' snapshots each flagged skill's current value to generated/skills-auto.state
# before setting everything to false, and 'off' puts those exact values back -
# a blind false->true inversion would silently demote skills that were authored
# auto-invokable rather than flipped there. Skills carrying no flag at all (the
# deliberate auto-load set) are untouched in both directions. With no -s the
# function only reports: the committed values are the authored intent.
applySkillsInvocation() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit - skipped"; return 0; }

    if [ -z "${SKILLS_AUTO}" ]; then
        echo "  left as committed (pass -s on|off to change)"
        reportSkillsInvocation
        return 0
    fi

    local f name v changed=0

    if [ "${SKILLS_AUTO}" = "on" ]; then
        # Append-only. A snapshot already on disk holds the PRE-flip values, so a
        # repeat -s on must not overwrite them with the flipped ones it is about
        # to read back - that would silently turn -s off into a no-op and strand
        # every manual skill on auto. Skills added to the kit since the first
        # -s on are appended at their current value.
        touch "${skills_auto_state}"
        for f in "${skills_src_dir}"/*/SKILL.md; do
            [ -f "${f}" ] || continue
            v="$(skillGateValue "${f}")"
            [ -n "${v}" ] || continue
            name="$(basename "$(dirname "${f}")")"
            cut -f1 "${skills_auto_state}" | grep -qxF "${name}" \
                || printf '%s\t%s\n' "${name}" "${v}" >> "${skills_auto_state}"
            [ "${v}" = "false" ] && continue
            setSkillGateValue "${f}" false
            echo "  true->false  ${f#"${kit_root}"/}"
            changed=$((changed+1))
        done
        echo "  snapshot holds $(wc -l < "${skills_auto_state}") pre-flip value(s) in ${skills_auto_state#"${kit_root}"/}"
    elif [ -f "${skills_auto_state}" ]; then
        while IFS=$'\t' read -r name v; do
            f="${skills_src_dir}/${name}/SKILL.md"
            [ -f "${f}" ] || { echo "  skipped ${name} - no longer in the kit"; continue; }
            [ "$(skillGateValue "${f}")" = "${v}" ] && continue
            setSkillGateValue "${f}" "${v}"
            echo "  restored ${v}  ${f#"${kit_root}"/}"
            changed=$((changed+1))
        done < "${skills_auto_state}"
        rm -f "${skills_auto_state}"
        echo "  snapshot consumed and cleared"
    else
        echo "  no snapshot to restore - setting every flagged skill to manual"
        for f in "${skills_src_dir}"/*/SKILL.md; do
            [ -f "${f}" ] || continue
            [ "$(skillGateValue "${f}")" = "false" ] || continue
            setSkillGateValue "${f}" true
            echo "  false->true  ${f#"${kit_root}"/}"
            changed=$((changed+1))
        done
    fi

    if [ "${changed}" -eq 0 ]; then
        echo "  nothing to change"
    else
        echo "  ${changed} skill(s) rewritten"
        echo "  restart your agent to pick up the change (skills bind at session start)"
    fi
    reportSkillsInvocation
}

# Generate skills/<name>/agents/openai.yaml in the KIT from each SKILL.md's
# frontmatter, so Codex gets a display name + description per skill and - for
# skills marked disable-model-invocation: true - allow_implicit_invocation:
# false, its Codex analogue. Runs every install AFTER applySkillsInvocation so
# the yaml reflects this run's final frontmatter state; a file is rewritten only
# when its content changes. No prune pass - the yaml lives inside the skill dir
# and dies with it.
writeOpenAiSkillMeta() {
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit - skipped"; return 0; }
    local f dir name desc tmp written=0
    for f in "${skills_src_dir}"/*/SKILL.md; do
        [ -f "${f}" ] || continue
        dir="$(dirname "${f}")"
        name="$(basename "${dir}")"
        # description: from the frontmatter only (line 2 up to the closing ---).
        desc="$(sed -n "2,/^---\$/p" "${f}" | sed -n 's/^description: //p' | head -1)"
        [ -n "${desc}" ] || desc="${name}"
        # YAML double-quoted scalar: escape backslashes first, then quotes.
        desc="${desc//\\/\\\\}"
        desc="${desc//\"/\\\"}"
        tmp="$(mktemp)"
        {
            echo "interface:"
            echo "  display_name: \"${name}\""
            echo "  short_description: \"${desc}\""
            if sed -n "2,/^---\$/p" "${f}" | grep -q '^disable-model-invocation: true$'; then
                echo "policy:"
                echo "  allow_implicit_invocation: false"
            fi
        } > "${tmp}"
        if [ -f "${dir}/agents/openai.yaml" ] && cmp -s "${tmp}" "${dir}/agents/openai.yaml"; then
            rm -f "${tmp}"
            continue
        fi
        mkdir -p "${dir}/agents"
        mv "${tmp}" "${dir}/agents/openai.yaml"
        chmod 644 "${dir}/agents/openai.yaml"
        echo "  wrote -> ${dir#"${kit_root}"/}/agents/openai.yaml"
        written=$((written+1))
    done
    if [ "${written}" -eq 0 ]; then
        echo "  all agents/openai.yaml files already current - no change"
    else
        echo "  generated/updated ${written} agents/openai.yaml file(s)"
    fi
}

# Mirror the kit's skills into <dest_dir>/<name> as symlinks, tracking the ones
# we manage in <manifest> so a skill later removed from the kit is pruned rather
# than left dangling. Used for ~/.claude/skills, ~/.codex/skills and
# ~/.agents/skills alike.
#
# Teardown-then-rebuild, in two prune passes:
#   1a. Manifest pass - remove the link for any skill we previously created that
#       is no longer in the kit. Needed because a kit-moved-since install leaves
#       the link dangling to a stale path (which the target pass can't match).
#   1b. Target pass   - also drop any symlink still pointing into this kit's
#       skills/ dir: catches links from installs predating the manifest, and
#       skills renamed within the kit.
# Step 2 then (re)creates a fresh symlink for every skill currently in the kit and
# rewrites the manifest to that exact set (the source of truth for 1a next run).
#
# Safety floors: a destination that is a REAL directory (a hand-added skill) or a
# symlink pointing outside this kit is skipped with a warning and never claimed
# in the manifest, so a later run cannot prune it.
linkKitSkills() {
    local dest_dir="$1" manifest="$2"
    [ -d "${skills_src_dir}" ] || { echo "  no skills/ dir in kit - skipped"; return 0; }
    mkdir -p "${dest_dir}" "$(dirname "${manifest}")"

    # 1a. Manifest pass - remove links for kit skills that have since been deleted.
    if [ -f "${manifest}" ]; then
        local prev mdst
        while IFS= read -r prev; do
            [ -n "${prev}" ] || continue
            [ -d "${skills_src_dir}/${prev}" ] && continue   # still in the kit -> keep (re-linked below)
            mdst="${dest_dir}/${prev}"
            if [ -L "${mdst}" ]; then
                rm -f "${mdst}"
                echo "  unlink-> ${mdst} (removed from kit)"
            fi
        done < "${manifest}"
    fi

    # 1b. Target pass - drop any symlink that points into this kit's skills/.
    local dst raw
    for dst in "${dest_dir}"/*; do
        [ -L "${dst}" ] || continue
        raw="$(readlink "${dst}")"
        case "${raw}" in
            "${skills_src_dir}"/*)
                rm -f "${dst}"
                ;;
        esac
    done

    # 2. (Re)create a symlink for every skill currently in the kit, recording the
    #    ones we manage into a freshly-rewritten manifest.
    local src name linked=0
    : > "${manifest}"
    for src in "${skills_src_dir}"/*/; do
        [ -d "${src}" ] || continue
        name="$(basename "${src}")"
        dst="${dest_dir}/${name}"
        # A leftover here is a real dir or a foreign symlink (not ours - 1a/1b
        # removed every kit-managed link) - leave it, and don't claim it in the
        # manifest, so a hand-added skill is never pruned on a later run.
        if [ -L "${dst}" ] || [ -e "${dst}" ]; then
            echo "  skip  -> ${dst} (exists and not kit-managed - leaving alone)"
            continue
        fi
        ln -s "${src%/}" "${dst}"
        printf '%s\n' "${name}" >> "${manifest}"
        linked=$((linked+1))
    done
    echo "  linked ${linked} skill(s) into ${dest_dir} (manifest: ${manifest})"
}
