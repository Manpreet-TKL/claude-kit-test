# Worklist "patient not appearing" — fix patterns for a `yiic` command

Source: analysis of 54 TKLS support tickets matching the "worklist" theme
(`/home/toukan/devops-keyword-worklist-2026-06-13.txt`). 28 had a confirmed fix;
this document distils the **automatable** ones into a spec a developer can build into
a console command.

The recurring shape across almost every automatable ticket is one thing:

> An inbound appointment exists, but never produces a worklist row — because the
> message can't be matched to a worklist definition (wrong/missing/whitespace-padded
> mapping, rejected booking type, duplicate instance), or it fell outside the
> generation window. The remedy is: **correct the matching data, then replay the
> appointment so it populates.**

A single `yiic` command group can cover ~14 of the 28 confirmed fixes.

---

## 0. Background the implementer needs

OpenEyes is PHP/Yii 1.1. Appointments flow in from the client PAS/CRS, usually via
Mirth Connect (HL7) or the PAS API (`pasv2` from OE v9), and are matched to a
**worklist definition** to generate **worklist instances** that patients appear on.

A definition carries a set of **mappings** — key/value pairs (e.g. `Clinic`,
`Booking type`, `Doctor`, `Status`, `Admit Source`) that the incoming message
attributes are matched against. If the match fails, the patient never lands on a
worklist even though the appointment exists.

> **Schema TODO for the implementer.** Confirm the exact model/table names in the
> `Worklist` module before coding — likely `Worklist`, `WorklistDefinition`,
> `WorklistDefinitionMapping` (key/value columns), `WorklistPatient`, and the
> inbound appointment store (`pas_appointment` / session / HL7 message log). Every
> SQL/pseudocode sketch below is intent, not verified column names.

---

## 1. Pattern catalogue

Ranked by how often it appeared. "Auto?" = good candidate for the command.

| # | Pattern | Count | Auto? | Maps to subcommand |
|---|---------|-------|-------|--------------------|
| 1 | Mapping wrong / missing / whitespace-padded → fix mapping + reprocess | 9 | **Yes** | `checkmappings` + `reprocess` |
| 2 | Already fixed in an OE release (upgrade) | 9 | No | — (out of scope) |
| 3 | Appointment outside the generation / lookback window | 2 | **Yes (config)** | window setting |
| 4 | Interface-channel / service-location config wrong | 2 | Partly | manual review |
| 5 | Thin "now appearing" data correction (really a reprocess) | 2 | **Yes** | `reprocess` |
| 6 | Mirth channel booking-type filter blocking the message | 1 | Mirth-side | flag only |
| 7 | Duplicate worklist instances → delete extras + reprocess | 1 | **Yes** | `dedupe` |
| 8 | Stuck/cancelled appointment lingering → delete the row | 1 | Semi | `deleteappointment` |
| 9 | Demo-env worklist provisioning (different purpose) | 1 | Yes (cron) | out of scope |

---

## 2. Proposed command: `yiic worklistrepair`

A console command (`protected/commands/WorklistRepairCommand.php`,
`CConsoleCommand`) with read-only diagnostics and guarded write actions. **Every
write action must support `--dry-run` (default ON) and print exactly what it would
change before `--commit` actually applies it.** Wrap each repair in a transaction
and log to the ticket/audit trail.

```
./yiic worklistrepair diagnose        --patient=<hos_num> | --clinic=<code> [--from=YYYY-MM-DD --to=YYYY-MM-DD]
./yiic worklistrepair checkmappings   [--site=<id>] [--clinic=<code>] [--fix]
./yiic worklistrepair reprocess        --clinic=<code> --from=YYYY-MM-DD --to=YYYY-MM-DD [--commit]
./yiic worklistrepair dedupe          [--site=<id>] [--window-seconds=60] [--commit]
./yiic worklistrepair deleteappointment --appointment=<id> [--commit]
```

`diagnose` is the support-desk entry point: read-only, runs all the checks below for
one patient or clinic and prints the most likely cause + the suggested action — so a
first-line engineer can resolve most of these without a developer.

---

## 3. The automatable patterns in detail

### 3.1 `checkmappings` — wrong / missing / whitespace mapping  (Pattern 1, ×9)

**Symptom.** Appointment received (often visible/errored in Mirth), patient absent
from the worklist. Tickets: TKLS-9157, 9039, 3838, 9338, 8136, 8574, 9242, 1191, 9360.

**Three concrete root causes seen:**

1. **Stray whitespace in a mapping key/value** — incoming `Doctor` won't match stored
   `Doctor ` (TKLS-3838), or `AdmitSource` vs `Admit Source` (TKLS-9039); a leading/
   trailing space in Clinic/Status/Doctor (TKLS-9338).
2. **Wrong clinic code** — e.g. `130` mapped where the message carries `130EME`
   (TKLS-9157); PAS sending `OPE99S` instead of `OPE99SE` (TKLS-9360, upstream).
3. **Missing mapping entirely** — a worklist defined with no mappings broke generation
   globally until configured (TKLS-8136, "Stroke Hemianopia"); a clinic with no mapping
   row at all (TKLS-8574 "Newmarket OPD", TKLS-1191); a booking type the definition
   didn't accept (TKLS-9242 "Private - Cataract Surgery").

**Detection (read-only):**

```
-- whitespace offenders
SELECT id, definition_id, `key`, `value`
FROM   worklist_definition_mapping
WHERE  `key`   <> TRIM(`key`)
   OR  `value` <> TRIM(`value`);

-- (correlate) inbound appointment attributes with NO matching mapping value
-- → join recent inbound appointments/sessions against the mapping set and list
--   clinic codes / booking types that have no corresponding mapping row.
```

