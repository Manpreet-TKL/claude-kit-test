---
name: teach
description: Teach a topic over many sessions in a persistent lesson workspace
disable-model-invocation: true
argument-hint: "What would you like to learn about?"
---

# Teach

When loaded as context with no task, reply only `Context loaded.`

The user has asked to be taught something. This is a **stateful** request: they intend to learn the topic over many sessions, so everything you produce is written to disk and picked up again next time.

## The workspace

One topic, one workspace, rooted at **`~/teach/<topic-slug>/`** - never the current directory, and never inside a git repo you are working in. If the cwd already contains a `MISSION.md` you are resuming that workspace; otherwise create `~/teach/<topic-slug>/` and say where it is. On the first turn of a resumed workspace, read `MISSION.md`, `NOTES.md`, and the learning records before doing anything else.

| Path | What it holds |
| --- | --- |
| `MISSION.md` | Why the user wants this. Grounds every teaching decision. Format: `subs/mission-format.md` |
| `RESOURCES.md` | Curated high-trust sources + communities. Format: `subs/resources-format.md` |
| `GLOSSARY.md` | Canonical language for the topic. Format: `subs/glossary-format.md` |
| `NOTES.md` | Scratchpad for user preferences and working notes |
| `lessons/NNNN-<slug>.html` | The lessons themselves - the primary unit of teaching |
| `reference/*.html` | Compressed, print-friendly reference documents - cheat sheets, algorithms, sequences |
| `learning-records/NNNN-<slug>.md` | What the user has actually learned. Format: `subs/learning-record-format.md` |
| `assets/*` | Reusable components shared across lessons - stylesheet first |

Create directories lazily, only when the first file lands in them. Numbering: scan the directory for the highest number and increment.

## Philosophy

Deep learning needs three things:

1. **Knowledge**, captured from high-quality, high-trust resources.
2. **Skills**, acquired through highly-relevant interactive lessons you devise from that knowledge.
3. **Wisdom**, which comes from interacting with other learners and practitioners.

Until `RESOURCES.md` is well-populated, your focus is finding high-quality resources. **Never trust your parametric knowledge** - search, read, cite. Some topics lean knowledge-heavy (theoretical physics), others skills-heavy (yoga).

Split your design between two kinds of learning: **fluency strength** (in-the-moment retrieval) and **storage strength** (long-term retention). Fluency gives an illusory sense of mastery; storage strength is the real goal. Build it with desirable difficulty - retrieval practice (recall from memory), spacing (practice distributed over time), and interleaving (mixing related topics, for skills practice only).

## Lessons

A lesson is one self-contained HTML file in `lessons/`, teaching one tightly-scoped thing tied to the mission.

- **Short and quickly completable.** Working memory is small. One tangible win per lesson, in the user's zone of proximal development.
- **Beautiful.** Clean typography and layout - the user returns to these. Think Tufte. Load `c-frontend-design` before authoring; `dataviz` if the lesson carries charts.
- **Linked.** HTML anchors to other lessons and to reference documents.
- **Cited.** Littered with links to external sources backing every claim. Recommend one primary source per lesson to read or watch - the highest-trust thing you found.
- **Conversational.** Each lesson closes with a reminder to ask the agent followup questions; you are the teacher and can unpick anything unclear.

Tell the user the path when a lesson is written - see [Viewing lessons](#viewing-lessons).

## Assets

Lessons are built from reusable components in `assets/`: stylesheets, quiz widgets, simulators, diagram helpers - anything a second lesson could reuse.

Reuse is the default, not the exception. Read `assets/` before authoring a lesson and build from what is there. When a lesson needs something new and reusable, write it as a component and link to it; never inline code that a future lesson would duplicate. The shared stylesheet is the first component every workspace earns - it makes the lessons read as one course rather than a pile of one-offs.

## The mission

Every lesson ties back to the mission - the reason the user cares about the topic.

If `MISSION.md` is missing or the user is vague about why, **your first job is to interview them**. Load `c-grill-me` for that: one question at a time until the real-world goal is concrete. Failing to understand the mission means knowledge is ungrounded, lessons feel abstract, and you have no basis for judging what comes next.

Missions change as skills develop. That is normal - confirm with the user, update `MISSION.md`, and add a learning record capturing the shift.

## Zone of proximal development

Each lesson should feel like being challenged just enough. If the user names an exact thing they want to learn, teach that. Otherwise: read the learning records, work out what the mission needs next, and teach the most relevant thing that fits.

## Knowledge and skills

**Knowledge acquisition: difficulty is the enemy.** It eats the working memory needed for understanding. Teach only the knowledge the target skill requires, drawn from `RESOURCES.md`, not from memory.

**Skill acquisition: difficulty is the tool.** Effortful retrieval is what builds storage strength. Teach knowledge first, then drive practice through a **feedback loop** that is as tight as possible - immediate, and ideally automatic:

- Interactive lessons with quizzes and light in-browser tasks.
- Lessons guiding the user through real-world steps to take (yoga poses, drills, exercises).

For quizzes, every answer gets the same number of words, and the same number of characters where possible. Formatting must give away nothing.

## Wisdom

Wisdom comes from testing skills outside the learning environment. When a question needs wisdom, attempt an answer but ultimately delegate to a **community** - a forum, a subreddit, a real-world class, a local group - where the user can test their skills for real. Find high-reputation ones. If the user says they do not want to join a community, respect it and record that in `RESOURCES.md`.

## Reference documents

Lessons are rarely revisited; reference documents are. Each one is the compressed essence of a lesson, in a format built for quick lookup: syntax and snippets for programming, algorithms and flowcharts for processes, poses and sequences for yoga, routines for fitness, glossaries for anything with its own nomenclature.

`GLOSSARY.md` in particular is essential. Once it exists, every lesson adheres to it.

## Viewing lessons

This host is headless - no browser, no `xdg-open`, no display - and nothing gets installed to change that. Do not try to launch a viewer. Instead:

1. Print the absolute path of the new lesson so the user can open it however they like.
2. Offer a local server when they want to browse the workspace: `python3 -m http.server 8800 --directory ~/teach/<topic-slug>` (python3 is already present; nothing to install).
3. For a single lesson the user wants to read right now, publishing it with the Artifact tool is an option - the files on disk stay the source of truth, since artifacts cannot cross-link to each other.

## House rules that apply here

- Workspaces live under `~/teach/`, outside `~/claude-kit` and outside any repo. Never write lesson material into a working tree.
- No client data, real hostnames, internal IPs, or patient-shaped payloads in lessons, even as examples - invent the example data.
- Lesson HTML is the user's document, so normal typography is fine inside it. Chat prose stays basic ASCII per the global rules.
