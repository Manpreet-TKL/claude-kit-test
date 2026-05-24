# Permissions

`~/.claude/settings.json` controls what Claude Code can do without asking. The kit ships four tiers as separate JSON files under `settings/permissions/`; `install.sh` copies the selected tier in via `jq`.

## The four tiers

| Tier      | `defaultMode` | What it feels like                                                         |
| ---       | ---           | ---                                                                        |
| `safe`    | `default`     | Read-mostly. Edit/Write/Bash all prompt. Suited to reviewing strangers' repos. |
| `standard`| `acceptEdits` | Day-to-day. Edits auto-accept; shell prompts unless in the curated allow list. |
| `trusted` | `dontAsk`     | Nothing prompts. Deny rules still catch git push/commit, secret reads, `rm -rf /*`. |
| `yolo`    | `dontAsk`     | Nothing prompts. Git push/commit and `rm -rf /*` / `rm -rf ~*` still denied; secrets reads go through. **Container/VM only.** |

Pick at install time:

```sh
./install.sh --permissions standard      # or safe / trusted / yolo
```

If you omit `--permissions`, the installer prompts (defaulting to `standard`).

## Evaluation order

For any tool call, the rules are evaluated in this order — **first match wins**:

1. `deny`  → block, don't ask, don't run.
2. `ask`   → prompt the user.
3. `allow` → run silently.
4. Otherwise → fall back to `defaultMode`.

This is why `trusted` is still safe-ish: even though `defaultMode` is `dontAsk`, the deny list still catches `git push`, `git commit`, secret reads, and wide `rm -rf`.

## What's denied where

| Deny rule | safe | standard | trusted | yolo |
| --- | :-: | :-: | :-: | :-: |
| `Bash(git push *)`                  | ✓ | ✓ | ✓ | ✓ |
| `Bash(git commit *)`                | ✓ | ✓ | ✓ | ✓ |
| `Read(./.env)`, `Read(./.env.*)`    | ✓ | ✓ | ✓ |   |
| `Read(~/.ssh/**)`                   | ✓ | ✓ | ✓ |   |
| `Bash(rm -rf /*)`, `Bash(rm -rf ~*)`|   |   | ✓ | ✓ |

`git push` and `git commit` are a **hard floor** — every tier carries them, `yolo` included. Commits and pushes are intentional human actions, not autonomous ones; no permission tier in this kit lets Claude do either. `yolo` only relaxes the secrets reads (`.env*`, `~/.ssh/**`); the wide `rm -rf` denies are kept on the two `dontAsk` tiers (`trusted` / `yolo`) where they're most useful. Use `yolo` exclusively inside a throwaway container/VM. See [sandbox.md](sandbox.md).

## Editing the tier files

The tier JSON lives at `settings/permissions/<tier>.json`. To change what `standard` allows, edit `settings/permissions/standard.json` and re-run `install.sh`. The installer replaces the entire `permissions` block on each run (so removed keys disappear), but unrelated keys in `settings.json` survive via `jq` merge.

## Idempotency

Re-running `install.sh` with the same tier is a no-op for content but **does** overwrite `settings.json.bak` with whatever `settings.json` looked like before this run. If you need a deeper history, version-control `~/.claude/settings.json` yourself.

## Where this maps in Claude Code

Anthropic's Claude Code docs call these "permission modes" and "permission rules". This kit just freezes a sensible default set into version-controlled JSON so you can re-apply them on a new machine in one command.
