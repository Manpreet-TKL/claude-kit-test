# Reading MariaDB EXPLAIN for OpenEyes

Use this alongside the [optimization workflow](oe-query-optimization.md) and
[date handling](oe-query-patterns-sorting-and-date-predicates.md). A plan tells
you how MariaDB intends to find rows. It is not a stopwatch.

## Start with the actual statement

Capture generated SQL and its parameter values. Preserve joins, predicates,
ordering, limit, column types and collations. A simplified query may get a
different plan. These diagnostic statements inspect the hotlist's metadata:

```sql
SHOW CREATE TABLE user_hotlist_item;
SHOW INDEX FROM user_hotlist_item;
```

Prefix the complete captured SELECT with `EXPLAIN` or `EXPLAIN FORMAT=JSON`.
Resolve Yii placeholders through binding or controlled representative literals;
`:user_id` is not standalone MariaDB client syntax.

For a query already running, substitute its numeric connection ID:

```sql
SHOW EXPLAIN FOR 123;
```

This can inspect the active plan without submitting the expensive SELECT again.
The query can finish before inspection. Account visibility and privileges still
apply. [MariaDB EXPLAIN](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/analyze-and-explain-statements/explain)
also explains metadata locking and the distinction from execution.

## Read the columns

| Column | Extremely simple meaning |
|---|---|
| `id` | Query-block label; not elapsed time or a step counter |
| `select_type` | Kind of query block |
| `table` | Table alias or intermediate result being read |
| `type` | How rows are found |
| `possible_keys` | Candidate lookup indexes |
| `key` | Index actually chosen |
| `key_len` | Bytes of key used for access; not index size |
| `ref` | Values or earlier columns supplying lookup keys |
| `rows` | Estimated rows read per lookup/scan |
| `filtered` | Estimated percentage surviving an additional condition, where shown |
| `Extra` | Other work and shortcuts |

In a simple nested-loop query block, follow table access from top to bottom.
Derived tables, materialization and subqueries have their own blocks: do not
flatten them into one execution sequence. JSON exposes the hierarchy and
`used_key_parts`; inspect that when a composite index is only partly useful.

Common block labels:

| `select_type` | Meaning |
|---|---|
| `SIMPLE` | No separate subquery or set-operation block |
| `PRIMARY` | Outermost block |
| `SUBQUERY` | Nested SELECT |
| `DEPENDENT SUBQUERY` | Nested SELECT depends on outer values |
| `UNCACHEABLE SUBQUERY` | Result cannot be reused in the usual subquery cache |
| `DERIVED` | SELECT used as a table |
| `MATERIALIZED` | Subquery result stored for later use |
| `LATERAL DERIVED` | Derived work performed for relevant outer keys |
| `UNION`, `DEPENDENT UNION`, `UNCACHEABLE UNION` | Set-operation branch, possibly dependent or uncacheable |
| `UNION RESULT`, `INTERSECT RESULT`, `EXCEPT RESULT` | Combined set result |
| `PUSHED SELECT`, `PUSHED DERIVED`, `PUSHED UNION` and related labels | Work delegated to an engine that supports it |

