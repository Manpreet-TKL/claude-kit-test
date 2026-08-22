#!/bin/bash -l
# Manpreet 22/08/2026
set -e

screen_geometry="${SCREEN_GEOMETRY:-1920x1080x24}"
oe_url="${OE_URL:-http://web}"

mkdir -p "${HOME}/chrome-profile" "${HOME}/artifacts"
Xvfb :99 -screen 0 "${screen_geometry}" -ac +extension RANDR &
fluxbox >/tmp/fluxbox.log 2>&1 &
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 >/tmp/x11vnc.log 2>&1 &
websockify --web=/usr/share/novnc 6080 localhost:5900 >/tmp/novnc.log 2>&1 &

google-chrome-stable --no-sandbox --test-type --disable-dev-shm-usage --no-first-run --no-default-browser-check --password-store=basic --user-data-dir="${HOME}/chrome-profile" --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 "${oe_url}" &

CDP_PORT=9222 node /usr/local/bin/oe-login.mjs >"${HOME}/oe-login.log" 2>&1 &
echo "noVNC ready on port 6080; CDP ready inside the container on port 9222"
wait
