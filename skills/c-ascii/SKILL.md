---
name: c-ascii
description: Non-ASCII pitfalls in prose for public or team sharing
---

# Non-ASCII: convert-or-keep pitfalls

Load only when non-ASCII appears in prose intended for public or team sharing:
Jira/Confluence text, kit files, or changed OpenEyes comments, documentation and
user-facing text. Private chat and unrelated source characters do not trigger it.
Use plain hyphens, `...` and basic ASCII for new prose. The exceptions below
preserve content whose characters carry meaning.

## First rule: scope

Never edit non-ASCII in code or text unrelated to the main change. No sweeps, no
drive-by "fixes" - convert only inside lines the task already changes. (If a
deliberate sweep is ever requested: a byte-mode regex character class over
multi-byte chars corrupts every char sharing those bytes - use full-sequence
string substitutions per character and validate UTF-8 afterwards.)

## Never convert

1. Display strings not meant to be read as text - e.g. what
   `~/claude-kit/settings/statusline.sh` renders, and the bar-format lines quoting
   it in docs. Never "fix" that file.
2. Tree/flow diagrams - box-drawing and arrow glyphs ARE the diagram.
3. Verbatim quotes of another program's output - keep byte-exact.
4. Fixtures and assertions - HL7/JSON payloads, expected-output files, exact-match
   test strings. A test comparing the accented original fails once the fixture is
   "fixed".
5. Meaning-carrying symbols in clinical/UI strings - micro sign in micrometre
   units (plain "um" is a different unit string), degree, plus-minus, delta,
   diopter notation. Changing a display label in code changes the app's UI.

## Pitfalls when you do convert

- Proper nouns transliterate lossily, and greps for the original spelling stop
  matching - flag the change in your reply.
- Widening a 1-char glyph to 2+ chars (arrow to `->`) shifts column alignment in
  anything vertically aligned to its right - re-check diagrams and tables.
- Foreign repos have their own typography; follow an explicit house standard over
  this rule, and keep your additions consistent with the file you are in.
