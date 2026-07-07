# Status line

The kit installs a `~/.claude/statusline.sh` script and wires it into `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

Claude Code runs the command on every render, pipes a JSON state blob to its **stdin**, and prints whatever the script writes to **stdout** as the status line.

## What the shipped script shows

```
⛭ <model> · <basename cwd> · [<effort> · ]5h <pct|count> · wk <pct|count>
```

For example, with budgets set and effort on `xhigh`:

```
⛭ Opus 4.7 · claude-kit · xhigh · 5h 64% · wk 27%
```

Without budgets (raw counts, humanised):

```
⛭ Opus 4.7 · claude-kit · xhigh · 5h 1.8M · wk 12M
```

| Segment           | Source                                                       | When it appears |
|---                |---                                                           |---              |
| `⛭ <model>`       | `.model.display_name // .model.id`                           | Always — falls back to `"claude"`. |
| `<basename cwd>`  | `.workspace.current_dir // .cwd`                             | Always — falls back to `.`. |
| `<effort>`        | `$CLAUDE_EFFORT` (in-session current), else `.effortLevel` in `~/.claude/settings.json` | Only when one of those is set. Levels: `low` / `medium` / `high` / `xhigh` / `max`. |
| `5h <…>`          | sum over `~/.claude/projects/*.jsonl`, last 5 hours rolling  | Always. Shows `%` if `$CLAUDE_5H_TOKEN_BUDGET` is set, otherwise a humanised count (`1.8M`, `42k`). |
| `wk <…>`          | sum over `~/.claude/projects/*.jsonl`, last 7 days rolling   | Always. Shows `%` if `$CLAUDE_WEEKLY_TOKEN_BUDGET` is set, otherwise a humanised count. |

## A proxy, not the GUI figure

The Claude Code GUI's `/usage` percentage (session % and weekly %) is computed from Anthropic's server-side rate-limit accounting — values that ride in API response headers and are held in Claude Code's in-memory state. They are **not persisted to disk** anywhere a status-line subprocess can read.

This script can only approximate the figure by summing tokens from the JSONL transcripts on disk. The two numbers will diverge for a few reasons:

