# OE Chrome agent - Claude in Chrome, containerised

A sidecar container (`docker/oe-chrome-agent/`) that runs a real Google Chrome under Xvfb,
with the [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)
installed, paired to a Claude Code CLI running in the same container. Built for driving
OpenEyes UI walks, documentation screenshots, and bug repro - Claude clicks through the
real app the way a user would, records GIFs/screenshots, and the browser is watchable
live over noVNC.

Everything that can be automated is: the container boots with the extension force-installed,
the native-messaging pairing pre-seeded, the CLI's tool permissions pre-allowed, the
extension's own site permission for `OE_URL` seeded directly into its LevelDB grant store,
and OE already logged in (CDP auto-login below the extension). The human signs in exactly
**once, ever** on a host - the CLI's `/login` and the extension's own claude.ai login - and
those two are lifted out into `~/.claude/oe-chrome-agent/` as ~1 KB of JSON that every later
container restores at boot, kept current automatically from then on (see "What persists").

**Every start is a clean browser.** The entrypoint wipes the container's own state - Chrome
profile, `~/.claude`, `/tmp` - and lays a fresh profile back down, on a restart as well as a
recreate, so one walk never begins inside the last walk's cookies, history or site grants.
Chrome is also policy-locked to the OE origin and the sign-in origins, since driving one
OpenEyes instance is the only thing this container is for. Steady-state operation needs zero
manual steps. `reset-session.sh -f | --full` drops the two saved logins as well, for a shared
host or a handover.

This is deliberately not the `oe-playwright-harness-plan.md` approach (a Playwright-driven
Chromium sidecar, still unbuilt). That harness is cheaper per step and fully unattended;
this container is heavier per step but lets Claude reason and adapt turn-by-turn, and
gives a human a live window into what's happening.

## How pairing actually works (validated)

Claude in Chrome pairs with Claude Code via Chrome's **native messaging** API - Chrome
reads a manifest under the profile dir and spawns `claude.exe --chrome-native-host` over
stdio. Same-host by construction, hence one container. Validated specifics:

1. **The CLI writes the manifest only at startup** (`claude --chrome` while already
   logged in) - running `/chrome` mid-session does NOT write it, which is why naive
   setups need a restart-after-`/login` dance. Both files are deterministic, so the
   entrypoint seeds them on every boot instead: the manifest at
   `<profile>/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json` and
   the host shim at `~/.claude/chrome/chrome-native-host`. Chrome can pair on first start,
   no restart ever needed.
2. **Two separate logins exist, and both need their own manual action** (validated
   2026-07-24). The CLI's `/login` writes `~/.claude/.credentials.json`. The extension keeps
   its own claude.ai session independently, gated behind its own **Log in** button on
   `chrome-extension://<ext-id>/options.html`: the CLI and the extension are separate OAuth
   clients with different scopes, so this click is never skippable. **Order matters, and it
   is the only lever there is.** Do the CLI first and take its *browser* flow (not
   paste-a-code): that completes against claude.ai in this container's own Chrome, so the
   extension's sign-in then finds itself already authenticated and collapses to a single
   Authorize click. Done the other way round it asks for the password twice. Both are
   one-time per host - each is a handful of OAuth tokens that live in the kit and get
   restored into every later container (see "What persists"); the entrypoint also pre-opens
   the extension's options tab on every boot so it's sitting there ready in noVNC if a
   re-sign-in is ever needed.
