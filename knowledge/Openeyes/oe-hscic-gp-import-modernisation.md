# Make the OpenEyes NHS directory import reliable and fast

Reviewed: 12 September 2026. Source: `protected/commands/ProcessHscicDataCommand.php`
at OpenEyes commit `ad2324084788608246a8250e817198c2f26a4fd6`.
This is a source review and proposed design, not a tested repair or benchmark.

## What needs fixing first

The `processhscicdata` command imports GPs, practices, optometrists, commissioning
bodies and practice assignments. It already reads CSV, but expects that CSV inside
a ZIP obtained by scraping NHS web pages. Direct CSV support removes the broken
download dependency; batching the database work is the larger performance opportunity.

NHS now publishes equivalent DSE predefined reports as direct CSV downloads. The
reports refresh nightly; the old monthly/quarterly amendment file service has
ended. Use the published report links, not a regular expression over page HTML.
The official page identifies `egpcur` for practitioners, `epraccur` for practices,
`epracmem` for practitioner memberships, and `epcmem` for commissioning mappings.
See [NHS GP download catalogue](https://digital.nhs.uk/services/organisation-data-service/data-search-and-export/csv-downloads/gp-and-gp-practice-related-data).

Changing only the URL is unsafe. The current GP parser treats only `A` and `P`
as active. DSE supplies status names instead. Its practitioner report also has
a narrower publication scope than the old file. Missing from DSE does not prove
that a historical practitioner should be deactivated. Membership reports have
their own full-file rules. See [NHS practitioner field specification](https://www.odsdatasearchandexport.nhs.uk/referenceDataCatalogue/General-Practitioners_571320285.html).

## Problems in the command

| Code area | Present behaviour | Required change |
| --- | --- | --- |
| `getDynamicUrls` / `mapFileConfig` | Scrapes several pages and insists on links ending in configured ZIP names. Even a full-file request resolves obsolete amendment links. | Resolve only the requested report through an explicit source profile. Allow a local CSV without any network access. |
| `processCSV` | Requires a ZIP member whose name is guessed from the URL. Reads once to count lines, then again to import. Uses positional columns without a schema/header gate. | Stream CSV once into validation/staging. Use a versioned header mapping; support headerless legacy input only with an explicit profile. |
| `importGp` / `importPractice` | One transaction per row, model and relationship lookups, repeated label/settings reads, then several saves. Dirty-save handling does not remove those reads. | Resolve configuration once, fetch existing keys in batches and apply only actual changes. |
| `processFile` | Copies the download into the supposedly processed location before import succeeds. A failure can leave a partially applied file looking already processed on retry. | Separate downloaded, validated, applying and completed states. Mark complete only after all chunks succeed. |
| `setCurlOpts` / `download` | Disables TLS peer verification, permits redirects, sets a connection timeout but no whole-transfer limit, and accepts any non-empty HTTP 200 body. | Verify TLS, constrain hosts/redirects, stream with byte and time limits, and reject HTML/error bodies before database changes. |
| `checkremovedfromfile` | Collects the whole source into memory and deactivates database records absent from it, without a clear source/region ownership boundary. | Disable absence-based deactivation until completeness and ownership are proven. Report candidates separately. |
| Audit/output | Compares a typed boolean `$audit` to the string `'false'`, prints progress for every row, and can print proxy configuration or complete failed rows. | Use real booleans, bounded summaries, redacted errors and durable audit evidence. Never print proxy credentials. |

The `downloadAndImportFromUrl` action is not a CSV solution as written: it still
passes the downloaded file to the ZIP-only parser.

## Proposed import sequence

1. **Acquire.** Fetch a configured HTTPS report, or accept an operator-supplied
   local CSV. Use a generated temporary filename, restrictive permissions and
   atomic finalisation. Record source, region, report/schema version, retrieval
   time, byte count and SHA-256. A checksum identifies the received file; it does
   not replace TLS or establish publisher authenticity. Keep downloads outside
   the public web root and outside git.
2. **Validate completely before applying.** Check required/duplicate headers,
   field counts, encoding/BOM, quoted fields/newlines, code formats, lengths,
   dates, known status values, duplicate identities and row-count anomalies.
   Reject unknown formats rather than silently mapping columns incorrectly.
   Do not silently truncate values to fit old column lengths. Preserve source
   names rather than guessing first names from every possible name format.
3. **Stage.** Stream bounded batches into an ordinary, pre-created InnoDB staging
   table keyed by run and source identity. This is not an optimizer temporary
   table and needs no runtime DDL. Keep the original file for reproducible retries.
   Validate foreign references before live writes. Apply practices before their
   memberships, and commissioning bodies before their assignments.
4. **Apply small atomic chunks.** Join staging to indexed natural keys. Insert
   new rows and update changed rows only. Preserve existing GP, contact, address
   and practice IDs, historical patient links and locally owned fields. Perform
   the required audit/history effects in the same chunk transaction. Do not
   replace whole tables, disable foreign keys or use `LOCK TABLES`.
5. **Checkpoint and finish.** Persist the last completed chunk and counts for
   inserted, changed, unchanged and rejected rows. Retrying the same run must be
   idempotent. Record completion separately from download success. A partially
   applied run must remain visibly incomplete and resumable.

Use explicit status mappings reviewed against the NHS specification. Unknown
values must fail validation, not become inactive. A delta may update only rows
it contains; it must never imply deletion of absent rows. Even a full report
needs a reviewed coverage policy before absence can change status. Retain closed
records needed by patients and historical correspondence.

Keep practitioner identity, role and practice membership distinct. Do not match
people by name, and do not assume the single parent practice in a GP report
describes every membership. Preserve manual provider numbers and practice-specific
email overrides unless an explicitly authoritative field is being updated.

## How to make it faster without hiding business rules

1. Start with cached reference lookups and bounded existing-record reads. Then
   compare batched parameterised inserts with an optional manager-only bulk loader.
   `LOAD DATA LOCAL INFILE` must not be enabled broadly just for speed; its file
   access and database-client security implications need a separate review.
2. Use set-based writes where they can preserve the model's actual rules. Inspect
   `Gp`, `Practice`, `Contact`, `Address`, their behaviours and audit hooks first.
   Bypassing ActiveRecord blindly can lose automatically created contacts, history,
   validation or correspondence-address behaviour. Keep a bounded model-based
   fallback where those effects have not yet been made explicit.
3. Match indexes to code/source lookups and chunk ordering. Test query counts and
   plans, including filesort/temporary-table work, on a realistic directory size.
   Do not force indexes. Avoid both one transaction per row and one transaction
   holding locks for the entire national directory.
4. Begin with one importer and small configurable chunks, for example 500 records
   as a starting point to measure. Monitor lock waits, database time, memory and
   replication lag before adding concurrency. Use a single-run lease per source,
   region and dataset; do not hold a database transaction open as the job lock.
5. Log a few phase summaries and a final result, not every row. Track last
   successful completion, current duration, failure reason and source age. Alert
   on stale or repeatedly failing imports through the deployment's monitoring.

## Minimum checks before release

1. Saved synthetic CSV fixtures prove header changes, full-word statuses, Unicode,
   BOM, quoted newlines, duplicate codes, unknown columns and missing references.
2. HTTP tests cover HTML with status 200, partial downloads, TLS failure, redirects,
   timeout, oversized responses, 429/503 and bounded retries.
3. Reimporting an unchanged file produces no clinical changes. A crash after one
   chunk resumes without duplicate contacts or a false completed marker.
4. Existing patient links, manual fields, audit/history and inactive records survive.
   A smaller report or region change cannot mass-deactivate unrelated records.
5. A separate read-only scheduled source-contract check detects endpoint/header
   changes and freshness problems. It must never modify clinical data. Keep
   deterministic CI independent of NHS service availability.

Scotland, Northern Ireland, optometry and commissioning feeds need their own
current specifications. Do not assume an England GP fix covers all report types.
GP practice files include prescribing-cost-centre distinctions and changed address
definitions; review [the NHS practice specification](https://www.odsdatasearchandexport.nhs.uk/referenceDataCatalogue/565791179.html)
before changing those mappings. Endpoint and schema checks must be repeated when
implementing: the website and report definitions can change again.
