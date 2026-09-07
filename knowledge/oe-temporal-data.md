# OpenEyes temporal data and migration

Read this before changing date or time columns, writing a date cleanup, or adding
date conversion to a hot query.

## The short rule

Do not make every date-like field the same database type. Make every field with
the same meaning use the same representation.

| Meaning | Recommended representation |
|---|---|
| A real moment, such as when a request was received | UTC `DATETIME`, with an agreed fractional-second precision |
| A calendar fact, such as date of birth | `DATE` |
| A time of day with an authoritative date elsewhere | `TIME` |
| An incomplete date, such as year only | Separate year, month, day and precision fields |
| The text received from another system | A separate raw source field when traceability requires it |

A value that is compared on most reads should already be stored in the form used
by that comparison. The application should not repeatedly run `DATE(column)`,
`YEAR(column)` or another conversion over every candidate row.

For a day filter over a UTC `DATETIME`, calculate the local day's UTC boundaries
once and compare the bare column:

```sql
WHERE starts_at >= :start_utc AND starts_at < :next_start_utc
```

If a large operation repeatedly groups by local clinic day, an indexed
`clinic_date` or a maintained projection may be justified. Its source timezone
and update rule must be explicit.

## Why old OpenEyes needs an inventory first

Old OpenEyes has several generations of date handling. Examples include normal
`DATE`, `DATETIME` and `TIME` columns, date-shaped strings, audit stamps with old
sentinel defaults, and values whose date is inferred from an event or creation
time. The same column name is not enough to prove that two fields mean the same
thing.

The Diagnoses2 migration is a useful example:

`protected/modules/Diagnoses/migrations/m231201_164500_initialise_patient_state_from_old_model.php`

It converts old diagnosis strings with `CASE`, `REGEXP` and `STR_TO_DATE`. It
accepts dashed and compact numeric forms, writes `NULL` when it cannot parse a
value, and records the original problem in a comment. Some recording dates fall
back to `last_modified_date`; later statements fill missing observations from
other diagnosis events.

An earlier migration,
`protected/modules/OphCiExamination/migrations/m180425_133636_set_diagnoses_date.php`,
fills an empty diagnosis date from the row's `created_date`.

These migrations show that inconsistent and missing dates are real. They are not
a parser specification to copy. A regular expression can match an impossible
calendar date, a fallback can change clinical meaning, and a value converted to
midnight no longer says whether midnight was real or the source omitted the time.

Before changing the rewrite schema, inventory the actual final legacy schema and
representative deployments. Count candidate columns, rows and bytes, including
the large `_version` tables. Then identify every reader, writer, comparison,
grouping and ordering operation. The change may affect only a small number of
columns, but that must come from evidence.

## `DATETIME` and `TIMESTAMP`

The two types look similar in query output, but they have different behaviour.

| Property | `DATETIME` | `TIMESTAMP` |
|---|---|---|
| Stored meaning | Calendar date and time exactly as supplied | Seconds from the UTC Unix epoch |
| Session timezone conversion | None | Converted between the session timezone and UTC |
| Stores the timezone name | No | No |
| MariaDB range | Year 1000 through 9999 | MariaDB 11.8: 1970 through early 2106 |
| Fractional seconds | 0 to 6 digits | 0 to 6 digits |
| Old automatic behaviour | Only when explicitly declared | First column could gain automatic current/update behaviour on older defaults |
| Good OpenEyes default | UTC clinical and application instants | Only when implicit timezone conversion or server-managed timestamp behaviour is deliberately required |

MariaDB documents `DATETIME` as unaffected by the session timezone. It documents
`TIMESTAMP` as epoch seconds stored in UTC and displayed in the session timezone.
The `TIMESTAMP` upper range was 2038 before MariaDB 11.5 and is 2106 on MariaDB
11.8. It still cannot represent a date of birth or historical clinical fact before
1970. `DATETIME` has the wider range and avoids a session setting silently changing
the displayed value. Neither type retains an IANA timezone name. A `TIMESTAMP`
retains an instant, not the name or rule used to convert the original input.

Useful MariaDB references:

