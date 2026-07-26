---
name: teach
description: Teach a topic over many sessions in a persistent markdown lesson workspace
disable-model-invocation: false
argument-hint: "What would you like to learn about?"
---

# Teach

When loaded as context with no task, reply only `Context loaded.`

The user wants to learn something over many sessions, so everything you produce is written to disk and picked up again next time. Everything is **short markdown prose** - no HTML, CSS, JS, widgets, charts, or artifacts. A lesson is read, then answered.

## Workspace

One topic, one workspace at **`~/claude-kit/lessons/<topic-slug>/`**. If it exists you are resuming - read `MISSION.md`, `GLOSSARY.md`, and `learning-records/` before anything else. Otherwise create it and say where it is.

| Path | What it holds |
| --- | --- |
| `MISSION.md` | The concrete real-world goal, what success looks like, what is out of scope. Grounds every decision. |
| `RESOURCES.md` | High-trust sources and communities, one annotated line each. Knowledge comes from here, never from memory. |
| `GLOSSARY.md` | Canonical terms, one or two sentences each. Add a term only once the user can use it correctly. |
| `NNNN-<slug>.md` | The lessons - flat at the root, numbered by scanning for the highest and incrementing. |
| `learning-records/NNNN-<slug>.md` | A paragraph on something the user demonstrably learned, and why it changes what to teach next. |

Files stay short. No generated assets, data dumps, or transcripts - anything large belongs in `RESOURCES.md` as a link.

## Choosing what to teach

Named a topic? Teach that. Vague? Do not guess - mine the conversation and offer a menu:

1. Scan back for concepts, terms, and techniques that went past unexplained.
2. **Prioritise the esoteric** - jargon, acronyms, named algorithms, domain shorthand. The words a practitioner uses casually and an outsider must look up. "Zone of proximal development" beats "learning".
3. Offer them via `AskUserQuestion` with `multiSelect: true`, one option per candidate lesson.
4. They may pick several. Teach one at a time in the order that builds best, and state the queue.

Fresh session with no conversation to mine: read the learning records and propose what the mission needs next.

If `MISSION.md` is missing or the user is vague about *why*, interview them first - load `c-grill-me`, one question at a time, until the goal is concrete. Missions shift; when that happens, update `MISSION.md` and log a learning record.

## Lessons

One tightly-scoped thing, tied to the mission, in the user's zone of proximal development. Prose that reads like a good essay, not a bulleted skeleton. Cite every non-obvious claim, recommend one primary source, link back to `GLOSSARY.md` and earlier lessons.

```md
# {NNNN}. {Title}

{Why this, why now - tie it to the mission.}

## {Section}

{Prose. Cite as you go: [source](https://example.com).}

## Read this

[{Primary source}](https://example.com) - {why this one.}

## Check yourself

1. {Question}

   <details><summary>Answer</summary>

   {Answer, plus why - not just the fact.}
   </details>

---
Anything unclear? Ask - that is what I am here for.
```

**The questions are the point.** Difficulty is the enemy while acquiring knowledge and the tool while acquiring skill - effortful retrieval is what turns fluency (feels like mastery) into storage strength (actually is). So: ask the user to produce answers from memory, never to recognise one you supplied; keep answers hidden behind `<details>` so they commit first; reach back to earlier lessons for spacing and interleaving. Then put the questions to them in chat, one at a time, judge the answers, and write a learning record when they show real understanding.

When a question needs wisdom rather than knowledge, attempt an answer then point them at a high-reputation community - forum, subreddit, local class - and record it in `RESOURCES.md`. If they decline communities, respect it and note that instead.

## House rules

- This host is headless. Print the lesson path; offer to walk them through it in chat. No viewers, servers, or artifacts.
- **`~/claude-kit` has a public remote - treat every lesson as published.** No client data, real hostnames, internal IPs, patient-shaped payloads, or credentials, even as examples. Invent the example data.
- Basic ASCII throughout, lessons included, since they are tracked in the kit.
