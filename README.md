# claude-kit

A container-first agent kit. The existing Claude Code installer remains unchanged,
and standalone Codex is the first independent consumer on the path toward a generic
multi-agent kit.

```bash
bash install.sh -q          # Claude Code setup
bash codex-install.sh -q    # standalone host Codex setup
bash codex.sh               # run sandboxed host Codex in the current directory
```
```
~/claude-kit/
├── install.sh              # Claude Code entry point
├── codex-install.sh        # standalone Codex entry point - same flags wherever the feature exists on both
├── codex.sh                # run host Codex with the kit profile
├── windows-install.ps1     # Windows/PowerShell installer - project-local .claude, copies instead of symlinks (section 21)
├── README.md               # this file
├── lib/
│   └── skills.sh           # skill plumbing shared by both installers (gate + snapshot, openai.yaml, symlink/prune)
├── radar/
│   └── release-radar.md    # dated upstream-release digests, written by the release-radar skill
├── todo/                   # queued tasks for Claude + the plans behind them (git-tracked, public)
│   ├── TODO.md             #   the queue - one task per line, removed when done
│   └── <slug>-plan.md      #   plans being developed / awaiting execution
├── knowledge/              # learnings from finished work; read on demand when a topic comes up
├── oe_bugs/                # OpenEyes bugs found off-ticket (doc campaigns, code sweeps), by version
│   ├── verified/           #   reproduced in a browser against a stated commit/tag
│   └── unverified/         #   code-level findings or reports not yet reproduced
├── handoff/                # handoff docs written by the c-handoff skill (contents gitignored; never read unless asked)
├── memory/
│   └── <project-slug>/     # adopted from ~/.claude/projects/<slug>/memory and symlinked back (versioned backup)
├── claude-md/
│   └── CLAUDE.md           # global instructions; symlinked into ~/.claude/CLAUDE.md (edits are live)
├── scripts/                # host helpers, run by hand
│   ├── screen5_install.sh  #   GNU screen 5 + managed Claude/Codex screen aliases
│   ├── codex_bwrap_install.sh # Ubuntu bubblewrap + restrictive AppArmor profile
│   ├── jira_filter_download.sh  # bulk ticket export straight over REST (no model tokens)
│   └── jira_dashboard_dump.sh   # dump a Jira dashboard's gadget config
├── docker/
│   ├── codex/              #   Dockerfile for the locally-built claude-kit-codex image
│   ├── codex-chrome-agent/ #   separate Chrome DevTools + Playwright sidecar for Codex
│   └── oe-chrome-agent/    #   the OE walker sidecar - Chrome + a paired Claude Code CLI under Xvfb
├── settings/
│   ├── permissions/
│   │   ├── ultra-safe.json # tier 1 - read-mostly
│   │   ├── standard.json   # tier 2 - day-to-day (default)
│   │   ├── trusted.json    # tier 3 - broad allow-list + wide `rm -rf` denies
│   │   └── yolo.json       # tier 4 - git mutations + `rm -rf` still denied, secrets reads go through (container/VM only)
│   ├── statusline.sh       # the status-line renderer; symlinked into ~/.claude/statusline.sh
│   ├── shift-enter.json    # newline-on-shift-enter fragment
│   ├── .atlassian.env.example # Jira/Confluence creds template -> copy to ~/.claude/mcp-env/.atlassian.env
│   ├── .github.env.example # GitHub read-only PAT template -> copy to ~/.claude/mcp-env/.github.env
│   ├── .aws.env.example    # AWS read-only IAM key template -> copy to ~/.claude/mcp-env/.aws.env
│   └── .codex.env.example  # Codex agent defaults template -> copy to generated/.codex.env (no secret)
├── generated/              # machine-local config, NO secrets (gitignored; back this up)
│   ├── .codex.env          #   Codex model/effort/sandbox/approval knobs (install.sh -x + codex-install.sh; no secret)
│   ├── .oe-chrome-agent.env #  walker network + OE URL     (created by install.sh -w; no secret)
│   ├── skills-auto.state   #   pre-flip snapshot written by -s on, consumed by -s off
│   └── mcp-on/             #   MCP startup-gate flags (+ .win grace markers)
│                           # SECRETS LIVE OUTSIDE THIS REPO - see below:
│                           #   ~/.claude/mcp-env/.atlassian.env   (install.sh -j/-c)
│                           #   ~/.claude/mcp-env/.github.env      (install.sh -g)
│                           #   ~/.claude/mcp-env/.aws.env         (install.sh -a)
│                           #   ~/.claude/oe-chrome-agent/         (install.sh -w, walker logins)
├── skills/                 # 50 dirs, linked by agent eligibility in deterministic name order
│   │                       #   user-authored actions use a-; user-authored context uses c-
│   │                       #   explicitly, and the kit currently ships all of them auto-invokable
│   ├── c-frontend-design/  #   auto-load ┐ no disable-model-invocation at all -
│   ├── c-oe-helm/          #   auto-load │ the model pulls these in itself when
│   ├── c-oe-ui/            #   auto-load │ the task matches, and install.sh -s
│   ├── a-oe-docs/          #   auto-load │ never touches them
│   ├── c-ascii/            #   auto-load ┘ (non-ASCII convert-or-keep pitfalls)
│   ├── c-oe-code/ c-oe-db-schema/ c-oe-coding-standards/ c-oe-components/           # OpenEyes
│   ├── c-oe-deploy/ c-oeimagebuilder/ c-pasapi/ c-mirth/ c-mcchannels/ c-oe-interop/  # OpenEyes
│   ├── c-mirth-estate/ c-oe-nav/ a-oe-repro/                    # OpenEyes estate + UI walking
│   ├── c-oe-iolmaster-import/ c-oe-payload-processor/           # OpenEyes file processors
│   ├── c-bash-style/ c-yiic-command-style/ c-note-style/        # house style
│   ├── c-claude-kit/ c-dblogin/ c-docbuilder-docset/ c-notes-app/   # kit/repo context
│   ├── a-clarify/ a-pr-explainer/                               # user-authored actions
│   ├── c-performance-indexes-rollup/ c-oe-unit-tests/            # context-only references
│   ├── create-pr/ create-oe-pr/ create-oe-module/ new-feature/   # imported or legacy workflows
│   ├── teach/ release-radar/ compact-memories/ c-grill-me/ c-handoff/  # imported or legacy names
│   ├── oe-probe-chrome/ oe-probe-playwright/                    # OE UI probes (walker / Playwright)
│   ├── jiramcp/ githubmcp/ awsmcp/ codexmcp/ devopstickets/     # MCP preflight - no "Context loaded" ack
│   └── codex-grill/ codex-swarm/                                # built on codexmcp; confirm cost before spawning
└── docs/
    ├── permissions.md      # how the 4 tiers work, deny -> ask -> allow
    ├── skills.md           # CLAUDE.md vs SKILL.md, sub-skills, naming
    ├── statusline.md       # how the status line script works
    ├── sandbox.md          # running without prompts in a container/VM
    ├── atlassian.md        # Jira + Confluence via the mcp-atlassian container - setup + teardown
    ├── github.md           # GitHub (read-only) via github-mcp-server - setup + teardown
    ├── codex.md            # Codex overview, standalone + MCP setup
    ├── codex-standalone.md # standalone Codex usage, flags and compatibility
    ├── chrome-agent.md     # the OE Chrome walker sidecar
    └── aws.md              # AWS (read-only) via aws-api-mcp-server - setup + limitations
```

