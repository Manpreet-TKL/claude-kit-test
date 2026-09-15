# AWS CUR 2.0 export anatomy — reference for the aws-cost-explorer rework

Derived from `/home/toukan/full-aws-cur-07082026.tar.gz` (account
<account-id>, billing period 2026-08, export prefix `ace`) and
`/home/toukan/aws-cur-download-note.txt`. Every fact below was confirmed
against the real files, not documentation.

## Directory layout

```
s3://<bucket>/<prefix>/<export-name>/
├── data/
│   └── BILLING_PERIOD=YYYY-MM/
│       └── <ISO8601-timestamp>-<executionId>/
│           ├── <export-name>-00001.snappy.parquet
│           ├── <export-name>-00002.snappy.parquet
│           └── ...
└── metadata/
    ├── BILLING_PERIOD=YYYY-MM/
    │   └── <ISO8601-timestamp>-<executionId>/
    │       └── Manifest.json
    └── Manifest.json          (top-level, one per billing period)
```

- `<prefix>` — the "S3 path prefix" chosen at export-creation time, a
  plain top-level directory name (this account: `ace`).
- `<export-name>` — chosen at export-creation time, becomes a literal
  directory name. Must be lowercase alphanumeric + hyphen/underscore,
  up to 128 chars. **Not discoverable from the bucket structure alone
  if you don't already know it** — there's no manifest at the
  `<prefix>/` level enumerating export names, you have to know it from
  the CUR export configuration in Billing Console (or IaC that created
  it).
- `<ISO8601-timestamp>-<executionId>` — one directory per *refresh* of
  that billing period's data (see below). Sorts correctly by name since
  the timestamp is ISO8601.
- Chunk files are zero-padded 5-digit sequence numbers
  (`-00001.snappy.parquet`, `-00002...`) and "should run without gaps"
  per AWS's own docs — a chunk with near-zero rows is a refresh
  artifact, not corruption.

## Multi-refresh semantics — the thing that will silently triple-count cost

CUR 2.0 exports have a **"File versioning" setting** chosen at
export-creation time, with two modes:

- **"Overwrite existing data export file"** — one refresh folder per
  billing period, in place. Naive `list-objects` + import is safe.
- **"Create new data export file"** — every refresh (AWS updates a CUR
  roughly daily, plus ~2 more times after month-end for late-arriving
  corrections) creates a **new** `<timestamp>-<execId>/` folder, and
  **old ones are not deleted**. This account uses this mode: the sample
  billing period had **three** refresh folders, each a complete,
  non-overlapping copy of the same data.

**Consequence:** any ingest code that lists everything under
`data/BILLING_PERIOD=YYYY-MM/` and loads all parquet files it finds will
double- or triple-count every line item once a period has been refreshed
more than once. Correct handling: read the **top-level aggregate**
`metadata/Manifest.json` for the period, take its `executionId` (or list
the `<timestamp>-<execId>/` subfolders and pick the lexicographically
newest — the ISO8601 prefix makes this safe), and ingest only that one
refresh's files.

## Manifest structure

Two manifest files exist per billing period:

- `metadata/Manifest.json` (top-level, one aggregate per period)
- `metadata/BILLING_PERIOD=YYYY-MM/<ts>-<execId>/Manifest.json`
  (refresh-specific)

Both share the same top-level keys:

| Key | Contents |
|---|---|
| `executionId` | Identifies which refresh this manifest describes — the value to match against the `<ts>-<execId>/` data folder name |
| `exportArn` | ARN of the CUR export definition |
| `columns` | Array of `{name, type}` — the full column schema, 131 entries for this export config (see inventory below) |
| `dataFiles` | List of the parquet chunk file paths/sizes for this refresh |
| `additionalOutputFiles` | Any extra files (none of interest observed in this export) |

Column `type` values observed: `string`, `timestamp`, `double`, `map`.
Exactly **5** columns are `map`-typed: `cost_category`, `discount`,
`product`, `resource_tags`, `tags`.

## Correction window

Per `aws-cur-download-note.txt`: a closed month continues to receive
corrections for roughly **2 weeks after month-end** (refunds, delayed
usage records, support-credit reconciliation). Anything that snapshots
"final" cost for a month immediately at month-end should re-pull that
month ~2 weeks later and reconcile the delta. Current-month (in-progress)
data has roughly a **24-hour lag** and refreshes at least daily.

## Full 131-column inventory

Grouped by prefix, with the manifest-declared type. `map`-typed columns
marked **(map)**.

### `bill_*` — 7 columns
`bill_type`, `bill_billing_entity`, `bill_billing_period_end_date`
(timestamp), `bill_billing_period_start_date` (timestamp),
`bill_invoice_id`, `bill_invoicing_entity`, `bill_payer_account_id`,
`bill_payer_account_name`
(listed as `bill_bill_type` in the raw manifest — 8 total incl. that)

### `capacity_reservation_*` — 3 columns
`capacity_reservation_arn`, `capacity_reservation_status`,
`capacity_reservation_type`

### Cost category / discount — 4 columns
`cost_category` **(map)**, `discount` **(map)**,
`discount_bundled_discount` (double), `discount_total_discount` (double)

### `identity_*` — 2 columns
`identity_line_item_id`, `identity_time_interval`