The [server's plan renderer](https://github.com/MariaDB/server/blob/mariadb-11.4.8/sql/sql_explain.cc)
shows why output includes intermediate and engine-specific blocks.

## Access types in plain English

| `type` | How MariaDB finds rows |
|---|---|
| `system` | Tiny table with at most one row |
| `const` | One constant-key row, resolved early |
| `eq_ref` | At most one unique-key match per incoming row |
| `ref` | All matches for an equality key or key prefix |
| `ref_or_null` | Equality lookup plus a NULL-key lookup |
| `range` | One or more bounded index intervals |
| `index` | Walk the whole chosen index |
| `ALL` | Walk the whole table/result |
| `index_merge` | Combine searches of several indexes on this table |
| `fulltext` | Use a text-search index |
| `unique_subquery` | Unique-key lookup for a transformed subquery |
| `index_subquery` | Non-unique-key lookup for a transformed subquery |
| `...\|filter` | Also use a second index to reject row IDs |
| NULL/blank | No ordinary table access to describe |

An index name in `key` does not prove efficient access. `type=index` can read
millions of entries. Equally, scanning a ten-row lookup table can be sensible.
See [MariaDB access types](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/analyze-and-explain-statements/explain)
and [rowid filtering](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/rowid-filtering-optimization).

## Ref and range in the hotlist

Consider the candidate composite index
`(created_user_id, is_open, last_modified_date)`. The equality values identify
one section of that index. The timestamp is ordered within the section.

The following figures are an illustration, not measurements of a deployment.
Assume a creator has 600 closed items, with six on the requested day:

| Hotlist access | What the lookup can use | Candidate entries |
|---|---|---|
| `ref` with an unrewritten wrapped date | Creator and closed status | 600, then test dates |
| `range` with bare timestamp bounds | Creator, closed status and day interval | Six |
| `eq_ref` for each patient/contact join | Complete primary key from earlier row | At most one per lookup |

Here `range` can be better because it reads a narrower interval. A `ref` lookup
on a different query may already find just one row; a `range` spanning years
could be far worse. Compare the constraints used and actual work.

Both hotlist paths may avoid sorting if the index supplies the requested order.
Removing `Using filesort` therefore does not prove that the date filter is fixed.
The [complete example](oe-query-patterns-sorting-and-date-predicates.md) shows the
PHP predicate change and the corresponding index candidate.

## Rows multiplied together do not give milliseconds

Multiplying row estimates is a rough way to notice join fanout in a simple
nested-loop block. It has no time unit.

Suppose a first access reads 100 candidates, each causes 20 child candidates,
and each surviving child causes five more. Ignoring filtering and early exits,
the last stage considers about `100 * 20 * 5 = 10,000` combinations. Total
candidate visits across those stages are closer to
`100 + 100 * 20 + 100 * 20 * 5 = 12,100`. Neither number predicts milliseconds.

Filtering changes subsequent loop counts. An outer join can preserve a
NULL-extended row. LIMIT and existence checks can stop early. Materialized
subqueries are not necessarily rebuilt per row. Buffered joins have different
work patterns. Never multiply every row in an entire EXPLAIN indiscriminately.

One thousand cached primary-key probes, one thousand physical page reads and
one thousand rows subjected to a costly function have very different costs.
Network time, result width, contention and cache state also matter.

For a controlled read-query execution, use `ANALYZE FORMAT=JSON` before the
complete SELECT. **It executes the statement.** Applied to a write, it performs
the write too; it is not `ANALYZE TABLE`.

| Actual field | Meaning |
|---|---|
| `r_rows` | Average rows read per execution of this node |
| `r_loops` | Number of executions |
| `r_filtered` | Percentage surviving filtering |
| `r_total_time_ms` | Time in this node, including its children |
| `r_engine_stats.pages_accessed` | Buffer-pool page accesses, not unique resident bytes |
| `r_engine_stats.pages_read_count` | Pages read from disk, where supported/reported |

For an ordinary table-read node, `r_rows * r_loops` approximates its actual row
visits. Do not add inclusive parent and child times. Engine counters depend on
server version; zero-valued fields may be omitted.
[MariaDB ANALYZE FORMAT=JSON](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/analyze-and-explain-statements/analyze-format-json)
defines these fields.

## Extra in plain English

Extra can contain several messages. This covers the standard documented
messages and relevant MariaDB extensions. Wording, capitalization and available
messages vary by release and storage engine; it is not a closed vocabulary
across every plugin and future version.

### Filtering, ordering and temporary work

| Extra | Meaning | What to investigate |
|---|---|---|
| `Using where` | Check a condition after finding candidates | How many candidates are discarded? |
| `Using filesort` | Sort separately from reading in index order | How many rows, bytes and merge passes? |
| `Using temporary` | Store an intermediate result in a temporary table | Size, lifetime and disk spills |
| `Using index` | Required values available from the index | Covering access; may still scan many entries |
| `Using index condition` | Test index values before fetching full rows | Useful filtering, not full coverage |
| `Using index condition(BKA)` | Index filtering with batched key access | Batch size and actual row/page work |
| `Using where with pushed condition` | Storage engine checks a condition | Rows eliminated before returning them |
| `Using index for group-by` | Use index grouping to skip repeated values | Often helpful for GROUP BY or DISTINCT |
| `Using index for group-by (scanning)` | Grouping optimization uses a scanning variant | Do not assume one read per group |

Filesort can stay in memory, including a small-LIMIT priority-queue strategy.
Temporary tables can also stay in memory. Neither label alone proves disk use.
[Index condition pushdown](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/index-condition-pushdown)
and [small-LIMIT filesort](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/filesort-with-small-limit-optimization)
explain these distinctions.

### Combining indexes and joins

| Extra | Meaning |
|---|---|
| `Using intersect(...)` | Keep row IDs found by every listed index search |
| `Using union(...)` | Keep row IDs found by any listed index search |
| `Using sort_union(...)` | Sort row IDs to combine those searches |
| `Using sort_intersect(...)` | Sort row IDs before finding their overlap |
| `Using rowid filter` | Reject row IDs using a second index before fetching rows |
| `Range checked for each record (index map: ...)` | Reconsider usable ranges for each incoming row |
| `Using join buffer (... BNL join)` | Match a batch of outer rows against a scan |
| `Using join buffer (... BNLH join)` | Use a hash table to match that batch |
| `Using join buffer (... BKA/BKAH join)` | Batch indexed lookups, optionally using hashing |
| `Rowid-ordered scan`, `Key-ordered scan` | Arrange batched reads for more efficient access |

`flat` and `incremental` describe join-buffer storage. A join buffer is not
proof of a missing index: BKA itself uses index lookups. A repeatedly scanned
large inner table with BNL is a reason to inspect join keys and selectivity.

See [index merge](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/mariadb-internal-optimizations/fair-choice-between-range-and-index_merge-optimizations),
[buffered join algorithms](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizer/block-based-join-algorithms)
and [rowid filtering](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/rowid-filtering-optimization).

### Existence checks and duplicate removal

| Extra | Meaning |
|---|---|
| `Not exists` | Stop looking after a match disproves a "no matching row" condition |
| `FirstMatch(table)` | Stop an existence-style join after its first valid match |
| `LooseScan` | Use an index to choose representatives and avoid duplicate combinations |
| `Start temporary` / `End temporary` | Boundaries of temporary duplicate-removal work |
| `Distinct` | Further matches are unnecessary once this combination is found |
| `Full scan on NULL key` | NULL handling requires a fallback scan for a subquery |

These often describe optimizations, not faults. See
[FirstMatch](https://mariadb.com/kb/en/firstmatch-strategy/),
[LooseScan](https://mariadb.com/kb/en/loosescan-strategy/) and
[DuplicateWeedout](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/optimization-strategies/duplicateweedout-strategy).

### Empty results, metadata and other statements

| Extra | Meaning |
|---|---|
| `Impossible WHERE` | Filter cannot be true |
| `Impossible WHERE noticed after reading const tables` | Constant lookups proved the filter impossible |
| `Impossible HAVING` | Group filter cannot be true |
| `Impossible ON condition` | Join condition cannot match |
| `Const row not found`, `no matching row in const table` | Constant-key lookup found nothing |
| `Unique row not found` | Required unique-key match absent |
| `No matching min/max row` | No qualifying value for MIN/MAX |
| `No matching rows after partition pruning` | No partition can contain an answer |
| `No tables used` | No table needed, such as SELECT of a constant |
| `Select tables optimized away` | Answer obtained without ordinary table iteration |
| `Skip_open_table` | Metadata query avoids opening the table |
| `Open_frm_only` | Read table definition only |
| `Open_full_table` | Open table to obtain requested metadata |
| `Open_trigger_only` | Read trigger metadata |
| `Scanned 0/1/all databases` | Scope of metadata discovery |
| `Table function: json_table` | Expand JSON through a table function |
| `Using buffer` | Buffer rows before an UPDATE changes them |
| `Deleting all rows` | Engine-supported whole-table deletion path |

An impossible filter may be correct or an application bug. Metadata messages
describe information-schema work, not clinical table joins. An aggregate can
still return a NULL/count result even when it has no qualifying input.
Consult the [standard catalogue](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/analyze-and-explain-statements/explain)
and [MariaDB's additional emitted messages](https://github.com/MariaDB/server/blob/mariadb-11.4.8/sql/sql_explain.cc#L2134-L2237)
for the exact wording.

## Does this plan prove an index is missing?

| Evidence | Likely next step |
|---|---|
| Large `ALL`, selective predicate, no usable key | Inspect whether the required index exists and the predicate is sargable |
| `possible_keys` lists a key but `key` is NULL | Check selectivity, statistics, conversions and scan cost |
| Composite chosen, only first parts used | Check index order and predicates on later parts |
| Huge `ref` candidate set | Equality prefix may be too broad; inspect residual filters |
| Large repeated inner scan | Check indexed join columns, compatible types and join fanout |
| Small scan or deliberate bulk export | Scanning may be appropriate |
| Small `rows`, huge `r_rows` | Estimates are misleading; inspect skew and statistics |

A foreign key is not a complete index design for every query. An index on
`created_user_id` can support that relationship while failing to narrow a
closed-hotlist search by status and timestamp. Compare equivalent existing
indexes before adding another. See [index design](oe-query-design.md#indexes-are-different-kinds-of-things).
