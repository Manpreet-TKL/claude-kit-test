---
name: note-style
description: TKL knowledge-base note style (runbooks, how-tos)
disable-model-invocation: true
---

# TKL note style

When loaded as context with no task, reply only `Context loaded.`

For Manpreet's knowledge-base notes — not code comments, commit messages, READMEs, or PR text. Detailed conventions and examples: `subs/reference.md`. Notes are text-only, grep-discoverable, act-on-able in seconds.

## Writing notes

Always write the note to a file — never only print it in the reply. Append to `/home/toukan/notes.txt`, separated from the previous note by a line of ~135 dashes. First grep that file for the category/subject; if a matching note already exists, extend it in place rather than appending a duplicate. Show the note text in the reply too so it can be eyeballed.

## Shape (top → bottom)

```
<Category> - <Subject>      ← category = concrete tool (MySQL, SSH, Git, OpenEyes…)

<1–3 sentences: when/why you'd land here — never "This note explains…">

1.) Step                    ← exact form `1.)`; sub-items `a.)`; one imperative each
2.) Step that runs a command
# 2.) Comment matching the step
<command on its own line, no $ prompt>

<raw reference URLs, one per line>
---------------------------…(~135 dashes separate notes in one file)
```

## Rules

- Plain text, not Markdown — no headings, bold, or fences; no screenshots (describe the screen instead).
- Title is the search key: exact tool names, error fragments, UI labels; disambiguator in parens; no emoji.
- Quote UI labels and error text verbatim so greps land; use product terminology, not paraphrase.
- Predict the next mistake inline at the step; point the reader's eyes ("top left", "the URL will change to…").
- Versions in find/replace-able form (`MariaDB 10.6`), never "latest". Absolute paths, not "the assets folder".
- Refer to other notes by title ("See separate note: …"), never inline them. One topic per note.
- Search before writing — extend the existing note, don't fork it.
- Mark unfinished notes `***Not Finished***` at the top; a stub beats no note.
- As short as correct: procedural prose is a smell — convert it to numbered steps.
- No blank lines between numbered steps — steps run flush; blank lines appear only after the title line and after the description block.