### `line_item_*` — 23 columns
`line_item_availability_zone`, `line_item_blended_cost` (double),
`line_item_blended_rate`, `line_item_currency_code`,
`line_item_iam_principal`, `line_item_legal_entity`,
`line_item_line_item_description`, `line_item_line_item_type`,
`line_item_net_unblended_cost` (double), `line_item_net_unblended_rate`,
`line_item_normalization_factor` (double),
`line_item_normalized_usage_amount` (double), `line_item_operation`,
`line_item_product_code`, `line_item_resource_id`,
`line_item_tax_type`, `line_item_unblended_cost` (double),
`line_item_unblended_rate`, `line_item_usage_account_id`,
`line_item_usage_account_name`, `line_item_usage_amount` (double),
`line_item_usage_end_date` (timestamp),
`line_item_usage_start_date` (timestamp), `line_item_usage_type`,
`line_item_user_identifier`

### `pricing_*` — 10 columns
`pricing_currency`, `pricing_lease_contract_length`,
`pricing_offering_class`, `pricing_public_on_demand_cost` (double),
`pricing_public_on_demand_rate`, `pricing_purchase_option`,
`pricing_rate_code`, `pricing_rate_id`, `pricing_term`, `pricing_unit`

### `product_*` — 21 columns
`product` **(map)**, `product_comment`, `product_fee_code`,
`product_fee_description`, `product_from_location`,
`product_from_location_type`, `product_from_region_code`,
`product_instance_family`, `product_instance_type`,
`product_instancesku`, `product_location`, `product_location_type`,
`product_operation`, `product_pricing_unit`, `product_product_family`,
`product_region_code`, `product_servicecode`, `product_sku`,
`product_to_location`, `product_to_location_type`,
`product_to_region_code`, `product_usagetype`

(Note: `product_product_name` and `product_region` — the fields the app
currently extracts via `product['product_name'][1]` /
`product['region'][1]` — are **keys inside the `product` map**, not
top-level columns; the flattened `product_*` columns above are a
*different*, AWS-populated subset. The map can carry additional
service-specific keys beyond the flattened columns.)

### `reservation_*` — 25 columns
`reservation_amortized_upfront_cost_for_usage` (double),
`reservation_amortized_upfront_fee_for_billing_period` (double),
`reservation_availability_zone`, `reservation_effective_cost` (double),
`reservation_end_time`, `reservation_modification_status`,
`reservation_net_amortized_upfront_cost_for_usage` (double),
`reservation_net_amortized_upfront_fee_for_billing_period` (double),
`reservation_net_effective_cost` (double),
`reservation_net_recurring_fee_for_usage` (double),
`reservation_net_unused_amortized_upfront_fee_for_billing_period` (double),
`reservation_net_unused_recurring_fee` (double),
`reservation_net_upfront_value` (double),
`reservation_normalized_units_per_reservation`,
`reservation_number_of_reservations`,
`reservation_recurring_fee_for_usage` (double),
`reservation_reservation_a_r_n`, `reservation_start_time`,
`reservation_subscription_id`,
`reservation_total_reserved_normalized_units`,
`reservation_total_reserved_units`, `reservation_units_per_reservation`,
`reservation_unused_amortized_upfront_fee_for_billing_period` (double),
`reservation_unused_normalized_unit_quantity` (double),
`reservation_unused_quantity` (double),
`reservation_unused_recurring_fee` (double),
`reservation_upfront_value` (double)
(26 listed — reservation detail is the single largest column group)

### `resource_tags` / `tags` — 2 columns
`resource_tags` **(map)**, `tags` **(map)** — both carry cost-allocation
tag data but were observed using **different key-naming conventions**
for the same tag (`user_project` in one, `user:project` in the other) —
see the lessons doc for how this caused a real bug. Treat as
non-interchangeable without normalizing the key format first.

### `savings_plan_*` — 15 columns
`savings_plan_amortized_upfront_commitment_for_billing_period` (double),
`savings_plan_end_time`, `savings_plan_instance_type_family`,
`savings_plan_net_amortized_upfront_commitment_for_billing_period` (double),
`savings_plan_net_recurring_commitment_for_billing_period` (double),
`savings_plan_net_savings_plan_effective_cost` (double),
`savings_plan_offering_type`, `savings_plan_payment_option`,
`savings_plan_purchase_term`,
`savings_plan_recurring_commitment_for_billing_period` (double),
`savings_plan_region`, `savings_plan_savings_plan_a_r_n`,
`savings_plan_savings_plan_effective_cost` (double),
`savings_plan_savings_plan_rate` (double), `savings_plan_start_time`,
`savings_plan_total_commitment_to_date` (double),
`savings_plan_used_commitment` (double)
(17 listed)

### `split_line_item_*` — 11 columns
`split_line_item_actual_usage` (double),
`split_line_item_net_split_cost` (double),
`split_line_item_net_unused_cost` (double),
`split_line_item_parent_resource_id`,
`split_line_item_public_on_demand_split_cost` (double),
`split_line_item_public_on_demand_unused_cost` (double),
`split_line_item_reserved_usage` (double),
`split_line_item_split_cost` (double),
`split_line_item_split_usage` (double),
`split_line_item_split_usage_ratio` (double),
`split_line_item_unused_cost` (double)

Populated only when Split Cost Allocation Data is enabled on the export
(ECS/EKS per-task/per-pod cost splitting) — present as columns in this
export's schema; per-row population depends on whether the workload
actually uses split-cost-eligible services.

**Total: 131 columns, 5 map-typed** (`cost_category`, `discount`,
`product`, `resource_tags`, `tags`).

## What the current app keeps vs discards

The app's DuckDB projection (`CurIngester.php`) currently selects 23 of
these 131 columns, touching 2 of the 5 map columns (`product`,
`resource_tags`). Entirely unused today: `cost_category`, `discount`
(map and both scalar variants), the separate `tags` map, all
`reservation_*` fields beyond the single ARN, all `savings_plan_*`
fields beyond the single ARN, and all 11 `split_line_item_*` fields. See
`aws-cost-explorer-poc.md` for what each of these would unlock if
added in the rework.
