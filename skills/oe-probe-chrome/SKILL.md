---
name: oe-probe-chrome
description: Drive OpenEyes in a real Chrome via the Claude-in-Chrome sidecar for interactive/gesture-heavy walks
disable-model-invocation: false
---

# OE probe - Chrome agent

When loaded as context with no task, reply only `Context loaded.`

Thin wrapper around `docker/oe-chrome-agent/` (in `~/claude-kit`): a sidecar container running a real Google Chrome under Xvfb, with the Claude in Chrome extension paired to a Claude Code CLI in the same container, driving a running OpenEyes instance the way a user would - real clicks, real gestures, watchable live over noVNC, GIF/screenshot recording built in. Full mechanics, setup, and troubleshooting live in `docs/chrome-agent.md` (~250 lines) - **read that file, don't ask for it to be duplicated here**; this skill only orients you to when and how to reach for it.

## When to use this over the other two probes

Three ways to drive OpenEyes exist in this kit; pick by task shape, not habit:

| Probe | Cost per step | Best for |
|---|---|---|
| `c-oe-nav`'s in-container Puppeteer (`subs/probe.md`) | Cheapest - a Haiku subagent + `docker exec` | Known journeys, bulk mechanical field/label capture, verification sweeps |
| `oe-probe-playwright` | Similar, when Puppeteer isn't available | Same as above, on images/stacks without bundled Chrome |
| **`oe-probe-chrome` (this skill)** | Heaviest - a full agentic Chrome session per call | Interactive, gesture-heavy exploratory walks where the flow itself needs figuring out; recording a GIF/screenshot as evidence; authoring a new canned walk |

**Never** use this for bulk mechanical field-table verification (documenting/checking many pages) - an agentic browser session per page is 10-50x the cost of a Haiku + `journey.mjs` dump-and-compare call. Reach for it when a human wants to *watch* the walk happen, when the journey isn't already known well enough to script, or to produce a recorded artifact.

## Setup (once per host/deployment)

`docs/chrome-agent.md`'s "Setup (once per host)" section - `./install.sh -w` from `~/claude-kit` (or `docker/oe-chrome-agent/setup-walker.sh` directly), then the one-time "First run only" three-step pass over noVNC at `http://localhost:6080`: CLI `/login` taking its **browser** flow first, then the extension's **Log in**, which that ordering collapses to a single Authorize click. Steady state after that needs zero manual steps. **Every start is a clean browser** - the entrypoint wipes the profile, `~/.claude` and `/tmp` on a restart as well as a recreate, so one walk never begins inside the last walk's cookies or site grants, and the two saved logins are restored at boot and re-harvested automatically after every drive. Chrome is policy-locked to the OE origin plus the sign-in origins; an unexpected `ERR_BLOCKED_BY_ADMINISTRATOR` is that lockdown, and `docs/chrome-agent.md` has the escape hatch.

## Driving

```bash
cd ~/claude-kit/docker/oe-chrome-agent
./drive.sh "<prompt>"
```

Under the hood: `printf '%s' "<prompt>" | docker exec -i claude-chrome claude -p --chrome --allowedTools "mcp__claude-in-chrome" --output-format json`. Multi-turn: `-s <session-id>`; tag logs and name the evidence folder: `-t <name>`; prepend a walk map: `-f <map-file>`; reboot first: `-r`; evidence elsewhere: `-e <dir>`.

### Two rules that are not optional

1. **Reboot before the first drive of a new reproduction.** `./drive.sh -r -t <slug> "<prompt>"`. Without `-r` the walk inherits the last walk's browser: whatever tabs, autosave drafts, half-filled forms and site grants it left behind, and an OE session that may be days old. A repro that starts there is not deterministic, and a repro that cannot be reproduced from a cold start is not a repro. `-r` restarts the container, which makes the entrypoint wipe the Chrome profile, `~/.claude` and `/tmp` and lay a fresh profile down from the baked template, then waits for the OE auto-login to land before driving. Later drives *within the same* reproduction skip `-r` - the point is a clean start, not a clean step. `-r` and `-s` are mutually exclusive and the script refuses the pair: the restart deletes the very transcript `-s` resumes.
2. **The evidence always leaves the container, and `drive.sh` does it for you.** Every drive copies each `/tmp/claude-chrome-*` file plus the walk's own JSON result into `~/repro-evidence/<date>-<tag>/`, and prints `EVIDENCE: <dir>` at the end. This is not tidiness. The extension writes screenshots into `/tmp`, the entrypoint clears `/tmp` on every boot, and rule 1 makes a boot the first thing the next reproduction does - so evidence still sitting in the container is evidence with a countdown on it. Pass a real `-t <slug>` so the folder is findable, and cite that folder in the repro's Evidence block. `~/repro-evidence` is outside `~/claude-kit` on purpose: the kit has a public remote and a walk photographs whatever the page happened to be showing.

**Check `ls ~/claude-kit/skills/c-oe-nav/subs/canned/` first** - if this exact journey was already walked, replay it with `./drive.sh -f subs/canned/<journey>.md "<what to re-verify>"` instead of a fresh exploratory walk. After a genuinely novel walk, distill it into a new `subs/canned/<journey>.md` file (same format as the existing ones) and add it to the index in `c-oe-nav/SKILL.md`.

## Discovery walks

The main paying use is bug discovery for **`c-oe-repro`**, and it comes with one rule, stated there as the whole cost story:

> **Chrome discovers the path. Puppeteer proves it. Confirmation replays never run in Chrome.**

So a discovery session here is scoped to exactly one job - **find the click path and narrate it**, quoting each control's on-screen label and marking which choices are free. It is not the place to re-run a known repro, verify a fix, or sweep pages. The moment the path is found, distil it into `c-oe-nav/subs/canned/<journey>.md`; every later run of that journey then costs a Haiku subagent instead of an agentic browser session. A Chrome walk that was never canned has been paid for twice.

Before spending a session, check the three gates in `c-oe-repro/subs/discovery.md`: is the journey already canned, does the screen have a row in `c-oe-nav/subs/page-index.md`, and do the form tables already carry the labels. All three miss -> this skill. Any one hits -> rung 1.

Repro brief template and prompt-style notes ("Do this now with tool calls, do not answer from memory" to force a live walk) are in `docs/chrome-agent.md`'s "Driving unattended" section.
