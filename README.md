# claude-kit

A single-script Claude Code setup. Run `./install.sh` to configure `~/.claude/` in one shot, idempotently.

```
~/claude-kit/
├── install.sh              # the only entry point
├── README.md               # this file
├── claude-md/
│   └── CLAUDE.md           # global instructions; symlinked into ~/.claude/CLAUDE.md (edits are live)
├── settings/
│   ├── permissions/
│   │   ├── ultra-safe.json # tier 1 — read-mostly
│   │   ├── standard.json   # tier 2 — day-to-day (default)
│   │   ├── trusted.json    # tier 3 — broad allow-list + wide `rm -rf` denies
│   │   └── yolo.json       # tier 4 — git mutations + `rm -rf` still denied, secrets reads go through (container/VM only)
│   ├── shift-enter.json    # newline-on-shift-enter fragment
│   ├── mcp-atlassian.json  # Atlassian Remote MCP fragment (opt-in)
│   ├── .atlassian.env.example # Jira/Confluence creds template → copy to generated/.atlassian.env
│   ├── .github.env.example # GitHub read-only PAT template → copy to generated/.github.env
│   └── .codex.env.example  # Codex agent defaults template → copy to generated/.codex.env
├── generated/              # ALL machine-local creds/config (gitignored wholesale; back this up)
│   ├── .atlassian.env      #   real Jira/Confluence creds (created by install.sh -j/-c)
│   ├── .github.env         #   real GitHub PAT          (created by install.sh -g)
│   └── .codex.env          #   Codex model/sandbox knobs (created by install.sh -x; no secret)
├── skills/                 # each dir symlinked into ~/.claude/skills/<name>
│   │                       #   context skills are prefixed c-; manual (disable-model-invocation) is the default
│   ├── c-frontend-design/  #   auto-load ┐ no disable-model-invocation —
│   ├── c-oe-helm/          #   auto-load │ the model pulls these in itself
│   ├── c-oe-ui/            #   auto-load ┘ when the task matches
│   ├── c-oe-code/ c-oe-db-schema/ c-oe-coding-standards/ c-oe-components/        # OpenEyes — manual
│   ├── c-oe-deploy/ c-oeimagebuilder/ c-pasapi/ c-mirth/ c-mcchannels/ c-oe-interop/  # OpenEyes — manual
│   ├── c-oe-iolmaster-import/ c-oe-payload-processor/          # OpenEyes file processors — manual
│   ├── c-bash-style/ c-yiic-command-style/ c-note-style/       # house style — manual
│   ├── c-claude-kit/ c-dblogin/ c-docbuilder-docset/ c-notes-app/  # kit/repo context — manual
│   ├── create-pr/ create-oe-pr/ create-oe-module/ new-feature/ performance-indexes-rollup/  # workflow — manual
│   └── jiramcp/ githubmcp/ codexmcp/ devopstickets/            # MCP preflight — manual; no "Context loaded"
└── docs/
    ├── permissions.md      # how the 4 tiers work, deny → ask → allow
    ├── skills.md           # CLAUDE.md vs SKILL.md, sub-skills, naming
    ├── statusline.md       # how the status line script works
    ├── sandbox.md          # running without prompts in a container/VM
    ├── atlassian.md        # Jira + Confluence via Atlassian MCP — setup + teardown
    ├── github.md           # GitHub (read-only) via github-mcp-server — setup + teardown
    └── codex.md            # OpenAI Codex agents via codex mcp-server — setup + teardown
```

The installer writes / merges:

- `~/.claude/settings.json` — status line, autocompact env vars, permissions block, shift-enter binding.
- `~/.claude/statusline.sh` — the status line renderer (**symlinked** to `settings/statusline.sh`).
- `~/.claude/CLAUDE.md` — **symlinked** to `claude-md/CLAUDE.md` in this kit (never-commit/push rules + condensed Karpathy guidelines); editing the kit file is live.
- `~/.claude/skills/<name>` — symlinked to `skills/<name>` in this kit.

