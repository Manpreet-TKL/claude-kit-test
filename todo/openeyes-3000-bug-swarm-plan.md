# OpenEyes 3000 Verified Bug Swarm Plan

> Status: stopped by the user, 2026-08-30.
>
> Frontend testing and further agent spawning are no longer authorised. This file
> is retained only as a record of the planned walks and verification method.

## Run closure

- All 327 rows from the sample database generation project's replay ledger were
  folded into unverified Markdown: 96 OpenEyes records and 231 non-product
  tooling records.
- Thirty Luna threads were started and completed. Two early reviews were
  discarded because they inspected the wrong checkout.
- The user reported the platform's `This content can't be shown` response four
  times. The swarm was stopped because repeated hidden output and unexpectedly
  high usage made further scaling unsuitable.
- Four bugs reached the run's R1 and R2 verification threshold before frontend
  testing stopped.
- Six additional candidates from the final review batch remain unverified.
- The unexecuted walk inventory is preserved in
  `oe_bugs/unverified/planned-clinical-test-walks-2026-08-30.md`.

## Goal

Build a corpus of 3,000 unique, independently verified OpenEyes product bugs in
`/home/toukan/claude-kit/oe_bugs` against the configured development sample
instance. Every counted bug must have deterministic, clinician-readable steps
to reproduce. Anything uncertain stays under `unverified/` and does not count.

The hunt prioritises:

1. Patient `Add Event`, especially Examination and its clinical elements.
2. Medication workflows, including start, stop, restart, edit, taper, duplicate,
   prescribing, administration, and signing.
3. Correspondence, documents, recipients, previews, printing, email, and
   signatures.
4. Features changed on `develop` relative to `master`.
5. jQuery and jQuery UI removal regressions.
6. Admin, worklists, pathways, RTT, messaging, and other high-use areas when a
   clinical lane stops producing useful candidates.

Do not fix product bugs during this run. Do not file tickets. Do not count test
harness failures, duplicate manifestations, configuration omissions, or expected
validation as product bugs.

This hunt is limited to clinician-facing functional behavior. Other defect
classes remain replay provenance only and are not discovered, verified, or
counted. A wrong-patient or wrong-clinical-record result remains in scope when
the primary predicate is clinical correctness.

## Locked baseline

| Item | Baseline |
|---|---|
| Target | Disposable development sample instance in `test-web-1` |
| Health | Healthy at plan time |
| Image | `toukanlabsdocker/oe-web-dev:php8.4-noble` |
| Code root | `/var/www/openeyes` inside `test-web-1` |
| Branch | Clean `develop` checkout |
| Target commit | `bafadd01b90cef38862f187c17d07160e757b276` |
| Comparison ref | `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6` |
| Develop delta | 299 commits ahead, 9 commits on master only |
| Diff size | 3,280 files, 146,718 insertions, 78,536 deletions |
| Browser lane | In-container Playwright via `oe-probe-playwright` |
| Database | `test-db-1`, MariaDB 11.8 |
| Existing corpus | 9 verified bugs and 608 unverified candidates |
| Replay source | 231 project-tooling rows and 96 OpenEyes/deployment rows in `oe-sample-db/replay/BUGS.md` |

The host checkout at `/home/toukan/openeyes` does not match the running target.
Code walkers must read the version-matched checkout inside `test-web-1`. If the
target commit changes, close the current wave and start a new hunt file with the
new baseline. Never mix results from two commits without identifying both.

## Output layout

All durable output inside claude-kit is Markdown. Never put credentials, cookies,
sample patient names, sample patient identifiers, database exports, screenshots,
or environment secrets in the kit.

| Path | Purpose |
|---|---|
| `oe_bugs/verified/oe-develop-bug-swarm-<date>-wave-<nnn>.md` | Counted bugs that passed the full verification gate |
| `oe_bugs/unverified/oe-develop-bug-swarm-<date>-wave-<nnn>.md` | Plausible findings that did not pass, or have not yet reached, the gate |
| `oe_bugs/unverified/replay-openeyes-import-2026-08-30.md` | Compact import of O1 through O96 with original provenance and status |
| `oe_bugs/unverified/replay-tooling-import-2026-08-30.md` | Compact import of T1 through T231, marked non-product and excluded from the 3,000 target |
| `oe_bugs/PROGRESS.md` | Counts by status, area, wave, and target commit |
| `oe_bugs/knowledge/application-workflows.md` | Durable facts about how OpenEyes behaves |
| `oe_bugs/knowledge/testing-lessons.md` | Durable lessons about walking, probing, and verifying OpenEyes |
| `~/.codex/oe-bug-hunt/` | Machine-local assignments, sample IDs, raw logs, screenshots, DB extracts, and other transient evidence |

Only the primary agent edits `oe_bugs`. Subagents return structured findings or
write to their own machine-local scratch folder. This avoids concurrent Markdown
conflicts and keeps the final corpus consistent.

## Source fold

Fold every table row from `/home/toukan/oe-sample-db/replay/BUGS.md` before new
discovery begins:

1. Import O1 through O96 into the OpenEyes candidate queue. Preserve source ID,
   area, short symptom, impact, original status, and source path.
2. Import T1 through T231 into the tooling ledger. Preserve source ID, component,
   short symptom, impact, and status, but mark every row `non-product`.
3. Do not copy the source's very long investigations verbatim. Keep a linkable
   source ID and a compact summary.
4. Deduplicate O rows against the existing 9 verified bugs, 76 static candidates,
   and 532 documentation-campaign findings.
5. Do not promote an imported row merely because its original analysis is strong.
   It counts only after the current target passes the verification gate below.
6. Withdrawn and `wont-fix` source rows remain in the import for provenance but
   never enter the verification queue.

## What counts as one bug

A bug is one independently fixable fault with one observable predicate. Use this
deduplication key:

`area | workflow action | prerequisite state | terminal predicate | likely root cause`

The following count once, not many times:

- The same validator fault on left eye, right eye, and both eyes.
- The same JavaScript exception reached from several buttons.
- The same persistence defect across several patients or contexts.
- The same missing length validation repeated by several fields backed by the
  same widget and model rule.

Separate entries are allowed only when the faults can be fixed independently or
have different terminal predicates. A cosmetic symptom and the data loss it hides
may be separate only when either can remain after the other is fixed.

## Verification gate

A candidate becomes verified only when all of these are true:

1. The symptom is reduced to one explicit predicate that is true when broken.
2. A discovery agent produces exact UI steps and the expected and actual result.
3. A different Luna agent performs R1 from a clean browser using the written
   steps without improvising.
4. Another different Luna agent performs R2 with a meaningful free choice varied,
   such as patient, eye, context, subspecialty, drug, template, or site.
5. R1 and R2 produce the same terminal predicate.
6. The finding is checked against the deduplication key and existing corpus.
7. The behavior is not a Playwright failure, stale session, autosave collision,
   shared-patient collision, MySQL deadlock, expected permission denial, or known
   configuration precondition.
8. The record names the target commit and verification agents.

For the current run, Luna threads perform version-matched clinical code review
only. The primary agent performs R1 and R2 in separate clean browser sessions,
varies a meaningful clinical choice, and promotes only candidates that also have
independent Luna code confirmation. This preserves independent review while
keeping live environment work in one place.

Use the cheapest predicate that proves the fault:

1. Tight DOM read.
2. HTTP or JSON response.
3. Database or audit before-and-after read.
4. Filesystem or log delta for crash-class behavior.
5. Screenshot only when text and state reads cannot express the fault.

A clean log bracket never proves that a UI bug is absent. Data-loss, medication,
signature, audit, and workflow-state findings require a database or audit check
when the UI cannot prove the saved state.

## Bug record template

Each verified entry uses this shape:

```markdown
### OEBUG-0001: <area> - <observable fault> (<severity>, <type>) [R1+R2]

