# OeStats card work - swap, gap-fill, devices/ingestion, sweep

Date: 2026-08-10. Scope: the 5-task plan (DB swap, injection_analysis gap-fill cards,
broken-card sweep, 10 card suggestions, device/ingestion cards).

## 1. Database swap (done)

The old `openeyes` (421,849 patients, 3.4M events, 62 GB) is back as `openeyes` and the
official sample DB is parked at `openeyes2` (2,284 patients). Schema-name swap via batched
`RENAME TABLE` (metadata-only) with view drop/recreate - minutes, no restore, no container
recreate. Reusable symmetric script: `/home/toukan/snail/scripts/swap-oe-dbs.sh` (rerunning it swaps
back). Its header documents the future zero-downtime alternative: write `/etc/openeyes/db.conf`
in the running containers (outranks env), grant, `apc_clear` - no stop at all.
Swapped back to the sample DB on request at 18:20 the same day (script `-y` run, ~1 min,
post-checks green) - keeper dataset parked at `openeyes2` again.

## 2. Migrations (nothing to run)

The migration heads match the sample DB. 13 migration rows were missing from the keeper DB's
`tbl_migration` history, but `yiic migrate` reports nothing pending: those rows were
history-only gaps (the schema changes are already present; the sample DB got the rows via a
fresh install path). No migration was executed against the keeper data.

## 3. oestats snapshot DB (provisioned)

`oestats` DB created in the db container; `db_oestats` override in the container's
`local/common.php` (host template `~/Temp10/local_common.php`); snapshot tables created.
- `yiic recordloginstats`: clean.
- `yiic recordmetricstats` first full run: 13m54s, zero step errors, all metrics recorded
  (the bulk was watermark backfill over `request_routine_execution`, 2.56M rows).
- Second run (after the new steps landed): 2m58s, zero errors - incremental watermarks make
  routine reruns cheap. Scheduling stays manual (dashboard "Record snapshot now" button or
  cron in the master container - decision open).

## 4. Card sweep and fixes

Code fixes shipped before the sweep:

1. `hl7_messages`: guarded with `hasTable()` - renders "source table not present" instead of 503.
2. `OeMainDbService::fetchDisplayNames()`: fixed the `user.username` join (usernames live on
   `user_authentication`); failures were silently swallowed before.
3. `DefaultController::actionCardData()`: `CDbException` no longer blanket-mapped to
   503 "Database unavailable" - missing table / lookup failure / connection failure are
   distinguished and logged.
4. Lookup (`resolveUniqueId`-style) failures now emit a `warning` field rendered as a badge
   instead of all-zero series that look like real data.
5. Case-rename of `OeStatsModule.php` / `components/OeStatsService.php` staged so fresh clones
   autoload (`core.ignorecase` was hiding it).
6. Tile titles in `views/default/index.php` aligned to `CardCatalog` (catalog is truth).
7. `medretina.oct_outcomes` renders 0 eyes because the source data has no OCT thickness values
   anywhere: `ophgeneric_assessment_entry` has 137,667 rows with `crt`/`cst`/`avg_thickness`/
   `total_vol` all NULL (only IRF/SRF flags, 4,819 rows). The imaging feed supplies images and
   device metadata, not quantitative measurements. The card now says so via a sublabel instead
   of an empty table. Not fixable in code; would need the ingest mapping extended upstream.

Sweep results (all 147 card-data endpoints as admin, real data):

- **147/147 endpoints return HTTP 200.** No 5xx anywhere - the error-mapping and hasTable
  fixes held up against the 62 GB dataset.
- **Latency**: median ~45ms (snapshot cards); slowest were `dna_rate` 5.6s (fixed - see below),
  `total_appointments` 896ms, `recorded_allergies` 846ms, `deleted_events` 829ms,
  `patients_by_ethnicity` 684ms. Everything except `dna_rate` is comfortably under the 5s bar.
