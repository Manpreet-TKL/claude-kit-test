# OpenEyes dm+d update plan

## Goal

Replace the destructive, manually assembled dm+d import with an auditable,
repeatable update process that can ingest the official NHS release efficiently,
show its clinical and configuration impact, require approval, preserve existing
OpenEyes references and report when the catalogue becomes stale.

The first implementation should update the VTM, VMP and AMP scope already used
by OpenEyes. It should not claim complete dm+d coverage and should not add new
concept classes until a workflow and data-model review establishes a need.

## CR approach

Reopen CR-379 or create a replacement CR if workflow rules do not permit an
expired request to be reopened. Make it the parent implementation item and link:

| CR | What to carry into the implementation |
| --- | --- |
| CR-379 | NHS acquisition, backend update command, validation, de-duplication, logging and scheduled preparation |
| CR-361 | Existing manual-add stopgap and the requirement for secondary clinical-safety validation |
| CR-443 | Upstream format-change detection, visible run results, failure alerts and staleness monitoring |
| CR-459 | Candidate matching may be automated, but local-to-national merging remains manual and separately reviewed |

CR-361 should not be expanded into the updater merely because it is already in
development. It solves a narrower manual-entry problem. The national update
mechanism has different acquisition, provenance, failure, rollback and clinical
safety requirements.

## Proposed operating model

The updater has separate prepare and apply stages.

| Stage | May run unattended | Result |
| --- | --- | --- |
| Acquire and prepare | Yes | Verified source archive, isolated staging data, immutable diff and impact report, report digest and health status |
| Review | No | A second person reviews the exact prepared report and records an approval reference |
| Apply | No | An explicit command applies only the reviewed run and digest in one transaction |

This resolves the tension between CR-379's proposed weekly automation and
CR-361's clinical-safety recommendation. A weekly job may download, validate and
prepare a release. It must not change the live medication catalogue. Unattended
application requires a separate clinical-safety decision and CR approval.

## Scope and acceptance criteria

The initial delivery is complete when all of the following are true:

1. OpenEyes can acquire an official dm+d item 24 archive through the TRUD API or
   accept the same official archive from an operator-provided local path.
2. It verifies provenance, size, SHA-256 data, signature material where supplied,
   ZIP paths, manifest, XSDs and expected source files before parsing data.
3. It streams VTM, VMP and AMP XML into isolated staging tables without loading a
   complete source file into PHP memory.
4. It produces a deterministic change and referential-impact report without
   changing live medication records.
5. A different operator can approve and explicitly apply the exact run and
   report digest that was reviewed.
6. Existing national concepts are updated in place and retain their
   `medication.id` values and all clinical references.
7. New, changed, retired, reactivated, duplicate and historic-code cases have
   explicit, tested behaviour.
8. Local and manually created records are not silently converted, deleted or
   linked to national records.
9. The current release and update health are available in human-readable and
   machine-readable form, with non-zero status for failures or staleness.
10. The update is idempotent, fails closed on unknown source changes, rolls back
    on an application failure and invalidates affected caches after success.
11. An efficient bulk-load path and a safe fallback produce equivalent staging
    data.
12. Runbooks cover initial classification of existing data, routine operation,
    failure recovery and rollback from a database backup.

## Proposed OpenEyes interface

Use a dedicated Yii console command named `DmdUpdateCommand.php`. Keep public
actions at the bottom of the command class and documented helpers above them, in
line with the OpenEyes command conventions.

The proposed operator commands are:

- `php protected/yiic dmdupdate prepare`
- `php protected/yiic dmdupdate prepare --archive=/path/to/release.zip`
- `php protected/yiic dmdupdate status`
- `php protected/yiic dmdupdate status --format=json`
- `php protected/yiic dmdupdate apply --runId=<id> --reportDigest=<sha256> --approvalReference=<reference> --confirm=yes`

There should be no public HTTP update endpoint and no update-triggering admin UI
in the first delivery. A later read-only status card can display the same status
and report data without becoming another mutation path.

## Data and provenance model

Add an update-run ledger such as `dmd_update_run`. It should record:

- TRUD item, release version and release date
- archive name, byte size, SHA-256 and verified manifest details
- updater version and supported concept-class scope
- state such as acquired, staged, prepared, approved, applying, applied or failed
- row and diff counts for every concept class
- referential-impact counts
- immutable report location and SHA-256 digest
- preparation, approval, application and failure timestamps
- operator identity, approval reference and failure reason

Add a historical-code table such as `dmd_historic_code` containing the previous
code, current code, concept class, effective date and source release.

Add explicit medication provenance. A field such as `dmd_origin` could use:

