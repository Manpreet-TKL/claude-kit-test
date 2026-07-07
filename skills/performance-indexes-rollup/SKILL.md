---
name: performance-indexes-rollup
description: Author the OE performance_indexes_rollup migration
disable-model-invocation: true
---

# performance_indexes_rollup

When loaded as context with no task, reply only `Context loaded.`

One migration per OE version consolidating that release's performance indexes into a single idempotent file: `protected/migrations/m<YYMMDD>_<HHMMSS>_performance_indexes_rollup.php`. Date it after the latest existing migration (`ls protected/migrations | sort | tail`). One rollup per version - start a new file, never append to a released one. Class name matches the file name, extends `OEMigration`. Not for ordinary schema migrations (column/table changes).

## Shape

```php
class m260604_120000_performance_indexes_rollup extends OEMigration
{
    // This edition speeds up the following:
    // Patient summary page load time
    // (one plain-English line per page/feature this rollup speeds up)

    public function safeUp()
    {
        // 1. Drop block - one dropIndexIfExists per managed index, all together
        //    first, so re-runs and ad-hoc-migrated installs are a no-op.
        $this->dropIndexIfExists('idx_pathway_status', 'pathway');

        // 2. Create block - grouped, each group introduced by a `// Speeds up ...`
        //    comment matching a summary line.
        // Speeds up Patient summary page load time
        $this->createIndex('idx_pathway_status', 'pathway', 'status');
    }

    public function safeDown()
    {
        // The drop block again, identical list. No createIndex.
        $this->dropIndexIfExists('idx_pathway_status', 'pathway');
    }
}
```

## Conventions

- Idempotent always: every `createIndex` has a matching `dropIndexIfExists` (an `OEMigration` helper - MySQL has no `DROP INDEX IF EXISTS`).
- A `// Speeds up ...` comment per group: a page, admin path, API call, or named job.
- Index name `idx_<table>_<col1>_<col2>...`; abbreviate when past MySQL's 64-char identifier limit. Never rename once shipped - the drop block keys off the name, so a rename leaves the old index behind as a duplicate.
- Columns comma-separated, no spaces (`'patient_id,when'`); equality-filtered columns first, then the range/sort column. Blob/text columns need a prefix length (`'blob_data(1)'`).

## Folding ad-hoc index migrations in

Copy each index across **keeping its original name** (idempotent re-create, not a duplicate); carry its comment into the group comment; drop the unreleased ad-hoc file - never ship both.

## Applying

```bash
./yiic migrate --interactive=0          # inside web / oe-manager
mysql -e "SHOW INDEX FROM <table> WHERE Key_name='<idx>'" <db>
```
