---
name: note-style
description: Apply Manpreet's "TKL" knowledge-base note style when drafting, rewriting, or adding to his personal notes / runbooks / how-to entries. A TKL note is a short text-only entry with a `Category - Subject` title, a plain-English description, numbered steps, and commands on their own lines so a reader can act in seconds. Trigger when the user says things like "write me a note for", "draft a TKL note", "add this to my notes", "turn this into a runbook entry", or pastes notes_sample.txt-style content asking for additions/edits. Skip for source code comments, commit messages, project README/design docs, or PR descriptions — those are not knowledge-base notes.
---

# TKL note style

Manpreet's knowledge-base notes are **text-only, discoverable, and act-on-able in seconds**. Optimise for "future Manpreet (or a teammate) finds this via search, reads it once, runs the commands, done." See `/home/toukan/notes_sample.txt` for canonical examples.

## Note shape (top → bottom)

```
<Category> - <Subject>           ← title, no trailing period
                                 ← blank line
<Short plain-English description, 1–3 sentences>
                                 ← blank line
1.) First step
2.) Second step
    a.) Sub-step
    b.) Sub-step
3.) Step that runs a command
# 3.) Comment matching the step
<the actual command on its own line>
…
<Reference URLs at the bottom, one per line>
---------------------------------------------------------------------------------------------
```

Notes are separated by a long row of dashes (`---…`, ~135 chars). When writing more than one in the same file, insert that separator between them.

## Title

- **Format**: `Category - Subject`. Hyphen-space on both sides.
- **Category is a concrete tool/system**, not a topic. Examples from the corpus: `MySQL`, `MariaDB`, `SSH`, `Git`, `Linux`, `OpenEyes`, `Mirth`. If two systems are equally involved, pick the one a searcher would type first.
- **Subject is the searchable phrase** — a fragment a future reader would type. Verbs welcome (`Show users read only or not`, `Terminate other peoples SSH connections`, `Making SMB channel compatible for DFS`).
- **Disambiguators in parens at the end** when the same subject could mean two things or when version/scope matters: `MySQL - Show users read only or not (Not for MariaDB 10.6)`, `MariaDB - Error: Aborted connection (Got timeout reading communication packets)`, `OpenEyes - When the client says it is slow (response)`.
- **No emoji, no punctuation flourishes**. Letters/numbers/parens/hyphens only.

## Description

One short paragraph in **very simple English** stating *when* and *why* a reader would land on this note. Imagine the reader is mid-incident and needs to confirm in one sentence "yes, this is the note I want."

```
If you need to terminate SSH sessions other than your own on a linux machine:
```

```
These are checks you can do if lightening images (previews on left at patient summary) are not loading.
```

Do **not** start with "This note explains…" / "In this article we…". Just state the situation.

## Steps

- **Number every action: `1.)`, `2.)`, `3.)`** — exact form, digit + `.` + `)` + space. Sub-items: `a.)`, `b.)`, `c.)`. A reader sharing "I'm stuck on step 4b" must map unambiguously back to this note.
- **Step zero** is allowed when there's a prerequisite that isn't really part of the procedure (`0.) Send client standard response to find what is slow`).
- **One imperative per step.** Don't pack two actions into one number.
- **Predict the next mistake** at the point it happens, not in a "common pitfalls" block at the bottom: `…(get rid of ProxyCommand if not needed)`, `…(do not delete /var/www/openeyes/assets/vue folder)`.
- **Point the reader's eyes**: `top left`, `the URL will change to /patient/summary/26332 (the number at the end is DB patient_id)`. Don't make them hunt.
- **Quote UI text and option values verbatim**: `Click 'Add PAS Configuration'`, `For 'Update Rule' we almost want it to 'Update All' demographics`.
- **Paste error text verbatim** so it's grep-able: `"Key is already in use"`, `2025-02-07 9:22:31 8797769 [Warning] Aborted connection 8797769 to db: 'openeyes' …`.

## Commands

Each command lives on **its own line**, preceded by a `#`-prefixed comment that matches the step number — so the whole command block can be copy-pasted and run as a script by someone who's read the note before.