| Value | Meaning |
| --- | --- |
| `NHS_RELEASE` | Code and identity verified in an applied official NHS release |
| `MANUAL_UNVERIFIED` | Manually added placeholder, including current `UNMAPPED` records |
| `LEGACY_UNVERIFIED` | Pre-existing `DM+D` row that could not be verified during initial adoption |

`LOCAL` records remain outside national provenance. The exact schema naming may
change during design, but these states must remain distinguishable in the data,
UI, reports and update rules.

## Source acquisition and storage

Use the TRUD API for dm+d item 24. Store the credential as a deployment secret
outside every repository. A non-secret setting such as `DMD_TRUD_API_KEY_FILE`
may point to that mounted secret. Never put the API key, cookie, downloaded
client data or deployment identity in the repository.

Support an offline mode that accepts an operator-provided official item 24 ZIP.
This provides a controlled path for restricted deployments and recovery without
making arbitrary CSV files part of the trusted input contract.

Use a private persistent runtime directory configured by a setting such as
`DMD_UPDATE_STORAGE_DIR`. Each run receives a generated `0700` subdirectory. The
process must reject archive path traversal, symbolic-link input and unexpected
files. Retain an agreed number of complete archive, manifest and report sets,
with eight as a reasonable starting point, subject to local retention policy.

Verification must use the release metadata returned by TRUD, including archive
size and SHA-256 information, plus the published checksum, signature and public
key material where present. A mismatch prevents staging and sets a failed health
state.

## Efficient XML, CSV and TSV ingestion

Keep the official XML archive as the canonical source. Parse it with a streaming
reader so memory usage is related to an individual record rather than to the
complete release.

For the fast path, write importer-generated UTF-8 TSV files and bulk-load them
into per-run all-text staging tables with `LOAD DATA LOCAL INFILE`. TSV is the
preferred internal representation because the importer controls escaping and
columns. A normal RFC 4180 CSV report may be produced for review, but a
third-party CSV should not be accepted as equivalent to a verified NHS release
in the first delivery.

The bulk loader must:

1. Use a dedicated database connection constructed with
   `PDO::MYSQL_ATTR_LOCAL_INFILE` and, where supported,
   `PDO::MYSQL_ATTR_LOCAL_INFILE_DIRECTORY` restricted to the run directory.
2. Generate every filename itself and allowlist every target table and column.
3. Reject source rows containing unexpected record structure, fields or invalid
   encoding before the live-data transaction.
4. Load into all-text staging columns first, then validate and convert types with
   explicit rules.
5. Check warnings, rejected rows, nullability, lengths, value domains, duplicate
   keys and input-to-stage row counts. MariaDB can disable strict SQL modes for
   `LOCAL`, so SQL mode alone is not adequate validation.
6. Remove generated staging files according to the approved retention policy.
7. Fall back to bound multi-row inserts when `local_infile` or the client option
   is unavailable. The fallback must pass the same validations and generate the
   same deterministic stage digest.

The NHS XML transformation workbook can create CSV, so it is useful as a manual
diagnostic aid. It must not become a production dependency because it requires
Windows, Excel, a macro-enabled workbook and a separately downloaded release.

## Prepare-stage design

The prepare action should:

1. Obtain an application-level advisory lock so only one prepare or apply
   operation can run at a time.
2. Resolve the requested or newest release and refuse a downgrade by default.
3. Acquire and verify the complete archive and manifest.
4. Check the source version, files, XSDs, element structure and known concept
   classes. Unknown mandatory content fails closed and requires importer review.
5. Stream VTM, VMP, AMP, relevant lookup and historical-code data into isolated
   staging tables.
6. Validate relationships, subtype consistency, duplicate codes, required
   fields, allowed values and complete row-count reconciliation.
7. Compare the staging snapshot with current `DM+D` data by `source_type` and
   `preferred_code`.
8. Produce a deterministic report, save its digest and mark the run `PREPARED`.

The report must separate:

- new, changed, unchanged, retired and reactivated concepts
- changes to descriptions, supplier terms, forms, routes and dose units
- duplicate names with different official codes
- subtype mismatches for an existing code
- historic and replacement-code relationships
- affected prescriptions and event medication-use records
- affected medication sets, automatic rules, aliases and defaults
- affected allergy assignments and PGD/PSD configuration
- manual `UNMAPPED`, legacy-unverified and local candidate matches
- integration and reporting checks that require human follow-up

The prepare stage must never modify live medication or clinical tables.
Repeating preparation of the same archive against the same database snapshot
must produce the same stage and report digests. A newer complete release may
supersede an older unapplied preparation, but the previous report remains in the
audit ledger.

## Review and approval

The reviewer receives the exact report and digest created by preparation. The
review checklist should require:

1. Source release, checksum and scope are expected.
2. Total and per-class counts are plausible against the preceding applied
   release and the NHS release notes.