- [DATETIME](https://mariadb.com/docs/server/reference/data-types/date-and-time-data-types/datetime)
- [TIMESTAMP](https://mariadb.com/docs/server/reference/data-types/date-and-time-data-types/timestamp)
- [Database design and temporal types](https://mariadb.com/docs/server/mariadb-quickstart-guides/database-applications/database-design)

### When `TIMESTAMP` can be useful

`TIMESTAMP` is useful when all of these are intentional:

1. The value is definitely a real instant within its supported range.
2. MariaDB should translate it using the session timezone.
3. Every connection has a controlled timezone configuration.
4. Automatic `DEFAULT CURRENT_TIMESTAMP` or `ON UPDATE CURRENT_TIMESTAMP` behaviour
   is wanted and declared explicitly.

That is a narrow case in OpenEyes. The application owns clinical audit and history,
so a database field that changes automatically can hide why a row changed. A UTC
`DATETIME` written explicitly by the application is usually simpler. It is a
convention rather than a timezone-aware database type, so validation and tests
must enforce that it is UTC.

Do not use `TIMESTAMP` merely because the value is called a timestamp. Do not mix
`DATETIME` and `TIMESTAMP` for the same concept without a documented reason.

## Daylight saving time

UTC has no daylight-saving gap or repeated hour. Local civil time does.

In the UK, clocks move forward in spring. Some local times never occur. They move
back in autumn, so some local times occur twice. A local value such as
`2026-10-25 01:30:00` is not one unique instant without a timezone and an offset or
another disambiguation rule.

Use these rules:

1. Store completed real-world instants in UTC.
2. Keep the source IANA timezone, such as `Europe/London`, when it is needed for
   display, audit or reconstruction. Do not store only a fixed `+00:00` or `+01:00`
   offset as the timezone rule.
3. Convert at a controlled application boundary and test both sides of the spring
   gap and autumn overlap.
4. Keep a calendar `DATE` as a calendar fact. Never shift a date of birth because
   a viewer is in another timezone.
5. For future clinic schedules or recurrences, retain the intended local date,
   local time and IANA zone, then derive each UTC occurrence. Timezone rules can
   change after the schedule is created.
6. Set ordinary database sessions to UTC. If database-side named-zone conversion
   is used, load and update MariaDB's timezone tables and test the exact server
   version. `CONVERT_TZ()` returns `NULL` for invalid arguments or unavailable named
   zones.

MariaDB reference:

- [CONVERT_TZ](https://mariadb.com/docs/server/reference/sql-functions/date-time-functions/convert_tz)
- [Loading named timezones](https://mariadb.com/docs/server/clients-and-utilities/administrative-tools/mariadb-tzinfo-to-sql)

## Cleaning old data

Build one read-only profiler before writing repair SQL. It should classify and
count, by table and column:

- empty strings, zero dates and zero date parts;
- known sentinel years and default values;
- impossible dates and values outside the field's valid business range;
- dashed, compact and other mixed input formats;
- partial dates that must not be expanded into invented precision;
- `NULL` and default disagreements;
- dates that contradict their parent event or another authoritative value;
- instants missing their timezone context;
- local times in a daylight-saving gap or overlap;
- midnight values where the concept normally requires a known time.

Midnight is not proof that a time was missing. Once MariaDB has accepted a date-only
input into a `DATETIME`, both a real midnight and an omitted time appear as
`00:00:00`. A cleanup can call this suspicious only when the column's meaning and an
authoritative source support that conclusion.

The profiler should suggest, but not silently apply, one of these actions:

1. Parse without losing information.
2. Keep the value as a `DATE`.
3. Combine it with a documented authoritative parent value.
4. Preserve it as partial or explicitly unknown.
5. Quarantine it for clinical review.
6. Leave it unchanged.

Normal output contains counts and reason codes, not patient identifiers or raw
clinical values. Any repair must be idempotent, auditable and reversible, with
before and after counts and checksums. Safe repairs can be released to old
OpenEyes before cutover so the migration night has less work. Ambiguous values
must not be guessed.

## Choosing the cutover method

Type conversion in the new schema and cleanup of bad old values are separate
problems. Most target-type conversion can happen while loading the empty new
schema. It does not require altering a large live legacy table.

| Method | Benefit | Cost or risk |
|---|---|---|
| Same-instance `INSERT ... SELECT` | No network copy, set-based, restartable by PK range | Conversion and writes share database CPU and I/O |
| Normalize to CSV, then bulk load | Can separate conversion from target loading and use fast bulk import | Extra read/write pass, temporary sensitive files, escaping and disk-space risks |
| Load a shadow target table, validate, then switch | Clear validation and retry boundary | Extra storage and index-build work |
| Alter the live legacy table in place | Avoids a separate target transform | Highest lock, rollback and compatibility risk; normally the wrong choice |

The rewrite plan currently uses same-instance, PK-chunked `INSERT ... SELECT` as
the default. Benchmark the real candidate columns on a production-sized disposable
copy before changing that decision. Measure elapsed time, CPU, I/O, temporary
space, redo/undo and binlog volume, locks, CDC lag, index build, reconciliation,
failure restart and rollback. Include history tables because they may dominate the
row count even when only a few base columns change.

## Review checklist

1. Is this a moment, date, time of day, partial date or source notation?
2. Is the stored timezone rule explicit?
3. Can a hot query compare the bare indexed column?
4. Is missing precision preserved rather than invented?
5. Has old data been counted before a type or cleanup rule is chosen?
6. Has the migration path been timed on production-sized data?
7. Do row counts, checksums, null counts and clinical invariants reconcile?
