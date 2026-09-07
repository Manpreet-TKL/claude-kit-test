#!/bin/bash
# Manpreet 06/09/2026
# Read-only AWS CLI for agents (Claude Code and standalone Codex), via the
# official aws-cli container. One long-lived container shared by every session
# and by the human; each session must arm the kit's one-shot gate before its
# first read. Writes are not blocked here - IAM is the boundary (docs/aws.md).

set -e

kit_root="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
container="ai-kit-aws-ro"
image="public.ecr.aws/aws-cli/aws-cli:latest"
secrets="${HOME}/.claude/mcp-env/.aws.env"
gate_dir="${kit_root}/generated/mcp-on"
flag="${gate_dir}/aws"
idle_seconds="${AGENT_AWS_IDLE_SECONDS:-28800}"

usage() {
    cat >&2 <<EOF
usage: bash ${BASH_SOURCE[0]} <command>

  run <aws arguments>   Run one read through the container (gate must be armed)
  up [--force]          Pull the latest image and start the container if absent
  down                  Remove the container
  status                Report container, image, gate and idle state

Arming the gate for this session:  touch ${flag}
EOF
    exit 2
}

running() { [ -n "$(docker ps -q -f "name=^${container}$" 2>/dev/null)" ]; }

# One id per agent session, so arming the gate lasts that session and no longer.
# The host's own session variable when there is one; otherwise the nearest
# ancestor that IS the agent process (subagents run in-process, so they share
# it, and it survives the Bash tool starting a fresh shell per call).
sessionId() {
    if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then echo "${CLAUDE_CODE_SESSION_ID}"; return; fi
    if [ -n "${CODEX_SESSION_ID:-}" ]; then echo "${CODEX_SESSION_ID}"; return; fi
    local pid="${PPID}" name
    while [ -n "${pid}" ] && [ "${pid}" -gt 1 ] 2>/dev/null; do
        name="$(ps -o comm= -p "${pid}" 2>/dev/null | tr -d ' ')"
        case "${name}" in claude | codex | node) echo "pid-${pid}"; return ;; esac
        pid="$(ps -o ppid= -p "${pid}" 2>/dev/null | tr -d ' ')"
    done
    echo "pid-${PPID}"
}

# The gate is one-shot like every other MCP in the kit, but this script is
# invoked many times per session, so consuming the flag leaves a per-session
# marker rather than the 60s window a single MCP spawn needs.
gateCheck() {
    local marker="${flag}.session.$(sessionId)"
    if [ -f "${marker}" ]; then
        # A later installer run may have pre-armed another flag while this
        # session stayed active. Any agent use closes that flag to new sessions.
        rm -f "${flag}"
        return 0
    fi
    mkdir -p "${gate_dir}"
    if mv "${flag}" "${marker}" 2>/dev/null; then
        touch "${marker}"
        find "${gate_dir}" -name 'aws.session.*' -mtime +1 -delete 2>/dev/null || true
        return 0
    fi
    echo "aws gated off for this session - arm it: touch ${flag}" >&2
    exit 1
}

up() {
    command -v docker >/dev/null 2>&1 || { echo "docker not found - this kit installs nothing on the host" >&2; exit 1; }
    [ -f "${secrets}" ] || { echo "missing ${secrets} - run: bash ${kit_root}/install.sh -a -p standard" >&2; exit 1; }
    if running; then
        if [ "${1:-}" != "--force" ]; then
            echo "${container} already running - nothing to do ('up --force' recreates it on the latest image)"
            return 0
        fi
        docker rm -f "${container}" >/dev/null
    fi
    docker pull "${image}"
    local keepalive="touch /tmp/.lastuse; echo ${idle_seconds} > /tmp/.idle; while [ \$(( \$(date +%s) - \$(stat -c %Y /tmp/.lastuse) )) -lt ${idle_seconds} ]; do sleep 60; done"
    docker run -d --rm --name "${container}" --env-file "${secrets}" --entrypoint sh "${image}" -c "${keepalive}" >/dev/null
    echo "${container} up on ${image} - self-removes after ${idle_seconds}s idle"
}

run() {
    [ "$#" -gt 0 ] || usage
    gateCheck
    running || { echo "${container} is not running - start it: bash ${kit_root}/scripts/agent-aws-cli.sh up" >&2; exit 1; }
    docker exec "${container}" touch /tmp/.lastuse
    exec docker exec -i -e "AWS_EXECUTION_ENV=agent-aws-cli/$(sessionId)" "${container}" /usr/local/bin/aws "$@"
}

down() {
    if running; then
        docker rm -f "${container}" >/dev/null
        echo "${container} removed"
    else
        echo "${container} not running"
    fi
}

status() {
    if running; then
        echo "container: ${container} running, $(docker exec "${container}" /usr/local/bin/aws --version 2>&1 | cut -d' ' -f1)"
        echo "idle out:  $(( $(docker exec "${container}" cat /tmp/.idle) - ($(date +%s) - $(docker exec "${container}" stat -c %Y /tmp/.lastuse)) ))s from now"
    else
        echo "container: ${container} not running - bash ${kit_root}/scripts/agent-aws-cli.sh up"
    fi
    if [ -f "${flag}.session.$(sessionId)" ]; then
        echo "gate:      armed for this session"
    elif [ -f "${flag}" ]; then
        echo "gate:      pre-armed, consumed by the next run"
    else
        echo "gate:      shut - arm it: touch ${flag}"
    fi
}

command="${1:-}"
[ "$#" -gt 0 ] && shift
case "${command}" in
    run) run "$@" ;;
    up) up "$@" ;;
    down) down ;;
    status) status ;;
    *) usage ;;
esac
