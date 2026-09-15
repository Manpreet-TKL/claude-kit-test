# Restoring a few tables from a very large mysqldump

Written after a phpunit run on a dev container emptied `element_type`, `element_type_version`,
`event_type`, `event_type_version` and `event_group` in the working database. The only source
was a 325 GB production mysqldump. Restoring the whole dump would have taken hours and replaced
22M events and 2.1M patients that were never damaged.

## Why a partial extract works

`mysqldump` writes one table at a time, in the order `SHOW TABLES` returns them, which is
alphabetical. Each table is introduced by a line of exactly this shape:

```
-- Table structure for table `element_type`
```

followed by `DROP TABLE IF EXISTS`, `CREATE TABLE`, then a `-- Dumping data for table` heading
and the `INSERT INTO` statements, up to the next `-- Table structure` line. So a single
sequential pass can copy out only the blocks you want, and stop the moment it reads a table
that sorts after the last one you asked for.

Cost is read throughput, nothing else. Measure the raw device first:

`dd if=/path/to/dump.sql of=/dev/null bs=1M count=4096`

That gives an upper bound; the sustained rate through awk will be lower, because awk pays a
regex match per line. Compare either figure with a full `mysql < dump.sql`, which is bounded by
insert and index-build speed rather than read speed, and is hours rather than minutes.

Watch progress on a running pass by reading the process's own byte counter - the output file
stays empty until the first wanted table is reached, so file size tells you nothing:

`p=$(pgrep -f "awk -v w=element_type"); awk '/^rchar/{print $2/1073741824 " GB read"}' /proc/$p/io`

## The extract

`LC_ALL=C awk -v w=element_type,element_type_version,event_group,event_type,event_type_version 'BEGIN{n=split(w,a,",");for(i=1;i<=n;i++)k[a[i]]=1;last=a[n]} /^-- Table structure for table `/{split($0,q,"`");t=q[2];if(t>last)exit;p=(t in k)} p' /path/to/dump.sql > /tmp/tables.sql`

`w` is a comma-separated list of tables **in ascending order** - the last entry is what triggers
the early exit. `LC_ALL=C` makes awk's `>` a byte comparison, matching the dump's ordering.

Points that matter:

1. Run it in the foreground of whatever backgrounding mechanism you use. `nohup cmd &` inside a
   wrapper that then exits will have the process killed with the wrapper.
2. The extract does not include the session preamble at the top of the dump. Prepend it
   yourself when loading (see below).
3. Sanity check the extract lists every table you asked for before you touch anything:
   `grep "^-- Table structure for table" /tmp/tables.sql`
4. Count rows, not statements. How depends on how the dump was written: with extended inserts
   the rows are tuples on one enormous line (`grep -o "),(" | wc -l`, plus one), while a dump
   written one row per line counts as `grep -c "^("`. Check which you have before trusting the
   number - `grep -c "^INSERT INTO"` counts statements and will happily report 1.
5. Run **one** extraction at a time. Two passes writing to the same path with `>` each keep
   their own file offset, so the output interleaves into something that still looks plausible.
   If you restart a pass, kill the old one first and delete the partial file.

## What it actually cost

Measured on the run this note came from, so the next one can be estimated rather than guessed.

| | |
|---|---|
| Dump file | 325,896,106,938 bytes (304 GiB), MariaDB 10.19 -> 11.8.8 |
| Raw read rate (`dd`, 4 GiB sample) | 502 MB/s |
| Sustained rate through awk | ~300 MB/s |
| Bytes read before the early exit | ~199 GB, about 61% of the file |
| Extraction wall clock | 11 min 4 s (10:38:39 -> 10:49:43) |
| Extract output | 362 KB, 1,803 rows across six tables |
| Load into MariaDB | 179 ms |
| Total | under 12 minutes |

Two things drive the estimate:

1. **How far into the alphabet your last wanted table sits**, not how big it is. These six
   tables are tiny, but `element_type_version` through `event_type_version` spans every `et_*`
   table and `event` itself, so the pass still had to read most of the file. Had the job needed
   only `element_type`, it would have stopped shortly after `audit` and taken about half as long.
   Estimate with: bytes up to the last wanted table, divided by the sustained rate.
2. **The in-database size of the tables that sort before yours.** `information_schema` is a good
   proxy for their bulk in the dump:

`docker exec <db> mariadb -u<user> -p<pass> -e "SELECT TABLE_NAME, TABLE_ROWS, ROUND((DATA_LENGTH+INDEX_LENGTH)/1073741824,1) gb FROM information_schema.TABLES WHERE TABLE_SCHEMA='openeyes' ORDER BY 3 DESC LIMIT 10"`

Here the largest were `et_ophinmehpac_patientassessment_version` (68.7 GB), `audit` (65.5 GB,
173.8M rows), `address_version` (15.9 GB) and `patient_version` (14.8 GB) - `audit` alone sits
between the start of the dump and `element_type`.

