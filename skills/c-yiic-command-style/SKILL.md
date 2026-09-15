---
name: c-yiic-command-style
description: House style for OpenEyes yiic console commands
disable-model-invocation: false
---

# yiic command style

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

For `*Command.php` files in `commands/` (the `commands:/extra_commands` bind-mount on web/oe-manager - drop-in, no image rebuild; canonical home `ace/commands/`). Match `MirthCommand.php` / `DBReportsCommand.php`; don't copy the older `DBACommand.php`. **Read `subs/reference.md` before authoring** - verbatim AGPL header, help heredoc, banners, output snippets, `getMcDbConnection()`.

## Skeleton (top -> bottom)

1. Licence header (verbatim) + `Created by Manpreet Singh <manpreet.singh@toukanlabs.com>.` tag and a brief description of the command's purpose in the same class header - the OpenEyes AGPL block for the public codebase, the proprietary Toukan Labs 2026 block (all rights reserved, explicitly not AGPL) for private TKL-only commands. Both in `subs/reference.md`; ask which when it isn't obvious.
2. `class <Name>Command extends CConsoleCommand` in `<Name>Command.php`; CLI handle is the lowercased prefix (`MirthCommand` -> `yiic mirth`)
3. Optional `public static $...` lookup arrays under a SCHEMA DESCRIPTIONS banner
4. `getName()` - one sentence
5. `getHelp()` - heredoc with dash rulers, `USAGE:`, aligned actions and examples or common uses. If full help would exceed 50 output lines, make `getHelp()` short (at most 50 lines): list actions and common uses with very brief explanations, or just the main uses when the action list is too large. End by pointing to full help through `--longHelp=1`. Put informative flag details and conspicuous `WARNING` blocks in a separate full-help method.
6. FUNCTIONS banner -> **every** non-action method (connections, shared utils, per-action workers, framework overrides like `run()` and `missingAction()`, and full-help methods)
7. ACTIONS banner -> `action<Pascal>()` methods, and nothing else, to the closing brace of the class

Banners are PHPDoc boxes of `*` rows. Yii's `CConsoleCommand::run()` selects `actionIndex()` when no action is given. Running the command without arguments prints short help and exits successfully; an overridden `run()` must delegate that call to `parent::run()` so Index remains the default. `actionIndex()` prints `$this->getHelp()` by default and accepts `--longHelp=1` when full help exists. For a potentially dangerous action, require both its explicit action name and at least one supplied flag. The action name alone prints short help and returns nonzero. Do not route flag-only invocations to a dangerous action; `--longHelp=1` without an action still reaches Index.

**The ACTIONS block is the last thing in the class and holds only actions.** A helper written for exactly one action still belongs above the banner, however natural it feels to park it next to its caller - the point of the block is that `yiic <cmd> <action>` maps to a contiguous, skimmable list at the bottom of the file. Check this before declaring a command finished: below the banner, every `function` should be an `action*`.

## Rules

- Action params = CLI flags (`--limit=5000`); always give defaults, `null` meaning "not supplied". Yii 1.1 matches option names to action parameter names exactly and case-sensitively, so document the action and preserve the spelling. PHPDoc every non-trivial action with a numbered workflow + `@param` lines; in-action step comments `/* ----- N. step ----- */`.
- **Every method carries an expanded, multi-line PHPDoc header - no exceptions, actions and helpers alike.** Never collapse a method header to `/** ... */` on one line, even for a trivial method. Put the summary on its own `*` line, use a blank `*` line before tags, and include `@param`/`@return` tags where applicable. `//` above a signature is not a header - convert it. Rationale on *why* a method exists this way goes on the method it explains, not on its neighbour.
- DB: `Yii::app()->db->createCommand($sql)` with `->bindValues()` - never interpolate user input. Non-default DBs get a static connection helper; password from `/run/secrets/<NAME>` first, env fallback, else exit with an error.
- Output: timestamped progress lines, per-item `[DONE]`, `str_pad` tables, CSVs named with `date('Ymd_His')`, red ANSI `Error:` + nonzero exit. Help text is echoed with one blank newline before and after it so it is separated from surrounding output.
- Output formatting is consistent across the whole command. Declare each table's column widths once as variables at the top of the action and reuse them for the header, the rule and every row - never hand-space or mix tabs and spaces, and never let two actions print the same data at different widths. Spaces only, `str_pad` only; a value longer than its column gets truncated with an ellipsis rather than pushing the row out of alignment. Same rule for label/value output: one padding width per block so the values line up.
- Prompts: `trim(fgets(STDIN))`, validate immediately, print the reason, `return`.
- No namespaces / Composer - bare Yii 1.x class names. Output artifacts to the working dir or an explicit `--filePath=`.
