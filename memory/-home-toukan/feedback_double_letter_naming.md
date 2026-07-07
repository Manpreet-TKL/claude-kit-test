---
name: feedback-double-letter-naming
description: "When naming a shell alias/function, double the last letter if the chosen name is an English word or an existing Unix command — `helpp`, `searchh`, `loadd`, `chmodd`, `pss`, `dff`, `apt-gett`, `versionss`. Leave compound/coined names alone."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a3ebd97-a1e1-42c9-84f6-46c2a5905f2c
---

When inventing names for new aliases / shell functions, double the **final
letter** of the bare name if that name collides with an English word *or* an
existing Unix command. Leave coined / compound / abbreviation names alone.

**Why:** the trailing-letter pattern is how Manpreet disambiguates "my
custom shortcut" from the built-in command of the same name (and lets him
shadow built-ins safely). Asked explicitly: "whenever an english
word/existing command is used then I repeat the last letter".

**How to apply:** check whether the proposed name is a word in the dictionary
or `command -v <name>` would resolve to something in `PATH`. If yes, double
the last letter; if no, leave it.

Reference precedents in `~/.bash_aliases` / `oe-shortcuts.sh`:

| Trigger | Result | Why |
| --- | --- | --- |
| `help` (word) | `helpp` | English word |
| `search` (word) | `searchh` | English word |
| `count` (word) | `countt` | English word |
| `bytes` (word) | `bytess` | English word |
| `load` (word) | `loadd` | English word |
| `ports` (word) | `portss` | English word |
| `version` (word) | `versionss` | English word — caught after I shipped `versions` once |
| `ps` (cmd) | `pss` | shell command |
| `df` (cmd) | `dff` | shell command |
| `watch` (cmd) | `watchh` | shell command |
| `chmod` (cmd) | `chmodd` | shell command |
| `chown` (cmd) | `chownn` | shell command |
| `apt-get` (cmd) | `apt-gett` | shell command |
| `glogs`, `oepatient`, `swapprocs`, `phperrors` | unchanged | coined / compound, not a word or cmd |
| `dba`, `dbm`, `dbsize`, `dblogin`, `dbwarm` | unchanged | abbreviations |

Edge cases:

- Compounds where the **whole** string is neither a word nor a command stay
  single-letter even if the trailing token *is* a word (`phperrors`,
  `oeerrors`, `oemodules`, `swapprocs`). The rule is on the full name, not
  the suffix.
- Prefixed wrappers (`oeanalyze`, `oeoptimize`) follow the same compound
  logic — left alone.

See also [[feedback-house-style-as-skills]].
