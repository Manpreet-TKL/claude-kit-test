# Manpreet 25/07/2026
# Sourced by the four host-side walker scripts (setup-walker.sh, drive.sh, save-state.sh,
# reset-session.sh) - not executable on its own.
#
# Resolves the ONE path holding the walker's two saved logins, and exports it so the
# docker compose call in the same script interpolates the same value.
#
# It lives under ~/.claude and NEVER inside ~/claude-kit. The kit is a git repo with a
# remote; a credential in its working tree is one `git add -f`, one .gitignore edit or one
# `tar czf kit.tgz ~/claude-kit` away from being published. ~/.claude is machine-local by
# definition and is never git-tracked. Keep it that way for anything new - see the "no
# secrets in the kit" rule in claude-md/CLAUDE.md.
#
# install.sh preserves this directory across --fresh alongside .credentials.json.

state_dir="${OE_CHROME_STATE_DIR:-${HOME}/.claude/oe-chrome-agent}"
export OE_CHROME_STATE_DIR="${state_dir}"
# Pre-create it user-owned: if compose's bind mount references it first, dockerd creates it
# root-owned and sync-state.sh then can't write the logins back.
mkdir -p "${state_dir}"