The load side is negligible for reference tables and stays negligible until you are restoring
millions of rows; at that point index rebuilds dominate and `SET UNIQUE_CHECKS=0` starts to
matter. For a table of a few hundred rows, the entire cost of this exercise is the read.

## Loading it

The extract carries `DROP TABLE IF EXISTS`, so **never** pipe it into the live schema - it will
destroy the table you are repairing. Load into a scratch schema:

`docker exec -i <db> mariadb -u<user> -p<pass> -e "CREATE DATABASE IF NOT EXISTS restore_scratch"`

`{ echo "SET NAMES utf8mb4; SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO'; SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0;"; cat /tmp/tables.sql; } | docker exec -i <db> mariadb -u<user> -p<pass> restore_scratch`

`NO_AUTO_VALUE_ON_ZERO` is not optional. mysqldump sets it in the preamble you skipped, and
without it an explicit `0` in an AUTO_INCREMENT column is treated as "assign the next value".
OE uses an id-0 sentinel row in `element_type` (`DUMMY - DON'T USE`), and on the first load
here it silently became id 718 - the row count was right, the ids were not, and every
`element_type_id = 0` reference in `setting_installation` would have been orphaned. Check the
low ids after loading rather than trusting the count:

`docker exec <db> mariadb -u<user> -p<pass> restore_scratch -e "SELECT MIN(id), MAX(id), COUNT(*) FROM element_type"`

Then check the counts against what you expected before swapping:

`docker exec <db> mariadb -u<user> -p<pass> -e "SELECT (SELECT COUNT(*) FROM restore_scratch.element_type) et, (SELECT COUNT(*) FROM restore_scratch.event_type) evt"`

## Swapping into the live schema

Copy rows rather than tables when the live table has columns the dump predates - name the
columns explicitly so the newer ones keep their defaults:

`docker exec <db> mariadb -u<user> -p<pass> openeyes -e "SET FOREIGN_KEY_CHECKS=0; DELETE FROM element_type; INSERT INTO element_type (id, name, class_name, ...) SELECT id, name, class_name, ... FROM restore_scratch.element_type; SET FOREIGN_KEY_CHECKS=1"`

If the live table is structurally identical to the dump, `RENAME TABLE` is faster and atomic:

`docker exec <db> mariadb -u<user> -p<pass> -e "RENAME TABLE openeyes.element_type TO openeyes.element_type_old, restore_scratch.element_type TO openeyes.element_type"`

Afterwards, re-apply anything the dump predates. A schema migration recorded as applied will not
re-run on its own - delete its row from the migration table and run the migrator again, rather
than hand-patching the column back.

Drop the scratch schema once the live data is verified.

## Verifying the restored tables are not out of sync

An old snapshot of a reference table is only correct if nothing has changed it since. "The box
has been idle" is not evidence of that: user activity is not what moves reference tables,
**migrations** are, and a deployment that has sat untouched can still have been migrated
repeatedly. Check the migration table, not the calendar.

The migration table is usually intact after this kind of accident - no fixture names it - so it
is the authority on what the schema and its seed data should look like.

**1. Which migrations post-date the dump.** Find the first apply batch that ran after the dump
was taken (here the dump is dated 15 Jul and the first post-restore batch is 16 Jul 12:07:41),
then list everything from that point on:

`docker exec <db> mariadb -u<user> -p<pass> openeyes -N -e "SELECT version FROM tbl_migration WHERE apply_time >= UNIX_TIMESTAMP('2026-07-16 12:07:41')" > post-dump-migrations.txt`

**2. Which of those touch the tables you are restoring.** Grep each migration's source:

`docker exec <web> bash -lc 'cd /var/www/openeyes && while read -r v; do f=$(find protected -name "${v}.php" | head -1); [ -n "$f" ] && grep -qEi "(element_type|event_type|event_group)" "$f" && echo "$v"; done < /root/post-dump-migrations.txt'`

On this deployment that returned 147 post-dump migrations, 36 of which write to these tables -
so the 15 Jul copy is genuinely stale, and restoring it verbatim would silently roll back a
month of reference data. Migrations whose file cannot be found are worth listing too: they came
from a module or branch that is no longer checked out.

**3. Column drift.** Compare the dump's `CREATE TABLE` against the live one before you decide
between `RENAME TABLE` and a column-named `INSERT ... SELECT`:

`grep -o "^  \`[a-z_]*\`" extract.sql` against
`docker exec <db> mariadb -u<user> -p<pass> openeyes -e "SHOW COLUMNS FROM element_type"`

Here the dump still had a `version` column that a later migration dropped, and lacked the
`deprecated_date` a later migration added - two independent reasons `RENAME TABLE` would have
been wrong.

**4. Row count against a known-good figure.** If you captured counts before the damage (or the
`_version` mirror survived, or a monitoring check recorded them), compare. 312 rows in the dump
against 320 live before the wipe means 8 rows arrived after the dump and must be reconstructed
from the migrations found in step 2.