3. All schema and relationship validation passed without ignored warnings.
4. Retirement, reactivation, duplicate-code and subtype-mismatch cases were
   reviewed.
5. High-impact clinical and configuration references were reviewed.
6. Manual, local and legacy-unverified matches were not scheduled for automatic
   merging.
7. A current database backup and tested recovery procedure are available.

Approval records a human-readable reference, approver, timestamp, run ID and
report digest. Editing or regenerating the report invalidates the approval.

## Apply-stage design

Before applying, reacquire the lock, verify the same source archive, rebuild or
revalidate staging, and recompute the report digest. Refuse the operation unless
the run ID, digest and approval reference match the reviewed preparation.

Apply the live-data changes in one database transaction:

1. Match a national record by `source_type = DM+D` and `preferred_code`, and
   require its subtype to match the staged concept class.
2. Insert new concepts with `NHS_RELEASE` provenance.
3. Update official NHS fields in place without changing `medication.id`.
4. Preserve local short terms, aliases, default route/form/dose choices,
   medication-set membership and other manual configuration unless an explicitly
   reviewed field rule says otherwise.
5. Preserve each distinct AMP code and official supplier description. Never
   group separate AMP concepts solely by preferred text.
6. Store the previous official term as a search alias when a description changes,
   subject to duplicate and length rules.
7. Soft-retire an absent concept by setting its retirement fields and making it
   unavailable for new prescribing while keeping historical references intact.
8. Reactivate the same row if the code returns in a later release.
9. Insert historic-code relationships without rewriting past clinical records.
10. Mark the release applied, write the immutable audit summary and invalidate
    affected medication caches only after the transaction succeeds.

The first adoption needs a one-time classification report:

| Existing record | Initial action |
| --- | --- |
| Code and subtype match the official release | Mark `NHS_RELEASE` and update under normal rules |
| Current `UNMAPPED` record | Mark `MANUAL_UNVERIFIED`; do not auto-link |
| Other `DM+D` record absent from the official release | Mark `LEGACY_UNVERIFIED`; require review before any change |
| `LOCAL` record with a possible national match | Report a CR-459 candidate only; do not auto-link |

An in-transaction error rolls back the whole application. Recovery after a
committed but operationally unacceptable update uses the verified database
backup and an explicit recovery runbook, not a reverse importer that might
destroy intervening clinical data.

## Scheduling and health monitoring

Schedule `prepare` only, for example at 04:15 UK time on Tuesday after the normal
Monday TRUD publication. Confirm the production schedule against the current
TRUD recommended access window before implementation.

Use these initial policy targets, subject to clinical-safety approval:

| Age of last successfully applied release | Status |
| --- | --- |
| Up to 14 days | Healthy target |
| More than 28 days | Warning |
| More than 56 days | Critical |
| Unknown release, failed verification or failed application | Critical |

The machine-readable status command should expose the active release, last
successful prepare and apply times, latest available release, age, state, failure
reason and report location. It returns non-zero for warning, critical, failed or
unknown states so existing monitoring can alert. The run summary must be visible
even when the upstream source format changes, addressing the silent failure seen
in CR-443.

## Testing and verification

### Import and validation tests

1. Stream XML containing special characters, UTF-8 data, empty optional fields
   and maximum allowed values.
2. Prove bulk-load and bound multi-row fallback paths create identical stage
   rows and digests.
3. Cover new, changed, unchanged, retired, reactivated, historic, duplicate and
   subtype-mismatch cases.
4. Prove two AMP records with the same display term and different codes survive
   as separate medications.
5. Reject a bad ZIP, path traversal, checksum mismatch, signature failure,
   malformed XML, changed XSD, changed manifest, unknown required file,
   truncated input, row-count mismatch and database warning.
6. Cover network failure, lock contention, disabled `local_infile`, insufficient
   storage and an interrupted prepare.

### Application and clinical-data tests

1. Existing `medication.id` values and every referencing row remain stable.
2. Local aliases, short terms, defaults, set membership and manual configuration
   survive an update.
3. Manual and legacy-unverified records remain excluded from automatic national
   matching and application.
4. Retirement hides a concept from new prescribing without removing historic
   prescriptions, medication use, allergies or PGD/PSD configuration.
5. Reactivation restores the same medication row.
6. Historic-code lookup resolves the current concept without changing the code
   stored on an old clinical record.
7. A failed apply rolls back all live changes and does not advance the active
   release.
8. Applying the same release twice is idempotent; downgrade and stale-digest
   attempts are refused.
9. Applying an approved report after the database comparison state has changed
   is refused and requires a new preparation.
10. A successful update invalidates relevant medication caches and reports the
    expected national codes.

### Operational verification

