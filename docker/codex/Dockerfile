# Codex CLI containerised for the codex MCP server (see docs/codex.md).
# OpenAI ships no official CLI image, so install.sh -x builds this one locally
# as claude-kit-codex. debian-slim over alpine: codex agents run commands via
# bash, and the glibc binary avoids musl edge cases.
FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ripgrep ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @openai/codex

# The container runs as the invoking host user (--user uid:gid at run time) so
# files written into the mounted workspace stay user-owned; 0777 lets any uid
# use this HOME, and ~/.codex (auth + session logs) is bind-mounted over it.
RUN mkdir -p /home/codex && chmod 0777 /home/codex
ENV HOME=/home/codex

ENTRYPOINT ["codex"]