**5. Referential integrity from the surviving side.** The intact tables are a strong oracle: any
id they reference must exist in the restored table. Generate the anti-joins from
`information_schema` rather than writing them by hand:

`docker exec <db> mariadb -u<user> -p<pass> -N -e "SELECT CONCAT('SELECT ''',TABLE_NAME,'.',COLUMN_NAME,''' t, COUNT(*) orphans FROM \`',TABLE_NAME,'\` c LEFT JOIN \`',REFERENCED_TABLE_NAME,'\` p ON p.',REFERENCED_COLUMN_NAME,'=c.',COLUMN_NAME,' WHERE c.',COLUMN_NAME,' IS NOT NULL AND p.',REFERENCED_COLUMN_NAME,' IS NULL UNION ALL') FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA='openeyes' AND REFERENCED_TABLE_NAME IN ('element_type','event_type','event_group')"`

Run the generated statements (drop the trailing `UNION ALL`) and expect zero everywhere. A
non-zero count names exactly which reference row the dump is missing. Note that the deletion
itself will have run with `FOREIGN_KEY_CHECKS=0` - Yii's fixture manager disables integrity
checks - so the FKs proved nothing at the time and are only useful now, on the way back.

**6. AUTO_INCREMENT.** A restored table carries the dump's counter. If newer rows existed, the
counter is now below the ids other tables reference and the next insert collides:

`docker exec <db> mariadb -u<user> -p<pass> openeyes -e "SELECT MAX(id) FROM element_type; SHOW TABLE STATUS LIKE 'element_type'"`

Raise it with `ALTER TABLE element_type AUTO_INCREMENT = <max+1>` if it is behind.

**7. The version mirrors.** OE mirrors these tables into `<table>_version`. Restore both, and
check the mirror's column set matches the base table - the same migration drift applies to it,
and `addOEColumn(..., true)` keeps them in step going forward.

**8. Application-level sweeps, last.** Once the data looks right, let the application judge it:
`yiic checkelementtypes` (zero `UNEXPLAINED`), `yiic checkrelations`, and load one event of each
event type. These catch the case where the rows are individually plausible but collectively
wrong - a class name that no longer exists, an element pointing at an event type that does not.

**What to do about a stale snapshot.** Restore the dump's rows first, then reconstruct the delta
from the migrations in step 2 - read each one and hand-apply only its writes to the affected
tables. Do not delete the `tbl_migration` rows and re-run those migrations wholesale: they also
create tables and seed unrelated data that is still present, so a re-run either fails halfway or
duplicates rows. The exception is a migration that only touches the damaged tables and is
written idempotently; that one is safe to replay.

## Can InnoDB undo logs recover the rows instead

No, and it is worth understanding why so the question does not come back.

Undo logs exist to roll back an open transaction and to serve older read views under MVCC. Once
the deleting transaction commits and no read view still needs the old versions, the purge
threads discard the undo records and physically remove the delete-marked rows. There is no
supported reader for undo tablespaces - no `flashback` for InnoDB in MariaDB.

Check whether purge has already run:

`docker exec <db> mariadb -u<user> -p<pass> -e "SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='INNODB_HISTORY_LIST_LENGTH'"`

Zero means purge has caught up and there is nothing left to read. That was the case here, within
minutes of the deletion, on an otherwise idle server.

What can work, in rough order of usefulness:

1. **Binary log with `binlog_format=ROW`.** `mysqlbinlog --flashback` inverts DELETE events back
   into INSERTs using the row images. This is the real answer to "undo the DELETE", but it needs
   `log_bin` to have been ON before the mistake. Check with
   `docker exec <db> mariadb -u<user> -p<pass> -e "SHOW VARIABLES LIKE 'log_bin'"`. It was OFF
   here, which is what forced the dump route.
2. **A filesystem or volume snapshot** from before the deletion.
3. **`undrop-for-innodb`** (`stream_parser` + `c_parser`) reads the `.ibd` pages directly and can
   sometimes recover delete-marked records. Two caveats: it only helps for `DELETE`, not
   `TRUNCATE`, because `TRUNCATE` drops and recreates the tablespace; and it only helps before
   purge has physically removed the records. Yii's `CDbFixtureManager::truncateTable()` issues a
   plain `DELETE FROM`, so the first condition held, but with the history list already at zero
   the second did not.

Note the distinction in point 3 when you assess damage. `TRUNCATE` shrinks the `.ibd` back to a
fresh tablespace, so a file that is still much larger than its remaining rows justify is a hint
that rows were deleted rather than truncated - useful, but not a recovery route on its own.

## Preventing the underlying mistake

The deletion came from running phpunit against a container where `DATABASE_TEST_NAME` was unset,
so the test connection fell back to the working database and the fixture manager emptied every
table named in a `$fixtures` array. Point the test connection at its own schema before running a
suite anywhere the data matters.