3. **Three permission layers gate automation**, and they are independent:
   - *CLI tool gate*: print mode (`claude -p`) auto-denies MCP tools. Pre-seeded away via
     `~/.claude/settings.json` allowing `mcp__claude-in-chrome` (the entrypoint writes it).
   - *Extension approval*: **persists at the site/profile level, not per CLI session**
     (validated 2026-07-23: a brand-new `-p --chrome` session with no `--resume`, run both
     immediately after an earlier approval and again after a full `docker compose
     restart`, hit zero permission denials). It is scoped **per origin** (verified
     2026-07-23: a profile approved for `http://snail-web-1` was denied on first
     navigation to `http://web`, even though both resolve to the same container).
     Originally a one-time manual noVNC click; now auto-seeded (validated 2026-07-23 via a
     LevelDB round-trip on a disposable profile copy: strip the grant, confirm denial
     reproduces, write it back via `seed-extension-state.mjs`, confirm an identical fresh
     session succeeds with no click - byte-for-byte the same outcome as the manual path).
     The grant is a JSON blob under the `permissionStorage` key in the extension's own
     `chrome.storage.local` LevelDB store (`Default/Local Extension Settings/<ext-id>/` -
     plain LevelDB, openable with `classic-level`, no custom comparator). The entrypoint
     runs `seed-extension-state.mjs` before `startChrome` on every boot - Chrome holds that
     store's file lock for as long as it's running, so this can only happen before Chrome
     starts - and it writes an `always`-duration `allow` grant for `OE_URL`'s origin if one
     isn't there yet; idempotent, so switching `OE_NETWORK`/`OE_URL` mid-life needs no
     re-approval either, automated or manual, any more. CDP itself cannot drive this
     directly (validated 2026-07-23: Chrome silently refuses all DevTools protocol
     commands against any extension-origin target - service worker, background page, or a
     freshly opened options page - while identical code against a normal page target works
     instantly), hence writing the LevelDB store directly instead of scripting the
     extension's own UI. Falls back to the one-time manual click only if the seed step
     itself fails (logged, non-fatal - see Troubleshooting).
   - *Tab groups*: each session only sees its own tabs it creates, but a fresh session
     with no tabs yet just creates one on first navigation - this doesn't reintroduce a
     per-session step. OE's auth cookie is profile-wide, so the CDP auto-login covers
     every session's tabs regardless. Tabs would otherwise accumulate, one per session -
     `oe-login.mjs` closes every extra tab down to one and re-asserts the OE session, and
     `drive.sh` runs it before **every** prompt, not just at boot, so each drive starts from
     exactly one tab at `OE_URL`. It keeps a `http`/`https` tab as the survivor rather than
     whichever the debugger lists first, so the extension's own options tab is never the one
     that gets driven. Skipped on `-s` (resume), because it also navigates that tab.
4. **The extension refuses to type passwords** - even sample `admin`/`admin` (policy).
   Login must happen below the extension: `oe-login.mjs` drives Chrome over CDP
   (localhost-only port 9222, never published) and submits the OE form before any agent
   session starts.
5. **Chrome 136+ refuses `--remote-debugging-port` on the default profile dir**, and it
   realpaths the flag value, so a symlink alias of the default dir is also refused. The
   working layout: the profile lives at the NON-default `~/chrome-profile` inside the
   container, Chrome runs with `--user-data-dir` pointing there, and
   `~/.config/google-chrome` is a symlink onto it so the CLI's hardcoded manifest writes
   still land in the live profile.

## What persists vs. what's destroyed

**Nothing in the container persists except the two logins.** `wipeContainerState` runs on
every start and removes the Chrome profile, `~/.claude`, `~/.claude.json`, `~/.config` and
everything in `/tmp` (bar the `.X11-unix` socket dir). `createChromeProfile` then lays a
fresh profile down from the baked template unconditionally. So a **restart is a full reset**,
not just a recreate - cookies, history, caches, transcripts and every site grant the last
walk collected are gone either way, and the copy costs about 0.05s.

The bind mounts are untouched by design: `~/state` (the saved logins) and `~/artifacts`
(screenshots and GIFs, host-visible).

What survives is deliberately tiny - **two login files, about 1 KB of JSON**, in
`~/.claude/oe-chrome-agent/` - **outside the kit on purpose**. `~/claude-kit` is a git repo
with a remote, and a live OAuth credential in its working tree is one `git add -f` or one
archive of the folder away from being published; `.gitignore` is not a security control.
The path is resolved in one place, `docker/oe-chrome-agent/state-dir.sh`, which the four
host scripts source and which exports `OE_CHROME_STATE_DIR` for `docker-compose.yml` to
interpolate - set that variable to relocate it. `install.sh --fresh` preserves the
directory alongside `.credentials.json`.

| File | What it is |
|---|---|
| `claude-credentials.json` | the CLI's `/login` OAuth credential |
| `extension-state.json` | the extension's claude.ai OAuth tokens plus the always-allow grant for the OE origin |

