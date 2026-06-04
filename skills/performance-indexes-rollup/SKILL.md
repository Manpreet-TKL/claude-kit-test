---
name: performance-indexes-rollup
description: Author the per-version OpenEyes `performance_indexes_rollup` migration — one OEMigration class per OE release that consolidates that version's performance indexes into a single idempotent file. Covers the file name (`m<YYMMDD>_<HHMMSS>_performance_indexes_rollup.php`), the class skeleton extending OEMigration, the leading "this edition speeds up the following" summary block, the drop-all-then-create-all idempotency pattern (`dropIndexIfExists` before every `createIndex`), the grouped `// Speeds up …` comments, index naming, composite column ordering, and blob/text prefix lengths. Trigger when asked to write, extend, or roll up performance indexes into one of these migrations for a new OE version, or to fold ad-hoc index migrations into the rollup. Skip for ordinary schema migrations (column/table changes) — this is only for the performance-index rollup.
---

# OpenEyes `performance_indexes_rollup` migration

One migration per OE version that collects every performance index added for that
release into a single idempotent file. Each index carries a short comment on what it
speeds up; every index is added in an idempotent (drop-then-create) way.

## File name and class

```
protected/migrations/m<YYMMDD>_<HHMMSS>_performance_indexes_rollup.php
```

- Date it **after the latest existing migration** in the repo (`ls protected/migrations
  | sort | tail`) — Yii applies migrations in filename order. There is **one rollup per
  version**: start a new file, never append to a released one.
- Class name matches the file name exactly and extends `OEMigration`.

## Shape

```php
<?php

class m260604_120000_performance_indexes_rollup extends OEMigration
{
    // This edition speeds up the following:
    // Patient summary page load time
    // Admin → Correspondence → Letter Macros
    // (one plain-English line per page/feature this rollup speeds up)

    public function safeUp()
    {
        // 1. Drop block — one dropIndexIfExists per index this migration manages,
        //    all together first, so re-running (or an install that already has the
        //    index from an ad-hoc migration) is a no-op rather than an error.
        $this->dropIndexIfExists('idx_pathway_status', 'pathway');
        // … one per index …

        // 2. Create block — grouped by what each group speeds up, each group
        //    introduced by a `// Speeds up …` comment matching a summary line.

        // Speeds up Patient summary page load time
        $this->createIndex('idx_pathway_status', 'pathway', 'status');
        // …
    }

    public function safeDown()
    {
        // The drop block again, identical list. No createIndex.
        $this->dropIndexIfExists('idx_pathway_status', 'pathway');
        // …
    }
}
```

## Conventions

- **Idempotent always.** Every `createIndex` has a matching `dropIndexIfExists` in the
  drop block — never a bare `createIndex`. `dropIndexIfExists` is an `OEMigration` helper
  (MySQL has no `DROP INDEX IF EXISTS`); it `SHOW INDEX`-guards then drops.
- **A comment per index/group** saying what it speeds up — a page name, an admin path,
  an API call, a named job. Short; the reader learns *why the index exists* without
  reading the query.
- **Index name:** `idx_<table>_<col1>_<col2>…`. Abbreviate tokens when the full name
  would exceed MySQL's **64-char identifier limit**. Keep the name stable once shipped —
  renaming on an install that already has it leaves the old one behind as a duplicate
  (the drop block keys off the name).
- **Columns:** comma-separated, **no spaces** — `'patient_id,when'`.
- **Composite column order matters.** Equality-filtered columns first, then the
  range/sort column — `WHERE event_id = ? AND nrf_check != 1` → `'event_id,nrf_check'`.
- **Blob/text columns need a prefix length** — `'blob_data(1)'`, or in a composite
  `'attachment_type,blob_data(1),protected_file_id,id'`. MySQL rejects an un-prefixed
  index on a `BLOB`/`TEXT`.

## Folding ad-hoc index migrations in

When the cycle produced standalone `m…_indexes_for_<thing>.php` migrations, fold their
indexes into the version rollup instead of shipping the ad-hoc files:

- Copy each index across **keeping its original name**, so an install that already ran
  the ad-hoc migration gets a harmless idempotent re-create, not a second index.
- Carry the ad-hoc per-index comment into the rollup's group comment.
- Don't ship both — drop the (unreleased) ad-hoc migration and let the rollup carry it.

## Applying

```bash
# inside the web / oe-manager container
./yiic migrate --interactive=0
# confirm an index landed
mysql -e "SHOW INDEX FROM <table> WHERE Key_name='<idx>'" <db>
```
