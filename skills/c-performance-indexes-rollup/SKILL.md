---
name: c-performance-indexes-rollup
description: OE performance_indexes_rollup migration structure and conventions
disable-model-invocation: false
---

# Performance index rollups

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it
never does anything by itself - it just loads knowledge; act only on instructions given in the
conversation.

This explains how an OE release's performance indexes are consolidated into one idempotent
migration. Do not create, edit, remove, apply, or test a migration unless the user explicitly asks
for that action.

The file is `protected/migrations/m<YYMMDD>_<HHMMSS>_performance_indexes_rollup.php`, dated after
the latest existing migration. Each version has one rollup; a released rollup is never appended to.
The class name matches the file name and extends `OEMigration`. This pattern is not for ordinary
schema migrations such as column or table changes.

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

When an unreleased ad-hoc index migration is folded into a rollup, the index keeps its original name
so an idempotent re-create cannot leave a duplicate. Its purpose becomes the group comment. The
ad-hoc migration and rollup must not both ship.
