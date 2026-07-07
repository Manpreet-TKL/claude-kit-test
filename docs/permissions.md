# Permissions

`~/.claude/settings.json` controls what Claude Code can do without asking. The kit ships four tiers as separate JSON files under `settings/permissions/`; `install.sh` copies the selected tier in via `jq`.

## The four tiers

The tier is only the **rule-set** — the allow/ask/deny lists. It says nothing about the session start mode; that's `-m` (next section), which defaults to `auto` for every tier.

| Tier         | What the rule-set does                                                     |
| ---          | ---                                                                        |
| `ultra-safe` | Tightest allow-list. Reads and inspection go through; edits, writes, and shell aren't pre-approved, so your mode decides them. Suited to reviewing strangers' repos. |
| `standard`   | Day-to-day. A curated allow-list auto-approves common edits and dev/test shell commands; anything off it falls to your mode. |
| `trusted`    | Same broad allow-list as `standard`, plus wide `rm -rf` denies. Pair with `-m dontAsk` for a prompt-free run that still blocks git push/commit, secret reads, and `rm -rf /*`. |
| `yolo`       | Like `trusted`, but the secret-read denies (`.env*`, `~/.ssh/**`) are dropped. **Container/VM only.** |

Pick at install time:

```sh
./install.sh --permissions standard              # standard rules; mode defaults to auto
./install.sh --permissions standard --mode plan  # standard rules, but boot into plan mode
```

If you omit `--permissions`, the installer prompts (defaulting to `standard`); under `-q` (quick, fully non-interactive) it takes `yolo` without asking.

## Session start mode (`-m`)

`defaultMode` is what the session boots as — the fallback the evaluator uses for any tool call not settled by an `allow`/`ask`/`deny` rule (step 4 below). It's independent of the rule-set, so `-p` and `-m` mix freely:

| Mode | Session starts as |
| --- | --- |
| `default` | Evaluate rules; anything unmatched prompts on first use. |
| `plan` | Plan mode — read-only; no edits or command execution until you approve a plan. |
| `acceptEdits` | Auto-accept Edit/Write; everything else follows the rules. |
| `auto` | LLM safety classifier judges each tool call — auto-approves the ones it deems safe, asks on the rest. Shell is routed through the classifier, which can even supersede a static `allow` rule. |
| `dontAsk` | No prompts; `deny` + `ask` rules still apply. |
| `bypassPermissions` | Skip **all** checks — the widest mode, wider than any tier. Sandbox/VM only. |

Omit `-m` and the session boots in `auto` regardless of tier (change the fallback with `DEFAULT_MODE=…` at install time, or pass `-m`) — the mode is never prompted for; interactive runs only ask for the tier. `bypassPermissions` ignores even the deny list, so the git push/commit hard floor no longer bites under it — see [sandbox.md](sandbox.md).

## Evaluation order

For any tool call, the rules are evaluated in this order — **first match wins**:

1. `deny`  → block, don't ask, don't run.
2. `ask`   → prompt the user.
3. `allow` → run silently.
4. Otherwise → fall back to `defaultMode`.

This is why a `dontAsk` run on `trusted` is still safe-ish: even with no prompts, the deny list still catches `git push`, `git commit`, secret reads, and wide `rm -rf`.

## What's denied where

| Deny rule | ultra-safe | standard | trusted | yolo |
| --- | :-: | :-: | :-: | :-: |
| `Bash(git push *)`                  | ✓ | ✓ | ✓ | ✓ |
| `Bash(git commit *)`                | ✓ | ✓ | ✓ | ✓ |
| `Read(./.env)`, `Read(./.env.*)`    | ✓ | ✓ | ✓ |   |
| `Read(~/.ssh/**)`                   | ✓ | ✓ | ✓ |   |
| `Bash(rm -rf /*)`, `Bash(rm -rf ~*)`|   |   | ✓ | ✓ |

`git push` and `git commit` are a **hard floor** — every tier carries them, `yolo` included. Commits and pushes are intentional human actions, not autonomous ones; no permission tier in this kit lets Claude do either. `yolo` only relaxes the secrets reads (`.env*`, `~/.ssh/**`); the wide `rm -rf` denies are kept on the two `dontAsk` tiers (`trusted` / `yolo`) where they're most useful. Use `yolo` exclusively inside a throwaway container/VM. See [sandbox.md](sandbox.md).

The hard floor has a mirror image: one universal **allow**. Every tier — `ultra-safe` included — carries `Bash(~/claude-kit/install.sh -l *)` and `Bash(bash ~/claude-kit/install.sh -l *)`, so logging out of an MCP never needs a prompt. That's safe to always-allow because `-l/--logout` is a standalone action: install.sh validates the target, clears the credentials, and **exits before any other flag takes effect** — appended arguments parse but never execute, so the rule can't be escalated into a full install.

## Editing the tier files

The tier JSON lives at `settings/permissions/<tier>.json`. To change what `standard` allows, edit `settings/permissions/standard.json` and re-run `install.sh`. The installer replaces the entire `permissions` block on each run (so removed keys disappear), but unrelated keys in `settings.json` survive via `jq` merge.

## Idempotency

Re-running `install.sh` with the same tier is a no-op for content but **does** overwrite `settings.json.bak` with whatever `settings.json` looked like before this run. If you need a deeper history, version-control `~/.claude/settings.json` yourself.

## Where this maps in Claude Code

Anthropic's Claude Code docs call these "permission modes" and "permission rules". This kit just freezes a sensible default set into version-controlled JSON so you can re-apply them on a new machine in one command.
