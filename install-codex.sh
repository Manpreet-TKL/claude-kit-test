#!/bin/bash -l
# Manpreet 10/08/2026
# Install claude-kit for standalone, containerised Codex.
set -e
abort() { echo "ABORTED DUE TO ERROR" >&2; exit 1; }
trap abort 0
kit_root="$(dirname "$(realpath "$0")")"
skills_src="${kit_root}/skills"
codex_home="${HOME}/.codex"
skills_dir="${HOME}/.agents/skills"
manifest="${HOME}/.agents/.claude-kit-skills"
agents_src="${kit_root}/claude-md/CLAUDE.md"
agents_md="${codex_home}/AGENTS.md"
image="claude-kit-codex"
command -v docker >/dev/null 2>&1 || { echo "Docker is required. Install Docker, then re-run." >&2; exit 1; }
mkdir -p "${codex_home}" "${skills_dir}"
if ! docker image inspect "${image}" >/dev/null 2>&1; then
    docker build -t "${image}" "${kit_root}/docker/codex"
fi
if [ -e "${agents_md}" ] && [ ! -L "${agents_md}" ]; then
    cp -p "${agents_md}" "${agents_md}.bak"
fi
ln -sfn "${agents_src}" "${agents_md}"
if [ -f "${manifest}" ]; then
    while IFS= read -r name; do
        [ -n "${name}" ] || continue
        [ -d "${skills_src}/${name}" ] && continue
        [ -L "${skills_dir}/${name}" ] && rm -f "${skills_dir}/${name}"
    done < "${manifest}"
fi
for destination in "${skills_dir}"/*; do
    [ -L "${destination}" ] || continue
    case "$(readlink "${destination}")" in
        "${skills_src}"/*) rm -f "${destination}" ;;
    esac
done
: > "${manifest}"
for source in "${skills_src}"/*/; do
    [ -d "${source}" ] || continue
    name="$(basename "${source}")"
    destination="${skills_dir}/${name}"
    if [ -L "${destination}" ] || [ -e "${destination}" ]; then
        echo "Skipping ${destination} - exists and is not kit-managed"
        continue
    fi
    ln -s "${source%/}" "${destination}"
    printf '%s\n' "${name}" >> "${manifest}"
done
for skill_file in "${skills_src}"/*/SKILL.md; do
    [ -f "${skill_file}" ] || continue
    skill_dir="$(dirname "${skill_file}")"
    name="$(basename "${skill_dir}")"
    description="$(sed -n "2,/^---\$/p" "${skill_file}" | sed -n 's/^description: //p' | head -1)"
    description="${description//\\/\\\\}"
    description="${description//\"/\\\"}"
    temporary="$(mktemp)"
    {
        echo "interface:"
        echo "  display_name: \"${name}\""
        echo "  short_description: \"${description:-${name}}\""
        if sed -n "2,/^---\$/p" "${skill_file}" | grep -q '^disable-model-invocation: true$'; then
            echo "policy:"
            echo "  allow_implicit_invocation: false"
        fi
    } > "${temporary}"
    mkdir -p "${skill_dir}/agents"
    if [ ! -f "${skill_dir}/agents/openai.yaml" ] || ! cmp -s "${temporary}" "${skill_dir}/agents/openai.yaml"; then
        mv "${temporary}" "${skill_dir}/agents/openai.yaml"
    else
        rm -f "${temporary}"
    fi
done
if [ ! -f "${codex_home}/auth.json" ]; then
    login_cmd='docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth'
    if [ -t 0 ] && [ -t 1 ]; then
        docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "${codex_home}:/home/codex/.codex" "${image}" login --device-auth
    else
        echo "Codex is not signed in. Run: ${login_cmd}"
    fi
fi
trap : 0
echo "Standalone Codex ready. Run ./codex.sh"
