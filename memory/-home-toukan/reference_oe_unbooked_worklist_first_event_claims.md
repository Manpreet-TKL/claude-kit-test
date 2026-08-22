---
name: reference_oe_unbooked_worklist_first_event_claims
description: "OpenEyes unbooked worklists: a patient joins at most ONE unbooked list per day - the day's first saved event claims them for its subspecialty's list; later saves that day add nothing. Probe/verify must span ALL of today's unbooked lists."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7f4b956c-11d9-43af-b3d6-bed06c12a1d5
  modified: 2026-08-10T12:18:37.965Z
---

OpenEyes unbooked-worklist rule (learned the expensive way on snail, 2026-08-10): **a patient
joins at most one unbooked worklist per calendar day**. The first event saved for the patient
that day claims them for the unbooked list of THAT event's subspecialty/firm; any later event
the same day adds them to no further list, silently.

**Why:** any seeding/automation that (a) creates a throwaway probe event first and (b) then
creates the "real" event expecting the patient on a specific list will find the patient on the
probe's list instead, and a naive "is patient on MY list?" check re-creates the event as a
duplicate (that is how duplicate DNA event 3687007 for patient 17891 happened).

**How to apply:** idempotency probes and post-seed verification must enumerate ALL of today's
unbooked lists and check the union of their patients, not just the target list. Definitions
live at `/Admin/worklist/definitions` (rows: `td[data-test="definition-name"]`; use the
`a[href^=".../definitionWorklists/"]` prefix WITH trailing slash to exclude the
`definitionWorklistsDelete/` links); a list's patients are `tr[data-patient]` rows. The
worklist seed spec in `~/oe-frontend-tests/tests/seed/worklist.spec.mjs` is the worked example.
See [[project-oe-frontend-tests-repo]] (seed suite section).
