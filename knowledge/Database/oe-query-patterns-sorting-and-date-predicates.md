# Handling dates efficiently in OpenEyes

Part of the OpenEyes query-efficiency series:
[optimization workflow](oe-query-optimization.md),
[EXPLAIN and index access](oe-query-explain.md),
[query and relational design](oe-query-design.md), and
[temporal data and storage](oe-temporal-data.md).

## Keep the date column available to the index

Sargable means the database can use a condition to find a small part of an index.
Think of opening a diary at the required day instead of reading every entry and
calculating which day it belongs to.

For a timestamp column, express a day as "at or after its start, and before the
next day's start":

```sql
WHERE t.last_modified_date >= :day_start AND t.last_modified_date < :next_day_start
```

Calculate both boundaries once in PHP. Keep the column bare in SQL. This gives
MariaDB a direct interval to search, includes fractional seconds at the end of
the day, and works before the DATE/YEAR optimizer rewrite was introduced.

## A complete OpenEyes example: the closed hotlist

`UserHotlistItem::getHotlistItems()` loads items by creator, open/closed status
and optional date, with their patient and contact. This is the full query shape,
retaining all selected fields and Yii aliases. The user and day are parameters:

```sql
SELECT `t`.`id` AS `t0_c0`, `t`.`patient_id` AS `t0_c1`, `t`.`is_open` AS `t0_c2`, `t`.`user_comment` AS `t0_c3`, `t`.`last_modified_user_id` AS `t0_c4`, `t`.`last_modified_date` AS `t0_c5`, `t`.`created_user_id` AS `t0_c6`, `t`.`created_date` AS `t0_c7`, `patient`.`id` AS `t1_c0`, `patient`.`dob` AS `t1_c1`, `patient`.`gender` AS `t1_c2`, `patient`.`last_modified_user_id` AS `t1_c3`, `patient`.`last_modified_date` AS `t1_c4`, `patient`.`created_user_id` AS `t1_c5`, `patient`.`created_date` AS `t1_c6`, `patient`.`gp_id` AS `t1_c7`, `patient`.`date_of_death` AS `t1_c8`, `patient`.`practice_id` AS `t1_c9`, `patient`.`ethnic_group_id` AS `t1_c10`, `patient`.`contact_id` AS `t1_c11`, `patient`.`archive_no_allergies_date` AS `t1_c12`, `patient`.`archive_no_family_history_date` AS `t1_c13`, `patient`.`archive_no_risks_date` AS `t1_c14`, `patient`.`deleted` AS `t1_c15`, `patient`.`is_deceased` AS `t1_c16`, `patient`.`is_local` AS `t1_c17`, `patient`.`patient_source` AS `t1_c18`, `patient`.`primary_institution_id` AS `t1_c19`, `contact`.`id` AS `t2_c0`, `contact`.`nick_name` AS `t2_c1`, `contact`.`primary_phone` AS `t2_c2`, `contact`.`mobile_phone` AS `t2_c3`, `contact`.`title` AS `t2_c4`, `contact`.`first_name` AS `t2_c5`, `contact`.`last_name` AS `t2_c6`, `contact`.`maiden_name` AS `t2_c7`, `contact`.`qualifications` AS `t2_c8`, `contact`.`email` AS `t2_c9`, `contact`.`last_modified_user_id` AS `t2_c10`, `contact`.`last_modified_date` AS `t2_c11`, `contact`.`created_user_id` AS `t2_c12`, `contact`.`created_date` AS `t2_c13`, `contact`.`contact_label_id` AS `t2_c14`, `contact`.`active` AS `t2_c15`, `contact`.`national_code` AS `t2_c16`, `contact`.`fax` AS `t2_c17`, `contact`.`created_institution_id` AS `t2_c18`, `contact`.`pas_id` AS `t2_c19` FROM `user_hotlist_item` `t` LEFT OUTER JOIN `patient` `patient` ON (`t`.`patient_id` = `patient`.`id`) LEFT OUTER JOIN `contact` `contact` ON (`patient`.`contact_id` = `contact`.`id`) WHERE (t.created_user_id = :user_id AND t.is_open = 0 AND DATE(t.last_modified_date) = DATE(:day)) ORDER BY t.last_modified_date DESC;
```

The long projection is not what prevents the date from narrowing an ordinary
timestamp index. That issue is in this predicate:

