# Designing efficient OpenEyes queries and relationships

Use the [capture-to-validation workflow](oe-query-optimization.md) to measure
changes and the [EXPLAIN guide](oe-query-explain.md) to read their plans.
Examples below use actual OpenEyes models and query structures. Proposed
rewrites and indexes require result-equivalence and workload checks.

## Sargability: give the index something it can find

An index is an ordered directory. A sargable condition gives it a value or an
interval to look up. A non-sargable condition asks MariaDB to calculate something
from candidate rows before knowing whether they match.

A function depending on a column can therefore cost work per candidate row and
prevent a direct lookup on the ordinary index. That is different from computing
a constant once. It is also different from formatting six already-selected rows
for display. Optimizer rewrites and indexed generated columns create exceptions;
"functions are always bad" is not a correct rule.

| Risky shape | Better starting point | Qualification |
|---|---|---|
| `DATE(t.last_modified_date) = DATE(:day)` | Bare-column half-open date range | MariaDB 11.1+ has a restricted DATE/YEAR rewrite |
| `DATE_FORMAT(column, ...) = :text` | Compare compatible typed bounds | Display formatting can stay in SELECT/PHP |
| `column + 1 = :value` | `column = :lookup_value` calculated once | Preserve numeric types and overflow semantics |
| `LIKE '%fragment%'` | Prefix lookup or a deliberately chosen search model | Changing substring search to prefix search changes results |
| Text key compared to a number | Bind the correct text type | Implicit conversion can defeat lookup and alter equality |
| Join followed by DISTINCT to hide duplicates | Correct the join or use EXISTS for an existence question | Preserve intentionally repeated rows |

The [date guide](oe-query-patterns-sorting-and-date-predicates.md) shows a complete
hotlist query, the exact CMP/constant limitation and the PHP rewrite.

## Indexes are different kinds of things

"Functional", "B-tree", "unique" and "covering" describe different properties.
One index can be a composite, unique B-tree over generated values.

| Structure or search method | Extremely simple meaning | Appropriate use |
|---|---|---|
| B-tree | Sorted directory supporting lookups and intervals | Normal InnoDB equality, date range and ordering queries |
| Hash | Bucket selected from an exact key | Equality access on engines supporting HASH; not sorted ranges |
| FULLTEXT | Directory of words/tokens | Deliberate text-search semantics; not a drop-in substring search |
| SPATIAL / R-tree | Directory of geometric areas | Spatial predicates on supported geometry columns/engines |
| VECTOR | Similarity search for vectors on supported versions | Specialized similarity workloads, not ordinary hotlist filtering |

MariaDB's [CREATE INDEX syntax](https://mariadb.com/docs/server/reference/sql-statements/data-definition/create/create-index)
lists supported index families; support depends on engine and version.
InnoDB's internal adaptive hash mechanism is not an application-created HASH
replacement for its normal B-tree indexes.

| Property | Meaning | Cost or limitation |
|---|---|---|
| Primary key | Identity of a row; InnoDB stores the row with this key | Wide primary keys also widen secondary indexes |
| Secondary index | Another route to the row | May require a primary-key row fetch |
| Unique index | Enforces unique non-NULL key combinations | MariaDB normally permits multiple NULL-containing keys |
| Composite index | Several columns in one ordered directory | Column order determines useful lookup prefixes |
| Prefix index | Only the beginning of a text column is indexed | Cannot fully cover the original long value |
| Covering index | Contains the values a particular table access needs | Coverage depends on the query; wide indexes cost storage/writes |
| Generated-column index | Index on a value calculated from the row | Expression and version constraints apply |

InnoDB secondary entries contain the primary key. Selecting only the primary
key and secondary-key values can therefore avoid full-row lookups. Covering does
not mean cheap if the query walks most of the index.
[Composite and covering indexes](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/optimization-and-indexes/compound-composite-indexes)
explain these access paths.

### Choose composite columns from the query

For a closed hotlist on one day, start with
`(created_user_id, is_open, last_modified_date)`: equalities first, then the
timestamp range and matching timestamp order. The order of the two equality
columns should also consider other queries; "most selective first" is not a
universal answer when both are supplied.

