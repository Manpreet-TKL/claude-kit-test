---
name: c-yiic-command-style
description: House style for OpenEyes yiic console commands
disable-model-invocation: true
---

# yiic command style

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

For `*Command.php` files in `commands/` (the `commands:/extra_commands` bind-mount on web/oe-manager - drop-in, no image rebuild; canonical home `ace/commands/`). Match `MirthCommand.php` / `DBReportsCommand.php`; don't copy the older `DBACommand.php`. **Read `subs/reference.md` before authoring** - verbatim AGPL header, help heredoc, banners, output snippets, `getMcDbConnection()`.

## Skeleton (top -> bottom)

1. OpenEyes AGPL header (verbatim) + `Created by Manpreet Singh <manpreet.singh@toukanlabs.com>.` tag
2. `class <Name>Command extends CConsoleCommand` in `<Name>Command.php`; CLI handle is the lowercased prefix (`MirthCommand` -> `yiic mirth`)
3. Optional `public static $...` lookup arrays under a SCHEMA DESCRIPTIONS banner
4. `getName()` - one sentence
5. `getHelp()` - heredoc: dash rulers, `USAGE:`, aligned action list, `Examples:` block
6. HELPER FUNCTIONS banner -> static helpers (connections, shared utils)
7. ACTIONS banner -> `action<Pascal>()` methods

Banners are PHPDoc boxes of `*` rows. `actionIndex()` prints `$this->getHelp()` - or validates top-level flags and falls back to help on missing required args.

## Rules

- Action params = CLI flags (`--limit=5000`); always give defaults, `null` meaning "not supplied". PHPDoc every non-trivial action with a numbered workflow + `@param` lines; in-action step comments `/* ----- N. step ----- */`.
- DB: `Yii::app()->db->createCommand($sql)` with `->bindValues()` - never interpolate user input. Non-default DBs get a static connection helper; password from `/run/secrets/<NAME>` first, env fallback, else exit with an error.
- Output: timestamped progress lines, per-item `[DONE]`, `str_pad` tables, CSVs named with `date('Ymd_His')`, red ANSI `Error:` + nonzero exit.
- Prompts: `trim(fgets(STDIN))`, validate immediately, print the reason, `return`.
- No namespaces / Composer - bare Yii 1.x class names. Output artifacts to the working dir or an explicit `--filePath=`.
