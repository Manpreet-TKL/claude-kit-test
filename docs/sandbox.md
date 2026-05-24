# Running without prompts in a sandbox

Sometimes you want Claude Code to operate fully autonomously — long batch jobs, CI-driven refactors, scripted bring-up. The kit ships two `defaultMode: dontAsk` tiers:

- `trusted` — no prompts, but the deny list still catches `git push`/`git commit`, secret reads, and wide `rm -rf`. Use this on a host you trust.
- `yolo` — no prompts, deny list trimmed to git push/commit and the two `rm -rf` rules (secret reads go through). Use this **only inside a throwaway container/VM**.

This doc explains the safe envelope for "no prompts" runs.

## The threat model

Without prompts, Claude Code can:

- Rewrite or delete any file your user can write/delete.
- Run any shell command (subject to deny rules).
- Push to any git remote that has cached credentials (this kit denies `git push` on **every tier**, but other tools can still push).
- Read every file your user can read (the kit denies `~/.ssh/**` and `.env*`, but anything else under your homedir is fair game).
- Hit any network endpoint reachable from the box.

The mitigation is the **container/VM** boundary, not the permission rules. The permission rules are belt-and-braces.

## Recommended envelope

1. **A throwaway VM or container** with no host-mount of your real homedir, no SSH agent forwarded, no cloud credentials baked in, and snapshot/rollback available.
2. **Network egress restricted** to the minimum the job needs (typically just the package registries and the git remote of the target repo).
3. **The repo bind-mounted read-write**, everything else read-only.
4. **`trusted` or `yolo` tier installed** for the in-container user. Pick `yolo` only if you genuinely need `.env*` / `~/.ssh/**` reads to go through unprompted (e.g. tooling that needs to read its own `.env` file); otherwise `trusted` gives the same prompt-free experience with the secrets safety net intact. **Neither tier lets Claude `git push` or `git commit`** — that's a hard floor across the kit.
5. **No human-account credentials inside the container.** Use a scoped bot account.
6. **No `bypassPermissions`** — this kit deliberately doesn't ship it. `yolo` is as wide as the kit goes; anything wider must come from a network-isolated VM, not a settings change.

## Minimum Docker recipe

```sh
docker run --rm -it \
  --network=none \                       # or a restricted bridge
  -v "$PWD/target-repo:/work" \
  -w /work \
  -e CLAUDE_API_KEY="$BOT_API_KEY" \     # scoped key, not yours
  claude-sandbox:latest
```

Inside the image, run this kit's `install.sh --permissions trusted -y` once during image build (or `--permissions yolo -y` if the job legitimately needs `.env` / `~/.ssh` reads to go through unprompted — note that git push/commit are still denied on `yolo`).

## What each prompt-free tier still denies

Even with `defaultMode: dontAsk`, the `trusted` tier blocks:

- `Bash(git push *)`, `Bash(git commit *)` — keep commits as a human action.
- `Read(./.env)`, `Read(./.env.*)`, `Read(~/.ssh/**)` — don't leak secrets into context.
- `Bash(rm -rf /*)`, `Bash(rm -rf ~*)` — guardrail against the most destructive shell typos.

The `yolo` tier keeps the git denies and the two `rm -rf` rules — only the secrets reads (`.env*`, `~/.ssh/**`) go through unprompted. **`git push` / `git commit` are a hard floor across every tier in this kit.** Use accordingly.

Tier deny lists live in `settings/permissions/<tier>.json`. Add your own deny rules to the file you actually install before re-running `install.sh` if you want more.

## What this kit deliberately doesn't do

- **No `bypassPermissions` flag.** The brief explicitly avoided it. `yolo` is the widest tier the kit ships, and even that keeps the git push/commit denies and the two `rm -rf` denies. Anything wider must come from a network-isolated VM, not a settings change.
- **No disabling auto-compact via `"autoCompactEnabled": false`.** That key is silently ignored — don't bother. Use `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` env vars instead (the installer sets both).

## CI-style autonomous runs

For "run claude over this branch in CI", you almost certainly want `claude --permissions trusted` inside the CI runner's normal container, with the deny rules from this kit and network access locked down by the CI runner itself. Treat the runner as the sandbox boundary, not the permission rules.
