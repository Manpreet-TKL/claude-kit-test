# TKLS full-corpus analysis plan (pending - execute on request)

Written 2026-08-10, while the full-project download (9,940 tickets, all
attachments) was running into `~/tkls-corpus-full/` (screen `tkls-corpus`).
Pipeline lessons and corpus layout live in `jira-corpus-triage.md`; this file is
the concrete analysis brief. Goals: SQL notes, doc-gap detection from
training-style asks, major bugs, error logs + fixes, KB-article candidates,
discard categorisation, common-pattern clustering, and RCA tickets (tickets
containing a root cause analysis).

Core principle: **classification is grep/jq/awk at zero model tokens and
produces statistics FIRST. No model reads any ticket until the stats have been
reviewed** and the model passes are sized from real counts - e.g. if only ~200
tickets carry SQL, Sonnet 5 subagents can note them all cheaply; the 105-ticket
open-DevOps sample hit 13% on `select..from`, so the real count may be far
higher, which is exactly why counting precedes analysing.

Grounding measured on `~/tkls-corpus-rest/` (July sample): ADF-flattened text is
~14% of raw JSON (~2-4k tokens/ticket); flattened sizes run min 0.4 KB / p25
1.7 KB / median 3.6 KB / p75 6.8 KB, so a fat tail of near-one-sentence tickets
exists; `.fields.issuelinks` targets carry dev-project keys (`OE-...` and other
non-TKLS prefixes) for tickets fixed via development; labels carry module names
(`worklist`, `correspondence`, `biometry`, `integration-pas`) plus
`logs-attached`; every service-desk ticket embeds the proforma "Please attach a
screenshot of the error screen INCLUDING the URL", so bare words like "error"
are unusable as detectors.

## Phase A - verify the download (bash only)

Against `~/tkls-corpus-full/`: keys.txt count vs `ls issues/ | wc -l`; every
file passes `jq -e '.key'`; `.fields.comment.total == (.fields.comment.comments|length)`
everywhere; attachment metadata `[.id,.size]` reconciles with on-disk files.
Any failure: re-run the downloader with `-r` (resumes) until clean:
`bash ~/claude-kit/scripts/jira_filter_download.sh -j 'project = TKLS ORDER BY created ASC' -a -r -o /home/toukan/tkls-corpus-full`

## Phase B - derived text + index (zero tokens)

Two generic additions to the kit (no client data, reusable for any Jira corpus):

1. `scripts/adf2text.jq` - validated def:

```jq
def adf2text:
  if type == "object" then
    if .type == "text" then .text
    elif .type == "hardBreak" then "\n"
    elif .type == "mention" or .type == "emoji" then (.attrs.text // "")
    else ((.content // []) | map(adf2text) | join(""))
         + (if .type as $t | ["paragraph","codeBlock","heading","listItem","blockquote","tableRow"] | index($t) then "\n" else "" end)
    end
  elif type == "array" then map(adf2text) | join("")
  else "" end;
```

2. `scripts/jira_corpus_text.sh` (house bash style): given `-i <corpus dir>`,
   writes per ticket `text/KEY.txt` - header line (key | issuetype | status |
   resolution | priority | created | resolved | reporter | labels), summary,
   flattened description, each comment as `-- <author> <date>` + flattened body,
   attachment list - and one `index.tsv` row: key, issuetype, status,
   resolution, priority, created, resolved, reporter, labels, comment_count,
   attachment_count, attachment_names, text_bytes (size of the flattened text -
   the sort key for the small-ticket sweep), linked_keys (issuelinks target
   keys, comma-joined), summary. One jq pass per file; expect 10-20 min for 10k
   files, text corpus ~80-140 MB.

## Phase C - zero-token classification -> statistics

`<corpus>/analysis/classify.sh` (corpus-local - the vocab is TKLS-specific):
`grep -lEi` detectors over `text/*.txt` plus awk over `index.tsv`, one key-list
per category in `analysis/hits/<cat>.keys`, then render `analysis/stats.md`.
Detector iteration costs seconds - refine until sample excerpts look right.

### Shrink-first funnel

The working set shrinks in this order, so every later stage sees fewer tickets:

1. **Upgrade tickets out first.** The `upgrade` bucket is pure noise for notes;
   stats.md reports every other category both raw and with upgrade keys
   subtracted, and the post-upgrade set is the pool everything below works on.
2. **Size-sort the remainder by `text_bytes`, smallest first.** One-sentence
   tickets can be analysed directly and removed for very few tokens - batched
   50-100 per agent context, each gets a one-line disposition (category or
   discard) and leaves the pool. The size decile table in stats.md sizes this
   sweep precisely before it runs.
3. **Dev-linked bugs out of note-writing - but never out of the sql pass.**
   OpenEyes bug tickets solved WITHOUT a dev ticket attached are prime note
   candidates - the fix (SQL, config, data repair) is documented nowhere else.
   Bugs solved WITH development (`devfixed`) are uninteresting for bug notes:
   the code fix is already documented in GitHub. The exception is SQL: many
   code-fix tickets carried an interim SQL data-fix patch before the permanent
   code fix landed, and those queries are collected regardless - `devfixed`
   filters the majorbug/rca/kbfix passes only, never the sql pass.