- **Sweep-driven fixes applied:**
  1. `dna_rate` (5.6s live) converted to a snapshot metric (`event.dna_attendance`, new
     runStep using the monthly-series helper). The event table has no
     (event_type_id, event_date) composite index and adding one to the keeper dataset was out
     of scope, so the cost moves into the snapshot command.
  2. `events_by_consultant` was empty: only 52 of 320 firms carry `consultant_id`, and none of
     those hold events - the event-holding firms are consultant-NAMED ("Mr Haider",
     "» Letters Kelly", "Sioras Firm") with NULL consultant_id. The attribution step now falls
     back to the normalised firm name (title / "Letters" / "Firm" variants folded together).
  Post-fix re-sweep: `dna_rate` 92ms (snapshot, was 5,601ms live), `events_by_consultant`
  attributes 1,772,844 events, `event.dna_attendance` holds 1,799,696 events over 24 months.
  Final snapshot run: exit 0, zero step errors, ~2.5 minutes (incremental watermarks).
- **Correct empty states (working as designed, no action):** `event_drafts` (0 outstanding,
  explicit sublabel - drafts are transient), `session_duration` (needs accumulated login
  snapshots - provisioning started today), `hl7_messages` (guarded "source table not present"
  message), `med_retina_oct_outcomes` (sublabel explains the missing thickness data).
- **Data-empty for data reasons (reported, not seeded):** the referral/RTT family
  (`referrals_received`, `referrals_by_institution`, `rtt_*` - 8 cards; the keeper data
  contains no referral/RTT rows), `docman_daily` (no Docman output in this instance),
  `worklist_dna` (0 DNA letters in 24 months - DNA is recorded via appointment status here,
  which the fixed `dna_rate` card covers).
- Sweep false positives (numeric heuristic, payload actually rich): `version_history`,
  `installed_modules`, `payload_routines_top` - their values are formatted strings/dates.

Report-only findings (pre-existing, untouched pending a nod):

1. `views/default/placeholder.php` is dead code.
2. `assets/oestats.js` / `assets/oestats.css` are orphans (nothing registers them).
3. `CardCatalog::get()` rebuilds every card definition per request; fine at 147 keys, but a
   static cache would be a one-line win.

## 5. injection_analysis gap-fill cards (implemented)

Five new snapshot cards in the Medical Retina group (gap-fill against the existing 10
`med_retina_*` cards):

| Card | Metric | Content |
|---|---|---|
| Treated Cohort Demographics | `medretina.demographics` | Per condition: patients, eyes, bilateral, mean age at 1st injection, % female, top ethnicity, mean IMD decile |
| Age at First Injection | `medretina.age_at_first` | Age-band distribution per condition |
| First-line Drug by Condition | `medretina.first_line_by_condition` | First injected drug split per condition |
| Injection Volumes by Drug | `medretina.injections_by_drug` | Yearly injection counts, top 8 drugs, 15y window |
| Indicative Drug Spend | `medretina.drug_costs` | Yearly spend by drug from a configurable price map |

Notes:
- Drug prices live in `config/common.php` param `oestats_medretina_drug_prices` (indicative
  GBP list prices, override in local config). The card description says explicitly: scale and
  drug mix, not finance reporting. Cumulative estimated spend on this data: GBP 42.2M.
- IMD lookup: postcodes are normalised to the mapping table's `OUTWARD INWARD` format and
  CONVERTed to latin1 so the index is used (a bare utf8-vs-latin1 compare forced 2.6M-row
  scans). Coverage on this data: 97.4% of wet AMD eyes, 98.5% of DMO eyes carry an IMD decile.
- Cohort sizes recorded: 4,047 treated eyes (3,007 condition-eye demographic rows;
  wet AMD 2,142 eyes, DMO 857, BRVO 493, CRVO 352, others smaller).
- First-line check numbers: wet AMD Eylea 1,061 / Lucentis 667 / Faricimab 205. The 2026
  injection mix shows Afqlir (1,763) overtaking Eylea (943) - the biosimilar switch is visible.