**Fix.** With `--fix`: `TRIM()` offending keys/values in a transaction; for missing
mappings, **report** the unmatched clinic codes/booking types for a human to add
(don't invent mapping values). After any change, hand off to `reprocess`.

**Automatable:** yes for whitespace (deterministic). Missing-mapping detection is
automatable; the *value* to add needs human confirmation.

---

### 3.2 `reprocess` — replay unmatched appointments  (Patterns 1, 5, and tail of 6/7)

**Symptom.** Mapping/config is now correct, but the patients booked *before* the fix
still aren't on the worklist — the original messages were dropped/errored. Tickets:
TKLS-9157 ("reprocessing the message has put the patient on the worklist"), 9039, 3838,
9110, and the thin 1185/1186 which were almost certainly this.

**Logic.**
1. Find appointments for `--clinic` in `[--from, --to]` that have **no** worklist
   instance / `WorklistPatient` row.
2. For each, re-run the worklist matcher against the **current** mappings (the same
   code path the inbound generator uses — reuse it, don't re-implement matching).
3. Under `--commit`, create the worklist rows; otherwise print what would be created.

**Automatable:** yes. This is the single highest-value action — it's the back half of
almost every Pattern-1 fix and the whole of the "thin data correction" cluster.

> Implementer note: prefer calling the existing generation/matcher service over raw
> INSERTs so future definition logic stays in one place.

---

### 3.3 `dedupe` — duplicate worklist instances  (Pattern 7, ×1: TKLS-9110)

**Symptom.** Two identical worklist instances generated seconds apart (generation ran
twice); messages match more than one clinic and patients don't show consistently.

**Detection:**

```
SELECT definition_id, scheduled_date, COUNT(*) AS n, MIN(id) AS keep_id
FROM   worklist            -- the instance table
GROUP  BY definition_id, scheduled_date
HAVING n > 1;
-- optional: only treat as dup if created_at within --window-seconds of each other
```

**Fix.** Keep the earliest instance, re-point/merge its `WorklistPatient` rows, delete
the duplicates, then `reprocess` the affected clinic/date. Transaction + dry-run
mandatory — this deletes rows.

**Automatable:** yes, with a conservative duplicate definition (same definition + date,
created within N seconds).

---

### 3.4 `deleteappointment` — stuck / cancelled appointment  (Pattern 8, ×1: TKLS-5597)

**Symptom.** A cancelled appointment keeps showing on the worklist, sometimes blocking
a rebooking. Fix in the ticket was a manual DB delete.

**Fix.** `--appointment=<id>`: remove the appointment row **and** its `WorklistPatient`
entry, in a transaction, after printing the patient/clinic/date for confirmation.

**Automatable:** semi. Keep it single-id and `--commit`-gated — never bulk-delete
appointments heuristically. (Ticket had weak confirmation; treat as the riskiest action.)

---

### 3.5 Generation / lookback window  (Pattern 3, ×2: TKLS-8658, 1900)

**Symptom.** Appointment exists but is booked beyond the worklist generation horizon
(TKLS-8658: extended 3→4 months) or the Mirth search window (TKLS-1900: only 4 weeks).

**Not a subcommand — a config value.** Surface the generation lookback as a documented,
read/settable setting rather than per-ticket code edits. A `worklistrepair diagnose`
run should flag "appointment date is outside the current N-month generation window" as
a likely cause so the engineer knows to widen it.

---

## 4. Out of scope (do NOT try to automate)

- **Pattern 2 — fixed in an OE release (×9).** TKLS-4165 (v9 pasv2), 2016 & 1666
  (v6.7.14, PR #9472 pathway/attendance race), 3027 (v7.0.8), 1129/1139/1128/1126,
  and 5377 (v9.1.10 eyedraw — not even a worklist bug). The fix is "upgrade"; nothing
  for a console command to do. `diagnose` could note the installed version vs the
  fix version, at most.
- **Pattern 4 — interface-channel / service-location config (×2).** TKLS-8630
  (service location "ETC OP"), TKLS-1893 (channel sending NHS numbers with spaces +
  historical cleanup). Needs human config judgement; the data cleanup half *could*
  reuse `reprocess` once the channel is fixed.
- **Pattern 6 — Mirth booking-type filter (×1, TKLS-2092).** Lives in the Mirth
  channel, not OE. `diagnose` should *flag* "appointment never reached OE — check the
  Mirth channel filter for this booking type" but can't fix it.
- **Pattern 9 — demo provisioning (×1, TKLS-7396).** Already solved by a cron
  (`populate_worklist_data.sh`); different purpose, leave as-is.

---

## 5. Build order (highest payback first)

1. **`reprocess`** + **`checkmappings --fix`** — together close Pattern 1 (×9) and the
   thin cluster (×2): the bulk of the desk's recurring worklist load.
2. **`diagnose`** — read-only front door so first-line can run 1 before escalating.
3. **`dedupe`**, then **`deleteappointment`** — lower volume, higher risk; ship behind
   `--commit` with loud dry-run output.

## 6. Cross-cutting requirements

- `--dry-run` default ON; `--commit` to apply. Every write wrapped in a transaction.
- Print a before/after diff and the affected ticket-relevant identifiers
  (patient hos_num, clinic code, definition id, dates) before committing.
- Log every applied repair (who/when/what) to the audit trail so a support reply can
  cite it — every ticket above closed on an explicit "confirmed working" comment.
- Never fabricate a mapping value or delete in bulk on a heuristic. Whitespace trims
  and single-id deletes are safe to automate; "what the correct clinic code is" is not.