Benchmark the new process against the legacy importer on equivalent database
copies and the same NHS release. Record elapsed time, peak process memory,
temporary storage, database load time, transaction and lock duration, and final
row counts. Do not claim a speed multiplier until these measurements exist.

Run a restore exercise before first production use. Exercise alerts for a missed
weekly release, failed checksum, source-schema drift and release age crossing
warning and critical thresholds.

## Delivery sequence

1. Confirm the CR scope, clinical-safety owner, supported concept classes,
   approval model, status thresholds and retention policy.
2. Add the run ledger, historic-code model and explicit medication provenance,
   including a report-only migration assessment of existing records.
3. Implement acquisition, archive verification, private storage and offline ZIP
   support.
4. Implement streaming XML parsing, controlled TSV generation, bulk loading and
   the equivalent fallback path.
5. Implement staging validation and the deterministic diff and impact report.
6. Implement the approval-bound transactional apply, stable-ID rules, retirement,
   reactivation, historic codes and cache invalidation.
7. Add status output, scheduled preparation, health checks and alerts.
8. Complete automated tests, performance comparison, clinical-safety review,
   operator documentation, backup and restore exercise, and a dry run using the
   latest named NHS release.
9. Roll out prepare-only first. Review at least two consecutive weekly reports
   before authorising the first apply.

## Deferred decisions and follow-on CRs

The following should not delay the safe VTM/VMP/AMP update unless discovery
shows they are required by an existing workflow:

| Item | Recommended treatment |
| --- | --- |
| VMPP, AMPP, TF and TFG | Separate data-model and workflow assessment |
| Device coverage | Audit actual OpenEyes device use before changing scope |
| Local and `UNMAPPED` merging | Separate manual CR-459 workflow with candidate suggestions only |
| Terminology Server lookups | Follow-on for point validation, manual additions and code history |
| Read-only admin status card | Follow-on consumer of the command status, with no update action |
| Live terminology-backed prescribing pickers | Separate architecture and availability decision |
| Unattended apply | Separate CR and clinical-safety approval after operational evidence exists |

## Paste-ready CR-379 replacement or addendum

### Summary

Provide an auditable backend mechanism to keep the OpenEyes VTM, VMP and AMP
catalogue aligned with named official NHS dm+d releases. The mechanism must
separate automated download and preparation from a second-person approved
application, preserve clinical references and expose update health.

### Source and security

- Use the official TRUD dm+d item 24 API or an operator-provided copy of the same
  official release archive.
- Store TRUD credentials as deployment secrets outside source repositories.
- Verify release metadata, archive size, SHA-256, checksum and signature material
  before parsing.
- Reject unexpected archive paths, files, schema changes and concept classes.

### Preparation

- Stream the official XML into isolated staging tables.
- Support controlled importer-generated TSV plus `LOAD DATA LOCAL INFILE`, with
  a validated bound multi-row fallback.
- Validate every row count, warning, type, required field, relationship and
  duplicate rule.
- Create an immutable diff and referential-impact report with a SHA-256 digest.
- Permit unattended weekly preparation but make no live medication changes.

### Approval and application

- Require a second-person approval reference tied to the prepared run ID and
  report digest.
- Re-verify the archive, comparison state and digest immediately before apply.
- Apply in one transaction by national code, preserving every existing
  `medication.id` and its clinical and configuration references.
- Soft-retire and reactivate concepts; never hard delete historic use.
- Preserve local configuration and never automatically merge local, `UNMAPPED`
  or legacy-unverified records into national records.
- Preserve distinct AMP codes even when display text is identical.
- Import historical-code relationships and invalidate affected caches after a
  successful commit.

### Monitoring and audit

- Record release version/date, checksums, counts, report digest, operators,
  approval, timestamps and failures in an update ledger.
- Expose human-readable and JSON status with non-zero exit status for failed,
  unknown or stale data.
- Alert on failed acquisition or validation, source-format drift, missed runs and
  catalogue age thresholds.
- Retain the official archive, manifest and immutable report according to the
  approved retention policy.

### Out of scope

- Unattended application
- Automatic local-to-national medication merging
- Arbitrary third-party CSV imports
- New dm+d concept classes without workflow and schema approval
- A public update API or update-triggering administration UI

### Evidence required for acceptance

- Automated tests for validation, stable IDs, reference preservation,
  retirement, reactivation, history, idempotency, rollback and cache invalidation
- Equivalent results from the bulk and fallback loaders
- A benchmark against the legacy importer on the same database and NHS release
- A successful backup and restore exercise
- Two consecutive prepare-only weekly reports reviewed before the first live
  application

## References

The supporting NHS, MariaDB, PHP, OpenEyes source and CR evidence is recorded in
`knowledge/Openeyes/openeyes-dmd.md`.
