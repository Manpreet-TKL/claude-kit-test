# Orphaned `archive_allergy` foreign key in OpenEyes (OE 10.0 onwards)

Read when a MariaDB error log is filling with `InnoDB: Foreign Key referenced
table ... not found`, when an insert into either
`ophtrintravitinjection_*_allergy_assignment` table fails with ERROR 1452, or
before concluding that the intravitreal injection allergy warning "does not
work". Also read before adding an `archive_%` cleanup step to any reset or
seeding script.

Evidence base: the stock OE 10.0 sample database image
`toukanlabsdocker/oe-sample-db:mariadb_11.8-10.0` (built 2026-05-11, the day
`release/10.0.x` went static), a synthetic reproduction on `mariadb:10.6`
(10.6.27), and the code at `v10.0.30` and `master`. All checked 2026-09-06.

## Symptom

Pairs of these, same connection id, same second, tens per second on a busy
MariaDB 10.6 instance:

    [Note] InnoDB: Foreign Key referenced table openeyes/archive_allergy not found for foreign table openeyes/ophtrintravitinjection_skindrug_allergy_assignment
    [Note] InnoDB: Foreign Key referenced table openeyes/archive_allergy not found for foreign table openeyes/ophtrintravitinjection_antiseptic_allergy_assignment

Over 1 MB/hour of error log on a weekday, which buries everything else in it.

## The log noise is the least of it

A dangling foreign key is not an unenforced one. InnoDB cannot resolve the
parent, so it rejects **every** write to the child. Verified against the real
sample tables, not a synthetic case:

    INSERT INTO ophtrintravitinjection_skindrug_allergy_assignment (skindrug_id, allergy_id) VALUES (1, 3);
    ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
    (`openeyes`.`ophtrintravitinjection_skindrug_allergy_assignment`, CONSTRAINT
    `ophtrintravitinjection_skindrug_allergy_assign_allergyi_fk` FOREIGN KEY (`allergy_id`)
    REFERENCES `archive_allergy` (`id`))

Reads are unaffected. So the tables are readable, frozen, and silently
unconfigurable.

## What the tables are for

They are the drug-to-allergy mapping behind the injection safety check. The
models declare them as `MANY_MANY` against the `Allergy` model, whose
`tableName()` is `allergy` - a **view** over `ophciexamination_allergy` created
by `m170510_131532`:

- `OphTrIntravitrealinjection_SkinDrug.php:90`
- `OphTrIntravitrealinjection_AntiSepticDrug.php:88`

Consumers:

- `views/default/form_Element_OphTrIntravitrealinjection_Treatment_fields.php:21,41`
  eager-loads `with('allergies')` and sets `data-allergic` / `data-allergy` on
  the antiseptic and skin-prep dropdowns when `$this->patient->hasAllergy(...)`.
- `Element_OphTrIntravitrealinjection_Treatment::setDefaultOptions()` (`:360`,
  `:368`) refuses to default to a drug the patient is allergic to.

There is **no write path in the module** - it is reference data, seeded or
maintained by hand. Which is why nobody notices the table is frozen: the failure
mode is an empty mapping and a warning that never fires, not an error on screen.
On an affected instance, check whether the two tables have any rows at all
before assuming the check has ever worked.

## How the database got here

Three steps, and the one that breaks it is not a migration.

| Step | Where | Effect |
|---|---|---|
| 1 | `OphTrIntravitrealinjection/migrations/m131010_074031_allergy_checking.php` | Creates both tables with `FOREIGN KEY (allergy_id) REFERENCES archive_allergy (id)` |
| 2 | `OphCiExamination/migrations/m170510_131532_event_allergy_record.php` | Renames `allergy` to `archive_allergy`, copies it to `ophciexamination_allergy`, leaves a view `allergy` over the copy |
| 3 | `protected/scripts/oe-reset.sh --drop-archive`, line 477 | `SET FOREIGN_KEY_CHECKS = 0; DROP TABLE <every archive_% table>; SET FOREIGN_KEY_CHECKS = 1;` |

Detail worth knowing:

