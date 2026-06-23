---
name: new-feature
description: Plan a green-field feature (plan mode + verify)
disable-model-invocation: true
---

# New-feature playbook

When loaded as context with no task, reply only `Context loaded.`

A green-field feature is the wrong place to start typing. This skill enforces a four-step shape: **plan → question → divide → verify**.

## 1. Enter plan mode immediately

Before any tool that writes (`Edit`, `Write`, `Bash` that mutates), call `EnterPlanMode`. The user will see a plan-mode banner. From now on, no implementation tool calls until the plan is approved with `ExitPlanMode`.

If `EnterPlanMode` isn't available in the session (rare), say so explicitly and proceed in "draft plan only — no edits" discipline manually.

## 2. Ask up to 10 clarifying questions

Use `AskUserQuestion` once with **as many of the most load-bearing questions as you actually have** (the tool accepts 1–4 per call, so chain calls if you need more — but cap the total at **10**). A bad question costs the user a click; a missing question costs them a re-do. Prioritise the questions whose answer would flip your design.

Question topics, in rough order of payoff:

1. **Outcome:** what user/system behavior should exist when this is done?
2. **Scope edges:** what is explicitly *out* of scope for this iteration?
3. **Surface:** UI, API, CLI, background job, or a mix?
4. **Data model:** new table/column? Mutating an existing one? Soft-delete or hard?
5. **Auth / multi-tenancy:** per-user, per-org, public? Does it cross trust boundaries?
6. **Failure mode:** what should happen on partial success / retry / network loss?
7. **Performance envelope:** how many records, how often, latency budget?
8. **Existing patterns:** is there a sibling feature whose conventions we should mirror?
9. **Release path:** flagged behind a toggle? Migration window? Backwards-compat needed?
10. **Done-ness:** what concretely makes this "shippable" — a passing test, a screenshot, a sign-off?

Skip any that the user has already answered in the brief. Stop asking the moment you have enough to write a sharp plan.

## 3. Divide the work — assign models and subagents

Build the plan as an ordered list of phases. For each phase, name:

- **Who runs it.** Default model (Opus) for design, judgment, and edits inside an active session. Sonnet for high-volume mechanical sweeps. Haiku for tight loops where latency matters more than nuance.
- **Which subagent (if any).** Use the lightest tool that fits.

  | Subagent              | Use for                                                                                  |
  |---                    |---                                                                                       |
  | `Explore`             | Bounded read-only code search. "Find every call site of X." Quick / medium / thorough.   |
  | `Plan`                | Architect a step-by-step implementation plan when the design space is non-trivial.       |
  | `claude-code-guide`   | Questions about Claude Code itself, the Agent SDK, or the Anthropic API.                 |
  | `general-purpose`     | Open-ended multi-step research or coding work that doesn't fit the specialised agents.   |
  | `code-review`         | Independent diff review at the end of an implementation phase.                           |
  | `verify`              | Drive the running app to confirm the feature actually works end-to-end.                  |

  Prefer running independent subagents **in parallel** (single message, multiple `Agent` calls) when their work doesn't depend on each other.

- **Verify check.** One concrete thing that proves the phase is done — a test name, a `curl` you'll run, a screenshot, a log line.

A good plan reads like:

```
1. Explore  · Explore-agent (quick) · find existing soft-delete pattern in modules/X
   → verify: report cites the trait and 2+ call sites

2. Design   · Opus inline · sketch model + migration, share schema diff
   → verify: user accepts schema

3. Build    · Opus inline · write migration + model + 1 unit test
   → verify: `yiic migrate --all` and `phpunit tests/unit/.../FooTest.php` both green

4. UI       · Opus inline · wire form + controller
   → verify: manual click-through (verify agent) + screenshot of success state

5. Review   · code-review subagent · final diff pass
   → verify: no high-severity findings
```

## 4. End with a verification / goal statement

The plan must close with a single line of the form:

> **Goal:** when `<concrete observable thing>` is true, this feature is done.

Examples:
- "When a user with role `clinic_admin` can click 'Archive' on a patient row and the row disappears from the default list but reappears under `?showArchived=1`, this feature is done."
- "When `POST /api/v1/widgets` accepts `{name,quantity}`, returns `201` with a created body, persists a row, and an integration test asserts all three, this feature is done."

This is the line you'll re-quote at the end of every phase to check you haven't drifted.

## When to invoke this skill

| Trigger | Yes / No |
|---|---|
| "Let's plan a new feature for X" | **yes** |
| "I want to add X — what should we do?" | **yes** if X is non-trivial |
| "Fix the bug where Y" | no — bugfix, not new feature |
| "Refactor module Z" | no — refactor, not new feature |
| "Rename foo to bar" | no |
| "Update the readme" | no |
| "Investigate why X breaks" | no — debugging, not building |

The skill is `disable-model-invocation: true` — Claude will not auto-load it. Invoke by name when you genuinely want this shape imposed on the work.

## What this skill is **not**

- Not a substitute for understanding the codebase. The `Explore` phase is mandatory the moment the plan touches anything you haven't read.
- Not a license to over-engineer. Karpathy guideline #2 — simplicity first — still applies. The plan should be the smallest set of phases that gets to the Goal line.
- Not a ceremony. If the user pushes back ("this is a 20-line change, skip the questions") respect that and drop straight to a one-line plan + Goal.