- Anthropic's accounting applies plan-specific weightings the kit doesn't see.
- Cache reads, server tool use, and various other line items are billed at non-1x rates the kit can't perfectly mirror.
- The window boundaries (UTC midnight rolling vs. Anthropic's billing window) won't align exactly.

The bar is here so you can spot a runaway session at a glance — treat the GUI as the source of truth when you're close to a limit.

## How the percentages are computed

The script walks JSONL transcripts under `~/.claude/projects/` and, for each `type:"assistant"` line, sums:

```
input_tokens + output_tokens + cache_creation_input_tokens
```

`cache_read_input_tokens` are **excluded** on purpose. They're billed at ~10% rate and would inflate the tally past anything actionable in a long cache-heavy session.

Window definitions (UTC, matching the `Z`-suffixed JSONL timestamps):

- `5h` — messages with `timestamp >= now - 5h`.
- `wk` — messages with `timestamp >= now - 7 days`.

The walk is prefiltered with `find -mmin -310` / `-mtime -8` so we only `cat` files that could possibly be in range — the full JSONL corpus is never opened on every render.

## Caching — keeping the bar fast

A cold walk over a week of JSONLs takes a few hundred ms on a typical box. To keep the status line snappy, the script caches each value to `/tmp/claude-statusline-{5h,wk}-<uid>.cache`:

- `5h` cache: 30-second TTL.
- `wk` cache: 5-minute TTL.

Both TTLs are vastly shorter than their respective windows, so freshness loss is negligible. Warm renders take ~40ms.

To force a recompute, delete the cache files:

```bash
rm -f /tmp/claude-statusline-{5h,wk}-$(id -u).cache
```

## Setting token budgets

Without budgets, the script shows raw token counts (humanised). To get percentages, set one or both budgets at install time:

```bash
FIVE_HOUR_BUDGET=2000000 WEEKLY_BUDGET=20000000 ./install.sh -p standard -y
```

This writes into `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_5H_TOKEN_BUDGET": "2000000",
    "CLAUDE_WEEKLY_TOKEN_BUDGET": "20000000"
  }
}
```

Claude Code exposes these env vars to the status-line subprocess, and the script flips to `5h N%` / `wk N%`. Re-running the installer without the variables removes the keys (and the segments revert to raw counts).

There's no canonical "right" budget — Anthropic's plan limits aren't published as token-budgets, and the JSONL-based sum is a proxy anyway (see "A proxy, not the GUI figure" above). Two practical strategies:

- **Calibrate against the GUI.** Note what `/usage` shows in Claude Code, then pick budgets so the bar lands near the same percentage. e.g. if GUI shows `4%` session at `1.8M` JSONL tokens, set `FIVE_HOUR_BUDGET≈45000000`.
- **Cap-yourself number.** Pick a round number you don't want to blow past in a 5h / 7-day window, irrespective of plan, and watch the bar.

## Refresh cadence

By default Claude Code only re-runs the status-line command on conversation events (a new assistant message, `/compact`, a mode change), so during a long unattended turn — hours of tool calls in auto mode — the token bar goes stale. The kit therefore writes `statusLine.refreshInterval` into `settings.json` (default **5 seconds**, needs Claude Code ≥ 2.1.97): the command is re-run on a timer *in addition to* the event-driven updates, keeping the 5h/weekly windows honest through long sessions. The script costs ~10ms per run, so this is negligible. Tune or disable at install time:

```bash
STATUSLINE_REFRESH=30 ./install.sh -q -U   # every 30s
STATUSLINE_REFRESH=0  ./install.sh -q -U   # event-driven only (key removed)
```

## Customising

Edit `~/.claude/statusline.sh` directly — the installer rewrites it on every run (the bar layout is part of the kit), but anything that doesn't survive a re-run isn't really a customisation, it's an installer change. Either edit `claude-kit/install.sh`'s `writeStatusline()` block and re-run, or fork the script after install and stop re-running the installer's statusline step.

Things you might add:

- Git branch (`git rev-parse --abbrev-ref HEAD 2>/dev/null`).
- Hostname (handy when bouncing between dev boxes).
- Time of day (long-running sessions, time-zoned teammates).

Keep additions fast. The status line runs every prompt; avoid network calls, sub-shells that fork heavily, or anything that touches a slow disk.

## Why a script instead of a static format string

Claude Code does support static formats, but a script:

- Lets you compute things the stdin doesn't expose (token usage over a window).
- Composes with `jq` (already a dependency of this kit).
- Survives Claude Code's status-line JSON schema changing — you only need to bump the `jq` selectors.

## Troubleshooting

| Symptom                                        | Likely cause |
|---                                             |---           |
| Status line is empty                           | `statusline.sh` is missing the executable bit. `chmod +x ~/.claude/statusline.sh`. |
| `jq: command not found`                        | The kit requires `jq`. Install via `apt install jq` (or `brew install jq`). |
| `5h 0` after a long active session             | Either `~/.claude/projects/` doesn't exist (fresh install or after `--reset`) or no `type:"assistant"` lines have been written since the cutoff. Run `find ~/.claude/projects -name '*.jsonl' -mmin -310` — if empty, you genuinely have no recent transcripts. |
| Cached value seems stale                       | Delete the cache: `rm -f /tmp/claude-statusline-{5h,wk}-$(id -u).cache`. |
| Bar % is wildly different from Claude Code's `/usage` | Expected — the bar is a JSONL-derived proxy, the GUI uses Anthropic's server-side accounting (see "A proxy, not the GUI figure"). Calibrate `FIVE_HOUR_BUDGET` / `WEEKLY_BUDGET` against the GUI if you want them to roughly agree. |
| `5h N%` shows `999%`                           | You've blown past your budget; the renderer clamps the display at 999% so it doesn't push the rest of the bar out of frame. Raise the budget or take a break. |