**Those two are kept current automatically**, which matters more than it looks: the
extension's token lasts about a year, but the CLI's access token lasts ~8h and its *refresh*
token rotates on use with a hard 28-day fuse. A copy saved once and never updated expires on
its own. `sync-state.sh` runs inside the container and writes both out; four things call it:

| Caller | When | Why |
|---|---|---|
| `entrypoint.sh` (`harvestSavedLogins`) | boot, **before** the wipe | catches whatever the last boot refreshed - Chrome is dead, so the extension's LevelDB reads with no lock |
| `drive.sh` (`syncState`) | after every prompt | a prompt is the only thing that makes the CLI touch its refresh token |
| `reset-session.sh` | before `down` (skipped on `-f`) | `down` destroys the writable layer |
| `save-state.sh` | by hand | belt and braces, e.g. straight after the first sign-in |

Ordering is load-bearing: the harvest runs before the wipe, or every restart would eat the
credential it exists to preserve.

`entrypoint.sh` restores both before Chrome starts (`restoreClaudeCredentials` and
`seed-extension-state.mjs`), so every boot comes up already signed in and already permitted
on the OE origin, with a browser that has never seen a previous session. The extension itself
is not re-downloaded either: the image bakes an unpacked copy into
`/opt/chrome-profile-template` at build time and the entrypoint copies that down.

One thing does not survive a restart any more: `drive.sh -s <session-id>`. Transcripts live
in `~/.claude`, so multi-turn continuity is a within-boot facility.

`reset-session.sh` is therefore only for getting rid of the container itself - a different OE
deployment, a different network, a handover. `-f | --full` additionally deletes the two saved
logins, and the next boot then needs the interactive pair again.

Only a full interactive `/login` (subscription) keeps Chrome integration eligible -
`claude setup-token`, `ANTHROPIC_API_KEY`, and `apiKeyHelper` all disable it - but that
`/login` is a **one-time-per-host** cost (see "First run only" below), not a per-session
or even per-container one.

## What the browser is allowed to do

Chrome runs under two managed-policy files in `/etc/opt/chrome/policies/managed/`. Keys are
split strictly between them: Chrome merges the directory, and a key set in both has no
defined winner.

- `claude-kit.json`, baked into the image from `chrome-policy.json`: force-installs the
  Claude in Chrome extension and blocks every other one, no metrics or crash reports, no
  incognito, no browser sign-in, no password-save bubble, no autofill, no notifications,
  downloads straight to `~/artifacts` with no prompt.
- `oe-lockdown.json`, written at boot by `writeLockdownPolicy` because the OE origin only
  exists in `$OE_URL` at runtime: `URLBlocklist: ["*"]` plus an allowlist of the OE host,
  `claude.ai`, `anthropic.com`, `accounts.google.com`, the extension's own origin and a few
  `chrome://` pages. Verified 2026-07-25: `example.com` and `google.com` return "This page is
  blocked", OE and claude.ai load normally, and the extension's options page still opens.

The point is not tidiness. This container holds a live OAuth token and hands a browser to a
model that reads whatever an OE page happens to contain, so confining that browser to the one
app it exists to drive is the real mitigation for a prompt injected into a page.

The image ships `oe-lockdown.json` as `{}` mode 0666, so a boot that cannot write it degrades
to an unrestricted browser rather than one that can reach nothing. To lift the restriction
temporarily: `docker exec claude-chrome sh -c 'echo {} > /etc/opt/chrome/policies/managed/oe-lockdown.json'`

## Setup (once per host)

```bash
cd ~/claude-kit/docker/oe-chrome-agent
mkdir -p artifacts
export UID GID OE_NETWORK=<the OE deployment's docker network>   # OE_URL defaults to http://web - only export it if this deployment's web service isn't reachable there
docker compose up -d --build
```

Nothing needs wiring on the host first - the profile is created inside the container and
`~/.claude/oe-chrome-agent/` is created on demand. **Chrome is never installed on this
host**; the only Chrome involved is the one inside the image.

`drive.sh` refuses to run when those two login files are absent and points at
`setup-walker.sh` to generate them, so a missing credential fails with an instruction
rather than a confusing agent error.

