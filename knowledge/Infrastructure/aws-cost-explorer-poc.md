# aws-cost-explorer — POC lessons (2026-08-08)

First real ingest of `aws-cost-explorer` against an actual CUR 2.0 export
(account <account-id>, billing period 2026-08, 304,998 line items,
$8,824.12 total). The app had never processed real data before this —
the May scaffold had a working migration/seeder path but the AWS sync and
local-import paths were both untested. This is the punch list for the
schema/architecture rework the app owner already knows is coming.

Numbers below are frozen at ingest time (2026-08-08, billing period
still open/provisional per CUR's ~24h lag).

## Bugs found and fixed

Every one of these was silent — no exception, no wrong-looking log line,
just wrong or empty data in the UI. None had test coverage.

| # | Bug | Symptom | Fix |
|---|-----|---------|-----|
| 1 | DuckDB `map['key']` bracket indexing returns a `LIST`, not a scalar | `product_region`/`product_product_name`/`product_product_family`/`product_location`/`product_instance_type` loaded as bracket-wrapped strings (`[eu-west-2]`) for every row | Index `[1]` off the list (`product['region'][1]`), or use `element_at(map,'key')[1]` |
| 2 | `PDO::MYSQL_ATTR_LOCAL_INFILE` never set client-side | `LOAD DATA LOCAL INFILE` refused even though MariaDB's `local_infile=ON` server-side | Add the PDO option in `config/database.php` — server-side alone is not sufficient |
| 3 | `Reconciler::reconcileCosts()` plain-inserted rows that collide on the `uq_rc(resource_id, billing_period, component, pricing_term, region)` unique index | Multiple CUR `usage_type`s collapse into one component → 1062 duplicate-key abort on ingest of any real account | Aggregate into a keyed accumulator (sum cost/usage) before inserting |
| 4 | Tag key coded as `user:project` (colon), real CUR tag key is `user_project` (underscore) | `clients`/attribution never populated from CUR-only tag data | Both `reconcileClients()` and `reconcileUnattributedCosts()` corrected |
| 5 | `line_item_resource_id` placeholder values not excluded | `'*'` (130 rows) and bare-account-ID (877 rows) — both AWS's "no specific resource" conventions — were treated as real resource IDs, which would merge unrelated account-level usage into one bogus "resource" | Excluded via `line_item_resource_id NOT IN ('', '*') AND line_item_resource_id <> line_item_usage_account_id` in both `reconcileCosts()` and `reconcileUnattributedCosts()` |
| 6 | `$progress?->call($this, 'msg')` — `Closure::call()` rebinds `$this` *and* drops an argument | `TypeError: too few arguments`; would also have broken `$this->line()` inside the closure had it not thrown first | Switched to plain `$progress?->__invoke('msg')` + matching 1-arg closures. Fixed in `Reconciler` (6 sites), `CurIngester::ingestRecent()` (2 sites), `AwsReconcileCommand`, and the `cur` stage of `AwsPullCommand`. **The `explorer`/`describe`/`recommendations` stages of `AwsPullCommand` have the identical bug and were not touched this session** — untested since those services need Resource Explorer/Describe/Optimizer API access this environment doesn't have. Anyone running `aws:pull` without `--only=cur` will hit it. |
| 7 | `reconcileClients()`'s `->pluck('tags->project')` on an already-hydrated Eloquent Collection | Laravel's `data_get()` treats `->` as PHP object-property traversal once the collection is materialized (not JSON-path), so it silently returned nulls against the array-cast `tags` attribute — dormant until `raw_resources` actually had a `project` key | Replaced with `->get()->map(fn ($r) => data_get($r->tags, 'project'))`, matching the pattern already used correctly elsewhere in the class |
| 8 | `computeFlags()` only ever *sets* flags, never clears them | A resource that starts orphaned and later gets tagged/attributed keeps the stale `orphan` flag forever — reproduced live in the UI (correctly-attributed resources still showing "orphan") | Always converge: compute the new flag string and write it whenever it differs from the current one, including to `null` |

Verified after all fixes: `raw_cur_lineitems` row count and cost sum match
the source Parquet exactly; 0 wrongly-orphaned and 0 missed-orphan
resources; a spot-checked dashboard GBP figure matches
`raw_usd * pinned_fx_rate` exactly.

## Architecture findings

- **The normalised layer has a hard dependency on Resource Explorer /
  Describe data that this POC never had.** `reconcileResources()` only
  reads from `raw_resources`, and nothing populates `raw_resources` from
  CUR alone. A CUR-only ingest — which is realistically the first data
  source anyone will have, since it needs zero extra IAM permissions
  beyond bucket read — leaves every page at zero. This session bridged it
  with a one-off SQL synthesis script (grouping `raw_cur_lineitems` by
  `line_item_resource_id`, parsing real ARNs with the existing
  `ArnParser`, heuristically typing bare IDs like `i-xxx`/`vol-xxx` by
  prefix, and normalizing `user_project` → `project` so the existing tag
  contract worked unmodified). **Recommendation:** either make CUR-derived
  resource synthesis a first-class ingest step (the `source='cur'` enum
  value already exists for exactly this) or make the rework's schema not
  assume Explorer/Describe as a prerequisite for basic cost attribution.
- **~6.8% of this account's spend has no resource ID at all and is
  invisible in the UI.** $599.46 of $8,824.12 — tax line items ($735.49
  RDS tax alone, wait: summed correctly to $599.46 total across all
  services), AWS Support fees, and account-level usage of CloudWatch,
  Security Hub, and GuardDuty — has `line_item_resource_id` NULL/`*`/the
  bare account ID. None of it carries a `user_project` tag (it's
  inherently shared/account-level cost), so it doesn't land in
  `client_unattributed_costs` either — it's simply dropped. Client-facing
  totals will always undercount actual AWS spend by this bucket. The
  rework should decide explicitly how to allocate or surface
  tax/support/account-level-security costs (pro-rata split? a visible
  "shared costs" line? passed through untouched to the payer?) rather than
  silently dropping them.
- **Two separate map-typed CUR columns carry tag-like data:
  `resource_tags` and `tags`.** Both are populated in real exports but use
  different key-naming conventions for what turned out to be the same
  underlying cost-allocation tag (`user_project` vs `user:project`) — this
  is what caused bug #4 above. Worth deciding on ingest which one is
  canonical (`resource_tags` is what this app already reads) rather than
  rediscovering the mismatch the hard way again.
- **Tag coverage on this account, for reference:** of 984 real resources
  synthesized from CUR, 519 (52.7%) resolved to a client via the
  `project` tag, 465 (47.3%) did not. 27 distinct project-tag values were
  discovered.

## Ingest and sync gaps

- **Local-file re-ingest had no idempotency guard at all before this
  session** — every re-run of `aws:import-cur` on the same file would
  reload all rows and double/triple-count cost. Fixed: `RawCurFile` is
  now keyed on `local://<key>` with size-based skip, matching the S3
  path's existing ETag-based idempotency. Verified: two consecutive
  re-runs left the row count and `raw_cur_files.ingested_at` timestamp
  frozen.
- **`CurIngester::ingestRecent()`'s S3 prefix never matched the real CUR
  2.0 layout.** It built
  `<prefix>/BILL_BillingPeriodStart=YYYY-MM-01/` — not a real AWS CUR
  path convention — and never used the `export_name` config value at all,
  so a real S3 sync would have listed zero objects every time, silently
  ("sync completed, 0 files"). Corrected to
  `<prefix>/<export_name>/data/BILLING_PERIOD=YYYY-MM/`, matching both the
  manifest layout inspected in the sample export and
  `~/aws-cur-download-note.txt`. **This fix is code-only — there is no
  AWS credential in this environment to test it against real S3.**
- **A billing period can have multiple refresh folders and the old code
  had no way to pick one.** The sample export had three refresh folders
  for the same billing period (`<ISO8601-timestamp>-<executionId>/`),
  each a complete copy — ingesting more than one would triple-count cost.
  `ingestRecent()` now lists all objects under the period, buckets by
  refresh-folder name, and ingests only the lexicographically-newest
  (folder names sort correctly by time since the prefix is an ISO8601
  timestamp). Also code-only/untested against real S3.
- **`/resources` and `/clients/{id}` defaulted to *last* calendar month**,
  not the current one — reasonable for a mature monthly-close product,
  actively confusing for a POC being demoed against the current month's
  data. Fixed both controllers to default to the current month.
- **`v_untagged_resources.last_month_cost_usd` is a SQL view with the
  "last month" logic hardcoded as
  `DATE_SUB(CURDATE(), INTERVAL 1 MONTH)`**, not parametrized by whatever
  period the rest of the UI is showing. This is a real, still-open
  inconsistency — the untagged-resources page will always show last
  month's cost column regardless of what period you're actually looking
  at elsewhere. Not fixed this session (it's a forward-only migration and
  wasn't in the four approved POC refinements) — worth resolving in the
  rework, either by parametrizing the view or moving the cost lookup into
  the controller.

## CUR export vs the app's 23-column projection

The real export has 131 columns (see the companion
`aws-cur2-export.md` for the full inventory); the app's DuckDB
transform only projects 23. What's currently discarded, grouped by what
it would enable:

- **Reservation/Savings Plan economics** — 13 `reservation_*` and 12
  `savings_plan_*` fields (amortized upfront cost, effective cost, net
  variants, utilization). The app currently only classifies pricing
  *term* (`CostComponentClassifier::classifyPricingTerm`) from
  `line_item_line_item_type` + the two ARN fields it does keep — it can't
  show utilization, amortization schedules, or RI/SP effective-vs-list
  cost without these.
- **Split cost allocation** — 11 `split_line_item_*` fields (actual
  usage, split/unused cost, split ratio, parent resource ID). Needed for
  the "per-pod EKS attribution" feature already listed as deferred to
  v1.1 in the app's own CLAUDE.md.
- **`discount` and `cost_category`** — both map-typed, both entirely
  unused. `discount_bundled_discount`/`discount_total_discount` (flat
  doubles) are also unused. Any EDP/PPA-style negotiated discount is
  invisible to the current cost figures.
- **Cost variants** — `line_item_blended_cost`/`line_item_net_unblended_cost`
  and their `_rate` counterparts aren't kept; only `unblended_cost` is.
  Fine for a single-account POC; matters the moment consolidated billing
  or a payer/linked-account split is in scope.
- **Directionality/geography** — `product_from_location`/`_region_code`
  and `product_to_location`/`_region_code`, `line_item_availability_zone`.
  Would be needed for real data-transfer cost attribution (currently
  classified only by usage-type string matching).
- **Tax/identity metadata** — `line_item_tax_type`, `line_item_iam_principal`,
  `line_item_legal_entity`, `line_item_user_identifier`. Relevant if the
  rework wants to show *who* (IAM principal) incurred a cost, not just
  *what*.

## Operational notes

- **`~/ace`'s db was published on host port 3306**, clashing with an
  unrelated `snail-db-1` on the same host — moved to 3406. Worth a
  default-port-collision check in `oe-deploy`'s pre-flight gates
  generally, not just for this app.
- **`ACE_CUR_PREFIX` in `~/ace/.env` was `cur-v2`; the real S3 layout's
  top-level prefix is `ace`** (per the app owner). Corrected in `.env`.
  **`AWS_CUR_EXPORT_NAME` is not wired through the `ace` oe-deploy
  template chain at all** (`templates/ace.yml`/`templates/ace.env` have
  no such variable, so the app always falls back to its config default of
  `toukanlabs-cur-v2` regardless of what's set anywhere else) — this needs
  adding to the template before a real S3 sync can be pointed at the
  actual export name, which is itself still unconfirmed. `ACE_CUR_BUCKET`
  is also still blank. None of this blocks the POC (local-file ingest
  only), but real S3 sync is not deploy-ready yet.
- **OPcache `validate_timestamps=0` in production** means every
  `docker cp` patch needs an explicit container restart, not just
  `artisan config:clear`/`view:clear` — `apachectl graceful` would
  probably also work but wasn't tried; a full restart was used throughout
  this session as the reliable option.
- **No VCS and no automated tests on this app** meant every one of the 8
  bugs above was found only by finally running it against real data, one
  at a time, each requiring a manual patch/restart/re-verify cycle. A
  single smoke test — even just a tiny synthetic 2-3-row Parquet fixture
  run through `ingestLocalParquet()` + `reconcile()` — would have caught
  the map-indexing bug, the tag-key mismatch, the unique-constraint
  collision, and the closure-signature bug before this session, without
  needing real CUR data at all. Worth prioritizing over new features in
  the rework.
- **A `''`-region-polluting-`/regions`** risk was flagged in planning but
  did not materialize — 0 resources have a blank region in this dataset.

## Still open / explicitly out of scope this session

- `explorer`/`describe`/`recommendations` stages of `aws:pull` share bug
  #6 above (`Closure::call()` progress-closure signature) — not fixed,
  not exercised (no Resource Explorer/Describe access in this
  environment).
- S3 prefix fix and multi-refresh-folder selection (both above) are
  code-only, never run against real AWS.
- `v_untagged_resources`'s hardcoded-last-month column.
- Real reservation/savings-plan/discount/split-cost data — not ingested
  at all, see the projection gap section above.