Columns after the first range usually cannot further narrow one contiguous
seek interval. They can still contribute filtering, coverage or ordering in
particular plans. Inspect the actual key parts instead of assuming the entire
index is used.

An index beginning with `last_modified_date` can find a day but may read that
day across all creators. Separate creator and date indexes are not equivalent
to one correctly ordered composite. Index merge is another possible plan, not
a guarantee of the same cost.

The no-date open-hotlist query also uses creator, status and timestamp order,
so consider it when assessing the same candidate. Other lookups by patient may
need a different path. Check equivalent indexes before adding another; check
write overhead and dependent foreign keys before removing one.
[MariaDB's index design guide](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/optimization-and-indexes/building-the-best-index-for-a-given-select)
provides the equality/range/order starting method.

## Functional indexes in MariaDB

The supported approach on the MariaDB versions discussed here is a generated
column plus an index. Do not copy direct expression-index syntax from another
database. For a deterministic DATETIME-to-DATE expression, a candidate is:

```sql
ALTER TABLE user_hotlist_item ADD COLUMN modified_day DATE AS (DATE(last_modified_date)) VIRTUAL, ADD INDEX idx_hotlist_creator_open_day_modified (created_user_id, is_open, modified_day, last_modified_date);
```

Then compare `modified_day = :day` with creator and status equalities. The final
timestamp key can support timestamp ordering within that day.

Both VIRTUAL and PERSISTENT generated columns can be indexed. VIRTUAL avoids
storing an extra base-row value, but its index still occupies space and must be
maintained. Generated indexed expressions must obey determinism and supported
expression rules. Do not encode an unstable session timezone as though it were
a permanent clinical-date definition.
[Generated columns](https://mariadb.com/docs/server/reference/sql-statements/data-definition/create/generated-columns)
documents these constraints.

Before MariaDB 11.8, queries generally need to name the generated column.
MariaDB 11.8 can recognize matching indexed virtual-column expressions in WHERE;
the expression must match. That does not mean every function, parameter shape,
ORDER BY or GROUP BY automatically uses the generated index.
[Virtual-column optimizer support](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/virtual-column-support-in-the-optimizer)
describes the version-dependent behaviour.

For a day filter over a timestamp, ordinary timestamp bounds are usually the
simpler design. Use a derived-date index when the derived value is itself a
repeated access requirement, not merely to avoid changing one PHP predicate.

## UNION ALL is not inherently expensive

UNION ALL appends branch results and retains duplicates. UNION without ALL
normally removes duplicates, which introduces additional work. MariaDB can
execute many UNION ALL queries without materializing the union.
[MariaDB UNION](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/set-operations/union)
documents this distinction.

The real OpenEyes `EventDraftWarningLoader::getDraftData()` combines drafts from
`event_draft` and correspondence events carrying a Draft issue. Its structural
shape is shown below; branch SELECTs are deliberately omitted, so this is a
diagram of the query, not runnable SQL:

```text
filtered event_draft rows + filtered event/event_issue/issue rows -> UNION ALL -> ORDER BY event_draft_date, event_id -> LIMIT/OFFSET
```

The expensive parts can be scanning too many rows in either branch, multiplying
rows through issue joins, globally sorting the combined rows, or discarding a
large offset. An outer LIMIT does not automatically let every branch stop after
that many rows.

Inspect each branch plan and the combined plan. Preserve duplicates unless the
feature says otherwise. Replacing ALL with DISTINCT as a speed fix usually adds
work and can change results. Splitting an OR into UNION ALL also duplicates rows
when both branches match, unless branch overlap is deliberately handled.

## Why ORDER BY and GROUP BY get expensive

ORDER BY arranges rows; GROUP BY combines rows with equal grouping values.
Both become costly when many input rows or wide intermediate values reach them.

| Situation | Cost | Design response |
|---|---|---|
| Index supplies required order after fixed equalities | Walk ordered entries, possibly stopping early | Check that join order and direction preserve it |
| No compatible ordering path | Compare and sort candidates | Reduce candidates/width before sorting where equivalent |
| Small LIMIT with filesort | May use a small priority queue, but still inspect input | Do not assume LIMIT avoids the scan |
| Deep OFFSET | Find and discard many earlier results | Consider keyset pagination with a stable unique ordering |
| GROUP BY over large history | Read and aggregate many inputs | Filter first, index appropriate group keys, consider summaries |
| One-to-many join before grouping | Multiply rows, memory and possibly counts | Aggregate the intended entity or preaggregate branches |

A broad ordered index scan can cost more than a selective scan plus a small
sort. The goal is less work, not an empty Extra column.

For a hotlist count by status, an illustrative query is:

```sql
SELECT is_open, COUNT(*) AS item_count FROM user_hotlist_item WHERE created_user_id = :user_id GROUP BY is_open ORDER BY NULL;
```

A creator/status index can help read the relevant entries without fetching
unneeded columns. Counting still generally requires processing the qualifying
entries. MariaDB normally orders grouped output by grouping expressions;
`ORDER BY NULL` removes that ordering requirement when the application does
not need it. It does not remove aggregation work.
[MariaDB GROUP BY](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/group-by)
explains the semantics.

Do not select arbitrary non-grouped columns alongside MAX and expect those
columns to come from the row with the maximum. The result is undefined where
permitted, or rejected under ONLY_FULL_GROUP_BY.

## Select the minimum that the feature needs

The [full hotlist example](oe-query-patterns-sorting-and-date-predicates.md)
selects 48 fields across hotlist, patient and contact. Some screens may require
them; the count alone does not prove a problem. Inspect what the rendering path
actually reads.

| Choice | Benefit | Cost |
|---|---|---|
| Narrow explicit selection | Fewer transferred bytes and hydrated values; may cover an index | Must include required identity/relation fields |
| Full ActiveRecord selection | Convenient complete model | More network, PHP memory and possibly row/page work |
| SELECT * for a bounded one-row detail view | Simplicity can be reasonable | Future columns silently enlarge the result |
| SELECT * across an unbounded list/join | Little code to write | Often much more work than the screen needs |

Removing projected columns does not automatically reduce rows examined. InnoDB
still reads pages, not individual scalars. Savings in network and PHP memory
can be real even when physical page reads remain similar.

In Yii, keep primary keys and foreign keys needed to build relations. Do not
hydrate a partial model and later assume every attribute was loaded. Test
getters and templates, because apparently unused fields may be read indirectly.
For exports, request required columns and process bounded batches rather than
loading an entire history into PHP.

## N+1: a cheap lookup repeated is no longer cheap

A hotlist renderer needs each item's patient and that patient's contact. Loading
the hotlist once and lazily loading both relations for every item can approach
`1 + 2N` queries. Shared references or caches can reduce that count; measure it.

If 100 items trigger 200 extra round trips, an illustrative 2 ms of per-trip
latency adds about 400 ms before useful database work. It is not an assumption
about a deployment's actual network. Every call also incurs driver, execution,
result handling and often ActiveRecord hydration work.

OpenEyes already uses this mitigation in `getHotlistItems()`:

```php
return $this->with('patient', 'patient.contact')->findAll($criteria);
```

Keep that benefit when changing date predicates or projections. In the toolbar,
test whether query count stays bounded as the list grows.

Eager loading is not "join everything". Several one-to-many relations can
multiply result rows enormously. Fetch the page's root IDs, batch-load children
with bound ID lists, and attach them in memory when that avoids a cross product.
Use EXISTS when only existence is needed; use an aggregate when only a count is
needed. A few bounded batch queries can be cheaper than one huge join.

## Normal forms: model facts once, then plan the reads

Normalization prevents contradictions when inserting, updating or deleting
facts. It is not a guarantee that every report will be cheap.

| Form | Simple rule | OpenEyes-shaped example |
|---|---|---|
| First normal form | One value of the intended kind per cell; no repeating groups | Child rows for multiple risks, not risk_1/risk_2 columns or an ID list |
| Second normal form | Non-key facts depend on the whole candidate key | Risk name belongs to risk, not to each patient/risk association |
| Third normal form | Non-key facts do not depend on another non-key fact | Contact facts belong to contact, referenced by patient |
| BCNF | Every determinant is a candidate key | Check alternate identifiers do not imply conflicting ownership |
| Fourth normal form | Separate independent multiple-valued facts | Independent patient lists should not require every pair combination |
| Fifth normal form | Remove redundancy caused by valid join dependencies | Specialist multi-party relationships need explicit business rules |

These are design examples, not a certification that the entire OpenEyes schema
satisfies each form. Candidate keys and real dependencies determine that.
[MariaDB normalization guidance](https://mariadb.com/docs/general-resources/database-theory/database-normalization/database-normalization-overview)
explains why avoiding update anomalies matters.

Before adding relationships, write the required reads: one patient's history,
a page of patients, latest per patient, daily totals, audit reconstruction.
Estimate how much history each read must visit. An ordinary view packages a
query; it does not store a precomputed answer or gain its own persistent index.

## Groupwise maximum: the latest row for every patient

"Find the maximum date" is easy. "Return the event belonging to the latest date
for every patient, with correct ties and deletions" is a different problem.

OpenEyes' `latest_history_risk_examination_events` uses this anti-join shape:

```sql
SELECT t1.event_id, t1.patient_id FROM history_risk_examination_events t1 LEFT JOIN history_risk_examination_events t2 ON t1.patient_id = t2.patient_id AND (t1.event_date < t2.event_date OR (t1.event_date = t2.event_date AND t1.created_date < t2.created_date)) WHERE t2.patient_id IS NULL;
```

It keeps a row only when no later row for that patient can be found. Equal
event_date and created_date values are tied winners. The underlying history view
joins the risk element to event, then event to episode for patient_id. The
history view also filters deleted events and episodes; confirm the deployed
definition when working with older schemas.

The patient grouping key is on episode; ordering keys are on event; risk-element
membership is on another table. One ordinary composite index cannot span those
tables. Expanding the history view twice can create substantial join and
comparison work. Restricting a query to one patient can be much cheaper than
finding winners for everyone.
[MariaDB groupwise maximum](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/groupwise-max-in-mariadb)
explains the problem and why tied winners matter.

### Candidate rewrite for one patient's latest risks

If the existing timestamps are non-NULL and the view's filtering semantics are
preserved, a candidate retaining tied winners is:

```sql
SELECT event_id, patient_id FROM (SELECT event_id, patient_id, RANK() OVER (PARTITION BY patient_id ORDER BY event_date DESC, created_date DESC) AS latest_rank FROM history_risk_examination_events WHERE patient_id = :patient_id) ranked WHERE latest_rank = 1;
```

RANK gives equal ordering values the same rank. ROW_NUMBER instead chooses
distinct row numbers; use it only when the feature requires a single winner
and specifies a deterministic tie-breaker.
[MariaDB RANK](https://mariadb.com/docs/server/reference/sql-functions/special-functions/window-functions/rank)
defines that distinction.

Do not paste this in as a guaranteed faster replacement. The window may sort or
materialize. Compare actual work and result multiplicity. NULL ordering differs
from the anti-join's three-valued comparisons, so audit NULLs first. Event dates
and creation dates must be interpreted separately: the largest event ID is not
necessarily the latest clinical event.

Filtering by patient before ranking is safe for a "latest for this patient"
question because it removes other complete groups. Filtering to rows that have
a particular risk before ranking changes the question to "latest event with
that risk". That can resurrect an old risk when the latest event records its
absence.

For all patients, compare a global window approach, carefully indexed
aggregate-and-join approaches, and the existing anti-join on representative
history. MAX(event_date) and MAX(created_date) taken independently may belong to
different rows. Preserve the lexicographic order and all intended ties.

### Think ahead when creating the schema

1. Decide the history grouping key, clinical ordering keys, tie policy and
   deleted/superseded behaviour before choosing tables.
2. Ensure foreign-key lookup paths exist. If group and ordering keys live on
   one history table, evaluate a composite beginning with the group key.
3. If keys live across tables, budget for the joins. Test one-patient and
   population-wide reads separately.
4. If "current state" is a dominant read, consider a maintained projection or
   latest-event pointer while preserving canonical history.
5. Specify how that projection handles edits to old events, backdated entries,
   deletion/restoration, concurrent writes and ties. Define transactional or
   explicit eventual consistency, reconciliation and rebuilding.

A projection trades extra write work and consistency responsibilities for
cheaper reads. Normalized history remains valuable for audit and correctness.
Do not duplicate patient or clinical facts merely to make one EXPLAIN label
look better.
