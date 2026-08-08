---
name: mariadb-correlated-in-list-no-index
description: "MariaDB cannot use an index for col IN (outer_ref, outer_ref); rewrite as COALESCE of single-equality probes, plus CONVERT for cross-charset compares"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4351dbb7-8f3b-45a8-a9c2-5484e312038a
  modified: 2026-08-07T17:57:07.916Z
---

Two independent index-killers seen in OpenEyes postcode/IMD lookups (MariaDB):

1. `col IN (expr1, expr2)` where exprs are correlated outer references NEVER uses an index (possible_keys NULL): ref access needs a single equality, range access needs constants at optimise time. Rewrite as `col = COALESCE((SELECT ... WHERE col = expr1 LIMIT 1), (SELECT ... WHERE col = expr2 LIMIT 1))`-style single-equality probes (preference order preserved by COALESCE).
2. Cross-charset comparison (utf8mb3 column vs latin1 indexed column) coerces the indexed column up to utf8 and disables its index. Fix by CONVERTing the non-indexed outer side to the indexed table's charset: `CONVERT(outer.col USING latin1)`. Lossless for ASCII data; note it also switches bin (case-sensitive) to _ci semantics - verify no skew on the data.

**Why:** EXPLAIN showed ALL/2.6M-rows-per-outer-row on `postcode_to_lsoa_mapping` even after fixing the charset; only the IN->equality rewrite made it eq_ref.
**How to apply:** when a dependent subquery is slow, check both causes; fix both; verify with EXPLAIN (want eq_ref/ref on the probe) and a result-equivalence run. Related: [[nodaudit-validation-snail]].