```sql
DATE(t.last_modified_date) = DATE(:day)
```

MariaDB may find the creator's closed items using the beginning of an index,
then test their dates one by one. The index can still help. The wasted work is
reading the creator's history when only one day is needed.

## Which MariaDB DATE/YEAR rule does this miss?

MariaDB's [sargable DATE and YEAR rule](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/sargable-date-and-year)
applies from 11.1. Its documented shape is `DATE(indexed_date_col) CMP const_value`
or `YEAR(indexed_date_col) CMP const_value`.

| Requirement | Meaning | Hotlist example |
|---|---|---|
| `CMP` | Operator: `=`, `<=>`, `<`, `<=`, `>`, or `>=` | `=` is allowed; this rule is not broken |
| Indexed temporal field | DATE, DATETIME or TIMESTAMP column participating in an index | Inspect the deployed column and indexes |
| Constant operand | Suitable constant on the other side; sides may be reversed | `DATE(:day)` remains a function expression unless simplified |

SQL `CMP` and the internal comparison type are different things. The
[MariaDB 11.4.8 implementation](https://github.com/MariaDB/server/blob/mariadb-11.4.8/sql/opt_rewrite_date_cmp.cc#L96-L198)
requires the DATE comparison handler and a `basic_const_item()` on the opposite
side. A constant function expression can miss the latter check while it remains
an expression. Constant in meaning does not necessarily mean a simple constant
at this optimizer stage.

`DATE(column) = DATE('2001-02-03')` does not inherently fail the comparison-type
check: DATE versus DATE can use the DATE handler. The differentiator from
`DATE(column) = '2001-02-03'` is the wrapped constant, not the allowed `=`
operator. See [comparison-type selection](https://github.com/MariaDB/server/blob/mariadb-11.4.8/sql/sql_type.cc#L1863-L1917)
and [constant classification](https://github.com/MariaDB/server/blob/mariadb-11.4.8/sql/item.h#L1744-L1748).

Do not claim that every DATE call forces a scan. Exact server version, operand
types, parameter handling and other predicates matter. Compare the generated
SQL and bound values. The optimizer trace transformation
`date_conds_into_sargable` confirms a successful rewrite. An explicit interval
avoids relying on this particular transformation.

## The small PHP change

Replace the optional DATE predicate in `getHotlistItems()` with two bound
timestamp comparisons. This example assumes local wall-time storage in the
application's configured timezone and complete ISO calendar-date input:

```php
if ($date !== null) {
    $timezone = new DateTimeZone(Yii::app()->timeZone);
    $start = DateTimeImmutable::createFromFormat('!Y-m-d', $date, $timezone);
    if (!$start || $start->format('Y-m-d') !== $date) {
        throw new InvalidArgumentException('Expected a valid date in YYYY-MM-DD format.');
    }
    $next = $start->modify('+1 day');
    $criteria->condition .= ' AND t.last_modified_date >= :day_start AND t.last_modified_date < :next_day_start';
    $criteria->params[':day_start'] = $start->format('Y-m-d H:i:s');
    $criteria->params[':next_day_start'] = $next->format('Y-m-d H:i:s');
}
```

Keep the existing creator/status parameters, eager loading and ordering. Decide
explicitly whether empty input means "no filter" or a validation error.

For UTC storage, construct both midnights in the timezone defining the requested
day, then convert each to UTC before binding. Do not add 86,400 seconds to the
first UTC boundary: a local day can be shorter or longer. For a UTC-day filter,
construct the boundaries in UTC. For TIMESTAMP, also align the session timezone.
Check actual storage semantics before changing legacy behaviour; see
[temporal data](oe-temporal-data.md).

This is a PHP-generated SQL change. It does not repair invalid stored dates or
establish a missing timezone convention.

## Pair the predicate with an appropriate index

A candidate for this access pattern is:

```sql
CREATE INDEX idx_hotlist_creator_open_modified ON user_hotlist_item (created_user_id, is_open, last_modified_date);
```

Inspect `SHOW INDEX FROM user_hotlist_item;` for an equivalent index before
preparing a migration. The two equalities select a section of the index; the
date bounds select an interval inside it. A backward scan can also supply
`last_modified_date DESC` when the chosen join plan preserves that order.

| Predicate and available index | Possible work on the hotlist table |
|---|---|
| Wrapped date; creator/status prefix usable | Find the creator's closed items, then filter dates |
| Explicit range; only creator/status indexed | Still filter dates after the prefix lookup; PHP cannot create the missing index |
| Explicit range; creator/status/date composite | Seek directly to that day's entries |
| Wrapped date; composite supplies ordering | Avoid filesort but still read too much history if the date rewrite is missed |

The [ref-versus-range explanation](oe-query-explain.md#ref-and-range-in-the-hotlist)
shows why `range` can be better here: it can narrow the search to one day, whereas
`ref` may only fix the creator/status prefix. `ref` is excellent when its equality
lookup already finds very few rows. These labels are not a universal ranking.

An index belongs to one table. It cannot cover all the patient/contact fields
in this SELECT. Their primary-key joins may appear as `eq_ref`: at most one
matching row per incoming hotlist item.

## Does this always cause Creating sort index or Using filesort?

No. Date filtering and result ordering are separate jobs.

An index may supply the order while still reading too many rows. A selective
date range may need a sort if its access path cannot supply the order. A tiny
sort can be cheaper than a much larger ordered scan.

`Creating sort index` is a transient process state associated with internal
sorting work. It does not mean MariaDB is permanently adding a schema index.
`Using filesort` in EXPLAIN means sorting outside ordered index access; it does
not prove disk I/O. See the [EXPLAIN glossary](oe-query-explain.md#extra-in-plain-english)
and MariaDB's [filesort optimization](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/filesort-with-small-limit-optimization).

Prioritize frequent patterns that examine large amounts of history, spend
substantial total time, spill temporary work to disk or delay other requests.
A sort label alone does not establish priority.

## Date comparison patterns

These are predicates, not complete statements. Bound values must have types and
timezone meanings compatible with the column.

| Intent | Avoid relying on | Prefer |
|---|---|---|
| One day of DATETIME/TIMESTAMP | `DATE(recorded_at) = DATE(:day)` | `recorded_at >= :start AND recorded_at < :next_start` |
| One year of timestamps | `YEAR(recorded_at) = :year` across mixed MariaDB versions | `recorded_at >= :year_start AND recorded_at < :next_year_start` |
| Calendar fact stored as DATE | Wrapping both sides in DATE | `dob = :date_of_birth` |
| End of a day | `recorded_at <= '2001-02-03 23:59:59'` | `recorded_at < '2001-02-04 00:00:00'` |
| Adjacent intervals | Inclusive `BETWEEN :start AND :next_start` | Inclusive lower and exclusive upper bound |
| Age, timezone or formatting | Converting each stored value while filtering | Calculate compatible lookup boundaries once |

`BETWEEN` is sargable for suitable bare-column comparisons. Its problem in the
adjacent-day example is correctness: the upper bound is inclusive.

## Could a functional index help?

MariaDB supports indexing generated columns. A candidate design could derive a
DATE from `last_modified_date` and index creator, status, that date and, if needed,
the timestamp for ordering.

For the hotlist, the explicit interval and ordinary composite index are usually
the simpler starting point. Generated columns help when many queries need the
same derived value. They add index storage and write maintenance, and require
appropriate deterministic semantics. See
[generated-column indexes](oe-query-design.md#functional-indexes-in-mariadb).

## CI design for new date predicates

This is a design only. Detect risky new predicates without banning every
function call.

1. Use the repository's CI base/head comparison and inspect added or modified
   SQL predicates in PHP strings, criteria builders and SQL files.
2. Tokenize SQL fragments and identify row-dependent functions in WHERE and ON,
   including DATE, YEAR, DATE_FORMAT, CAST and CONVERT_TZ. Match column references,
   not just `DATE(`. Bound-constant calculations and SELECT formatting differ.
3. Report the location, predicate and suggested bare-column bounds. Dynamic SQL
   may require runtime capture. Comments and PHP date functions are not SQL.
4. Baseline existing findings. Warn on ambiguous cases; require an explained
   exception for deliberate predicates, generated-column indexes or a verified
   optimizer rewrite. Record the supported MariaDB version and plan evidence.
5. Test the guard against safe ranges, constants, projections, comments, dynamic
   fragments and wrapped columns. Separately test application results at
   boundaries, NULLs, invalid input and timezone transitions.

CI cannot infer deployment statistics or guarantee a particular access type.
It should prompt an efficient predicate and a reviewed index design.
