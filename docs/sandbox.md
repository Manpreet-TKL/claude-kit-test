# Running without prompts in a sandbox

Sometimes you want Claude Code to operate fully autonomously — long batch jobs, CI-driven refactors, scripted bring-up. For that, pair a permissive tier with `-m dontAsk` — the mode that suppresses prompts while still honouring the deny/ask rules. Two tiers suit prompt-free runs:

- `trusted` — broad allow-list + wide `rm -rf` denies; the deny list still catches `git push`/`git commit`, secret reads, and wide `rm -rf`. Use this on a host you trust.
- `yolo` — deny list trimmed to git push/commit and the two `rm -rf` rules (secret reads go through). Use this **only inside a throwaway container/VM**.

> **Mode is separate from the tier and defaults to `auto`.** A bare `-p trusted` boots into the `auto` classifier, which still stops to ask on some calls — *not* `dontAsk`. For a genuinely prompt-free unattended run, always pass `-m dontAsk` explicitly.

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
6. **Prefer `-m dontAsk` over `-m bypassPermissions`.** Mode is now separate from the rule-set (`-p` picks the deny/allow tier, `-m` picks `defaultMode`), so `bypassPermissions` is selectable — but it skips *every* check, including the git push/commit and secret-read denies that `dontAsk` still enforces. It's wider than any tier because it ignores the rules entirely; reach for it only in a throwaway VM, and only when `dontAsk` genuinely isn't enough.

## Minimum Docker recipe

```sh
docker run --rm -it \
  --network=none \                       # or a restricted bridge
  -v "$PWD/target-repo:/work" \
  -w /work \
  -e CLAUDE_API_KEY="$BOT_API_KEY" \     # scoped key, not yours
  claude-sandbox:latest
```

Inside the image, run this kit's `install.sh --permissions trusted -m dontAsk -y` once during image build (or `--permissions yolo -m dontAsk -y` if the job legitimately needs `.env` / `~/.ssh` reads to go through unprompted — note that git push/commit are still denied on `yolo`). The `-m dontAsk` is what makes it prompt-free; without it the install defaults to `auto`, which still stops to ask on some calls.

## What each prompt-free tier still denies

Even with `defaultMode: dontAsk`, the `trusted` tier blocks:

- `Bash(git push *)`, `Bash(git commit *)` — keep commits as a human action.
- `Read(./.env)`, `Read(./.env.*)`, `Read(~/.ssh/**)` — don't leak secrets into context.
- `Bash(rm -rf /*)`, `Bash(rm -rf ~*)` — guardrail against the most destructive shell typos.

The `yolo` tier keeps the git denies and the two `rm -rf` rules — only the secrets reads (`.env*`, `~/.ssh/**`) go through unprompted. **`git push` / `git commit` are a hard floor across every tier in this kit.** Use accordingly.

Tier deny lists live in `settings/permissions/<tier>.json`. Add your own deny rules to the file you actually install before re-running `install.sh` if you want more.

## What this kit deliberately doesn't do

- **`bypassPermissions` is mode-only, never a tier.** It's reachable via `-m bypassPermissions` (behind a warning) now that mode is separable from the rule-set, but no *tier* enables it: `yolo` is the widest rule-set and still keeps the git push/commit and two `rm -rf` denies. `bypassPermissions` skips those denies too, so it belongs only in a network-isolated VM — the mode is the wide part, not the tier.
- **No disabling auto-compact via `"autoCompactEnabled": false`.** That key is silently ignored — don't bother. Use `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` and `CLAUDE_CODE_AUTO_COMPACT_WINDOW` env vars instead (the installer sets both).

## CI-style autonomous runs

For "run claude over this branch in CI", you almost certainly want this kit's `trusted` tier installed with `-m dontAsk` (`install.sh -p trusted -m dontAsk -y`) inside the CI runner's normal container, with the deny rules from this kit and network access locked down by the CI runner itself. Don't rely on the default mode here — it's `auto`, which still prompts. Treat the runner as the sandbox boundary, not the permission rules.
