# `latest_*` examination views — deep analysis, EXPLAIN guide & cross-instance research kit

**Reference instance:** `openeyes` on `test-db-1` · MariaDB 11.8.8 · analysed 2026-06-26
**Companion script:** [`latest_views_diagnostic.sql`](./latest_views_diagnostic.sql) — run it on any instance to reproduce every number below.
**Scope:** the six views whose names begin with `latest_`.

---

## Contents

1. [TL;DR](#tldr)
2. [What these views do](#1-what-these-views-do)
3. [Why the data lives in separate tables](#2-why-the-data-lives-in-separate-tables)
4. [Why it's slow — root cause](#3-why-its-slow--root-cause)
5. [How to read the EXPLAIN / ANALYZE (the signatures)](#4-how-to-read-the-explain--analyze)
6. [The fix and how to verify it](#5-the-fix-and-how-to-verify-it)
7. [Strategy ladder](#6-strategy-ladder)
8. [Cross-instance research playbook](#7-cross-instance-research-playbook)
9. [Per-instance results template](#8-per-instance-results-template)
10. [Correctness & version notes](#9-correctness--version-notes)
11. [Observations / smells to raise](#10-observations--smells-to-raise)

---

## TL;DR

* Each `latest_*` view answers: **"for each patient, which is the most recent examination event of this type?"** — a **groupwise-max**.
* It is implemented with the **self-join anti-join** idiom (`LEFT JOIN same_view … WHERE t2 IS NULL`), over a second view layer (`*_examination_events`) that joins **three tables** (`et_ophciexamination_* → event → episode`). The anti-join materialises that 3-table join **twice** and compares the dates between the two copies.
* **Root cause of the slowness:** the **group key** `patient_id` lives on `episode`, the **sort keys** `event_date`/`created_date` live on `event`, and the **row identity** `event_id` lives on the `et_*` element table. Because group key and sort key are in *different tables*, **the one composite index that normally makes groupwise-max instant cannot be built** — which is exactly why the [rjweb groupwise_max](https://mysql.rjweb.org/doc.php/groupwise_max) tricks top out here. There is also **no index on `event.event_date` at all**, so the date comparison is done by reading rows and filtering in memory.
* **Per-patient access is already fast** (~1–2 ms): `patient_id = X` pushes down into the base `episode` scan. **The slow path is the whole-population scan** used by cohort / case search (`OECaseSearch`), which forces the groupwise-max to be computed for every patient at once.

### The win (measured on the reference instance)

| Wholesale `COUNT(*)` | Element rows | Current self-join | `RANK()` rewrite | Speed-up |
|---|---:|---:|---:|---:|
| `latest_history_risk_…` | 70 k | **77.7 s** cold / 7.23 s warm | **0.27 s** cold / **0.20 s** warm | **≈285× / 37×** |
| `latest_allergy_…` | 1.67 M | **did not finish in 150 s** (warm, killed) | **6.40 s** warm | **≥25×** (really far more) |

Per-patient (`WHERE patient_id = X`): current **1.74 ms**, window **0.58 ms** — *no regression*. Result sets **provably identical**.

**Recommendation:** replace the six `latest_*` view bodies with a `RANK()` window function ([Strategy 1](#6-strategy-ladder)). Pure DDL; no schema/app/write-path change; low clinical-safety risk.

---

## 1. What these views do

### 1.1 The two-layer view stack

```
latest_history_risk_examination_events      (layer 2: keep only the latest row per patient)
        └── history_risk_examination_events (layer 1: flatten element + event + episode)
                ├── et_ophciexamination_history_risks   the clinical payload (one row per element) → event_id
                ├── event                               the encounter                              → event_date, created_date, deleted, episode_id
                └── episode                             the course of care                         → patient_id, deleted
```

**Layer 1 — `*_examination_events`** flattens the spine to `(event_date, created_date, event_id, patient_id)`:

```sql
-- history_risk_examination_events
SELECT event.event_date, event.created_date, et.event_id, episode.patient_id
FROM et_ophciexamination_history_risks et
JOIN event   ON et.event_id = event.id
JOIN episode ON event.episode_id = episode.id
WHERE episode.deleted = 0 AND event.deleted = 0;
```

**Layer 2 — `latest_*`** keeps, per patient, the row with the greatest `(event_date, created_date)`:

```sql
-- latest_history_risk_examination_events
SELECT t1.event_id, t1.patient_id
FROM history_risk_examination_events t1
LEFT JOIN history_risk_examination_events t2
       ON t1.patient_id = t2.patient_id
      AND ( t1.event_date <  t2.event_date
         OR (t1.event_date =  t2.event_date AND t1.created_date < t2.created_date) )
WHERE t2.patient_id IS NULL;   -- t1 survives only if nothing later exists
```

Plain English: *return `t1` unless there is another row `t2` for the same patient that is strictly later.* Rows with no later sibling are "the latest". (Note: rows tied on **both** dates all survive — see [§9](#9-correctness--version-notes).)

### 1.2 The six views

| `latest_*` view | element table | `deleted` filter in layer 1 |
|---|---|---|
| `latest_allergy_examination_events` | `et_ophciexamination_allergies` | `episode.deleted=0 AND event.deleted=0` |
| `latest_history_risk_examination_events` | `et_ophciexamination_history_risks` | `episode.deleted=0 AND event.deleted=0` |
| `latest_socialhistory_examination_events` | `et_ophciexamination_socialhistory` | `event.deleted=0` only |
| `latest_familyhist_examination_events` | `et_ophciexamination_familyhistory` | **none** |
| `latest_history_medication_examination_events` | `et_ophciexamination_history_medications` | **none** |
| `latest_medication_examination_events` | `et_ophciexamination_history_medications` | **none** |

### 1.3 Who consumes them (and how)

| Pattern | Consumer | Filter | Cost today |
|---|---|---|---|
| **Per-patient** | `PcrRisk::getCannotLieFlat($patient_id)` (via `patient_risk_assignment`) | `WHERE patient_id = :pid` | ~1.7 ms ✅ |
| **Set of patients** | `PatientFlagsRepository::getPatientIdsWithRiskAssignments($ids)`; `Allergies_API::getPatientIdsWithPresentAllergies($ids)` | `WHERE patient_id IN (…)` | fast ✅ |
| **Whole population** | `OECaseSearch\…\PatientMedicationParameter::query()`, `FamilyHistoryParameter` | **no `patient_id`** (`JOIN patient p ON m.patient_id = p.id WHERE drug=…`) | **the slow path** ❌ |

Downstream views: `patient_risk_assignment` → `latest_history_risk_…`; `patient_medication_assignment` → `latest_medication_…`; `patient_family_history` → `latest_familyhist_…`; `socialhistory` → `latest_socialhistory_…`. Allergy has **no** downstream view — it is read directly in `Allergies_API.php`.

Case search builds patient cohorts by joining the whole `patient` table to these assignment views; that is where the groupwise-max is paid across the entire population.

---

## 2. Why the data lives in separate tables

OpenEyes is an **event-based clinical record**, deliberately normalised:

```
patient ─┬─ demographics, identifiers
         └─ episode ──── a course of care under a firm/subspecialty        owns: patient_id, deleted
               └─ event ──── one clinical encounter or document            owns: event_date, created_date,
                     │                                                            deleted, episode_id
                     └─ element  et_ophciexamination_<name>                 owns: the clinical payload, event_id
                                  (one table per element type)
```

Why the split is correct (and should stay):

1. **One event carries many element types.** A single examination event may hold allergies *and* risks *and* social history *and* medications (248 examination element tables exist). Recording the per-encounter facts (`event_date`, `deleted`, ownership) **once** on `event` avoids duplicating them into every element table.
2. **`event_date` is a property of the encounter, not the payload.** "When did this happen" (clinical date) vs "when was it typed" (`created_date`) belong to the event; the element only records *what*.
3. **`patient_id` is reached via the episode**, because care is owned per episode (per firm/subspecialty). `event` has **no** `patient_id` column — only `episode_id`.
4. **Elements are versioned and soft-deleted independently**; normalisation keeps history (`*_version`) and `audit` clean.

This is right for writes and clinical integrity — but it is **the direct cause of the read-time cost**, because the three facts groupwise-max needs are in three tables:

| groupwise-max needs | column | table |
|---|---|---|
| the **group** key | `patient_id` | `episode` |
| the **sort** key | `event_date`, `created_date` | `event` |
| the **row** identity | `event_id` | `et_ophciexamination_*` |

Two hard consequences:

* You must **join all three tables before ranking can even begin** — there is no single table to scan or to index for the answer.
* **You cannot build the index that normally makes groupwise-max O(groups).** The rjweb fix is a composite `(group, sort DESC)` index — here `(patient_id, event_date DESC, created_date DESC)` — letting the engine jump to one row per group. That index is **impossible** because the columns are not co-located. This is the ceiling on the rjweb "minor improvements," and the thing any real fix must design around (see [Strategy 3/4](#6-strategy-ladder)).

---

## 3. Why it's slow — root cause

For the **wholesale** scan, the anti-join does, **for every element row (`t1`)**, a walk of that patient's entire `episode → event → et` subtree looking for a *later* sibling (`t2`), and the date comparison is unindexed (no index on `event_date`), so it is evaluated by reading rows and filtering in memory.

On the reference instance, even the **smallest** view examines ~3.6 M rows to return 60 k (see the ANALYZE in [§4](#4-how-to-read-the-explain--analyze)). The cost grows with *events-per-patient*, so it is roughly **quadratic in how much history a patient has** — which is why allergy (1.67 M rows, long histories) doesn't finish in 150 s while risk (70 k) is "only" ~78 s cold.

Per-patient is fast only because `patient_id = X` is pushed into the base `episode` scan (`episode_1`, `ref: const`), collapsing the whole structure to one patient's handful of rows.

---

## 4. How to read the EXPLAIN / ANALYZE

This is the part to carry to other instances: **recognise the slow pattern and confirm the fast one from the plan alone.** Use `ANALYZE` (MariaDB) — it *executes* the query and adds the `r_rows` / `r_filtered` (actual) columns next to `rows` / `filtered` (estimated). `ANALYZE FORMAT=JSON … \G` gives the richest detail.

### 4.1 The SLOW signature — current self-join (wholesale, smallest view)

`ANALYZE SELECT * FROM latest_history_risk_examination_events;`

```
id table   type   key                ref                          rows  r_rows   r_filtered Extra
1  et      index  …hrisks_ev_fk      NULL                         70761 70673.00 100.00     Using index
1  event   eq_ref PRIMARY            openeyes.et.event_id         1     1.00      99.81     Using where
1  episode eq_ref PRIMARY            openeyes.event.episode_id    1     1.00     100.00     Using where
1  episode ref    episode_1          openeyes.episode.patient_id  2     4.15      94.32     Using where; Not exists   ← anti-join
1  event   ref    event_1            openeyes.episode.id          5    12.47      31.65     Using where               ← date compare in memory
1  et      ref    …hrisks_ev_fk      openeyes.event.id            1     0.01     100.00     Using index
```

**Tells, in priority order:**

1. **Each base table appears *twice*** (`et`, `event`, `episode` each listed two times) → it's a **self-join**. This alone identifies the groupwise-max-by-anti-join shape.
2. **`Extra: Using where; Not exists`** on the second `episode` → this *is* the `LEFT JOIN … WHERE t2 IS NULL` anti-join. `Not exists` = "stop at the first match" (a small mercy, not a fix).
3. **`Extra: Using where`** (not `Using index condition`) on the second `event`, whose `key` is `event_1 (episode_id)` → the `event_date`/`created_date` comparison is **not** index-supported; rows are read and filtered in memory. Confirm with [STEP 3b](#7-cross-instance-research-playbook): `event_date` is in no index.
4. **`rows` ≪ `r_rows`** on that step (here `5` → `12.47`) → the optimiser under-estimates the fan-out; the real per-patient event count is higher.
5. **Multiply `r_rows` down the loop** to get rows examined: `70673 × 4.15 × 12.47 ≈ 3.6 M` to return 60 k. The ratio *examined ÷ returned* (~60×) is the waste. On allergy it's far worse.

> Rule of thumb: **same table twice + `Not exists` + `Using where` on an unindexed date = the slow groupwise-max.** If you see that on any instance, this analysis applies.

### 4.2 The FAST signature — `RANK()` rewrite (wholesale)

`ANALYZE SELECT … RANK() OVER (PARTITION BY patient_id ORDER BY event_date DESC, created_date DESC) … WHERE rnk=1;`

```
id select_type table      type   key       ref                       rows  r_rows   Extra
1  PRIMARY     <derived2> ALL    NULL      NULL                      70761 70538.00 Using where                    ← rnk=1 filter
2  DERIVED     et         index  …ev_fk    NULL                      70761 70673.00 Using index; Using temporary   ← single window sort
2  DERIVED     event      eq_ref PRIMARY   openeyes.et.event_id      1     1.00     Using where
2  DERIVED     episode    eq_ref PRIMARY   openeyes.event.episode_id 1     1.00     Using where
```

**Tells:**

1. **Each base table appears *once*.** No self-join, no second subtree walk.
2. **Exactly one `Using temporary`** on the `et` line = the window function's sort/partition buffer. In `FORMAT=JSON` this is explicit: `window_functions_computation → sorts → filesort` with `sort_key: episode.patient_id, event.event_date desc, event.created_date desc`.
3. **`r_rows` collapses to `1.00`** on `event` and `episode` (PK `eq_ref` lookups) → rows examined ≈ `70 k + one sort`, ~50× fewer touches than the self-join.
4. A single `<derived2>` materialised once, then scanned with the `rnk = 1` filter.

### 4.3 The PUSHDOWN signature — per-patient must stay fast

The make-or-break for shipping a window-function *view*: does the optimiser push `patient_id = X` **through** the window partition into the base scan? Use `ANALYZE FORMAT=JSON … WHERE patient_id = X … \G` and look **inside** the materialised derived table:

```json
"table_name": "episode",
"access_type": "ref",
"key": "episode_1",
"used_key_parts": ["patient_id"],
"ref": ["const"],          ← patient_id pushed all the way down to the base episode scan
"r_rows": 8                ← only this patient's episodes are read
```

* **Good (pushdown works):** the inner plan *starts* at `episode` with `key=episode_1`, `ref=[const]`, tiny `r_rows`. Per-patient stays ~ms. This is what the reference instance (11.8.8) does.
* **Bad (pushdown fails):** the derived table is fully materialised (you'll see `r_rows` ≈ the whole element count) and the `patient_id = X` filter is applied *after* the window. If you see this on an older optimiser, **do not ship the view rewrite blind** — use a [fallback](#9-correctness--version-notes).

Because pushdown quality is **version-dependent**, re-run this probe ([STEP 6](#7-cross-instance-research-playbook)) on **every** instance.

---

## 5. The fix and how to verify it

Replace each `latest_*` body with a `RANK()` window over its *existing* inner view (so each keeps its own `deleted` filter untouched). Use **`RANK()`**, not `ROW_NUMBER()` — [§5.1](#51-how-rank-and-partition-by-work-here) explains the mechanics, [§9](#9-correctness--version-notes) the clinical-safety reason.

### 5.1 How `RANK()` and `PARTITION BY` work here

A **window function** computes a value over a set of rows *related to the current row* — its "window" — **without collapsing them** the way `GROUP BY` does. Every input row survives; the function just annotates each one with an extra column. That is the whole point here: we must identify each patient's latest row **and keep its `event_id`**. A `GROUP BY patient_id` with `MAX(event_date)` cannot do that — it collapses each patient to a single row and throws away *which* `event_id` the maximum belonged to. A window function ranks the rows in place, then we filter.

Read `RANK() OVER (PARTITION BY patient_id ORDER BY event_date DESC, created_date DESC)` in three parts:

* **`PARTITION BY patient_id`** — cut the rows into independent groups, one per patient. This defines the groups the way `GROUP BY` would, but it does **not** merge them: numbering restarts at 1 inside each partition and the rows stay separate. (With no `PARTITION BY`, the whole result is one window — every patient's rows ranked together, which is wrong here.) This is the direct expression of the self-join's `t1.patient_id = t2.patient_id` — "only compare a patient against themselves."
* **`ORDER BY event_date DESC, created_date DESC`** — inside each partition, sort newest-first, using `created_date` to break ties on the clinical `event_date`. This ordering is what *defines* "latest", and it is exactly the precedence the self-join encodes in `t1.event_date < t2.event_date OR (t1.event_date = t2.event_date AND t1.created_date < t2.created_date)`.
* **`RANK()`** — walk each sorted partition and number the rows 1, 2, 3, …, but **rows that are equal under the `ORDER BY` receive the same rank**, and the count then skips the gap (so a tie for first yields `1, 1, 3` — never `1, 1, 2`). The newest event in a partition is therefore rank 1; if two rows tie on *both* dates, **both are rank 1**.

The outer `WHERE rnk = 1` keeps exactly the top of each partition — one row per patient, or several when they tie for newest. Preserving those ties is why it must be `RANK()`, not `ROW_NUMBER()` (which force-numbers ties `1, 2, …` and would drop a genuinely-tied-latest row — [§9](#9-correctness--version-notes)). For the `= 1` filter alone, `DENSE_RANK()` would behave identically to `RANK()`; the rank gap after a tie never matters because we never look past 1.

Worked example — the same window over five rows for two patients, where rows 102 and 103 tie on **both** dates (this is real output from the reference engine, MariaDB 11.8.8):

| event_id | patient_id | event_date | created_date | `RANK()` | `DENSE_RANK()` | `ROW_NUMBER()` |
|---:|---:|---|---|---:|---:|---:|
| 102 | 1 | 2026-03-05 | 2026-03-05 14:00:00 | **1** | 1 | 1 |
| 103 | 1 | 2026-03-05 | 2026-03-05 14:00:00 | **1** | 1 | 2 |
| 101 | 1 | 2026-01-10 | 2026-01-10 09:00:00 | 3 | 2 | 3 |
| 202 | 2 | 2026-02-02 | 2026-02-02 11:00:00 | **1** | 1 | 1 |
| 201 | 2 | 2025-12-01 | 2025-12-01 11:00:00 | 2 | 2 | 2 |

`WHERE rnk = 1` returns rows **102 and 103** for patient 1 (*both* tied-latest kept — matching the anti-join) and **202** for patient 2. `ROW_NUMBER() = 1` would return only 102 and 202, silently discarding 103. Note the numbering restarts at 1 for patient 2 — that reset **is** the `PARTITION BY`. In the plan this whole step is the single `Using temporary` sort seen in the [fast signature](#42-the-fast-signature--rank-rewrite-wholesale).

### 5.2 The rewrite

```sql
CREATE OR REPLACE
ALGORITHM = MERGE   -- nudges the optimiser to merge the outer view & push predicates
VIEW latest_history_risk_examination_events AS
SELECT event_id, patient_id
FROM (
    SELECT event_id, patient_id,
           RANK() OVER (PARTITION BY patient_id
                        ORDER BY event_date DESC, created_date DESC) AS rnk
    FROM history_risk_examination_events
) z
WHERE rnk = 1;
```

[`latest_views_diagnostic.sql`](./latest_views_diagnostic.sql) **STEP 8** prints the exact `CREATE OR REPLACE` for *all* `latest_*` views found on the instance (it derives the inner view name by stripping `latest_`). Review, then run inside a migration.

**Verify before/after on each instance** (all in the kit):
1. **Plan** — STEP 4 shows the slow signature, STEP 5 the fast one.
2. **Pushdown** — STEP 6 confirms per-patient is not regressed.
3. **Correctness** — STEP 7 proves identical results (exact for small views; bounded-by-sample for big ones).

---

## 6. Strategy ladder

| # | Strategy | Effort | Risk | Wholesale | Per-patient | When |
|---|---|---|---|---|---|---|
| **1** | **`RANK()` window rewrite** (recommended) | low (DDL only) | low | 37–285× | unchanged (slightly better) | **do first** |
| 2 | Index housekeeping | low | low | minor | minor | alongside #1 |
| 3 | Denormalise `patient_id`+dates onto `et_*` + composite index | high | med (schema + sync) | sub-second even at allergy scale | index-only | if #1 insufficient at scale |
| 4 | Materialised "latest per patient" table, maintained by SystemEvent listeners | high | high (write-path + staleness + clinical-safety) | O(groups) | O(1) | if reads must be near-instant & slight staleness OK |

**Strategy 1 — window rewrite.** Dramatic wholesale win; no per-patient regression (pushdown verified); provably identical; pure DDL — no schema/app/write-path/`audit` impact. *Caveat:* add an `EXPLAIN`-based regression test so a future optimiser/flag change can't silently turn a per-patient lookup into a full scan.

**Strategy 2 — indexes.** Drop the **duplicate** `event` index (`event_1` and `idx_event_episode_id` are both just `(episode_id)`). No index can give the covering `(patient_id, event_date, created_date)` (cross-table) — housekeeping, not a fix.

**Strategy 3 — denormalise.** Add `patient_id`, `event_date`, `created_date` onto each `et_ophciexamination_*` row (or a slim companion table) and build `INDEX(patient_id, event_date DESC, created_date DESC, event_id)`. *Now* the rjweb composite-index groupwise-max applies. Cross-table generated columns aren't possible, so keep them in sync via the existing `ClinicalEvent*SystemEvent` listeners (cleaner than triggers). Needs clinical-safety review.

**Strategy 4 — materialise.** A real `latest_<x>(patient_id PK, event_id, …)` table updated incrementally on event save. Reads become a PK lookup. Highest effort/scrutiny; reserve for population-scale case search that must be sub-second.

**Path:** ship **1 (+2)** now; hold 3/4 in reserve.

---

## 7. Cross-instance research playbook

Run [`latest_views_diagnostic.sql`](./latest_views_diagnostic.sql) on each instance. Connection (per the `c-dblogin` skill):

```bash
# Local container (root):
docker exec -i <project>-db-1 bash -c \
  'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -A openeyes -t' < latest_views_diagnostic.sql

# RDS / no local DB container (app user), from inside the web container:
dblogin -t < latest_views_diagnostic.sql
```

What each step gives you, and what to record:

| Step | Question | Look for / record |
|---|---|---|
| **0** | Version & optimiser flags | `VERSION()` (window fns need ≥10.2; pushdown quality varies); `optimizer_switch` (`split_materialized`, `condition_pushdown%`) |
| **1** | Which `latest_*` views exist here? | the inventory + `inner_exists=1`; diff **view bodies** between instances (deleted-filter wording drifts by version) |
| **2** | How big is the spine? | `event`/`episode`/`patient` counts; **element-table sizes** (the biggest = worst offender, usually allergy) |
| **3** | Can an index help? | confirm **3b is empty** (`event_date` unindexed); note any **duplicate** `episode_id` indexes |
| **4** | Prove it's slow | the [slow signature](#41-the-slow-signature--current-self-join-wholesale-smallest-view); wall-clock; `rows` vs `r_rows` blow-up |
| **5** | Prove the rewrite is fast | the [fast signature](#42-the-fast-signature--rank-rewrite-wholesale); wall-clock |
| **6** | Does pushdown hold *here*? | the [pushdown signature](#43-the-pushdown-signature--per-patient-must-stay-fast) — `episode … ref=[const]`. **Critical per instance.** |
| **7** | Same results? | `in_cur_not_win = in_win_not_cur = patient_mismatch = 0` |
| **8** | Generate the fix | copy the printed `CREATE OR REPLACE` for a migration |

**Editing per instance:** STEP 4/5 default to `latest_history_risk_examination_events` (usually smallest, so `ANALYZE` finishes). If an instance lacks it, swap to the smallest from STEP 2b and update the inner-view name in STEP 5 (strip `latest_`). On very large instances use **STEP 7b (bounded-by-sample)** rather than 7a so you don't materialise the slow view in full.

**Timing tip:** run wholesale counts twice (cold vs warm) — first touch is dominated by buffer-pool misses. Quote both, or pin warm-vs-warm for a fair comparison. Cap the self-join with `SET STATEMENT max_statement_time=… FOR …`; a *cap hit* is itself a reportable result.

---

## 8. Per-instance results template

Copy one block per instance.

```
Instance: ____________________   OE version: ______   MariaDB: __________   Date: __________

STEP 0  optimizer_switch split_materialized / condition_pushdown: on / off
STEP 1  latest_* views present: ___ / 6        body deltas vs reference: ____________________
STEP 2  event=______  episode=______  patient=______
        biggest element table: ____________________ = ______ rows
STEP 3  event_date indexed? (expect NO): ____    duplicate episode_id index? ____
STEP 4  smallest view tested: ____________________
        wholesale current:  cold ______ s   warm ______ s   (or "cap hit at ___ s")
        r_rows examined ≈ ______  to return ______  (ratio __×)
        slow signature present? (same-table-twice + Not exists + Using where): Y / N
STEP 5  wholesale window:   cold ______ s   warm ______ s
        fast signature present? (each table once + one Using temporary): Y / N
        speed-up: ______×
STEP 6  test patient ______ (events ___)
        per-patient current ______ ms   window ______ ms
        PUSHDOWN holds? (episode ref=[const]): Y / N        ← gate for shipping the view rewrite
STEP 7  cur_rows=______  win_rows=______  in_cur_not_win=__  in_win_not_cur=__  mismatch=__
DECISION: ship Strategy 1 here?  Y / N     notes: ______________________________________
```

---

## 9. Correctness & version notes

**Reference-instance correctness** (`latest_history_risk_…`, exact set-difference):

| cur_rows | win_rows | in cur∖win | in win∖cur | patient mismatch |
|---:|---:|---:|---:|---:|
| 60 072 | 60 072 | **0** | **0** | **0** |

Identical *sets*, not just counts. Allergy independently returns the same `466 917` rows from both.

**`RANK()` vs `ROW_NUMBER()` — must use `RANK()`.** (Mechanics: [§5.1](#51-how-rank-and-partition-by-work-here).) The anti-join returns **all** rows tied on `(event_date, created_date)` (neither beats the other), so a patient can legitimately have >1 "latest" row. `RANK() = 1` reproduces that; `ROW_NUMBER() = 1` would keep exactly one and **silently change clinical results**. (`created_date` is `DATETIME`, second precision — ties are real, e.g. bulk/automated imports.)

**Version dependence — re-test per instance:**
* Window functions require **MariaDB ≥ 10.2** (OE v6–v10 run 10.6; v11–v26 run 11.8 — all fine).
* **Predicate pushdown through the window partition** is the part that varies. It is governed by optimiser features (`split_materialized`, condition pushdown into derived tables) that improved across 10.x→11.x. It works on 11.8.8 here. **Always run STEP 6** on each instance; if pushdown fails, the per-patient path would regress.
* **Pushdown fallback** (only if STEP 6 fails on some instance): keep the window rewrite for the wholesale consumers, but serve per-patient reads through a path that filters *before* ranking — e.g. a small stored function / inline-correlated form that takes `patient_id`, or `... FROM <inner_view> WHERE patient_id = X` then `ORDER BY event_date DESC, created_date DESC` with `RANK()`/`LIMIT`-style top-tie logic. (Not needed on the reference instance.)

---

## 10. Observations / smells to raise

Surfaced during analysis; **not changed** (clinical-safety — need an explicit decision):

1. **Inconsistent `deleted` filtering** across the six inner views (allergy & risk filter both `episode` and `event`; family-history, history-medication & medication filter **nothing**; social-history filters `event` only). Where it's absent, a *deleted* event can be returned as "latest." Migration `m260604_123404_filter_examination_event_views_by_deleted_state` appears to be standardising this and looks **incomplete**. The window rewrite preserves each view's current filter exactly — fix the filters separately and deliberately.
2. **`medication_examination_events` and `history_medication_examination_events` are byte-for-byte identical** (both read `et_ophciexamination_history_medications`). One is likely a redundant alias.
3. **Duplicate index on `event`:** `event_1` and `idx_event_episode_id` are both just `(episode_id)` — drop one.
4. **No index on `event.event_date`** (or `created_date`) anywhere — expected given the design, but it's why the date comparison is in-memory.

---

## Appendix — how the reference numbers were taken

* **Wholesale:** `SELECT COUNT(*) FROM <view>` vs the inlined `RANK()` equivalent; cold = first touch, warm = repeated; `SET STATEMENT max_statement_time=…` to cap the self-join (allergy hit the 150 s cap).
* **Per-patient:** `ANALYZE FORMAT=JSON … WHERE patient_id = 2521383` (a patient with 16 risk events); checked for `episode key=episode_1 ref=const`.
* **Set equality:** both result sets materialised into temp tables in one session and diffed both directions + on `patient_id`.
* **Counts / indexes / DDL:** `information_schema`. All reproducible via [`latest_views_diagnostic.sql`](./latest_views_diagnostic.sql).