```
# 1.) Add a second key to the machine
ssh-keygen -q -t rsa -b 4096 -C "sysadmin@toukanlabs.com" -N '' -f ~/.ssh/id_rsa2 <<<n && cat ~/.ssh/id_rsa2.pub
# 2.) Create a config entry (in ~/.ssh/config) for clone of second repo to use id_rsa2
…
# 3.) Test you have access to git
ssh -Tv git@github-toukan
```

- **No `$` / `>` prompts.** Just the command.
- **SQL / config blocks** sit on their own lines too, without a leading `#`. They're already visually distinct.
- **Inline cleanup commands** after the install are part of the note, not omitted — keep machines tidy:
  ```
  # 4.) Remove it after done
  sudo apt remove nethogs && sudo apt autoremove
  ```
- **Multi-line one-liners are fine** if they're a single logical action (e.g. the `for i in {0..255}; do …` block).

## References

Put external links at the **bottom** of the note, one per line, no markdown wrapping — just the raw URL. Anything that needs more than a sentence of explanation lives behind the link (don't quote the linked doc inline).

```
https://github.com/ToukanLabs/scripts/pull/14
https://keepersecurity.com/vault/#detail/_e9W1ZCisnrFSG_eKLaxAg
```

If the procedure refers to a longer Word/Confluence doc, paste the link and keep this text note short and findable.

## Future-proofing

- **Write versions in find/replace-able form**: `Mirth 4.5.2`, `MariaDB 10.6`, `Python 3.13`. Never "latest" or "current". When the version bumps, a global find/replace updates every note that mentions it.
- **Use absolute paths** where they help searchability (`/var/www/openeyes/assets/`, `~/.ssh/config`). Don't write "the assets folder" if you mean a specific path.
- **Refer to other notes by their title**, don't inline them. *"See separate note: SSH - Connect to MEH machines"* is right; copy-pasting that procedure into this note is wrong.
- **Mark unfinished notes** with `***Not Finished***` at the top so a reader knows to stop. Better to ship a stub than skip the note entirely.

## Discoverability

The note must be findable by `grep -ri <thing>` in under 5 seconds. To make that real:

- **Pack the title with keywords** a future searcher would type — exact tool names, exact error fragments, exact UI labels.
- **Quote exact error strings** in the body so log greps land on this note.
- **Use the same terminology as the product** (`worklist page`, `event image`, `PAS Configuration`) not paraphrases.
- **Search before writing**. If the topic already has a note, extend that one — don't fork it.

## Format conventions cheatsheet

- **Text only.** No screenshots. If a UI is involved, describe what's on the screen ("there is a green button labelled 'Add PAS Configuration' top right under the page header"), don't link to an image.
- **Plain text, not Markdown.** No `#` headings, no `**bold**`, no backtick fences. The notes live in flat text files (e.g. `notes_sample.txt`) and must read identically in a pager, in `grep` output, and in Confluence.
- **NOTE:** inline asides for alternatives (`NOTE: Alternative is to create a generic user like ToukanMachineUser…`).
- **One topic per note.** If something is genuinely two procedures, write two notes and link by title.
- **Notes can also be canned reply drafts** (e.g. `OpenEyes - When the client says it is slow (response)`). Title still follows the same format; the body *is* the email/message text. The `(response)` qualifier in the title flags the kind of note it is.

## Length

As short as it can be while still being correct. Long expository paragraphs are acceptable **only when the note is explaining a concept** (e.g. `MariaDB - Error: Aborted connection …` walks through what the warning means and lists every relevant variable). For procedural notes, prose is a smell — convert it to numbered steps.

## Anti-patterns

- ❌ Title without category prefix (`How to terminate SSH sessions`)
- ❌ Markdown headings or fenced code blocks
- ❌ Screenshots / images / "see attached"
- ❌ "Latest version", "newest release", "recently"
- ❌ Multiple topics combined ("SSH + Git + Network" in one note)
- ❌ Paraphrased error messages ("you'll see a key error")
- ❌ Skipping a note because "I don't have time"
- ❌ Vague instructions ("configure it appropriately", "set the right value")