The container is always named `claude-chrome` (fixed in `docker-compose.yml`, not
project-prefixed) - `docker exec claude-chrome ...` / `docker compose exec oe-chrome-agent
...` both work, one by container name, one by compose service name.

Automated: `./install.sh -w` (docker build output silenced) or
`docker/oe-chrome-agent/setup-walker.sh` on its own (verbose build - if the silenced `-w`
path fails, re-run this directly to see why). It asks for `OE_NETWORK` (saved to
`generated/.oe-chrome-agent.env` and reused as the default next time; `-y` skips the prompt
and reads that file), runs the two commands above, waits for the container to boot, and
drops into the "First run only" pause below only when the two logins are not yet saved -
once they are, it skips straight through. `-n <network>` sets the network without
prompting; `-u <url>` overrides the `http://web` default.

Optional env (exported before either path, or left at their `docker-compose.yml`
defaults): `OE_USERNAME`/`OE_PASSWORD` (default `admin`/`admin`),
`OE_INSTITUTION_ID`/`OE_SITE_ID` (default `1`/`1`), `NOVNC_PORT` (default 6080),
`CHROME_KIOSK=1` for a chromeless recording window - keep it off otherwise, kiosk hides
the extension's permission prompts.

## First run only

Boot state is already: Chrome up on OE, logged into OE, extension installed, pairing
seeded, CLI tools pre-allowed, extension site permission for `OE_URL` seeded, and the
extension's own options tab already open in the noVNC session. Only **two logins** are
needed **once, ever** per host - not once per session, and not again after any
`reset-session.sh`, container restart or rebuild, because they are saved out of the
container and restored into every later one (see "What persists" above).
`setup-walker.sh` detects whether they're still saved and, if not, pauses on
`Press Enter once both are done`. **Do the three steps in that order** - it comes to one
credential entry and one click:

1. Forward port `6080` (VSCode: Ports panel -> Forward a Port -> `6080`) and open
   `http://localhost:6080`. It auto-connects and scales on its own, no query string or
   manual `ssh -L` tunnel needed.
2. In another terminal, `docker exec -it claude-chrome claude`, run `/login`, and choose
   the **browser** option (not paste-a-code) - the OAuth page opens in the Chrome you are
   watching. Sign in there, then leave the CLI with Ctrl-D or `/exit`; unlike `attach`,
   `exec` doesn't stop the container on exit, so there's no detach sequence to remember.
3. Back on the noVNC screen, switch to the extension's options tab (already open) and click
   **Log in**. Because step 2's browser flow left a claude.ai session in this same Chrome,
   this should reduce to a single **Authorize** click.

Doing 3 before 2 asks for the password twice, which is the only reason the order is
prescribed.

`setup-walker.sh` then runs `save-state.sh`, which copies both logins into
`~/.claude/oe-chrome-agent/`. If you signed in outside the walker, the harvest on the next
boot picks them up anyway - but run `docker/oe-chrome-agent/save-state.sh` by hand if you
are about to `down` rather than restart, since `down` destroys the writable layer before
any harvest can run.

Steady-state operation after that is **zero manual steps**: `docker compose up -d` then
`./drive.sh "<prompt>"` straight away. If the extension ever does show an approval prompt
anyway (the boot-time auto-seed failed, or an extension update changed its storage
schema), approve it once over noVNC the same way - the "always allow" style option - then
re-run `save-state.sh` so the refreshed grant persists.

## Driving unattended

`./drive.sh "<prompt>"` starts a fresh session in the container, pipes the prompt via
stdin, and prints result + token usage (also appended to `artifacts/drive.log`). No
session resolution needed - fresh sessions are no longer denied (see above). Multi-turn
continuity: `./drive.sh -s <session-id> "<prompt>"`; tag log lines with `-t <name>`;
prepend a walk map with `-f <map-file>` (see "Walk maps" below).

Each run brackets the prompt with two housekeeping steps, both non-fatal:

- **Before** - `oe-login.mjs` collapses the tabs to one and re-asserts the OE session, so a
  walk always starts from exactly one tab at `OE_URL` (2-4s). **Skipped on `-s`**, because
  it also navigates that tab and would throw away where the resumed session was.