- **The 2013 migration did not originally say `archive_allergy`.** It said
  `allergy`. Commit `8a783fc83e` ("OE-7023 Refactoring of table and field names
  in migrations") retro-edited historical migration files to the post-rename
  names. So on a fresh `migrate up` the 2013 migration now creates a foreign key
  to a table that will not exist for another four years of migration history.
- **Step 2 is not the break.** `RENAME TABLE` is followed into child constraints
  by InnoDB, so after `m170510` the two foreign keys are still valid, pointing at
  the renamed parent.
- **Step 3 is the break.** Dropping the parent with `FOREIGN_KEY_CHECKS = 0`
  leaves the child constraints in the InnoDB dictionary with nothing to resolve
  against. Any instance built from a sample dump produced this way inherits it.
- The same script is unchanged on `master`.

## The fix already exists for a third table

`protected/migrations/m190523_130701_alter_constraint_drug_allergy_assignment_allergy_id_fk.php`,
commit `84c5f2111c` ("OE-8561 alter_constraint `drug_allergy_assignment_allergy_id_fk`
to reference the correct table (`ophciexamination_allergy` instead of
`archive_allergy`)"). Three tables had this constraint; one was fixed, two were
missed. Copy its shape, including the column retype - it does
`alterColumn('allergy_id', 'INT NOT NULL')` for a reason (see below).

## Detection

One query finds every orphaned foreign key in the schema, not just this pair:

    SELECT f.FOR_NAME AS child_table, f.REF_NAME AS missing_parent
    FROM information_schema.INNODB_SYS_FOREIGN f
    LEFT JOIN information_schema.TABLES t ON CONCAT(t.TABLE_SCHEMA,'/',t.TABLE_NAME) = f.REF_NAME
    WHERE t.TABLE_NAME IS NULL ORDER BY f.FOR_NAME;

On the OE 10.0 sample database it returns exactly two rows, both to
`openeyes/archive_allergy`, and nothing else. The `_version` twins of the two
tables carry no foreign keys and are unaffected.

## What emits the note, and what does not

Measured on MariaDB 10.6.27 by counting error-log lines around each statement.
This matters because the obvious theory (the injection event save does it) is
wrong, and so is the second theory (dictionary cache eviction).

| Statement | Emits? |
|---|---|
| `SELECT`, joins, `DESCRIBE`, `SHOW CREATE TABLE`, `SHOW TABLE STATUS` | no |
| `ANALYZE TABLE`, `TRUNCATE`, `LOCK TABLES`, transaction + rollback | no |
| Forced dict eviction (`table_definition_cache=400`, 700 filler tables) | no |
| `information_schema.COLUMNS`, `.STATISTICS` | no |
| **`ALTER TABLE`** | one line per broken constraint |
| **`information_schema.KEY_COLUMN_USAGE`** | one line per broken constraint |
| **`information_schema.REFERENTIAL_CONSTRAINTS`** | one line per broken constraint |
| **`information_schema.TABLE_CONSTRAINTS`** | one line per broken constraint |

A single one of those `information_schema` reads emits **both** lines on the same
connection id in the same second, which reproduces the production pairing
exactly. So a flood means something is reading foreign-key metadata many times a
second. Nothing in the OE request path does
(`CheckRelationsCommand`, `OEMigration` helpers and two migrations are the only
callers in the repo), so the caller is outside Yii - a Laravel/Doctrine
introspection, a Hibernate `validate`, an ORM in an integration service, or a
monitoring agent. The note carries the connection id; match it against
`SHOW FULL PROCESSLIST` while it is happening to name the caller.

## Version behaviour

| Engine | Emits the note | Rejects the insert |
|---|---|---|
| MariaDB 10.6 | yes | yes |
| MariaDB 11.8 | no | yes |

An upgrade to 11.8 silences the log flood and leaves the broken constraint and
the ERROR 1452 exactly where they were. Do not read "the noise stopped" as "the
schema was fixed".

## Fixes, in priority order

1. **Repoint both constraints at `ophciexamination_allergy`.** The right fix:
   restores integrity, stops the noise, and unfreezes the tables so the allergy
   mapping can be configured. `allergy_id` is `int(10) unsigned` and
   `ophciexamination_allergy.id` is `int(11)` signed, so the column must be
   retyped in the same statement or the `ADD CONSTRAINT` fails - the same trap
   `m190523_130701` hit:

        ALTER TABLE ophtrintravitinjection_skindrug_allergy_assignment DROP FOREIGN KEY ophtrintravitinjection_skindrug_allergy_assign_allergyi_fk, MODIFY allergy_id INT NOT NULL;
        ALTER TABLE ophtrintravitinjection_skindrug_allergy_assignment ADD CONSTRAINT ophtrintravitinjection_skindrug_allergy_assign_allergyi_fk FOREIGN KEY (allergy_id) REFERENCES ophciexamination_allergy (id);

   and the antiseptic pair with `antiseptic` substituted throughout. Any existing
   row whose `allergy_id` does not resolve blocks this with the same ERROR 1452,
   so left-join against `ophciexamination_allergy` first and clear what comes
   back.
2. **Drop both constraints** if the allergy warning is deliberately not wanted.
   Stops the noise and unfreezes writes, leaves `allergy_id` unvalidated. The
   `KEY` on `allergy_id` survives `DROP FOREIGN KEY`, so no plan changes.
3. **Upstream**: a migration in `OphTrIntravitrealinjection` doing what
   `m190523_130701` did, plus dropping the two constraints in `oe-reset.sh`
   before the `archive_%` drop. Unfixed on `master` as of 2026-09-06.
4. **Do not recreate an empty `archive_allergy`.** It does work - InnoDB
   re-resolves the constraint by name and the note stops on the next
   introspection, verified - but it reinstates a dead table and validates against
   nothing useful.

## Reproducing it

    docker run -d --name oe-fk-probe-db -e MYSQL_ROOT_PASSWORD=openeyes toukanlabsdocker/oe-sample-db:mariadb_11.8-10.0 mariadbd

The image has **no default CMD**; without the trailing `mariadbd` its entrypoint
runs the init scripts and exits immediately. Root password is `openeyes`, schema
is `openeyes`. Being 11.8 it reproduces the broken constraint and the ERROR 1452
but not the log note - use a plain `mariadb:10.6` with a hand-built child table
for that.

## Not verified

- Which process on a live instance is reading the foreign-key metadata views.
  The class of statement is established; the caller is not.
- Whether affected instances have any rows in the two tables, i.e. whether the
  injection allergy warning was ever configured before the tables froze.
- Whether any instance predating the OE-7023 retro-edit and never reset with
  `--drop-archive` still has a live `archive_allergy` and working constraints.
