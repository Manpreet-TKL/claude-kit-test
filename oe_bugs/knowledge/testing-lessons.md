# OpenEyes clinical testing lessons

## Baseline discipline

- Walk the checkout inside the running web container. The host checkout does not
  match the target used by the browser and database.
- Pin every result to both the target commit and comparison ref. Close the wave if
  the target commit changes.
- Static confidence is not verification. Changed code provides a candidate and a
  predicate; a clean browser provides R1; a second patient or clinical choice
  provides R2.

## Browser walking

- Use a separate patient for each concurrent write-capable walk.
- Select clinical context explicitly because concurrent sessions using one account
  can share its last-firm state.
- Put an `oewalk` tag on the starting URL so logs can be attributed without saving
  patient identifiers in the kit.
- A clean log bracket does not refute a UI defect. Prefer a tight DOM predicate,
  then a response or database read when persistence is the actual concern.
- Stop after four failed setup attempts. Record the candidate as blocked or
  unverified instead of improvising a different workflow.
- The multi-site login page keeps username and password hidden until institution
  and site are selected. The Playwright journey driver must settle the page,
  select those visible choices, and only then fill credentials.

## Swarm operation

- Do not start a large agent swarm from the requested total alone. Run one to
  three pilot threads first, confirm that their results are visible to the user,
  and inspect usage before widening the batch.
- During this run, 30 Luna threads completed but the user reported the platform's
  `This content can't be shown` response four times. Narrowing prompts to
  read-only clinical functional review did not make the large batch reliable.
- Stop spawning as soon as that response repeats. Internally returned agent
  results do not make a run usable when the user-facing result is suppressed.
- Luna consumed substantially more usage than expected in this run. A smaller or
  nominally efficient model is not a budget guarantee when multiplied across
  many threads. Agree a total-thread and usage ceiling after the pilot rather
  than assuming that a 40- or 50-thread run will be economical.
- Only the primary agent writes the Markdown corpus. Worker logs and sample record
  assignments stay under `~/.codex/oe-bug-hunt/`.
- Keep Luna work on version-matched clinical code snapshots. The primary agent
  performs live R1 and R2 in separate clean browser sessions and varies the
  patient, context, or configured reference row.
- A narrow snapshot can create false missing-class or missing-asset findings.
  Check the complete target checkout before retaining any cross-module dependency
  candidate.
- Count only clinician-facing workflow, correctness, persistence, validation,
  state, audit, correspondence, signing, and UI faults.
