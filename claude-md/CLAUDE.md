# Global instructions

## Hard rules

- **Never `git commit`.** Stage; show the diff. The human commits.
- **Never `git push`.** Even on `--force`-prone branches. The human pushes.
- **Never `--no-verify`, `--amend` published commits, or `git reset --hard`** without an explicit instruction in this turn.
- **No secrets inside `~/claude-kit`.** It is a git repo with a remote, so anything
  in its working tree is one `git add -f`, one `.gitignore` edit or one archive of
  the folder away from being published - `.gitignore` is not a security control.
  Any new mechanism that needs a credential, token, cookie, key or session writes it
  under `~/.claude/<thing>/` (machine-local, never git-tracked) and reads it from
  there; the kit may hold only the non-secret config that points at it. Same rule for
  client data - real hostnames, internal IPs, patient-shaped payloads and
  customer-identifying exports do not belong in the kit either.
- **AWS is read-only. Always.** Never create, modify, delete, tag, start or stop
  anything in AWS - through an MCP server, a CLI, an SDK or a console-driving
  browser. Reads only, on every tier, in every session. If a task needs a write,
  say what you would run and stop; the human runs it. See `docs/aws.md`.
- **Everything runs in a container.** Nothing this kit drives is installed on the
  host - no browser, no runtime, no CLI. If a task seems to need a host install, say
  so and stop rather than installing it.

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
4. **Goal-driven execution.** Turn tasks into verifiable goals ("fix the bug" ->
   "write a failing test that reproduces it, then make it pass"). For multi-step
   work, state a brief plan with a verify check per step, then loop until verified.
   When a task is complicated, offer plan mode first; once the plan is approved,
   auto-execute it and close with a verification step.
5. **Tooling & dependencies.** Prefer FOSS and dockerised solutions; reach for a
   container before installing anything on the host, and call it out when an
   install is genuinely unavoidable.

## Output discipline

- No emojis unless asked.
- No em or en dashes - the plain hyphen `-` is the only dash. Use `...`, never
  the single-character ellipsis. New prose you generate is basic ASCII, but never
  edit code or text that has nothing to do with the main change to "fix" its
  characters. If non-basic-ASCII has been used - in your draft or in lines you
  touch - load the `c-ascii` skill for the pitfalls before converting or keeping it.
- Present choices or options as a numbered list; present any comparison as a table.
- Runnable commands (chat, docs, script output) go on ONE line - up to 200 chars
  is fine; never backslash-wrapped across lines.
- No trailing summary of what you just did - the diff speaks.
- No new `.md` planning docs in a repo unless explicitly requested. When a complex
  writeup is genuinely warranted, write it as a `.md` under `/home/toukan/`, not in
  the working tree.
- Comments: default none. Only write a comment for a non-obvious *why*.
- In documentation and PRs never mention Claude, and never name test
  environments (e.g. animal-named hosts) - write as though for any deployment,
  unless told to be environment-specific.

## Session context

- You are running in Claude Code; `~/.claude/` is generated from `~/claude-kit`
  (config, skills, and memory are symlinks back into the kit), and the kit is
  freely readable.
- On the first message of a session, assess which `c-*` context skills fit the
  work and load them before starting.
- `~/claude-kit/knowledge/` holds learnings from previous projects - read a
  file when its topic comes up.
- `~/claude-kit/handoff/` holds handoff documents - never read from it unless
  explicitly asked.
- When you learn something durable about a repo or technology in regular use,
  offer to fold it into the matching context skill; update only on approval.
