---
name: c-clarify
description: Re-explain the last response or a given excerpt in very simple words.
disable-model-invocation: false
---

# Clarify

When loaded as context with no task, reply only `Context loaded.`

Re-explain one thing so a junior with a short attention span gets it in one
read. Invocable any number of times per conversation, each time on a fresh
target.

## Target

The argument names what to clarify - a concept, an excerpt, "the query part".
No argument = the last substantive response in this conversation. The target
must already be in the conversation (or pasted with the request); if
clarifying it would mean reading files, repos, or anything sizeable
("/c-clarify the openeyes codebase"), refuse and ask for a narrower target.

## Rules

1. Shorter than the target, and simpler: plain words, short sentences.
2. Swap each technical term for a very simple word, original in brackets -
   "cached (memoised)" - once per term, on first mention.
3. Resolve vague references from conversation context: "the previous index"
   becomes the actual CREATE INDEX statement, shown inline.
4. Numbered points only for a real sequence or list; a comparison becomes a
   small table; otherwise plain prose. Code stays as code, trimmed to the
   lines that matter.
5. At most one everyday analogy, only when it genuinely helps a junior get
   the idea - never more.
6. Re-explain only - no new information, no advice, no next steps.
