---
name: c-yiic-command-style
description: House style for OpenEyes yiic console commands
disable-model-invocation: false
---

# yiic command style

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

For `*Command.php` files in `commands/` (the `commands:/extra_commands` bind-mount on web/oe-manager - drop-in, no image rebuild; canonical home `ace/commands/`). Match `MirthCommand.php` / `DBReportsCommand.php`; don't copy the older `DBACommand.php`. **Read `subs/reference.md` before authoring** - verbatim AGPL header, help heredoc, banners, output snippets, `getMcDbConnection()`.

## Skeleton (top -> bottom)

1. Licence header (verbatim) + `Created by Manpreet Singh <manpreet.singh@toukanlabs.com>.` tag - the OpenEyes AGPL block for the public codebase, the proprietary Toukan Labs 2026 block (all rights reserved, explicitly not AGPL) for private TKL-only commands. Both in `subs/reference.md`; ask which when it isn't obvious.
2. `class <Name>Command extends CConsoleCommand` in `<Name>Command.php`; CLI handle is the lowercased prefix (`MirthCommand` -> `yiic mirth`)
3. Optional `public static $...` lookup arrays under a SCHEMA DESCRIPTIONS banner
4. `getName()` - one sentence
5. `getHelp()` - heredoc: dash rulers, `USAGE:`, aligned action list, `Examples:` block
6. HELPER FUNCTIONS banner -> **every** non-action method (connections, shared utils, per-action workers, framework overrides like `missingAction()`)
7. ACTIONS banner -> `action<Pascal>()` methods, and nothing else, to the closing brace of the class

Banners are PHPDoc boxes of `*` rows. `actionIndex()` prints `$this->getHelp()` - or validates top-level flags and falls back to help on missing required args.

**The ACTIONS block is the last thing in the class and holds only actions.** A helper written for exactly one action still belongs above the banner, however natural it feels to park it next to its caller - the point of the block is that `yiic <cmd> <action>` maps to a contiguous, skimmable list at the bottom of the file. Check this before declaring a command finished: below the banner, every `function` should be an `action*`.

## Rules

- Action params = CLI flags (`--limit=5000`); always give defaults, `null` meaning "not supplied". PHPDoc every non-trivial action with a numbered workflow + `@param` lines; in-action step comments `/* ----- N. step ----- */`.
- **Every method carries a PHPDoc header - no exceptions, actions and helpers alike.** A one-liner `/** ... */` is enough for something trivial (`/** @return string ... */`, `/** Print a timestamped progress line. */`); anything with real parameters gets `@param`/`@return` lines. `//` above a signature is not a header - convert it. Rationale on *why* a method exists this way goes on the method it explains, not on its neighbour.
- DB: `Yii::app()->db->createCommand($sql)` with `->bindValues()` - never interpolate user input. Non-default DBs get a static connection helper; password from `/run/secrets/<NAME>` first, env fallback, else exit with an error.
- Output: timestamped progress lines, per-item `[DONE]`, `str_pad` tables, CSVs named with `date('Ymd_His')`, red ANSI `Error:` + nonzero exit.
- Output formatting is consistent across the whole command. Declare each table's column widths once as variables at the top of the action and reuse them for the header, the rule and every row - never hand-space or mix tabs and spaces, and never let two actions print the same data at different widths. Spaces only, `str_pad` only; a value longer than its column gets truncated with an ellipsis rather than pushing the row out of alignment. Same rule for label/value output: one padding width per block so the values line up.
- Prompts: `trim(fgets(STDIN))`, validate immediately, print the reason, `return`.
- No namespaces / Composer - bare Yii 1.x class names. Output artifacts to the working dir or an explicit `--filePath=`.