The installer writes / merges:

- `~/.claude/settings.json` - status line, autocompact env vars, permissions block, shift-enter binding.
- `~/.claude/statusline.sh` - the status line renderer (**symlinked** to `settings/statusline.sh`).
- `~/.claude/CLAUDE.md` - **symlinked** to `claude-md/CLAUDE.md` in this kit (never-commit/push rules + condensed Karpathy guidelines); editing the kit file is live.
- `~/.claude/skills/<name>` - symlinked to each Claude-enabled skill in this kit.
- `~/.claude/.claude-kit-skills` - manifest of the skill links it created, used to prune the ones for skills since removed from the kit.
- With `-x`, also `~/.codex/AGENTS.md` and each Codex-enabled `~/.codex/skills/<name>` compat link. An existing `skills/<name>/agents/openai.yaml` opts a skill into Codex and has its generated fields refreshed from `SKILL.md`; the installer never creates a missing one.

**No secret ever lives inside this repo.** Tokens, cookies, keys and saved sessions go under `~/.claude/` - `~/.claude/mcp-env/` for the Atlassian, GitHub and AWS credentials, `~/.claude/oe-chrome-agent/` for the Chrome walker's two saved logins. This kit is a git repo with a remote, so anything in its working tree is one `git add -f`, one `.gitignore` edit or one archive away from being published; `.gitignore` is a convenience, not a security control. What the installer *does* keep in the gitignored `generated/` folder is machine-local **non-secret** config (Codex model knobs, the walker's network/URL, the MCP startup-gate flags) - see [Backing up generated config](#backing-up-generated-config). MCP server registrations themselves are written by the `claude` CLI to `~/.claude.json` (not `settings.json`), and those *do* embed the token, which is why `~/.claude.json` is also outside the kit.

It backs up the pre-existing `settings.json` to `settings.json.bak` only when the merged content actually differs, so a no-op re-run preserves your existing backup. The first time it converts a real `~/.claude/CLAUDE.md` (or `statusline.sh`) into the kit symlink it backs that file up to `*.bak`; once it's a symlink there's nothing left to back up. `settings.json` is edited as JSON via `jq` (never blind text-append).

---

## Quick start

```bash
cd ~/claude-kit
bash install.sh -q                             # quick: no prompts, yolo tier, all defaults
bash install.sh --permissions ultra-safe       # explicit tier (interactive prompt if -p omitted)
bash install.sh -p trusted -y                  # non-interactive
bash install.sh --reset -p standard -y         # archive bloat -> reinstall
bash install.sh --fresh -p standard            # back up data -> wipe ~/.claude -> fresh install
bash install.sh --no-update -p standard -y     # skip the `claude update` step
AUTOCOMPACT_PCT=50 bash install.sh -p standard -y
bash install.sh --help
```

Re-running is safe - Claude Code itself is installed if it's missing and otherwise updated (`claude update`), `settings.json` is re-merged, and the `CLAUDE.md`, status-line, and skill symlinks are refreshed to point back into the kit (so editing any kit file is live; a pre-existing *real* `CLAUDE.md`/`statusline.sh` is backed up to `.bak` the first time it's replaced by a link). Skill links are pruned too: real directories under `~/.claude/skills/` are left alone, and symlinks this kit created for skills since removed from the kit are removed (see [section 7](#7-skills)).

---

## The features

### 1. Permission rule-set + start mode (`--permissions ultra-safe|standard|trusted|yolo`, `--mode ...`)

Each tier lives as a standalone JSON file at `settings/permissions/<tier>.json`. The installer reads the file and copies it whole into `permissions:` - no inline construction.

| Tier         | Rule-set (allow/ask/deny)                                                                  |
| ---          | ---                                                                                        |
| `ultra-safe` | Tightest allow-list - reads + inspection only; edits/writes/shell aren't pre-approved; denies git mutations and secrets. |
| `standard`   | Curated allow-list for common edits and dev/test commands; arbitrary shell falls to your mode. |
| `trusted`    | Same broad allow-list as `standard` + extra `rm -rf` denies; still denies git mutations + secrets. |
| `yolo`       | Like `trusted`, but `.env`/`.ssh` reads go through; `git push` / `git commit` and `rm -rf /*` / `rm -rf ~*` still denied (those denies are a hard floor across every tier). **Container/VM only.** |

The tier (`-p`) is just the **rule-set**. The **session start mode** (`permissions.defaultMode`) is separate and defaults to `auto` for every tier: `-m default|plan|acceptEdits|auto|dontAsk|bypassPermissions` picks it explicitly - e.g. `-p standard -m plan`. (`auto` is the classifier-judged mode - auto-approves calls it deems safe, asks on the rest.) Omit `-m` and the session boots in `auto` - the mode is never prompted for; interactive runs only ask for the tier.

Full explanation including evaluation order (`deny -> ask -> allow`) and what each tier denies: **[docs/permissions.md](docs/permissions.md)**. No *tier* enables `bypassPermissions` - `yolo` is the widest rule-set - but `-m bypassPermissions` is now selectable behind a warning; it skips even the deny floor, so it's VM-only. See [docs/sandbox.md](docs/sandbox.md) for the safe envelope.

### 2. Status line

A `statusLine.command` pointing at `~/.claude/statusline.sh`. The script reads the session-context JSON from stdin, sums token usage from `~/.claude/projects/*.jsonl` over a 5-hour and 7-day rolling window, and renders:

```
⛭ <model> · <dir> · [<effort> · ]5h <pct|count> · wk <pct|count>
```

Each window segment shows a **percentage** if you set a budget (`FIVE_HOUR_BUDGET`, `WEEKLY_BUDGET` - see env-overrides table below) and a humanised **raw count** otherwise. The optional `<effort>` segment (e.g. `xhigh`) reflects the reasoning-effort level - `$CLAUDE_EFFORT` from the live session, falling back to `.effortLevel` in `~/.claude/settings.json`; omitted if neither is set. Results are cached to `/tmp/claude-statusline-{5h,wk}-<uid>.cache` (30s / 5min TTL) so the bar renders in ~40ms after the first cold walk.

The figures are a **local proxy**: Claude Code's GUI `/usage` % comes from Anthropic's server-side rate-limit accounting (held in-memory, not persisted), so the bar will diverge - calibrate budgets against the GUI if you want them to roughly agree. See **[docs/statusline.md](docs/statusline.md)**.

The kit also writes `statusLine.refreshInterval` (default **5** seconds; needs Claude Code >= 2.1.97) so the bar re-runs on a timer in addition to conversation events - without it, the token windows go stale during long unattended turns (hours of tool calls in auto mode). Tune with `STATUSLINE_REFRESH=<seconds>`; `0` removes the key (event-driven only).

### 3. Shift+Enter newline

`settings/shift-enter.json` is merged into `settings.json` to bind Shift+Enter for newline. If your terminal still won't honour it, run `/terminal-setup` once interactively or bind the key sequence in your terminal app.

### 4. Auto-compact env vars

```
AUTOCOMPACT_PCT      -> env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE   (default 100 - no reduction; only lowers, clamped to ~83)
AUTOCOMPACT_WINDOW   -> env.CLAUDE_CODE_AUTO_COMPACT_WINDOW   (default 200000)
FIVE_HOUR_BUDGET     -> env.CLAUDE_5H_TOKEN_BUDGET            (unset - status line shows raw count; set to flip to a 5h %)
WEEKLY_BUDGET        -> env.CLAUDE_WEEKLY_TOKEN_BUDGET        (unset - status line shows raw count; set to flip to a wk %)
STATUSLINE_REFRESH   -> statusLine.refreshInterval            (default 5 - re-run the bar every N seconds on top of event-driven updates; 0 = events only)
```

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` only **lowers** the trigger; values above the internal cap (~83%) are clamped.
- The percentage applies to the original window, not the reduced one - `CLAUDE_CODE_AUTO_COMPACT_WINDOW` is the lever for the absolute token budget.
- Don't use `"autoCompactEnabled": false` - that key is silently ignored.
- Token budgets aren't published by Anthropic per-plan; pick numbers from observed usage or calibrate against the Claude Code GUI's `/usage`. Example: `FIVE_HOUR_BUDGET=2000000 WEEKLY_BUDGET=20000000`.

### 5. Git + secret deny rules

`Bash(git push *)` and `Bash(git commit *)` are denied on **every tier including `yolo`** - that's a hard floor. The human raises commits and pushes; Claude doesn't. The two `rm -rf /*` / `rm -rf ~*` denies are also universal.

Reads of `.env*` and `~/.ssh/**` are denied on `ultra-safe` / `standard` / `trusted`. `yolo` drops only the secrets reads - use it only in a throwaway container/VM. Deny rules live inside each tier JSON file - to change them, edit the relevant `settings/permissions/<tier>.json` and re-run.

### 6. Global CLAUDE.md

`~/.claude/CLAUDE.md` is a **symlink** to `claude-md/CLAUDE.md` in this kit. The shipped file is short and opinionated:

- Hard rules at the top: never `git commit`, never `git push`, never `--no-verify` / `--amend` / `git reset --hard` without explicit instruction.
- Condensed Karpathy-style coding guidelines (think first, simplicity, surgical changes, goal-driven execution with plan-mode-then-verify for complex tasks, and a preference for FOSS/dockerised tooling over host installs).
- Output discipline (no emojis, no trailing summaries; planning docs only when asked, and complex writeups land under `/home/toukan/`).

Because it's a symlink, editing `claude-md/CLAUDE.md` rolls out immediately - no re-install needed. The first time `install.sh` replaces a pre-existing *real* `~/.claude/CLAUDE.md` with the link it preserves the old file at `~/.claude/CLAUDE.md.bak`.

### 7. Skills

`install.sh` symlinks each Claude-enabled directory under `skills/` into `~/.claude/skills/<name>`. Edit a linked skill in this kit and the change is live without re-installing.

**Naming and agent availability.** A user-authored action or workflow is named `a-<topic>`; a user-authored context-only skill is named `c-<topic>`. Imported and built-in skills keep their upstream names. `agents/openai.yaml` opts a skill into Codex. Claude is enabled by default; `agents/claude.yaml` with `enabled: false` makes a skill Codex-only. A Claude-only skill therefore omits `agents/openai.yaml`. Installers recreate links and manifests in C-locale name order, which gives both agents the same deterministic alphabetical source order; an agent UI can still apply its own sorting.

**How a skill gets its context in front of Claude - two modes:**

- **Auto-load (no `disable-model-invocation`).** Claude reads every skill's `name` + `description` at startup and decides *on its own* to pull the whole `SKILL.md` into context the moment a task matches the description. You don't name these - they load when relevant. Today: **`c-ascii`, `c-frontend-design`, `a-oe-docs`, `c-oe-helm`, `c-oe-ui`**. For these the **`description:` is the trigger**, so it's written to fire on the right task.
- **Auto-invokable (`disable-model-invocation: false`).** Same behaviour, but flipped by `install.sh -s`. **This is the kit's current committed state for every other skill.**
- **Manual (`disable-model-invocation: true`).** Claude will *never* auto-load these; the body only enters context when you (or a plan) invoke the skill **by name** (`/c-oe-code`, `/jiramcp`, ...). Nothing in the kit sits here today, but it's one `-s off` away.

**A new skill must state the flag explicitly** - `false` to match the kit's current all-auto state, or `true` to keep it name-only. Omitting it is not a shortcut for either: it opts the skill out of `-s` entirely, and that is reserved for the five deliberate auto-load exceptions above.

Either way the **`description:` is a single terminal line** (<= ~78 chars) so the whole thing is readable when you search skills inside Claude - keep it one line when editing.

**Loading convention - "Context loaded".** Every skill except six (`awsmcp`, `codexmcp`, `devopstickets`, `githubmcp`, `jiramcp` and `c-ascii`) starts its body with:

> When loaded as context with no task, reply only `Context loaded.`

So invoking a skill just to prime context returns a one-word ack instead of a 2,000-token summary you didn't ask for. The five preflight skills are the deliberate exception - they *do* run a check and report - and `c-ascii` is always-auto, so it is never invoked bare in the first place. Aim to keep each `SKILL.md` **under ~2,000 tokens** (~ 8 KB) so loading is cheap; push volatile detail into `subs/*.md` and let Claude open those on demand. Two skills intentionally exceed this - `create-oe-module` (~4.2k) and `c-oe-coding-standards` (~3.2k) - because they're reference-dense scaffolding/standards docs.

Each repo-specific skill follows the **stable mental model in `SKILL.md`, volatile detail in `subs/*.md`** convention. See **[docs/skills.md](docs/skills.md)**.

**Symlink lifecycle.** `install.sh` records exactly which skills it symlinked in `~/.claude/.claude-kit-skills`. On every run it (1) re-links current eligible kit skills in name order, and (2) **prunes** any managed `~/.claude/skills/<name>` symlink for a removed or Claude-disabled skill. Codex uses the same process for skills without `agents/openai.yaml`. Two safety floors: a destination that is a **real directory** (your hand-added skill) is skipped with a warning and never touched, and a **symlink pointing somewhere other than this kit** (added by hand or another tool) is left alone. Only kit-created symlinks are ever removed.

### 8. Reset to first-install state (`--reset`)

`bash install.sh --reset` archives Claude Code's auto-generated state - `file-history`, `paste-cache`, `backups`, `shell-snapshots`, `stats-cache`, `session-env`, `plugins`, `tasks` - into `~/.claude-backups/<timestamp>/`, then proceeds with the normal install. Preserved in place: `.credentials.json` (don't lose your auth), `history.jsonl`, and `projects/`. The reset runs **before** `settings.json` is backed up to `.bak`, so a single `--reset` run leaves you with a clean state plus one snapshot archive you can rummage through later. Combine with `-p <tier>` and `-y` to do it non-interactively.

### 9. Nuke and pave (`--fresh`)

`bash install.sh --fresh` rebuilds `~/.claude` from scratch while **keeping your conversations and staying logged in**. It:

1. Backs up `projects/` (your conversations), `history.jsonl`, and `.credentials.json` (auth) to `~/.claude-backups/<timestamp>-fresh/`.
2. **Deletes the entire `~/.claude`.**
3. Reinstalls Claude Code fresh (the from-scratch `curl ... | bash`).
4. Restores those three items, then re-applies the kit (settings, CLAUDE.md, skills) on top.

Everything else - settings, caches, plugins, `shell-snapshots`, MCP registration state - is regenerated clean rather than carried over. Use it when `~/.claude` has accumulated cruft a `--reset` won't shake, or after an upgrade leaves it inconsistent. **`--fresh` supersedes `--reset`** (no point archiving bloat you're about to delete). Because it runs `rm -rf ~/.claude`, an interactive run makes you **type `fresh` to confirm**; `-y` skips that prompt for automation. The full pre-wipe snapshot is kept at `~/.claude-backups/<timestamp>-fresh/` - nothing is deleted that isn't archived first. On a machine with no `~/.claude` yet, `--fresh` simply does a clean install. Restore anything else you want with `cp -a ~/.claude-backups/<timestamp>-fresh/<item> ~/.claude/`.

### 10. Fresh-machine bootstrap + `claude update`

The installer manages the Claude Code CLI itself, so a brand-new machine needs nothing pre-installed beyond `jq`/`curl`:

- **Install if absent.** If `~/.claude` doesn't exist, install.sh runs `curl -fsSL https://claude.ai/install.sh | bash` to install Claude Code before configuring it.
- **Update if present.** Otherwise it runs **`claude update`** to pull the latest CLI before applying config. Skip with `--no-update` (`-U`) when offline or when the CLI is managed by a package manager; it's auto-skipped right after a from-scratch install (already current) and if `claude` isn't on `PATH`. A failed update warns and continues rather than aborting.

### 11. Jira + Confluence (`-j` + `-c` / `--without-atlassian`)

**All four MCP servers (sections 11-14) register behind a startup gate.** A new
session starts **no** MCP containers - each server shows `failed` in `/mcp` until you
request it: `touch ~/claude-kit/generated/mcp-on/<atlassian|github|aws|codex>` then
reconnect the server in `/mcp` (its tools bind on the late connect - verified). The
flag is consumed by the first spawn, so the next session begins gated again - touch it
just before launching Claude Code to have a server up from the start.

Consuming the flag leaves a `<server>.win` marker that holds the gate open for a
further **60 seconds**, because one `/mcp` reconnect spawns the wrapper more than once:
the first spawn ate the flag and a later spawn in the same reconnect hit a shut gate,
so the reconnect always failed with `CONNECTION_CLOSED`. The window ages out on its own
whether or not anything connected, so the gate never fails open.

Register or remove the community **`mcp-atlassian`** server, run as a Docker stdio
server (`ghcr.io/sooperset/mcp-atlassian`) at user scope - the same shape as GitHub
and AWS. Jira and Confluence are configured independently and bundle as `-jc`:

```bash
bash install.sh -jc               -p standard -y    # opt in  (--with-jira + --with-confluence)
bash install.sh --without-atlassian -p standard -y  # tear down (-J)
```

Authentication is an **Atlassian API token** per product, stored in
`~/.claude/mcp-env/.atlassian.env` (mode 600, outside the kit) - never on the `docker`
command line. Scope is narrowed at registration with `JIRA_PROJECTS_FILTER` and
`CONFLUENCE_SPACES_FILTER`. Unlike GitHub and AWS this server has **no read-only
switch** - it exposes `createJiraIssue` / `transitionJiraIssue` and friends - so
read-only is a hard rule in `CLAUDE.md` instead: Claude reports the exact change it
would make and the human makes it. Full setup + teardown lives in
**[docs/atlassian.md](docs/atlassian.md)**.

Neither flag = `mcpServers.atlassian` is left exactly as-is on re-runs (the installer never silently flips it on or off).

### 12. GitHub - read-only (`--with-github` / `--without-github`)

Register or remove GitHub's official `github-mcp-server`, run as a Docker stdio server
(`ghcr.io/github/github-mcp-server`) at user scope - the same shape as Atlassian:

```bash
bash install.sh --with-github    -p standard -y    # opt in  (-g)
bash install.sh --without-github -p standard -y    # tear down (-G)
```

**Read-only is enforced and not configurable.** install.sh bakes `GITHUB_READ_ONLY=1`
into the registration, so the server exposes only read tools - creating PRs/branches,
pushing, commenting, and merging are impossible by construction. This is the GitHub-API
analogue of the never-`git push`/never-`git commit` hard floor. The human raises PRs
(see the `create-oe-pr` skill).

Authentication is a **fine-grained, read-only** personal access token (with `openeyes`
org access), stored in `~/.claude/mcp-env/.github.env` (mode 600, gitignored) - never on the
`docker` command line. After opting in, restart Claude Code and run `/githubmcp` to
verify. Full setup, token minting, rotation, and teardown live in
**[docs/github.md](docs/github.md)**.

Neither flag = `mcpServers.github` is left exactly as-is on re-runs.

### 13. AWS - read-only (`--with-aws` / `--without-aws`)

Register or remove the **awslabs `aws-api-mcp-server`** container so Claude can read
AWS state (`call_aws`, `suggest_aws_commands`) instead of clicking through the console:

```bash
bash install.sh --with-aws    -p standard -y    # opt in  (-a)
bash install.sh --without-aws -p standard -y    # tear down (-A)
```

**Claude never changes anything in AWS.** No create, modify, delete, tag, start or
stop - a hard rule in `CLAUDE.md`, backed by `READ_OPERATIONS_ONLY=true` baked into
the registration (the server refuses any command off its read-only list) and by a
`Bash(aws *)` deny on every tier so there is no route around the MCP. Telemetry is
off and the server gets no local filesystem access.

Authentication is a **dedicated read-only IAM user's** access key, stored in
`~/.claude/mcp-env/.aws.env` (mode 600, outside the kit) - never on the `docker`
command line. Note that the managed `ReadOnlyAccess` policy still permits
`secretsmanager:GetSecretValue`, `ssm:GetParameter`, `s3:GetObject` and
`kms:Decrypt`; deny those explicitly. Full setup and the limitations that matter
live in **[docs/aws.md](docs/aws.md)**; the environment it reads is described in
`knowledge/aws-production-deployments.md`.

Neither flag = `mcpServers.aws` is left exactly as-is on re-runs.

### 14. OpenAI Codex agents (`--with-codex` / `--without-codex`)

Register or remove **OpenAI Codex** as an MCP server so Claude can spawn one or
many autonomous Codex coding agents. Like Atlassian/GitHub it runs **in Docker**:
OpenAI ships no official CLI image, so `-x` builds one locally (`claude-kit-codex`,
from `docker/codex/Dockerfile`) and runs `codex mcp-server` inside it - **nothing is
installed on the host** (a host `codex` binary is only the fallback when Docker is
absent):

```bash
bash install.sh --with-codex    -p standard    # opt in  (-x); builds the image on first run
bash install.sh --without-codex -p standard -y  # tear down (-X)
```

Needs **Docker** and a one-time **ChatGPT sign-in through the container** (when not
signed in, install.sh prints the exact `... claude-kit-codex login` command and waits
for you to run it in another terminal, continuing once the credentials land - so **no
token is stored in this kit**; auth lives in `~/.codex`, which every agent container
mounts). The server
exposes `mcp__codex__codex` / `mcp__codex__codex-reply`; Claude fans agents out by
calling them in one message. Run `/codexmcp` to preflight and for the fan-out + safety
rules.

install.sh pins the agent defaults as `-c` launch overrides - **flagship model
(`gpt-5.6-sol`) at `xhigh` reasoning effort**, `approval_policy=never` (there is no
human at the other end of a spawned agent to answer a prompt) - recorded
(non-secretly) in `generated/.codex.env`, the same file the standalone runner uses. **The container is the safety floor:** an
agent runs its own shell *outside* Claude's `deny` rules, but only the project dir and
`~/.codex` are mounted and the container carries **no git credentials**, so a
`git push` fails auth (in the no-Docker host fallback the floor is codex's own
`workspace-write`, network-off sandbox instead); the `codexmcp` skill additionally
tells agents never to commit (the human commits). `mcp__codex` is allowed on
`standard`/`trusted`/`yolo` but **prompts on `ultra-safe`** - spawning a writer is a
write action. Full setup, model/sandbox tuning, and teardown:
**[docs/codex.md](docs/codex.md)**.

`-x` also wires **Codex compat** so the same instructions and Codex-enabled skills reach Codex:
`~/.codex/AGENTS.md` and eligible `~/.codex/skills/<name>` entries are symlinked back into this kit
(manifest `~/.codex/.claude-kit-skills`; `-X` unwires them). An existing
`agents/openai.yaml` is the Codex opt-in and its generated fields are refreshed from
frontmatter, including `allow_implicit_invocation: false` mirroring `disable-model-invocation: true`.
See also [section 19](#19-standalone-codex---codex-installsh--codexsh).

Neither flag = `mcpServers.codex` is left exactly as-is on re-runs.

### 15. Skills auto-invoke toggle (`--skills-auto on|off`)

A kit skill carrying `disable-model-invocation: true` is loaded only when you invoke it
by name; `false` lets Claude auto-pull it when its description matches the task. `-s on`
rewrites `true` to `false` across every kit `SKILL.md` (the files are live symlink
targets - no re-link needed, but skills bind at session start, so restart Claude Code):

```bash
bash install.sh -s on  -p standard -yU    # everything auto-invokable
bash install.sh -s off -p standard -yU    # back to how it was
```

Before flipping, `-s on` snapshots each flagged skill's current value to
`generated/skills-auto.state`, and `-s off` puts those exact values back and clears the
snapshot. That matters because the flip is not symmetric: a skill authored `false` must
stay `false` through an `on`/`off` round trip, and a blind `false` -> `true` inversion
would quietly demote it. Run `-s off` with no snapshot and it sets every flagged skill
to manual and says so, rather than guessing.

The snapshot is **append-only**, so `-s on` twice is safe: the second run reads
already-flipped values, and overwriting the file with them would strand every manual
skill on auto and turn `-s off` into a permanent no-op. A skill added to the kit after
the first `-s on` is appended at its own current value.

Only an *existing* flag line inside the frontmatter is touched - the deliberate
always-auto skills (`c-ascii`, `c-frontend-design`, `a-oe-docs`, `c-oe-helm`, `c-oe-ui`) carry no
flag and are ignored in both directions. The change is a plain git diff in `skills/` -
revert with git if ever needed.

**Omitting `-s` changes nothing.** The committed per-skill values are the authored
intent, so a plain run only reports the current tally (`N auto-invokable, M manual,
K always-auto`) instead of rewriting 40-odd tracked files as an install side effect.

### 16. Conversation pruning + retention (`--prune-sessions`, `CLEANUP_PERIOD_DAYS`)

Two controls over conversation history:

- **Retention** - `install.sh` now always writes `cleanupPeriodDays` into
  `settings.json` (default **365**; Claude Code's built-in default is only **30 days**,
  after which it deletes old transcripts itself). Override per run:
  `CLEANUP_PERIOD_DAYS=90 bash install.sh -p standard -y`.
- **Pruning** - `-d <days|date>` archive-then-deletes every conversation whose last
  activity predates the cutoff (a bare number = that many days ago; anything else is
  parsed by `date -d`, e.g. `2025-01-31`):

```bash
bash install.sh -d 180        -p standard -yU   # drop sessions idle > 180 days
bash install.sh -d 2025-01-31 -p standard -yU   # drop sessions untouched since Feb
```

For each stale session the transcript (`projects/<proj>/<id>.jsonl` - what
`claude --resume` lists), its sidecar dir (`subagents/`, `tool-results/`), and the
matching `session-env/`, `file-history/` and `tasks/` entries are **moved** to
`~/.claude-backups/<timestamp>-pruned/`, mirroring the live layout. Nothing is
destroyed - restore by moving files back, or `rm -rf` the archive to actually free the
disk. Interactive runs print a summary (count, projects, size) and ask `y/N`; `-y`
skips the prompt. `memory/` dirs and `history.jsonl` (up-arrow prompt history) are
never touched.

### 17. Memory backup (`memory/`)

Claude Code saves cross-conversation memories under `~/.claude/projects/<slug>/memory/`
- plain markdown, but outside git and gone if `~/.claude` is lost. On every run
`install.sh` (`syncMemory`) **adopts** each real memory dir into the kit at
`memory/<slug>/` and symlinks it back, the same link-don't-copy idiom as skills: edits
stay live, and **every kit commit is a versioned backup of your memories**. Safety
floors match `syncSkills` - correct links untouched, foreign symlinks skipped with a
warning, and if both a real dir and a kit dir exist nothing is merged silently. After
`--fresh` (or on a new machine) the link pass recreates the symlinks from the kit copy.

### 18. MCP logout (`--logout codex|github|atlassian|aws|all`)

`bash install.sh -l <mcp>` logs out of an MCP and **exits** - a standalone action that
runs nothing else, which is why every permission tier always-allows
`install.sh -l *` (and the standalone `codex-install.sh -l`): Claude can log you out on
request, and an allowed `-l` can never be leveraged into a full install, `--fresh`, or
anything beyond the logout. What it removes:

- **codex** - `~/.codex/auth.json` (the ChatGPT session). The registration stays in
  place; a fresh container `login` brings the tools straight back.
- **github / atlassian / aws** - the `~/.claude/mcp-env/` env file **and** the
  `~/.claude.json` registration, because that registration embeds the credentials.

Everything is local-only: each block prints where to revoke the token server-side
(GitHub token settings, Atlassian API-tokens page, IAM access keys, ChatGPT
authorized apps).

### 19. Standalone Codex (`codex-install.sh` + `codex.sh`)

Section 14 puts Codex under the primary CLI as an MCP server. This is the other direction:
Codex driving the kit on its own. It uses an existing host Codex under bubblewrap;
Docker is used only for MCP services and the browser walker.

```bash
bash scripts/codex_bwrap_install.sh      # once per blank Ubuntu host
bash codex-install.sh -q                 # write profile, links and rules, then verify
bash codex-install.sh -t 50 -U -y        # set native subagent concurrency for new sessions
bash codex.sh                            # interactive session in the current directory
bash codex.sh exec "review the changes"  # normal Codex arguments pass straight through
```

It accepts the full installer flag set and implements each capability through Codex's
own profile, permission, rule, MCP, memory, archive, skill, and TUI mechanisms. It links
`~/.codex/AGENTS.md` to the kit instructions and each skill carrying
`agents/openai.yaml` into `~/.agents/skills`.
The launcher also applies the VS Code keyboard workaround without changing any other
CLI environment. Usage, the feature table, permission translation, memory preservation,
Docker limits, browser walker, and verification are in
**[docs/codex-standalone.md](docs/codex-standalone.md)**.

### 20. OpenEyes Chrome walker (`--setup-walker`)

`bash install.sh -w` runs `docker/oe-chrome-agent/setup-walker.sh`: it asks for the OE
deployment's Docker network, boots the `claude-chrome` sidecar (Chrome plus a paired
Claude Code CLI under Xvfb), and pauses once for the `/login` and extension sign-in.

Both saved logins land in **`~/.claude/oe-chrome-agent/`, outside the kit**, so no
later container needs them again and no credential is ever in the repo; only the
non-secret network/URL answer is kept, in `generated/.oe-chrome-agent.env`. `OE_URL`
defaults to `http://web` (override with `setup-walker.sh -u`). With `-y` the network is
read from the saved env file instead of prompting. See
**[docs/chrome-agent.md](docs/chrome-agent.md)**, and the `oe-probe-chrome` skill for
driving it.

---

### 21. Windows (`windows-install.ps1`)

The PowerShell twin of `install.sh`, for a machine with no WSL. It installs into a
**project-local** `.claude` (default: the folder one level above the kit) and
**copies** `CLAUDE.md`, `statusline.sh` and `skills/` rather than symlinking them -
Windows has no symlinks without Developer Mode - so a kit edit only reaches the
target on a re-run.

With no parameters it is fully interactive (target, tier, mode, skill gate). Any of
those can be a parameter instead, and `-Yes` takes the default for whatever is left:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-install.ps1
powershell -ExecutionPolicy Bypass -File .\windows-install.ps1 -Quick
powershell -ExecutionPolicy Bypass -File .\windows-install.ps1 -Yes -Permissions standard -Mode plan
powershell -ExecutionPolicy Bypass -File .\windows-install.ps1 -Target C:\repo\.claude -SkillsAuto on -NoUpdate
```

| Parameter | Effect |
| --- | --- |
| `-Target <path>` | install target (default `..\.claude`, next to the kit) |
| `-Permissions <tier>` | `ultra-safe` / `standard` / `trusted` / `yolo` |
| `-Mode <mode>` | session start mode, same set as `install.sh -m` |
| `-SkillsAuto on\|off` | the skill gate of section 15, sharing `generated\skills-auto.state` with `install.sh -s` so a flip made under WSL reverts from Windows and back |
| `-Yes` | no prompts; the default for anything not given |
| `-Quick` | `-Yes` plus the yolo tier unless `-Permissions` names one (mirrors `install.sh -q`) |
| `-NoUpdate` | skip the CLI install/update step |

Like `install.sh` it manages the CLI itself: `claude` missing means it is installed
with npm, otherwise `claude update` runs. The status line still shells out to `bash`
and `jq`, so both have to be on PATH (Git for Windows ships bash; `winget install
jqlang.jq` for jq).

Skills are copied with `robocopy /MIR`, which deletes anything in the destination
that is not in the kit. Files you added by hand inside a kit-managed skill folder are
listed and the folder is skipped instead of wiped - `-Yes` always skips, an
interactive run offers to delete them.

Not covered, because they lean on Unix-only tooling: MCP server registration,
session pruning, MCP logout, `--reset` and `--fresh`. Run `install.sh` under WSL for
any of those.

## Verification

After applying, `install.sh` runs the checks and prints `[PASS]` / `[FAIL]` / `[INFO]` per feature. Re-run them by hand at any time:

```bash
jq '.statusLine'                                       ~/.claude/settings.json   # status line
jq '.permissions.defaultMode'                          ~/.claude/settings.json   # session start mode
jq '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE,
    .env.CLAUDE_CODE_AUTO_COMPACT_WINDOW'              ~/.claude/settings.json   # autocompact
jq '.permissions.deny'                                 ~/.claude/settings.json   # deny rules
jq '.shiftEnterKeyBindingInstalled'                    ~/.claude/settings.json   # shift-enter
jq '.cleanupPeriodDays'                                ~/.claude/settings.json   # retention (365)
cmp -s ~/claude-kit/claude-md/CLAUDE.md ~/.claude/CLAUDE.md && echo match        # CLAUDE.md
ls -l ~/.claude/skills/                                                          # symlinks
readlink ~/.claude/projects/*/memory                                             # memory links
jq -r '.mcpServers | keys[]'                           ~/.claude.json            # registered MCP servers
readlink ~/.codex/AGENTS.md                                                      # codex compat (if -x)
```

Read `~/.claude.json` rather than running `claude mcp get <server>` - that command
*launches* the server, which consumes the one-shot startup-gate flag described in
[section 11](#11-jira--confluence--j---c----without-atlassian) and leaves the next
real session gated again.

---

## Restoring a previous settings.json or CLAUDE.md

```bash
cp ~/.claude/settings.json.bak ~/.claude/settings.json
cp ~/.claude/CLAUDE.md.bak     ~/.claude/CLAUDE.md
```

`settings.json.bak` is rewritten only when a re-run actually changes `settings.json`, so it reflects the state immediately before the most recent *content-changing* install (a no-op run leaves it untouched). `CLAUDE.md.bak` is written only once - the first time `install.sh` replaces a *real* `~/.claude/CLAUDE.md` with the kit symlink - and isn't touched on later runs.

## Restoring data from a `--reset` or `--fresh` archive

If `--reset` archived directories you turn out to need, they're at `~/.claude-backups/<timestamp>/<dir>/`. Move the ones you want back into `~/.claude/` manually - `--reset` never auto-restores.

`--fresh` archives to `~/.claude-backups/<timestamp>-fresh/` and *does* auto-restore `projects/`, `history.jsonl`, and `.credentials.json`. The archive is the full pre-wipe copy of those three, so anything else you want back you copy by hand: `cp -a ~/.claude-backups/<timestamp>-fresh/<item> ~/.claude/`.

## Backing up generated config

Machine-local state splits in two, and the split is deliberate:

| Where | What | Backed up by |
|---|---|---|
| `~/claude-kit/generated/` (gitignored) | non-secret knobs: `.codex.env`, `.oe-chrome-agent.env`, `mcp-on/` | copy the folder |
| `~/.claude/mcp-env/`, `~/.claude/oe-chrome-agent/`, `~/.claude/.credentials.json` | every actual secret | outside the kit; `install.sh --fresh` preserves them |

Nothing else in the repo is machine-specific, so you can wipe the kit back to a pristine
checkout with a back-up / restore around the reset - and your credentials are not even in
the blast radius:

```bash
cp -a ~/claude-kit/generated /tmp/claude-kit-generated.bak   # 1. back up the one folder
cd ~/claude-kit && git reset --hard && git clean -fdx        # 2. pristine checkout (clears generated/)
cp -a /tmp/claude-kit-generated.bak/. ~/claude-kit/generated/ # 3. drop the knobs back in
bash install.sh -p standard -y                                  # 4. re-apply (re-registers MCP servers from ~/.claude/mcp-env/)
```

`git reset --hard` alone won't touch `generated/` (it's ignored); it's `git clean -fdx`
that removes it - hence the back-up. Step 4 re-reads the env files non-interactively and
re-registers any MCP servers. An older install with creds still in `settings/.*.env` or
`generated/.*.env` has them migrated to `~/.claude/mcp-env/` automatically on the next
run, and the in-repo copies removed.

(MCP server registrations also live in `~/.claude.json`, outside the kit - re-running
install.sh with the relevant `-j`/`-c`/`-g`/`-x` flags rebuilds them from
`~/.claude/mcp-env/`.)
