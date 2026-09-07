---
name: new-feature
description: Plan a green-field feature (plan mode + verify)
disable-model-invocation: false
---

# New-feature playbook

When loaded as context with no task, reply only `Context loaded.`

A green-field feature is the wrong place to start typing. Use this four-step
shape: **plan -> question -> divide -> verify**.

## 1. Plan before writing

In standalone Codex, keep the main thread on `gpt-5.6-sol` at `xhigh`. For a
non-trivial plan, spawn one read-only `planner` agent, pinned by the kit to
`gpt-6-astra` at `max`, and integrate its result in the main thread. This one
planner is pre-authorized by the kit's global model route. After approval,
execute in the Sol main thread. For a trivial plan or when that custom agent is
unavailable, plan read-only in the current thread.

In other clients, use the available native planning mode or work read-only and
produce a draft plan. Do not edit or run mutating commands until the user
approves the implementation plan.

## 2. Ask up to 10 clarifying questions

Explore the real environment first. Then ask only the load-bearing questions
whose answers would change the design, capped at 10. Use the client's
structured question facility when available; otherwise ask one concise
numbered question at a time. A bad question costs the user a click; a missing
question costs them a re-do.

Question topics, in rough order of payoff:

1. **Outcome:** what user or system behavior should exist when this is done?
2. **Scope edges:** what is explicitly out of scope for this iteration?
3. **Surface:** UI, API, CLI, background job, or a mix?
4. **Data model:** new table or column? Mutating an existing one? Soft-delete
   or hard-delete?
5. **Auth and multi-tenancy:** per-user, per-org, or public? Does it cross a
   trust boundary?
6. **Failure mode:** what should happen on partial success, retry, or network
   loss?
7. **Performance envelope:** how many records, how often, and what latency?
8. **Existing patterns:** is there a sibling feature whose conventions should
   be mirrored?
9. **Release path:** feature flag, migration window, or backwards compatibility?
10. **Done-ness:** what concretely makes this shippable?

Skip anything the user already answered. Stop asking as soon as the plan is
decision-complete.

## 3. Divide the work

Build the plan as an ordered list of phases. For each phase, name:

- **Who runs it.** Keep design and integration with the main agent. Assign a
  subagent only when the work has a bounded independent slice that benefits
  from delegation.
- **Which capability.** Use the current client's native collaboration tools
  when delegation is available and authorised. Prompts must be self-contained,
  and model or reasoning overrides require explicit user approval, except for
  the kit-managed planner above. Ask once before any other multi-agent fan-out
  because each agent consumes additional usage.
  Use the matching installed review or UI-probe skill for independent review
  and end-to-end checks rather than assuming a client-specific slash command.
- **Verify check.** Name one observable check that proves the phase is done: a
  test, request, UI state, or log line.

A good plan reads like:

```
1. Explore, main agent, find the existing soft-delete pattern in modules/X
   -> verify: report cites the trait and 2+ call sites

2. Design, main agent, sketch the model and migration, then share the schema diff
   -> verify: user accepts schema

3. Build, main agent, write the migration, model, and one unit test
   -> verify: `yiic migrate --all` and `phpunit tests/unit/.../FooTest.php` both green

4. UI, main agent, wire the form and controller
   -> verify: live click-through reaches the expected success state

5. Review, installed review capability on the working diff
   -> verify: no high-severity findings
```

## 4. End with a verification goal

The plan must close with one line in this form:

> **Goal:** when `<concrete observable thing>` is true, this feature is done.

Re-quote this line after every implementation phase to detect drift.

## When to invoke this skill

| Trigger | Yes / No |
|---|---|
| "Let's plan a new feature for X" | **yes** |
| "I want to add X - what should we do?" | **yes** if X is non-trivial |
| "Fix the bug where Y" | no - bugfix, not new feature |
| "Refactor module Z" | no - refactor, not new feature |
| "Rename foo to bar" | no |
| "Update the readme" | no |
| "Investigate why X breaks" | no - debugging, not building |

Invoke by name when this planning shape is wanted. Do not auto-apply it to
every task.

## What this skill is not

- Not a substitute for understanding the codebase. Exploration is mandatory
  when the plan touches anything you have not read.
- Not a license to over-engineer. Simplicity first still applies.
- Not ceremony. If the user says a change is small and wants fewer questions,
  use the smallest useful plan plus the Goal line.
