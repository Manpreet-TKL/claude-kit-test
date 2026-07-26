# TKL note style - detail and examples

## Titles

- `Category - Subject`, hyphen-space both sides. Category is a concrete tool/system (`MySQL`, `MariaDB`, `SSH`, `Git`, `Linux`, `OpenEyes`, `Mirth`) - if two are equally involved, pick the one a searcher would type first.
- Subject is the phrase a future reader would type; verbs welcome: `Show users read only or not`, `Terminate other peoples SSH connections`, `Making SMB channel compatible for DFS`.
- Disambiguators in parens at the end: `MySQL - Show users read only or not (Not for MariaDB 10.6)`, `OpenEyes - When the client says it is slow (response)`.

## Descriptions

State the situation, nothing else - "If you need to terminate SSH sessions other than your own on a linux machine:". Never "This note explains...".

## Steps

- `1.)`, `2.)` exactly - digit + `.` + `)` + space; sub-items `a.)`, `b.)`. "Stuck on step 4b" must map back unambiguously.
- `0.)` allowed for a prerequisite that isn't really part of the procedure.
- One imperative per step. Predict the next mistake inline at the step (`...(get rid of ProxyCommand if not needed)`), not in a pitfalls block.
- Point the reader's eyes: `top left`, `the URL will change to /patient/summary/26332 (the number at the end is DB patient_id)`.
- Quote UI text/option values verbatim: `Click 'Add PAS Configuration'`. Paste error text verbatim so it's grep-able.

## Command blocks

Each command on its own line, preceded by a `#` comment saying what the command does, so the block runs as a script. The comment never carries a step number:

```
# Add a second key to the machine
ssh-keygen -q -t rsa -b 4096 -C "sysadmin@toukanlabs.com" -N '' -f ~/.ssh/id_rsa2 <<<n && cat ~/.ssh/id_rsa2.pub
# Test you have access to git
ssh -Tv git@github-toukan
```

No `$`/`>` prompts. SQL/config blocks sit on their own lines without a leading `#`. Keep cleanup commands in the note (`# Remove it after done` / `sudo apt remove nethogs && sudo apt autoremove`). Multi-line one-liners are fine if they're a single logical action.

## References

Raw URLs at the bottom, one per line, no markdown. Anything needing more than a sentence lives behind the link.

## Separators and delivery

A `~135`-dash rule separates one note from the next. It only appears when a file holds more than one note - a file with a single note simply ends after its references.

Every drafted note is Written to a file and the absolute path stated; the body is never printed in chat. Put it in the current working directory when that is a sensible home for it, otherwise `/home/toukan/<topic>-note.txt`.

## Other note types

- Canned reply drafts are notes too - `(response)` qualifier in the title, body is the message text.
- `NOTE:` for inline asides (`NOTE: Alternative is to create a generic user like ToukanMachineUser...`).
- Long expository prose is acceptable only for concept notes (e.g. `MariaDB - Error: Aborted connection...`); for procedures, prose is a smell.

## Anti-patterns

- Title without category prefix (`How to terminate SSH sessions`)
- Markdown headings or fenced code blocks; screenshots / "see attached"
- "Latest version", "recently"; paraphrased error messages
- Multiple topics in one note; vague instructions ("configure it appropriately")
- Skipping a note because "I don't have time" - ship a `***Not Finished***` stub instead