- Drill-down from cards to patient line listings is documented in
  `docs/DATAPOINTS.md` ("Medical retina drill-down: from cards to patients") - cohort
  definition, first-injection matching, hospital-number resolution by identifier type, baseline
  VA window, and why line listings stay out of card endpoints.

## 6. Device and ingestion cards (implemented)

Eight new snapshot cards in the Ingestion & Devices group:

| Card | Metric | Headline numbers on this data |
|---|---|---|
| Device Fleet | `device.fleet` | 76,549 device-information events; CIRRUS HD-OCT 5000/6000 dominate (OPT), plus Kowa (OP), Pentacam (OT), CellChek (GM), 4Sight (OAM) |
| Device Activity by Manufacturer | `device.activity` | 76,523 events in 24m window |
| Device Software Versions | `device.software_versions` | 12 manufacturer/model/version combos - patch drift visible (two CIRRUS 6000 builds live) |
| DICOM Import Outcomes | `ingest.dicom_outcomes` | 36,224 success / 1,821 failed (95.2%); queue funnel 36,187 success / 7,799 failed |
| Payload Routine Activity | `ingest.routine_activity` | 1.88M executions in window |
| Payload Routines League Table | `ingest.routines_top` | 2.02M requests lifetime; DICOM_SEED 304k, OPTOS pair 157k each, GENERIC_PAS_API 145k |
| Imported Biometry | `ingest.biometry` | 14,665 lifetime, 13,063 linked (89.1%), Carl Zeiss only |
| Automated Event Sources | `ingest.sources` | 89,237 automated events; EventCreator 42.9k, Not recorded 11.3k, worklist drug admin 10.8k, optician 8.1k |

Device volume is counted from `et_ophgeneric_device_information` (element table), not the
`is_automated` flag (only 275 of 85,110 device events carry it). "Last seen" uses
`event.event_date` (the element's `created_date` is anonymised to 1901 in this data).

## 7. Ten suggested new cards (not implemented)

1. **Injection-interval adherence** - actual gap between consecutive injections per eye vs the
   4-20-week grid, split by drug. Directly answers "are we under-treating"; the interval data
   is already in `v_patient_intravitreal_injections` (185k+ injections) and no card shows it.
2. **Batch traceability completeness** - % of injections with batch number + expiry recorded,
   plus administrations within 30 days of expiry. Medico-legal requirement; the columns exist
   on the injection element and are invisible today.
3. **VA recorded within 28 days of injection** - the clinical spec requires a VA close to each
   injection; % compliance by month catches drift in clinic discipline
   (`et_ophciexamination_visualacuity`, 1.4M readings).
4. **Correspondence turnaround** - days from clinical event to letter sent
   (`ophcocorrespondence` + `event`, 554k correspondence events). GIRFT cares; long tails are
   invisible without it.
5. **Document delivery outcomes** - `document_output` success/failure by channel (post, Docman,
   email) at scale. A failed-delivery spike is a safety incident in waiting.
6. **Examination element usage league table** - events per `et_ophciexamination_*` element
   table (248 tables). Shows which parts of the product are actually used - deployment and
   training gold.
7. **Consultant activity mix** - events by user x event type for the top 30 of 658 users.
   Workload transparency; pairs with the existing workforce cards.
8. **Booking-to-operation lead time** - `ophtroperationbooking` (26k) to op note (20k) interval
   distribution by subspecialty; the RTT view from inside the theatre pipeline.
9. **DNA equity profile** - DNA rate by age band and IMD decile (25.7k DNA-flagged events + the
   IMD join built for the demographics card). Health-inequality reporting is increasingly
   commissioner-mandated.
10. **Second-eye cataract interval** - months between first- and second-eye cataract surgery
    per patient (20k op notes). A classic GIRFT metric absent from the current cataract group.

## Sync and git state

- Container module == `~/Temp10/oestats-test` (md5-verified on all changed files).
- All changes staged in `~/Temp10/oestats-test` git; diff shown in session. No commit, no push.
