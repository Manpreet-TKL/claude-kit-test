FROM node:22-slim

RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends wget gnupg ca-certificates xvfb fluxbox x11vnc novnc websockify \
    && wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -qqy --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g chrome-devtools-mcp @playwright/mcp

RUN mkdir -p /home/agent /tmp/.X11-unix && chmod 0777 /home/agent && chmod 1777 /tmp/.X11-unix
ENV HOME=/home/agent
ENV DISPLAY=:99
WORKDIR /home/agent

COPY oe-chrome-agent/oe-login.mjs /usr/local/bin/oe-login.mjs
COPY oe-chrome-agent/highlight-shot.mjs /usr/local/bin/highlight-shot.mjs
COPY oe-chrome-agent/novnc-index.html /usr/share/novnc/index.html
COPY codex-chrome-agent/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh && chmod 0644 /usr/local/bin/oe-login.mjs /usr/local/bin/highlight-shot.mjs /usr/share/novnc/index.html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