| Category | Detector (grep -lEi on text/ unless noted) | Notes |
|---|---|---|
| sql | `select[[:space:]]+[a-z_*,. ]+[[:space:]]+from[[:space:]]`, `insert[[:space:]]+into`, `update[[:space:]]+[a-z_]+[[:space:]]+set[[:space:]]`, `delete[[:space:]]+from`, `alter[[:space:]]+table` | anchored forms only - bare `update`/`select` false-positive |
| training | `how (do|does|can|to) `, `is it possible`, `can you (advise|confirm|explain)`, `training`, `user guide`, `any documentation` | high-FP expected; judge via excerpts |
| majorbug | index: priority in (Highest, Blocker, Major); text: `data loss`, `wrong patient`, `clinical (risk|safety)`, `incident`, `all (users|sites)`, `system (down|unavailable)`, `cannot log ?in`, `outage` | union of both |
| errorlog | index: label `logs-attached` or `.log`/`.txt` attachment; text: `stack trace`, `SQLSTATE`, `CDbException`, `PHP (Fatal|Warning|Notice)`, `Exception`, `(HTTP |error )50[03]`, `Internal Server Error` | never bare `error` (proforma) |
| rca | `root cause`, `RCA`, `post-?mortem`, `caused by`, `underlying (cause|issue)` | new category |
| kbfix | resolved (index) AND (in sql or rca hits OR `workaround`, `the fix (was|is)`, `resolved by`, `fixed by (running|changing|updating)`) | KB-article candidates |
| upgrade | summary/text: `(upgrade|upgrading).*(openeyes|oe|v?[0-9]+\.[0-9])`, `please upgrade` | discard bucket |
| notissue | index: resolution in the won't-do family (enumerate real values from index.tsv at run time); text: `as designed`, `expected behaviou?r`, `not a bug`, `user error` | discard bucket |
| codefix | `fixed in (v|release)`, `hotfix`, `will be (fixed|released) in`, `pull request`, `github\.com/`, `merged` | discard bucket (fixed by code release) |
| stale | resolved (index) AND `clos(ing|ed) due to (inactivity|no response)`, `no response from`, or comment_count <= 1 | discard bucket |
| devfixed | index: linked_keys contains a non-TKLS key (OE-, ... - enumerate real prefixes from the full corpus at run time); text: `(OE|OPD)-[0-9]+`, `github\.com/`, `pull request` | solved via development - skip bug notes (GitHub documents code fixes); does NOT remove a ticket from the sql pass |
| oebug-nodev | resolved (index) AND bug-shaped (in errorlog or majorbug hits) AND NOT devfixed | prime note candidates - fixed operationally (SQL/config/data repair), documented nowhere else |
| patterns | frequency tables, not a key-list: label counts from index.tsv; module vocab `grep -c` (worklist, correspondence, docman, letter, prescription, biometry, PAS, DICOM, print, SSO, login, Mirth, virtual clinic, ...); top summary terms | common-pattern clustering |

`stats.md` contains: corpus overview (per year, issuetype, status, resolution,
priority); per category the count, % of corpus, overlap matrix (`comm` between
key sets), and 10 random sample keys each with the matched-line excerpt
(`grep -m1 -oE`) so precision is judgeable at zero tokens; category counts both
raw and post-upgrade-subtraction; the text_bytes decile table plus counts under
1/2/4 KB (sizes the small-ticket sweep); the devfixed vs oebug-nodev split among
resolved bug tickets and the sql-within-devfixed overlap (interim data patches
that preceded code fixes); the module frequency table; a proposed sizing table
(category -> count -> est input tokens at ~3k per ticket -> proposed tier ->
wall time); the final regex per detector for reproducibility; a closing
decision checklist.

## HARD GATE

stats.md goes to Manpreet. No ticket content enters any model context until he
approves the sizing. Phases A-C only are pre-authorised.

## Phase D - model passes (shape only; size after stats review)

All read `text/KEY.txt` from disk, never via MCP:

- **small-ticket sweep (runs first)**: post-upgrade pool in ascending
  text_bytes order; batch 50-100 near-one-sentence tickets per agent for a
  one-line disposition each (category or discard) - cheapest tokens-per-ticket
  in the plan, and it removes a large slice of the corpus before any per-ticket
  work starts.
- **sql**: Sonnet 5 subagents, 10-15 tickets each, write
  `analysis/notes/sql/KEY.md` (what the query does, problem solved, tables
  touched, reuse conditions). Covers ALL sql hits including devfixed tickets -
  an interim SQL data-fix patch that preceded a permanent code fix is exactly
  the kind of query worth keeping; the note records that it was an interim fix
  and names the linked dev ticket. 300 tickets x ~3.5k in + ~400 out is roughly
  1M Sonnet tokens; at 1,000+ run a Haiku keep/drop triage first.
- **training**: Sonnet batches asks into a topic table; check topics against the
  docs (`c-oe-docs`) for gaps.
- **majorbug / rca / kbfix**: Sonnet per-ticket notes, later merged into KB
  drafts (`c-note-style` format) - restricted to the oebug-nodev side of the
  split; devfixed tickets get no notes (GitHub already documents the code fix).
- **discard buckets**: no model - counts and key-lists only; at most a Haiku
  spot check of borderlines.
- **patterns**: zero-token counts stand; Sonnet only names clusters from a few
  samples.

Notes stay corpus-local (`analysis/notes/`) - the kit remote is public, so
client-referencing knowledge never lands in `knowledge/`; per-category promotion
(Confluence, or sanitised kit notes) is a stats-review decision.

## Verification

- Phase B: `ls text/ | wc -l` equals issue count; `find text -size 0` is empty;
  spot-check 3 flattened tickets against the Jira UI.
- Phase C: each category's sample-excerpt block in stats.md is the precision
  check; iterate regexes until samples are clean before presenting.
