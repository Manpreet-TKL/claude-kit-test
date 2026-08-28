---
name: oe-probe-codex-chrome
description: Drive OpenEyes in the isolated Codex Chrome sidecar through Chrome DevTools or Playwright MCP
disable-model-invocation: false
---

# OE probe - Codex Chrome

When loaded as context with no task, reply only `Context loaded.`

Use this skill for interactive OpenEyes browser walks from Codex. The browser, its profile, and both MCP servers run in `docker/codex-chrome-agent/`; Codex stays on the host and reaches the container only through `docker exec` MCP wrappers.

Prefer `chrome-devtools` for inspection, screenshots, performance, console, and network work. Prefer `playwright` for repeatable user interactions and accessibility-based selectors. Use only the configured OpenEyes origin. Never put browser profiles, cookies, credentials, or screenshots in the kit.

Set up once with `bash /home/toukan/claude-kit/codex-install.sh -w`. Watch the browser at `http://localhost:6081`. The persistent Chrome profile is machine-local at `~/.claude/codex-chrome-agent`; only its non-secret Docker network and URL pointers are stored under `generated/`.

The two MCPs are disabled at normal startup. If their tools are absent, run `touch /home/toukan/claude-kit/generated/mcp-on/chrome-devtools /home/toukan/claude-kit/generated/mcp-on/playwright`, then restart Codex. They are enabled for that new session only.