- **After** - `sync-state.sh -s` writes the two logins back to the kit, since a prompt is
  the only thing that makes the CLI touch its rotating refresh token.

`-s <session-id>` is a **within-boot** facility: transcripts live in `~/.claude`, which the
next start wipes, so a session id does not survive `docker compose restart`.

Under the hood: `printf '%s' "<prompt>" | docker exec -i claude-chrome claude -p --chrome --allowedTools "mcp__claude-in-chrome" --output-format json` (`--resume <id>` added only with `-s`).
Gotcha baked into the script: `--allowedTools` is variadic and swallows a trailing
prompt argument, so the prompt MUST go via stdin.

**Repro brief template**:
> Reproduce this bug in the OpenEyes instance already open in Chrome (already logged in).
> Expected: `<expected>`. Actual (reported): `<actual>`. Narrate each UI action as a
> numbered step as you perform it. Record a GIF of the full sequence and a screenshot at
> the point of failure, both into `~/artifacts`. Finish with the full steps-to-reproduce
> list and whether the bug reproduced.

Prompt style that matters in print mode: sessions answer from conversation memory when
they can - add "Do this now with tool calls, do not answer from memory" to force a live
walk when freshness matters.

## Walk maps

For a UI journey that's been walked before (same click-path, a different bug), check
`ls ~/claude-kit/skills/c-oe-nav/subs/canned/` first - one file per journey, with a bug
ledger of every fault already found on it, so a repeat repro is a replay instead of a
rediscovery. Replay with `./drive.sh -f subs/canned/<journey>.md "<what to re-verify>"`
(the file's content is prepended to the prompt). After a genuinely novel walk, distill it
into a new `subs/canned/<journey>.md` file following the existing ones' format and add it
to the index paragraph in `c-oe-nav/SKILL.md` - a canned walk that isn't indexed there
won't get found next time.

## Codex verdict

Codex CLI has no browser-extension path at all (app-only, confirmed via an open upstream
GitHub issue) - there is no simpler Codex-based equivalent to this container. Codex stays
useful for non-browser work in this stack (see `docs/codex.md`), but UI-driven walks and
repro stay on Claude in Chrome.

## Recording

The extension records GIFs natively ("record a GIF" in the prompt). Point
screenshot/GIF tools at `~/artifacts` - bind-mounted to
`docker/oe-chrome-agent/artifacts/` (created by `mkdir -p artifacts` before first `up`,
else Docker creates it root-owned). For chromeless captures recreate with
`CHROME_KIOSK=1`; drop back to `0` before any pass that needs a permission prompt.

## Teardown

```bash
./reset-session.sh        # keep-logins default: asks for confirmation (y/N); -y skips
./reset-session.sh -f     # also drops the saved logins: asks for confirmation (type RESET); -y skips
```

**For a clean browser this script is optional** - `docker compose restart` already wipes the
profile, `~/.claude` and `/tmp` (see "What persists" above), so there is no cookie or history
surgery to do either way. Reach for `reset-session.sh` when you want the *container* gone: a
different OE deployment, a different network, a handover.

Default: sync the two logins out (`down` destroys the writable layer, and with it anything the
container refreshed since the last drive), then `docker compose down`. The saved logins in
`~/.claude/oe-chrome-agent/` survive, so the next boot needs no manual steps at all.
`-f | --full` skips that sync and deletes those two files, for a shared host or a handover -
next boot needs the "First run only" steps again.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Permission denied by user" on navigation in a `-p` run | The boot-time seed (`seed-extension-state.mjs`) hasn't run yet, failed, or `~/.claude/oe-chrome-agent/extension-state.json` is missing - check `docker logs claude-chrome` for its permission line; if it says "skipped", do the one-time manual "always allow" pass over noVNC (see "First run only"), then `./save-state.sh`. |
| "Claude in Chrome requires permission" in a `-p` run | CLI tool gate - the `~/.claude/settings.json` seed is missing (pre-dates this layout?); pass `--allowedTools "mcp__claude-in-chrome"` or recreate the container. |
| `claude -p ... "<prompt>"` says input must be provided via stdin | `--allowedTools` swallowed the trailing prompt argument - pipe the prompt via stdin. |
| Extension logged out / asks to sign in | `reset-session.sh -f \| --full` ran, the saved tokens in `extension-state.json` expired, or `save-state.sh` was never run after the first sign-in - independent of the CLI's `/login`. Open the pre-opened options tab over noVNC (or navigate to `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html`), click **Log in** again, then `./save-state.sh`. |
| CDP down, log says "DevTools remote debugging requires a non-default data directory" | Chrome was started against the default profile path - `--user-data-dir` must point at `/home/agent/chrome-profile` (this layout), not `~/.config/google-chrome`, which is only a symlink onto it. |
| Boot log says "no baked template in this image" | The image pre-dates the build-time Chrome pre-warm - rebuild (`docker compose up -d --build`). Harmless: Chrome just re-fetches the extension from the Web Store on that boot. |
| Any page returns "This page is blocked" / `ERR_BLOCKED_BY_ADMINISTRATOR` | The runtime lockdown policy allowlists `OE_URL`'s host and the sign-in origins, nothing else. If it's the OE host itself, `OE_URL` is wrong - fix it and recreate. To lift the restriction for one debugging session: `docker exec claude-chrome sh -c 'echo {} > /etc/opt/chrome/policies/managed/oe-lockdown.json'` then reload the tab (Chrome re-reads the dir); the next boot re-applies it. |
| Extension missing after a rebuild | `ExtensionInstallBlocklist: ["*"]` allows only the forcelisted id, and the CRX fetch needs egress to `clients2.google.com` on a cold build - check `chrome://policy` over noVNC for both keys applied with no conflict warning. |
| noVNC black screen, or Chrome "profile in use" | Stale `/tmp/.X99-lock` or a `SingletonLock` in the profile. Neither can survive any more: every start wipes `/tmp` and lays a fresh profile down. Rebuild if the image pre-dates `wipeContainerState`. |
| A saved login stopped working after weeks idle | The CLI's refresh token has a 28-day fuse and rotates on use. It is re-saved on every boot, drive and `reset-session.sh`, so this means the container hasn't been booted or driven inside that window - re-run the "First run only" `/login`. |
| OE not logged in on boot | Check `~/oe-login.log` in the container - wrong `OE_USERNAME`/`OE_PASSWORD`/`OE_INSTITUTION_ID`/`OE_SITE_ID`, `OE_URL` not reachable (default `http://web` assumes the OE deploy template's service name - override with `-u` if this deployment differs), or OE was still booting; rerun with `docker exec claude-chrome node /usr/local/bin/oe-login.mjs`. |
| `install.sh -w`/`setup-walker.sh` build fails | Silenced by default when run via `install.sh -w`; re-run `docker/oe-chrome-agent/setup-walker.sh` directly (no `-q`) to see the full docker build error. |
| A permission prompt never appears | Kiosk mode hides all browser chrome - make sure `CHROME_KIOSK=0` (the default) for any pass needing prompts. |
| "Browser extension is not connected" in a `-p --chrome` run shortly after boot | Transient - the extension's native-messaging pairing/service-worker isn't ready yet if a driven prompt runs within seconds of `docker compose up`; wait ~20-30s after boot before the first `drive.sh` call. Mid-session (not right after boot) it means the service worker went idle instead - `/chrome` -> "Reconnect extension" (interactive). |
| `/chrome` shows "Extension: Not detected" on a brand-new host | Forcelist install needs egress to `clients2.google.com` on first boot - retry in ~60s. |
| Chrome integration off despite `/login` | An `ANTHROPIC_API_KEY` in the env overrides the subscription login and disables it. |
| An agent reports OE showing "For security reasons you have been logged out... Timed out" | **Not a real logout** (root-caused 2026-07-25). OE ships that login form hidden in the markup of every page, so it appears in the accessibility tree even while the session is live - an agent reading the tree rather than the rendered page will report it. Confirm before believing it: the rendered page shows the user and site in the header, and `docker exec claude-chrome node /usr/local/bin/oe-login.mjs` prints "no login form ... assuming already logged in" when the session is fine. |
