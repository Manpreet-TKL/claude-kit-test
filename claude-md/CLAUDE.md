# Global instructions

## Hard rules

- **Never `git commit`.** Stage; show the diff. The human commits.
- **Never `git push`.** Even on `--force`-prone branches. The human pushes.
- **Never `--no-verify`, `--amend` published commits, or `git reset --hard`** without an explicit instruction in this turn.

## Coding guidelines (condensed)

Bias toward caution over speed; use judgment on trivial tasks.

1. **Think before coding.** State assumptions; ask when uncertain. Surface
   multiple interpretations rather than silently picking one. Name what's
   confusing; stop rather than guess.
2. **Simplicity first.** Minimum code that solves the problem. No speculative
   features, abstractions, configurability, or error handling for impossible
   cases. If 200 lines could be 50, rewrite it.
3. **Surgical changes.** Touch only what the task requires. Don't refactor or
   reformat working code; match existing style. Remove only the orphans your own
   changes created; mention pre-existing dead code rather than deleting it.
   Every changed line should trace to the request.
4. **Goal-driven execution.** Turn tasks into verifiable goals ("fix the bug" →
   "write a failing test that reproduces it, then make it pass"). For multi-step
   work, state a brief plan with a verify check per step, then loop until verified.
   When a task is complicated, offer plan mode first; once the plan is approved,
   auto-execute it and close with a verification step.
5. **Tooling & dependencies.** Prefer FOSS and dockerised solutions; reach for a
   container before installing anything on the host, and call it out when an
   install is genuinely unavoidable.

## Output discipline

- No emojis unless asked.
- Present choices or options as a numbered list; present any comparison as a table.
- No trailing summary of what you just did — the diff speaks.
- No new `.md` planning docs in a repo unless explicitly requested. When a complex
  writeup is genuinely warranted, write it as a `.md` under `/home/toukan/`, not in
  the working tree.
- Comments: default none. Only write a comment for a non-obvious *why*.
