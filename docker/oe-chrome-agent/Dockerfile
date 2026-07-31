# Chrome + Xvfb + noVNC + Claude Code, containerised, for driving OpenEyes UI walks/repro
# via the Claude in Chrome extension (see docs/chrome-agent.md). node:22-slim over a
# browser-testing image: same base as docker/codex/Dockerfile, one glibc/Debian lineage
# for both agent containers.
FROM node:22-slim

RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        wget gnupg ca-certificates \
        xvfb fluxbox x11vnc novnc websockify \
    && wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -qqy --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

# Same rationale as docker/codex/Dockerfile: run as the invoking host user (--user uid:gid)
# so the mounted state stays user-owned; 0777 lets any uid use this HOME. Both ~/.claude
# and Chrome's profile (~/chrome-profile - non-default so Chrome allows CDP; the entrypoint
# symlinks ~/.config/google-chrome onto it) live in the container's writable layer and are
# destroyed on recreate. The only bind mount carrying state is ~/state, which holds the two
# saved logins - see save-state.sh and docs/chrome-agent.md.
# /tmp/.X11-unix must exist and be world-writable before Xvfb runs as a non-root uid, or it
# fails to create its socket there (euid != 0).
RUN mkdir -p /home/agent /tmp/.X11-unix \
    && chmod 0777 /home/agent \
    && chmod 1777 /tmp/.X11-unix
ENV HOME=/home/agent
ENV DISPLAY=:99
WORKDIR /home/agent

# Chrome policy: no metrics/crash reports to Google, no default-browser nag (there's no
# OS-level "default browser" inside a container - $BROWSER below does that job),
# force-installs the Claude in Chrome extension so pairing never needs a manual Web Store
# visit, and blocks everything else the browser would otherwise offer a walk - other
# extensions, incognito, browser sign-in, the password-save bubble, autofill, notifications,
# a download-location prompt. chmod 0644 so an arbitrary --user uid can still read it.
COPY chrome-policy.json /etc/opt/chrome/policies/managed/claude-kit.json
RUN chmod 0644 /etc/opt/chrome/policies/managed/claude-kit.json

# The runtime half of the policy - the navigation allowlist, which can only be written at boot
# because the OE origin comes from $OE_URL (see the entrypoint's writeLockdownPolicy). Shipped
# as {} and world-writable so an arbitrary --user uid can rewrite this one file without the
# root-owned policy directory itself being writable. Keys are split strictly between the two
# files: Chrome merges the directory and a key set in both has no defined winner.
RUN echo '{}' > /etc/opt/chrome/policies/managed/oe-lockdown.json \
    && chmod 0666 /etc/opt/chrome/policies/managed/oe-lockdown.json

# $BROWSER: whatever URL the CLI wants opened (e.g. the /login OAuth link) is handed to
# the already-running Chrome via its ProcessSingleton instead of spawning a second one.
COPY browser.sh /usr/local/bin/browser
RUN chmod 0755 /usr/local/bin/browser
ENV BROWSER=/usr/local/bin/browser

# CDP-driven OE auto-login, run backgrounded by the entrypoint after Chrome starts.
COPY oe-login.mjs /usr/local/bin/oe-login.mjs
RUN chmod 0644 /usr/local/bin/oe-login.mjs

# Opens the extension's options tab after oe-login.mjs settles - see startOeAutoLogin.
COPY open-options-tab.mjs /usr/local/bin/open-options-tab.mjs
RUN chmod 0644 /usr/local/bin/open-options-tab.mjs

# Agent-free annotated screenshots: red-box a selector's matches and capture, over CDP.
COPY highlight-shot.mjs /usr/local/bin/highlight-shot.mjs
RUN chmod 0644 /usr/local/bin/highlight-shot.mjs

# Bare / auto-connects and scales instead of requiring the full vnc.html query string.
COPY novnc-index.html /usr/share/novnc/index.html
RUN chmod 0644 /usr/share/novnc/index.html

# Extension state seed/dump (classic-level to read/write its LevelDB store directly) - the
# one real dependency in this image, so these get their own node_modules rather than living
# next to the dependency-free oe-login.mjs.
COPY package.json seed-extension-state.mjs dump-extension-state.mjs /usr/local/lib/oe-chrome-agent/
RUN cd /usr/local/lib/oe-chrome-agent && npm install --omit=dev --no-audit --no-fund --silent \
    && chmod 0644 seed-extension-state.mjs dump-extension-state.mjs

# Lifts the two logins into the mounted state dir. Run by the entrypoint at boot before it
# wipes, by drive.sh after every prompt, and by reset-session.sh before `down` - the CLI's
# refresh token rotates on use, so a saved copy that is never refreshed expires by itself.
COPY sync-state.sh /usr/local/bin/sync-state.sh
RUN chmod 0755 /usr/local/bin/sync-state.sh

# Pre-warm the profile the entrypoint copies for every fresh container. Chrome is started
# once here purely so the managed policy above force-installs and unpacks the extension into
# a profile skeleton; without this the extension is re-downloaded from the Web Store on
# every container recreate, which the disposable-profile layout makes a routine event.
# The Default/Service Worker dir must NOT ship in the template: its registration store is
# tied to the profile path it was created under, so after the copy to ~/chrome-profile the
# extension's MV3 worker persistently fails to start (DidStartWorkerFail, "Receiving end
# does not exist" on any page messaging it). Chrome re-registers it cleanly at first boot.
# 0777 because an arbitrary --user uid has to be able to copy this out at boot.
RUN mkdir -p /opt/chrome-profile-template \
    && (google-chrome-stable --no-sandbox --disable-dev-shm-usage --headless=new --disable-gpu \
          --user-data-dir=/opt/chrome-profile-template --no-first-run --no-default-browser-check \
          about:blank > /tmp/prewarm.log 2>&1 &) \
    && for i in $(seq 1 60); do \
         [ -d "/opt/chrome-profile-template/Default/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn" ] && break; \
         sleep 1; \
       done \
    && pkill -TERM chrome || true \
    && sleep 2 \
    && [ -d "/opt/chrome-profile-template/Default/Extensions/fcoeoabgfenejglbffodgkkbkcdhcgfn" ] \
       || { echo "extension pre-warm failed - see /tmp/prewarm.log"; cat /tmp/prewarm.log; exit 1; } \
    && rm -rf "/opt/chrome-profile-template/Default/Cache" \
              "/opt/chrome-profile-template/Default/Code Cache" \
              "/opt/chrome-profile-template/Default/Service Worker" \
              "/opt/chrome-profile-template/SingletonLock" \
              "/opt/chrome-profile-template/SingletonSocket" \
              "/opt/chrome-profile-template/SingletonCookie" \
    && chmod -R a+rwX /opt/chrome-profile-template \
    && rm -rf /home/agent/.config /home/agent/.local /home/agent/.npm

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