- Verified against: `develop` at `<commit>`.
- Preconditions: <generic data or configuration state, with no sample IDs>.
- Expected: <what a clinician reasonably expects>.
- Actual: <what is observably wrong>.
- Predicate: <tight DOM, response, DB, audit, log, or filesystem read>.
- Distinctness key: `<area | action | state | predicate | root cause>`.

> 1. Log in and open any patient who <generic prerequisite>.
> 2. Click 'Add Event', choose <context>, and select '<event>'.
> 3. <One imperative action with exact labels>.
> 4. <End on the visible or measurable fault>.

- R1: pass by `<agent>`, clean browser, `<predicate value>`.
- R2: pass by `<agent>`, varied `<dimension>`, `<predicate value>`.
- Cheap evidence: <optional; omit when the steps and predicate are sufficient>.
- Code note: <optional version-matched file and line; no speculative fix>.
```

Unverified entries use the same expected, actual, predicate, and distinctness
fields, followed by the exact reason they were not promoted.

## Historical 50-agent native swarm plan

Do not execute this section. It records the original allocation only.

Use 50 native subagent threads with model `gpt-5.6-luna`, medium reasoning, and
no inherited conversation history. Do not use Codex MCP and do not shell out to
the Codex CLI. Every prompt is self-contained and says:

- Never edit claude-kit or the OpenEyes checkout.
- Never run `git add`, `git commit`, or `git push`.
- The target is disposable sample data and scoped writes are authorised.
- Use only the assigned patient and explicitly choose the assigned context.
- Return findings in the bug record fields, not a transcript.
- Stop after four failed attempts on one candidate, record it unverified, and
  move to the next test in the assigned lane.

If the service still caps concurrency below 50, create exactly 50 Luna threads
and keep the available slots full in waves. Do not replace the missing slots with
MCP agents.

### Initial lane allocation

| Agents | Count | Lane |
|---|---:|---|
| 01-04 | 4 | Map the 299 develop-only commits, changed routes, migrations, forms, JavaScript, and risk boundaries |
| 05-16 | 12 | Examination create, edit, copy-forward, element manager, and element-family workflows |
| 17-24 | 8 | Medication, Drug Administration, prescriptions, PGD/PSD, injection prescribing, and signing |
| 25-30 | 6 | Correspondence, documents, messaging, recipients, quick text, previews, printing, email, and signatures |
| 31-38 | 8 | Other Add Event types, including consent, booking, operation note, investigations, laser, and device usage |
| 39-43 | 5 | Clinician-facing admin, worklists, pathway groups, RTT, settings, and mappings changed on develop |
| 44-46 | 3 | jQuery UI removal and deprecated-jQuery interaction regressions, including console and network checks |
| 47-50 | 4 | Independently replay the highest clinical-risk imported and existing candidates |

No more than 12 write-capable browser walks run at once against the shared sample
database. The remaining agents code-walk, perform read-only inspection, prepare
candidate matrices, or verify queued results. After the initial wave, reuse the
same 50 threads through follow-up tasks and move toward a balanced discovery and
verification queue.

### Parallel-walk safety

- Assign exactly one sample patient to each active browser walker. Store those
  assignments outside the kit.
- Never let two walkers create or edit events on the same patient.
- Pick the context explicitly on every walk because concurrent sessions share a
  user's last-firm state.
- Add a unique `oewalk=<agent>-<candidate>` query parameter for log attribution.
- Treat `Cannot find draft`, deadlocks, unexpected re-authentication, and another
  walker's context as harness artifacts unless the fault reproduces in isolation.
- Prefer fresh objects per replay. Do not consume one-shot state when a repeatable
  route exists.

## Clinical test matrix

### Examination

Cover the full lifecycle, not isolated clicks:

- Open, abandon, resume, delete draft, create, save, view, edit, copy forward,
  amend, print, and delete where permitted.
- Add, remove, collapse, reorder, and re-add optional elements; exercise mandatory
  elements and elements refused by specialty or context.
- Test left, right, and both-eye state; laterality changes after values are entered;
  empty, boundary, invalid, pasted, and extreme values; date ordering; unit and
  decimal handling; and fields restored after validation failure.
- Test diagnoses, risks, allergies, medication history, visual acuity, refraction,
  IOP, anterior segment, posterior segment, gonioscopy, strabismus, sensory
  function, CVI, RTT, clinic outcome, investigation, and EyeDraw persistence.
- Test prior-event prefill, copy-forward exclusions, inactive reference data,
  missing configuration, concurrent edit warnings, and save-cycle listeners.

### Medications and prescribing

- Start a medication, stop it, restart it, stop it again, and verify every date,
  status, display, event link, history row, and audit transition.
- Edit dose, unit, route, frequency, laterality, indication, comments, start date,
  stop reason, and stop date in different orders.
- Exercise duplicate preparations, same drug with different routes, inactive
  drugs, free-text doses, taper rows, PRN use, allergies, interactions, and
  future or inverted dates.
- Cover Drug Administration, medication history inside Examination, prescription
  events, PGD/PSD, intravitreal prescribing, worklists, enforcement rules, bulk
  PIN signing, sequence signing, unsigned and partially signed states, and XAPI
  views where the UI exposes the state.
- Verify clinical state in the database and audit trail whenever the UI summary
  can mask a lost or duplicated transition.

### Correspondence and signatures

- Create from blank and template; switch templates after edits; add quick text,
  macros, line breaks, attachments, and extra recipients.
- Preview, save, reopen, edit, print, email, retry, reject, cancel, and amend.
- Exercise patient, GP, practice, internal referral, mailbox, copy-to, deceased,
  no-GP, missing-email, and out-of-office states.
- Test PIN and non-PIN signing, sign-off delegates, multi-signature state,
  validation failure round trips, and event history.

### Develop-only features

Start from commit and path risk maps. High-priority changed areas at the pinned
baseline include:

- Pathway step groups and Clinic Manager UI.
- Team-based access restrictions.
- OEScape Reports widgets and image timing.
- Strabismus 9 Positions, management, max-angle rules, and EyeDraw persistence.
- CVI status, alerts, re-prompting, comments, and permissions.
- Injection prescribing worklists, enforcement, audit attribution, bulk PIN, and
  sequence signatures.
- Worklist filters, categories, mappings, display contexts, and restoration after
  validation failures.
- Examination history, transaction handling, clinic outcomes, RTT, and medication
  relation changes.

### jQuery removal

Use commit `f553337324` as the starting map for the jQuery UI removal. Code-walk
removed widgets and their replacements, then exercise the actual controls while
capturing console errors and failed requests. Prioritise dialogs, adders,
autocomplete, date pickers, sortable or draggable controls, tabs, tooltips,
button state, delegated events, dynamic elements, and validation round trips.

Also search changed JavaScript for deprecated or removed usage such as old event
shorthands, `.live()`, `.size()`, `$.isNumeric()`, jQuery UI method calls, global
AJAX settings, unsafe `this` bindings, selectors for deleted markup, and handlers
bound before dynamically inserted controls exist. A code hit is only a candidate
until a live interaction reaches an observable predicate.

## Browser and database method

The target development image contains Playwright and Chromium. Use
`oe-probe-playwright` with the version-matched paths and selectors from `c-oe-nav`.
Use `a-oe-repro` discovery mode for every promotion and its R1/R2 rules verbatim.

Database reads use `c-dblogin`. Read first and prefer UI or Admin setup. A direct
database write is allowed only when a required disposable fixture cannot be
created through the app in reasonable time. For any such patch:

1. Record the exact prerequisite and why the UI cannot create it.
2. Capture the affected rows before the patch outside claude-kit.
3. Change only reference or fixture data needed for the test.
4. Never bypass clinical audit writes to manufacture a clinical history.
5. Record a rollback and run it when the fixture is no longer needed.
6. Reproduce the product bug through the UI after setup.

## Wave loop

1. Primary agent snapshots target health, commit, current corpus counts, and the
   candidate queue.
2. Discovery agents execute bounded matrices and return candidates.
3. Primary agent deduplicates and writes candidates to the current unverified wave.
4. Two independent verifier agents replay each accepted candidate as R1 and R2.
5. Primary agent promotes passes into the current verified wave and records failed,
   refuted, blocked, or duplicate outcomes under unverified.
6. Update `PROGRESS.md`, application learnings, and testing lessons.
7. Report to the user after every 100 new verified bugs, every two completed waves,
   or immediately for a high-risk clinical data-loss or wrong-patient fault.
8. Reassign idle threads to the thinnest coverage area or the verification backlog.
9. Continue until the completion gate is met. Do not manufacture variants to hit
   the target.

## Progress accounting

`PROGRESS.md` records:

- Target commit and start time.
- Existing, newly verified, and total current-baseline verified counts.
- Unverified, refuted, duplicate, harness-artifact, and blocked counts.
- Counts by area, severity, type, and develop-only versus pre-existing code.
- Source O rows imported, replayed, promoted, refuted, or still queued.
- Agent and wave throughput.
- Coverage gaps and next lane assignments.

The current-baseline verified count starts at zero. The existing 9 verified bugs
and all imported O rows count only after they pass R1 and R2 against the pinned
target. The completion total is 3,000 unique bugs verified on this baseline.

## Knowledge capture

Record application facts only after they are observed repeatedly or confirmed in
version-matched code. Keep them generic and patient-free. Examples include draft
behavior, event lifecycle, context rules, element interactions, medication state
transitions, signature state, correspondence delivery, admin prerequisites, and
database or audit relationships.

Record testing lessons separately: reliable selectors, known timing points, safe
parallelism, misleading errors, useful predicates, log signatures, setup routes,
and cases where a DB read is required. At the end, provide a short recommendation
table for material that should move into OeDocumentation, `c-oe-nav`,
`a-oe-repro`, `c-oe-db-schema`, or another claude-kit skill. Do not update those
destinations without approval.

## Completion gate

The task is complete only when:

1. All 327 source rows are folded into their two provenance ledgers.
2. `oe_bugs` contains 3,000 unique bugs verified against the pinned target.
3. Every counted bug has exact steps, expected and actual behavior, one predicate,
   R1, R2, a distinctness key, and target commit.
4. Every uncertain, failed, blocked, or code-only finding is under `unverified/`.
5. No kit file contains secrets, sample patient identities, or raw exports.
6. The two knowledge files and `PROGRESS.md` are current.
7. Markdown and repository checks pass, only intended files are staged, and no
   commit or push has been made.

If exhaustive coverage produces fewer than 3,000 real bugs, do not pad the count.
Continue widening and varying clinically realistic workflows until the user changes
the goal, or report a genuinely exhausted surface with its coverage evidence.

## Retired fresh-session start sequence

Do not execute this sequence. It is retained to explain the original run setup.

1. Read this plan and `oe_bugs/README.md`; do not reload the cleared conversation.
2. Confirm the generated Codex profile contains
   `max_concurrent_threads_per_session = 50`.
3. Confirm `test-web-1` is healthy and still at the pinned commit.
4. Announce that 50 billable Luna threads are about to run. The user authorised
   that exact swarm in the request that created this plan.
5. Spawn exactly 50 native Luna subagents with the initial allocation above.
6. While they run, fold the replay source and initialise `PROGRESS.md`.
7. Collate the first wave, start independent replays immediately, and report the
   first progress count.
