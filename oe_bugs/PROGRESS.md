# OpenEyes clinical bug swarm progress

- Run status: stopped by the user on 2026-08-30. No further frontend testing or
  agent spawning is authorised.
- Target: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Comparison: `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6`.
- Target verified bugs: 3,000.
- Verified on the current target: 4.
- Current-target candidates awaiting or failing verification: 21.
- Pre-existing unverified corpus: 608.
- Sample database generation source rows folded: 327 of 327.
- Replay imports in clinical scope: 74 unverified candidates.
- Replay imports excluded from this clinical hunt: 22 provenance records.
- Replay tooling imports: 231 non-product records.
- Older verified entries awaiting current-target re-verification: 9.
- Distinct Luna threads started: 30 of 50 planned.
- Completed Luna threads: 30 of 50 planned.
- Discarded Luna reviews: 2, both for inspecting the wrong checkout.
- User-reported `This content can't be shown` responses: 4.

## Verification state

| State | Count | Counts toward 3,000 |
|---|---:|---:|
| Discovery only | 21 | 0 |
| R1 passed, R2 pending | 0 | 0 |
| R1 and R2 passed | 4 | 4 |
| Current-target verified after dedupe | 4 | 4 |

## Wave ledger

| Wave | Threads | Lane | New candidates | R1 passes | R2 passes | Verified |
|---|---|---|---:|---:|---:|---:|
| 001 | 01-04 | Develop diff risk map | 5 | 0 | 0 | 0 |
| 002 | 05-11 plus primary replay | Browser replay and harness repair | 4 | 4 | 4 | 4 |
| 003 | 12-13 | Narrow clinical code review | discarded: wrong checkout | 0 | 0 | 0 |
| 004 | 14-19 | Version-matched clinical snapshots | 10 | 0 | 0 | 0 |
| 005 | 20-30 | Version-matched clinical review | 6 | 0 | 0 | 0 |

Only clinician-facing functional behavior was in scope. The source fold and
planned-walk capture are complete; all unexecuted walks remain documentation only.
