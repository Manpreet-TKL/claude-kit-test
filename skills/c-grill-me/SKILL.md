---
name: c-grill-me
description: Relentless one-question-at-a-time interview until shared understanding.
disable-model-invocation: false
---

# Grill me

When loaded as context with no task, reply only `Context loaded.`

Interview the user relentlessly about every aspect of the task, plan, or idea
on the table until you reach a shared understanding. Reworked from
mattpocock/skills `grilling` (MIT, (c) 2026 Matt Pocock).

## How

- Walk down each branch of the decision tree, resolving dependencies between
  decisions one by one - settle the decisions later ones hang on first.
- Ask ONE question at a time and wait for the answer before continuing. Asking
  multiple questions at once is bewildering. Use AskUserQuestion and make your
  recommended answer the first option, labelled `(Recommended)`.
- If a fact can be found by exploring the environment (filesystem, git, tools),
  look it up rather than asking. The decisions, though, are the user's - put
  each one to them and wait for the answer.
- Do not act until the user confirms you have reached a shared understanding.
- Close with a numbered summary of every agreed decision, then stop - the next
  instruction decides what happens with it.