Machine-local credentials and config the installer generates (Atlassian / GitHub / Codex) all land in **one gitignored folder, `generated/`**, so you can back up that single folder, `git reset --hard` + `git clean -fdx` the whole kit, and drop it back in — see [Backing up generated config](#backing-up-generated-config). MCP server registrations themselves are written by the `claude` CLI to `~/.claude.json` (not `settings.json`).

It backs up the pre-existing `settings.json` to `settings.json.bak` only when the merged content actually differs, so a no-op re-run preserves your existing backup. The first time it converts a real `~/.claude/CLAUDE.md` (or `statusline.sh`) into the kit symlink it backs that file up to `*.bak`; once it's a symlink there's nothing left to back up. `settings.json` is edited as JSON via `jq` (never blind text-append).

---

## Quick start

```bash
cd ~/claude-kit
./install.sh                                # interactive tier choice (default standard)
./install.sh --permissions ultra-safe       # explicit tier
./install.sh -p trusted -y                  # non-interactive
./install.sh --reset -p standard -y         # archive bloat → reinstall
./install.sh --fresh -p standard            # back up data → wipe ~/.claude → fresh install
./install.sh --no-update -p standard -y     # skip the `claude update` step
AUTOCOMPACT_PCT=50 ./install.sh -p standard -y
./install.sh --help
```

Re-running is safe — Claude Code itself is installed if it's missing and otherwise updated (`claude update`), `settings.json` is re-merged, and the `CLAUDE.md`, status-line, and skill symlinks are refreshed to point back into the kit (so editing any kit file is live; a pre-existing *real* `CLAUDE.md`/`statusline.sh` is backed up to `.bak` the first time it's replaced by a link). Skill links are pruned too: real directories under `~/.claude/skills/` are left alone, and symlinks this kit created for skills since removed from the kit are removed (see [§7](#7-skills)).

---

## The features

### 1. Permission rule-set + start mode (`--permissions ultra-safe|standard|trusted|yolo`, `--mode …`)

Each tier lives as a standalone JSON file at `settings/permissions/<tier>.json`. The installer reads the file and copies it whole into `permissions:` — no inline construction.

| Tier         | Rule-set (allow/ask/deny)                                                                  |
| ---          | ---                                                                                        |
| `ultra-safe` | Tightest allow-list — reads + inspection only; edits/writes/shell aren't pre-approved; denies git mutations and secrets. |
| `standard`   | Curated allow-list for common edits and dev/test commands; arbitrary shell falls to your mode. |
| `trusted`    | Same broad allow-list as `standard` + extra `rm -rf` denies; still denies git mutations + secrets. |
| `yolo`       | Like `trusted`, but `.env`/`.ssh` reads go through; `git push` / `git commit` and `rm -rf /*` / `rm -rf ~*` still denied (those denies are a hard floor across every tier). **Container/VM only.** |

The tier (`-p`) is just the **rule-set**. The **session start mode** (`permissions.defaultMode`) is separate and defaults to `auto` for every tier: `-m default|plan|acceptEdits|auto|dontAsk|bypassPermissions` picks it explicitly — e.g. `-p standard -m plan`. (`auto` is the classifier-judged mode — auto-approves calls it deems safe, asks on the rest.) Omit `-m` and the session boots in `auto`; interactive runs prompt for it (Enter selects `auto`).

Full explanation including evaluation order (`deny → ask → allow`) and what each tier denies: **[docs/permissions.md](docs/permissions.md)**. No *tier* enables `bypassPermissions` — `yolo` is the widest rule-set — but `-m bypassPermissions` is now selectable behind a warning; it skips even the deny floor, so it's VM-only. See [docs/sandbox.md](docs/sandbox.md) for the safe envelope.

### 2. Status line

A `statusLine.command` pointing at `~/.claude/statusline.sh`. The script reads the session-context JSON from stdin, sums token usage from `~/.claude/projects/*.jsonl` over a 5-hour and 7-day rolling window, and renders:

```
⛭ <model> · <dir> · [<effort> · ]5h <pct|count> · wk <pct|count>
```

Each window segment shows a **percentage** if you set a budget (`FIVE_HOUR_BUDGET`, `WEEKLY_BUDGET` — see env-overrides table below) and a humanised **raw count** otherwise. The optional `<effort>` segment (e.g. `xhigh`) reflects the reasoning-effort level — `$CLAUDE_EFFORT` from the live session, falling back to `.effortLevel` in `~/.claude/settings.json`; omitted if neither is set. Results are cached to `/tmp/claude-statusline-{5h,wk}-<uid>.cache` (30s / 5min TTL) so the bar renders in ~40ms after the first cold walk.

The figures are a **local proxy**: Claude Code's GUI `/usage` % comes from Anthropic's server-side rate-limit accounting (held in-memory, not persisted), so the bar will diverge — calibrate budgets against the GUI if you want them to roughly agree. See **[docs/statusline.md](docs/statusline.md)**.

### 3. Shift+Enter newline

`settings/shift-enter.json` is merged into `settings.json` to bind Shift+Enter for newline. If your terminal still won't honour it, run `/terminal-setup` once interactively or bind the key sequence in your terminal app.

### 4. Auto-compact env vars

```
AUTOCOMPACT_PCT      → env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE   (default 100 — no reduction; only lowers, clamped to ~83)
AUTOCOMPACT_WINDOW   → env.CLAUDE_CODE_AUTO_COMPACT_WINDOW   (default 200000)
FIVE_HOUR_BUDGET     → env.CLAUDE_5H_TOKEN_BUDGET            (unset — status line shows raw count; set to flip to a 5h %)
WEEKLY_BUDGET        → env.CLAUDE_WEEKLY_TOKEN_BUDGET        (unset — status line shows raw count; set to flip to a wk %)
```

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` only **lowers** the trigger; values above the internal cap (~83%) are clamped.
- The percentage applies to the original window, not the reduced one — `CLAUDE_CODE_AUTO_COMPACT_WINDOW` is the lever for the absolute token budget.
- Don't use `"autoCompactEnabled": false` — that key is silently ignored.
- Token budgets aren't published by Anthropic per-plan; pick numbers from observed usage or calibrate against the Claude Code GUI's `/usage`. Example: `FIVE_HOUR_BUDGET=2000000 WEEKLY_BUDGET=20000000`.

### 5. Git + secret deny rules

`Bash(git push *)` and `Bash(git commit *)` are denied on **every tier including `yolo`** — that's a hard floor. The human raises commits and pushes; Claude doesn't. The two `rm -rf /*` / `rm -rf ~*` denies are also universal.

Reads of `.env*` and `~/.ssh/**` are denied on `ultra-safe` / `standard` / `trusted`. `yolo` drops only the secrets reads — use it only in a throwaway container/VM. Deny rules live inside each tier JSON file — to change them, edit the relevant `settings/permissions/<tier>.json` and re-run.

### 6. Global CLAUDE.md

`~/.claude/CLAUDE.md` is a **symlink** to `claude-md/CLAUDE.md` in this kit. The shipped file is short and opinionated:

- Hard rules at the top: never `git commit`, never `git push`, never `--no-verify` / `--amend` / `git reset --hard` without explicit instruction.
- Condensed Karpathy-style coding guidelines (think first, simplicity, surgical changes, goal-driven execution with plan-mode-then-verify for complex tasks, and a preference for FOSS/dockerised tooling over host installs).
- Output discipline (no emojis, no trailing summaries; planning docs only when asked, and complex writeups land under `/home/toukan/`).

Because it's a symlink, editing `claude-md/CLAUDE.md` rolls out immediately — no re-install needed. The first time `install.sh` replaces a pre-existing *real* `~/.claude/CLAUDE.md` with the link it preserves the old file at `~/.claude/CLAUDE.md.bak`.

### 7. Skills

`install.sh` symlinks each directory under `skills/` into `~/.claude/skills/<name>`. Edit a skill in this kit and the change is live without re-installing.

**How a skill gets its context in front of Claude — two modes:**

- **Auto-load (no `disable-model-invocation`).** Claude reads every skill's `name` + `description` at startup and decides *on its own* to pull the whole `SKILL.md` into context the moment a task matches the description. You don't name these — they load when relevant. Today: **`c-frontend-design`, `c-oe-helm`, `c-oe-ui`**. For these the **`description:` is the trigger**, so it's written to fire on the right task.
- **Manual (`disable-model-invocation: true`).** Claude will *never* auto-load these; the body only enters context when you (or a plan) invoke the skill **by name** (`/c-oe-code`, `/jiramcp`, …). Everything else in the kit is manual — they're large, repo-specific, or preflight checks you want to fire deliberately, not opportunistically. **Manual is the default for a new skill** — set the flag unless you have a deliberate reason to auto-load.

Either way the **`description:` is a single terminal line** (≤ ~78 chars) so the whole thing is readable when you search skills inside Claude — keep it one line when editing.

**Loading convention — "Context loaded".** Every skill except the four MCP-preflight ones (`codexmcp`, `devopstickets`, `githubmcp`, `jiramcp`) starts its body with:

> When loaded as context with no task, reply only `Context loaded.`

So invoking a skill just to prime context returns a one-word ack instead of a 2,000-token summary you didn't ask for. The four preflight skills are the deliberate exception — they *do* run a check and report. Aim to keep each `SKILL.md` **under ~2,000 tokens** (≈ 8 KB) so loading is cheap; push volatile detail into `subs/*.md` and let Claude open those on demand. Two skills intentionally exceed this — `create-oe-module` (~4.2k) and `c-oe-coding-standards` (~3.2k) — because they're reference-dense scaffolding/standards docs.

Each repo-specific skill follows the **stable mental model in `SKILL.md`, volatile detail in `subs/*.md`** convention. See **[docs/skills.md](docs/skills.md)**.

**Symlink lifecycle.** `install.sh` records exactly which skills it symlinked in `~/.claude/.claude-kit-skills`. On every run it (1) re-links all current kit skills, and (2) **prunes** any `~/.claude/skills/<name>` *symlink* that this kit created but that has since been removed from `skills/` — so deleting a skill from the kit and re-running cleans it out of `~/.claude`. Two safety floors: a destination that is a **real directory** (your hand-added skill) is skipped with a warning and never touched, and a **symlink pointing somewhere other than this kit** (added by hand or another tool) is left alone. Only kit-created symlinks are ever removed.

### 8. Reset to first-install state (`--reset`)

`./install.sh --reset` archives Claude Code's auto-generated state — `file-history`, `paste-cache`, `backups`, `shell-snapshots`, `stats-cache`, `session-env`, `plugins`, `tasks` — into `~/.claude-backups/<timestamp>/`, then proceeds with the normal install. Preserved in place: `.credentials.json` (don't lose your auth), `history.jsonl`, and `projects/`. The reset runs **before** `settings.json` is backed up to `.bak`, so a single `--reset` run leaves you with a clean state plus one snapshot archive you can rummage through later. Combine with `-p <tier>` and `-y` to do it non-interactively.

### 9. Nuke and pave (`--fresh`)

`./install.sh --fresh` rebuilds `~/.claude` from scratch while **keeping your conversations and staying logged in**. It:

1. Backs up `projects/` (your conversations), `history.jsonl`, and `.credentials.json` (auth) to `~/.claude-backups/<timestamp>-fresh/`.
2. **Deletes the entire `~/.claude`.**
3. Reinstalls Claude Code fresh (the from-scratch `curl … | bash`).
4. Restores those three items, then re-applies the kit (settings, CLAUDE.md, skills) on top.

Everything else — settings, caches, plugins, `shell-snapshots`, MCP registration state — is regenerated clean rather than carried over. Use it when `~/.claude` has accumulated cruft a `--reset` won't shake, or after an upgrade leaves it inconsistent. **`--fresh` supersedes `--reset`** (no point archiving bloat you're about to delete). Because it runs `rm -rf ~/.claude`, an interactive run makes you **type `fresh` to confirm**; `-y` skips that prompt for automation. The full pre-wipe snapshot is kept at `~/.claude-backups/<timestamp>-fresh/` — nothing is deleted that isn't archived first. On a machine with no `~/.claude` yet, `--fresh` simply does a clean install. Restore anything else you want with `cp -a ~/.claude-backups/<timestamp>-fresh/<item> ~/.claude/`.

### 10. Fresh-machine bootstrap + `claude update`

The installer manages the Claude Code CLI itself, so a brand-new machine needs nothing pre-installed beyond `jq`/`curl`:

- **Install if absent.** If `~/.claude` doesn't exist, install.sh runs `curl -fsSL https://claude.ai/install.sh | bash` to install Claude Code before configuring it.
- **Update if present.** Otherwise it runs **`claude update`** to pull the latest CLI before applying config. Skip with `--no-update` (`-U`) when offline or when the CLI is managed by a package manager; it's auto-skipped right after a from-scratch install (already current) and if `claude` isn't on `PATH`. A failed update warns and continues rather than aborting.

### 11. Jira + Confluence (`--with-atlassian` / `--without-atlassian`)

Merge or remove the Atlassian Remote MCP server entry in `settings.json`:

```bash
./install.sh --with-atlassian    -p standard -y    # opt in
./install.sh --without-atlassian -p standard -y    # tear down
```

Authentication is OAuth-based and happens inside Claude Code via `/mcp` — no tokens stored in this repo. Full setup + teardown (including revoking the OAuth grant on Atlassian's side) lives in **[docs/atlassian.md](docs/atlassian.md)**.

Neither flag = `mcpServers.atlassian` is left exactly as-is on re-runs (the installer never silently flips it on or off).

### 12. GitHub — read-only (`--with-github` / `--without-github`)

Register or remove GitHub's official `github-mcp-server`, run as a Docker stdio server
(`ghcr.io/github/github-mcp-server`) at user scope — the same shape as Atlassian:

```bash
./install.sh --with-github    -p standard -y    # opt in  (-g)
./install.sh --without-github -p standard -y    # tear down (-G)
```

**Read-only is enforced and not configurable.** install.sh bakes `GITHUB_READ_ONLY=1`
into the registration, so the server exposes only read tools — creating PRs/branches,
pushing, commenting, and merging are impossible by construction. This is the GitHub-API
analogue of the never-`git push`/never-`git commit` hard floor. The human raises PRs
(see the `create-oe-pr` skill).

Authentication is a **fine-grained, read-only** personal access token (with `openeyes`
org access), stored in `generated/.github.env` (mode 600, gitignored) — never on the
`docker` command line. After opting in, restart Claude Code and run `/githubmcp` to
verify. Full setup, token minting, rotation, and teardown live in
**[docs/github.md](docs/github.md)**.

Neither flag = `mcpServers.github` is left exactly as-is on re-runs.

### 13. OpenAI Codex agents (`--with-codex` / `--without-codex`)

Register or remove **OpenAI Codex** as a local MCP server so Claude can spawn one or
many autonomous Codex coding agents. Unlike Atlassian/GitHub this is **not** a Docker
image — it runs the host `codex` binary as `codex mcp-server`:

```bash
./install.sh --with-codex    -p standard    # opt in  (-x)
./install.sh --without-codex -p standard -y  # tear down (-X)
```

Needs the **Codex CLI** on PATH (`npm install -g @openai/codex`) and a one-time
**`codex login`** (ChatGPT sign-in — so **no token is stored in this kit**; auth lives
in `~/.codex`). The server exposes `mcp__codex__codex` / `mcp__codex__codex-reply`;
Claude fans agents out by calling them in one message. Run `/codexmcp` to preflight and
for the fan-out + safety rules.

install.sh pins the agent defaults as `-c` launch overrides — **flagship model
(`gpt-5.5`) at `high` reasoning effort**, in a **`workspace-write`, network-off
sandbox** with `approval_policy=never` — recorded (non-secretly) in
`generated/.codex.env`. **Network-off is the safety floor:** an agent runs its own
shell *outside* Claude's `deny` rules, so blocking the network is what stops it
`git push`-ing; the `codexmcp` skill additionally tells agents never to commit (the
human commits). `mcp__codex` is allowed on `standard`/`trusted`/`yolo` but **prompts on
`ultra-safe`** — spawning a writer is a write action. Full setup, model/sandbox tuning, and
teardown: **[docs/codex.md](docs/codex.md)**.

Neither flag = `mcpServers.codex` is left exactly as-is on re-runs.

---

## Verification

After applying, `install.sh` runs the checks and prints `[PASS]` / `[FAIL]` / `[INFO]` per feature. Re-run them by hand at any time:

```bash
jq '.statusLine'                                       ~/.claude/settings.json   # status line
jq '.permissions.defaultMode'                          ~/.claude/settings.json   # session start mode
jq '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE,
    .env.CLAUDE_CODE_AUTO_COMPACT_WINDOW'              ~/.claude/settings.json   # autocompact
jq '.permissions.deny'                                 ~/.claude/settings.json   # deny rules
jq '.shiftEnterKeyBindingInstalled'                    ~/.claude/settings.json   # shift-enter
cmp -s ~/claude-kit/claude-md/CLAUDE.md ~/.claude/CLAUDE.md && echo match        # CLAUDE.md
ls -l ~/.claude/skills/                                                          # symlinks
claude mcp get codex                                                             # codex MCP server (if -x)
```

---

## Restoring a previous settings.json or CLAUDE.md

```bash
cp ~/.claude/settings.json.bak ~/.claude/settings.json
cp ~/.claude/CLAUDE.md.bak     ~/.claude/CLAUDE.md
```

`settings.json.bak` is rewritten only when a re-run actually changes `settings.json`, so it reflects the state immediately before the most recent *content-changing* install (a no-op run leaves it untouched). `CLAUDE.md.bak` is written only once — the first time `install.sh` replaces a *real* `~/.claude/CLAUDE.md` with the kit symlink — and isn't touched on later runs.

## Restoring data from a `--reset` or `--fresh` archive

If `--reset` archived directories you turn out to need, they're at `~/.claude-backups/<timestamp>/<dir>/`. Move the ones you want back into `~/.claude/` manually — `--reset` never auto-restores.

`--fresh` archives to `~/.claude-backups/<timestamp>-fresh/` and *does* auto-restore `projects/`, `history.jsonl`, and `.credentials.json`. The archive is the full pre-wipe copy of those three, so anything else you want back you copy by hand: `cp -a ~/.claude-backups/<timestamp>-fresh/<item> ~/.claude/`.

## Backing up generated config

Every credential and machine-local setting the installer writes *into the kit* lives in
one gitignored folder: **`generated/`** (`.atlassian.env`, `.github.env`, `.codex.env`).
Nothing else in the repo is machine-specific. So you can wipe the kit back to a pristine
checkout and keep your creds with a back-up / restore around the reset:

```bash
cp -a ~/claude-kit/generated /tmp/claude-kit-generated.bak   # 1. back up the one folder
cd ~/claude-kit && git reset --hard && git clean -fdx        # 2. pristine checkout (clears generated/)
cp -a /tmp/claude-kit-generated.bak/. ~/claude-kit/generated/ # 3. drop creds back in
./install.sh -p standard -y                                  # 4. re-apply (re-registers MCP servers from the env files)
```

`git reset --hard` alone won't touch `generated/` (it's ignored); it's `git clean -fdx`
that removes it — hence the back-up. Step 4 re-reads the env files non-interactively and
re-registers any MCP servers. An older install with creds still in `settings/.*.env` is
migrated into `generated/` automatically on the next run.

(MCP server registrations also live in `~/.claude.json`, outside the kit — re-running
install.sh with the relevant `-j`/`-c`/`-g`/`-x` flags rebuilds them from `generated/`.)
