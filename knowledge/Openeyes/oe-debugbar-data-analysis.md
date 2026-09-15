# Parsing Yii debug-bar .data files (2026-07)

Analysing OpenEyes debug toolbar captures (`protected/runtime/debug/*.data`)
programmatically - the only sane route on a heavy page: the /debug Queries tab
renders every statement and a many-thousand-query load kills it. Companion to
`oe-page-benchmarking.md`.

- Query-family keys are built from the first 250 chars of the SQL, so a wide
  SELECT column list truncates before the FROM clause and big-join families
  vanish from keyed/grouped output. Count those by grepping the RAW .data file
  case-insensitively for a distinctive fragment (e.g. "FROM `table` `t` WHERE").
- Each query string appears ~5x in the serialized file (begin:/end: log pairs
  and friends). Divide raw grep counts by the multiplier, and calibrate it once
  per file with a query whose count is known.
- Background pollers (healthCheck etc.) can occupy the newest .data slot.
  Select the file by grepping the patient/URL id across the newest few
  (`grep -l <id> $(ls -t *.data | head -8)`), never by taking the newest mtime.
- History cap is 50 files - harvest immediately after each measured load.
