# Probe discipline: when a check returns nothing, suspect the check (2026-07)

A "probe" here is any throwaway command run to settle a question of fact - a
`grep -c`, a row count, a `docker exec ... | wc -l`. They are cheap, which is
exactly why they get trusted without inspection, and a probe that is silently
wrong is worse than no probe at all: it launders a guess into a stated fact, and
everything built on it inherits the error without inheriting the doubt.

This file exists because the same failure has now happened at least six times
across unrelated tasks. The shape is always identical.

## The shape

1. A question has an expected answer ("this table should be in the list").
2. A one-line probe returns **zero / empty / no match**.
3. The zero is read as the *answer* ("it is not in the list") rather than as
   *ambiguous* ("either it is absent, or my probe cannot see it").
4. A conclusion gets stated, sometimes acted on.

Step 3 is the whole bug. **Zero from a probe is two hypotheses, not one.**

## The instances

| What was probed | What went wrong |
|---|---|
| Is table `$p` in `the102.txt`? | `grep -c " $p$"` assumed space-separated fields. Zero. |
| Same question, "corrected" | `grep -cP "\t\Q$p\E$"` assumed tab-separated. Zero again - two confident wrong answers in a row. |
| Settled it | `od -c` showed the file *was* space-separated; the real cause was elsewhere entirely (an upstream filter had dropped category `A`). |
| Which migration creates `ophciexamination_areaofcare_type`? | `grep -e "createOETable(.\{0,3\}$t"` is line-based; the call has a newline between `(` and the quote. Reported "no creator" for a table that has one. |
| Does OE's own cleardown clear table `t`? | Extracted table names from SQL ignoring the `WHERE` clause, so scoped row surgery read as a whole-table clear. Produced eight false accusations against the keep list; three survived a statement-by-statement reparse. |
| Assorted | stderr swallowed by a pipe, so a command that failed outright looked like a command that found nothing. |

## Rules

1. **Never conclude from a negative probe alone.** A zero result earns one more
   command - not a sentence. Two independent probes that disagree are a signal to
   go look at the bytes, not to average them.
2. **Positive-control every probe.** Run it against a value that MUST match. If
   the control also returns zero, the probe is broken, not the data. This is one
   extra command and it catches every instance in the table above.
3. **Look at the raw bytes before assuming a delimiter.** `od -c | head`, or
   `head -n2 | cat -A`. Guessing tab-vs-space twice in a row cost more than
   looking once would have.
4. **Match the tool to the shape of the data.** Line-oriented tools (`grep`,
   `sed`, `awk`) cannot see across newlines; source code, SQL and JSON routinely
   put the interesting thing on the next line. Reach for slurp mode (`perl -0777`)
   or a real parser when the pattern could straddle a line break.
5. **Extracting a name is not extracting the semantics.** `DELETE FROM t` and
   `DELETE FROM t WHERE id IN (...)` mention the same table and mean opposite
   things. If the qualifier changes the answer, the probe has to parse it.
6. **Never let stderr vanish.** `2>&1` or an explicit exit-code check. "No output"
   and "it crashed" must never look the same.
7. **Say which hypothesis you have ruled out.** Writing "no match, and the
   positive control matched, so it is genuinely absent" takes one clause and makes
   the claim auditable. Writing "it is not there" does not.

## The other half: a positive result from a loose pattern

Everything above is about a probe that wrongly returns nothing. The mirror failure
is a probe that wrongly returns *something*, and it is harder to catch, because a
positive result never prompts anyone to re-read the regex. Three landed in one
afternoon on the same task, all found by a second reader rather than by the author:

| What was probed | Why the positive was wrong |
|---|---|
| Does a migration insert literal rows? | The pattern tested for `[` followed by a quote. That matches the quoted **key** of `['element_id' => $item->id]`, so every backfill that named its columns scored as a shipped seed. Four tables came out "keep this whole table" when they hold one row per existing patient record. |
| Is this table read by literal name? | Only `findByAttributes(['name' => 'x'])` was matched. `find('name = "CREATED"')` means the same thing and was invisible - and the two spellings sit in the same codebase. |
| Does an admin screen manage this table? | The path test wanted `Admin` as a whole path segment, so an entire `ExaminationAdmin/` sub-module scored zero, and CRUD wired up through a `use AdminFor...` trait or a `genericAdmin(...)` call never names its table at all. |

The generalisation: **a pattern proves what it matches, not what you meant.** Before
trusting a classifier that scores hundreds of items, take the ten it scored most
confidently and read the underlying text for each. If the sample is clean the
pattern is probably sound; if one is wrong the count is meaningless, because you
have no idea how many others share the defect.

Corollary, and the reason this one bites hardest: **when the classifier's output
feeds a keep-or-delete decision, its false positives are not symmetric with its
false negatives.** Score the loose direction toward the recoverable outcome.

## Dynamic SQL is invisible to a SQL parser

A related and much larger miss on the same task. A statement-by-statement parse of
some SQL scripts reported which tables they touched, and it was accurate for every
statement it could see. It reported nothing for ~440 tables because four of the
scripts do not name their tables at all:

```sql
DECLARE cur1 CURSOR FOR SELECT TABLE_NAME FROM information_schema.tables
  WHERE table_schema = DATABASE() AND TABLE_NAME LIKE CONCAT('et_', et_type, '%');
...
SET @full_query = CONCAT('DELETE FROM ', tn);
PREPARE stmt FROM @full_query; EXECUTE stmt;
```

Nothing textual connects `CALL CLEAN_ETDATA("ophciexamination")` to the 90 tables it
empties. The parser was not wrong; it was answering a different question than the
one being asked of it, and the silence read as "upstream says nothing about this
table" when upstream deletes it outright.

Whenever a corpus of SQL, shell or config is being mined for "what does this touch",
grep it first for `PREPARE`, `EXECUTE IMMEDIATE`, `eval`, `CONCAT(... TABLE_NAME`,
`information_schema` and `GROUP_CONCAT`. Each one is a place where the names are
computed at run time and a static reader will report a confident, quiet nothing.
Expand the pattern against the real object list and record the expansion, so the
derived facts say which ones were literal and which were swept.

## Related

`knowledge/oe-cleardown-versions.md` section 9 ("Trust a probe only after proving
it can return a positive") is the same rule discovered independently while
instrumenting a live suite; section 7 there covers the timing variant, where the
window being probed is shorter than the probe interval and every sample reads
empty.

## Why it recurs

Probes feel like observation but are actually inference: the command encodes an
assumption about format, scope and tooling, and only its *conclusion* is visible.
When the conclusion happens to be the expected one, nobody checks. When it is the
unexpected one, the temptation is to explain the surprise rather than to doubt the
instrument. Rule 2 is the cheap fix and the only one that generalises - a probe
that cannot find something known to be present has told you nothing about anything
else.
