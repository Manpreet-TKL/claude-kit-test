# OpenEyes ingestion regression harness

## Goal

Build one lightweight image in `OEImageBuilder` that characterises
`IOLMasterImport` and `PayloadProcessor` as black boxes. The image must run next
to an OpenEyes web container, database, both components and the shared IOL
incoming volume, then report every selected result and exit once.

The first compatibility targets are the v26.0.9 sample database and the develop
sample database. CI workflow changes in the component repositories are deferred,
but the image must emit stable JSON and JUnit reports for that later work.

## Decisions

- Default injection reproduces the destinations of the production Mirth DICOM
  channel: every DICOM is posted to the Payload queue and qualifying Zeiss
  IOLMaster objects are also placed in the IOL file-watcher directory.
- Mirth traversal, document upload, advanced failures, concurrency and soak tests
  are explicit opt-in suites.
- The harness does not add test APIs or drain controls to either component.
- Database access used by the harness is read-only. Writes happen only through
  the production API or IOL watched folder.
- An explicit sample-database acknowledgement and a versioned canary set are both
  required. Overrides never bypass the canaries.
- Missing patients, schema, request types, queues, routines and reference data
  are collected into one preflight report. No file is sent after any safety or
  prerequisite failure.
- Optional suites log the exact enabling option when skipped. If selected, their
  missing prerequisites are errors. The harness never creates configuration.
- The normal suite is serial. Concurrency uses all configured patients and a
  configurable per-patient rate.
- Known unsupported cases are strict characterisation tests. A changed failure
  or unexpected success requires deliberate promotion of the case contract.
- Approved core fixtures are compressed in the image. Large or client-derived
  fixtures are supplied in a checksum-pinned private mount.
- Browser rendering is outside v1. Document tests cover routing, storage,
  metadata, clinical linkage and byte-accurate retrieval.
- Optional A/B comparisons require an immutable operator-supplied image digest.

## Work

### 1. Ticket evidence

Download OE and CR with the existing read-only Jira downloader in separate
detached GNU screen sessions. Use resume mode, persistent logs, low CPU priority
and idle I/O priority. Keep the corpora under `/home/toukan/jira-corpus`, never in
this repository.

After completion, verify issue/comment/attachment completeness with NUL-safe
checks. Search locally for integration changes, device formats, MIME and PDF
versions, transfer syntaxes, SOP UIDs, routine names and exact error signatures.
Reduce locally with `rg` and `jq`; do not pass the corpus through a model.

### 2. Coverage inventory

Build a ledger from source, the interop guide, Mirth mappings, v26.0.9 and develop
database configuration, TKLS/OE/CR evidence and aggregate usage queries from all
active clients. Every route is labelled `required`, `known_failure`,
`exploratory`, `fixture_needed` or `out_of_scope`.

Ship read-only schema and usage inventory queries. Results contain aggregate
counts only and exclude patient identifiers, names, filenames, raw headers,
payloads, logs, hostnames and client names.

### 3. Image and runtime

Create `Integration-Harness/` in `OEImageBuilder` with a pinned slim Python base,
`pydicom`, DCMTK, qpdf and only the database/HTTP/reporting libraries required at
runtime. Do not include a JVM, browser, Mirth or either component.

Commands:

- `preflight`: validate without injecting.
- `run`: prepare, inject, observe, report and exit.
- `prepare`: edit selected fixtures without sending.
- `compare`: compare normalised report bundles.
- `inventory`: emit safe schema and usage aggregates.

Required runtime contracts include the OpenEyes profile and URL, read-only DB
connection, secret-file paths, IOL incoming mount, patient CSV, selected suites,
fixture-pack mount and report directory. CI mode disables colour and always
writes fixed JSON and JUnit paths.

### 4. Fixtures and cases

Copy approved IOLMaster archives as compressed immutable sources. Extract only
selected files into a writable run directory. Rewrite patient identity and
run-specific Study, Series and SOP UIDs, preserve private and pixel data, then
reparse with pydicom and validate independently with `dcmdump`.

Each case manifest records provenance, checksum, suite, lifecycle state, route,
patient slot, transformations, expected routine order, normalised DB/API effects,
timeout and accepted failure signature. Promoting JPEG-CV from failure to support
must be a manifest change, not a runner change.

Required coverage includes:

- IOLMaster 500 private sequence variants and IOLMaster 700 PDF layouts.
- Exact, missing and ambiguous patient matching.
- IOL file-watcher discovery, local/global directories, queue transitions,
  retries, mixed identifier types, replay and deduplication.
- Payload vendor and generic modality dispatch, routine order, retries, events,
  laterality, episode visibility, attachments and no cross-patient writes.
- Supported embedded PDFs, images and multiframe content.
- Optional document formats and PDF version behaviour.
- Advanced JPEG-CV, malformed/private-tag cases, stale routes, MIME mismatches,
  unsupported documents and resource/error boundaries.

### 5. Results and comparison

Scope evidence to a run correlation ID and DB watermarks. Normalise generated
IDs, timestamps, paths and regenerated UIDs while retaining clinical values,
ordering, laterality, patient slot, statuses and hashes.

Write console, `results.json`, `junit.xml` and a run manifest. Continue through
all selected cases after preflight. Exit codes distinguish invalid config,
sample safety, missing prerequisites, behavioural mismatches and harness errors.

For A/B testing, run baseline and candidate against equivalent reset sample
environments and compare their report bundles. Reject moving tags as baseline
evidence.

### 6. Verification and documentation

Unit-test configuration, manifests, preflight aggregation, transformations,
normalisation, reports and comparison. Then run the core suite on v26.0.9 and
develop in separate isolated compose projects.

Start concurrency calibration at one small unique DICOM per configured patient
per second for 60 seconds. If that does not drain cleanly on both profiles, use
the highest passing rate from 0.5 and 0.25. Allow documented overrides from 0.1
to 5.0 within a maximum-in-flight bound.

Keep image builds, stacks, large fixtures and load tests serial. Never run the
v26.0.9 and develop stacks together. Limit the harness to one CPU and 1 GiB
unless a measured case proves that inadequate.

Document compose usage, variables, secrets, volumes, modes, skipped-suite
messages, patient CSV overrides, sample-canary drift, fixture provenance,
private packs, editing, reports, exits, promotion and future CI integration.

## Acceptance

- One adjacent container runs selected tests, prints clear results and exits.
- Default mode is deterministic, serial and excludes every optional suite.
- All targets are checked before injection and sample drift reports every missing
  or mismatched requirement with `files_sent=0`.
- The IOL file watcher is exercised rather than bypassed.
- Success means final component and clinical effects, not transport acceptance.
- CI mode collects all case failures in JSON and JUnit.
- No component source change is needed.
- No secret, client data or unapproved patient-shaped payload enters a repository
  or published image.
- The core image remains at or below 250 MiB compressed, or the fixture-pack split
  is documented and enforced.
- The v26.0.9 and develop core suites pass before the image is ready.

## Inputs still required

1. Aggregate inventory output from all active clients.
2. Approval and provenance for any additional deidentified authentic fixtures.
3. Immutable known-good component image digests for optional A/B runs.
