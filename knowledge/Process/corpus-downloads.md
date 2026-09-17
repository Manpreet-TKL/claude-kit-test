# Repeatable Jira and Confluence corpora

Use `scripts/corpus.sh` for downloads, estimates, verification and offline
search. Its Python runtime and PDF extractor run in Docker. It makes read-only
API requests and does not call any model service. Raw documents, manifests,
timing logs, query results and the derived database stay outside the repository.

Credentials are read inside the container from the machine-local Atlassian env
file. They are mounted read-only, never passed as Docker environment variables
or command-line arguments, and stripped from cross-origin attachment redirects.
Run `auth` after refreshing that file; restarting an integration server is not
necessary for these scripts.

```bash
bash "$HOME/claude-kit/scripts/corpus.sh" auth --source jira
bash "$HOME/claude-kit/scripts/corpus.sh" auth --source confluence
bash "$HOME/claude-kit/scripts/corpus.sh" help
```

Defaults are the home-relative `jira-corpus`, `confluence-corpus` and
`corpus-index` directories. Override a selected source with `--root`, or supply
`--jira-root`, `--confluence-root` and `--index-root` when searching or indexing a
relocated copy. Store data outside the kit. Override credentials with
`--credential-file` when needed.

## Download or refresh

```bash
bash "$HOME/claude-kit/scripts/corpus.sh" estimate --source jira
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source jira --mode delta
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source jira --projects EXAMPLE,SECOND --root "$HOME/new-jira-corpus" --mode full
bash "$HOME/claude-kit/scripts/corpus.sh" spaces
bash "$HOME/claude-kit/scripts/corpus.sh" estimate --source confluence --spaces all
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source confluence --spaces all --mode full
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source confluence --spaces all --mode delta
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source confluence --spaces EXAMPLE --mode delta
```

Use the real keys returned by `spaces` or the relevant Jira project keys.
`full` requires empty selected destinations and never erases an existing corpus.
`delta` also initializes missing scopes, so it can add newly accessible spaces
while reusing those already downloaded. A one-key Confluence refresh is a run
override: it does not change the catalog's saved all-space selection or another
space's files and checkpoint.

For a legacy Jira corpus, the first run chooses the largest existing snapshot
for each project. Smaller duplicate snapshots and analysis directories remain
separate. The selected paths are saved in the catalog. Review its scopes before
later use if your local snapshots have intentionally overlapping purposes.
On an empty machine, select Jira projects explicitly; no account-wide project
filter is silently assumed. Raw REST does not inherit integration-server filters.

`jira_filter_download.sh` retains its `-j/--jql`, `-f/--filter`, `-o/--output`,
`-a/--attachments` and `-r/--resume` interface. Its attachment download is opt-in;
the unified command includes attachments by default. Saved-filter and arbitrary
JQL destinations perform complete metadata reconciliation on each invocation so
membership changes do not depend on a guessed update watermark. Previously
downloaded records that leave a scope are retained and marked as not seen.

```bash
bash "$HOME/claude-kit/scripts/jira_filter_download.sh" -j 'project = EXAMPLE' -o "$HOME/example-corpus" -a -r
bash "$HOME/claude-kit/scripts/confluence_corpus_download.sh" --spaces EXAMPLE --mode delta
```

## Portable layout and recovery

The root `corpus.json` records schema, site identity and scope paths. Jira keeps
the existing `issues/<key>.json` and ID-prefixed attachment filenames. Issue IDs
are the logical identity, so a renamed key does not create duplicate search
documents. A new project can use `--projects KEY:folder` to select a folder name.

Confluence uses `spaces/<space-id>/`, with separate `pages`, `blogposts` and
`comments` JSON files named by immutable content ID. Attachments use
`attachments/<attachment-id>/v<version>/metadata.json` and `content`. Human names
stay in metadata. The script downloads current content and current attachment
versions; it does not crawl remote version history. Older downloaded versions
remain local when a new version arrives.

Each scope has a manifest plus `.sync/state.json`, pending selections, receipt
journals and run reports. Every path inside a manifest is relative to its scope.
Copy the whole corpus, including dot directories, to another machine and pass
its new root. A missing index needs only an offline rebuild. Missing manifests
trigger local adoption followed by complete remote metadata reconciliation.
Missing or damaged files invalidate receipts and are fetched selectively.

An interrupted run keeps completed files. After fixing the reported problem:

```bash
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source jira --mode resume
bash "$HOME/claude-kit/scripts/corpus.sh" sync --source confluence --spaces EXAMPLE --mode resume
bash "$HOME/claude-kit/scripts/corpus.sh" verify --source all --hashes
bash "$HOME/claude-kit/scripts/corpus.sh" inventory --source all
```

Resume uses a frozen pending selection when one exists. Normal deltas discover a
fresh selection. The checkpoint uses the run's starting time, with at least a
24-hour overlap; Confluence uses a wider calendar-date window to cover account
timezones. A complete metadata reconciliation runs again after seven days, on
the next invocation. Nothing schedules a job automatically.

The default is four workers shared by the selected scopes within one invocation.
Rate-limit waits are shared by those workers, with bounded retries and
`Retry-After` support. Root locks reject overlapping writers. Atomic publication,
JSON identity checks, complete Jira comment pagination, byte-length checks and
SHA-256 receipts prevent incomplete files from being accepted as complete.
Unavailable records are retained; the script does not infer deletion from a
missing result or a permission error.

## Estimates and failure reports

Before transfer, the script prints selected/reused records, expected binary GB,
an elapsed-time range and the basis. The fallback is a historical 909 MB transfer
in 221 seconds, plus an allowance for body requests. Recent successful transfers
at the destination replace that fallback. Many small requests can dominate a
download, so this is a range, not a promise.

Run reports store discovery, download and total seconds, byte counts, retries,
concurrency, forecast, actual result and failures. The first adoption of an old
corpus includes local checksumming, which is separate from remote payload
transfer. Progress includes a rolling ETA based on this run. A no-change run must
report zero body and binary downloads even though metadata requests are needed.

In a measured refresh of roughly 27,500 Jira tickets, about 1,300 bodies changed.
The scripts transferred 1.55 GB of binaries plus 165 MB of API JSON in about
11 minutes. Roughly eight minutes were first-time adoption and metadata work;
the transfer phase took about three minutes. A subsequent delta reused every
body and binary. A separate Confluence pull processed 24 accessible spaces,
about 1,200 pages, 280 comments and 2,900 attachment records in about 12 minutes,
transferring 1.44 GB of binaries. A small number of listed binaries were absent
from remote file storage, so their scopes correctly remained incomplete.
These examples are observations from one corpus and connection, not universal
throughput guarantees; the local run reports are the basis for future estimates.

| Failure | Corrective action |
|---|---|
| HTTP 401 or anonymous identity | Refresh the machine-local credential file and rerun `auth` |
| HTTP 403 or inaccessible space key | Check account permissions and token scopes; list accessible keys with `spaces` |
| HTTP 404 for a listed attachment | Check the attachment in the source site; metadata may exist while its binary is unavailable |
| HTTP 429 or temporary service/network failure | Bounded retries run automatically; after exhaustion, check connectivity and resume |
| Disk full or permission denied | Free space or correct ownership, then resume using the same root |
| Invalid JSON, length or hash mismatch | Keep the previous raw files and run delta to repair the selected record |
| Wrong site or unsupported manifest schema | Use matching credentials/root or a compatible script; do not overwrite the manifest |
| Another process owns the root lock | Wait for it to finish, then rerun |

Failed scopes retain their checkpoint and produce a nonzero overall status.
Successful scopes keep independent progress. Per-record reports identify the
source, key or ID and required action; they do not print credentials or signed
download URLs.

## Build and use the index

```bash
bash "$HOME/claude-kit/scripts/corpus.sh" index --mode rebuild --text-only
bash "$HOME/claude-kit/scripts/corpus.sh" index --mode update
bash "$HOME/claude-kit/scripts/corpus.sh" search --source jira --query 'deadlock'
bash "$HOME/claude-kit/scripts/corpus.sh" search --source jira --key EXAMPLE-123
bash "$HOME/claude-kit/scripts/corpus.sh" search --source jira --sql-kind data-change --query 'duplicate'
bash "$HOME/claude-kit/scripts/corpus.sh" search --source jira --sql-kind any --table sample_table --format json
bash "$HOME/claude-kit/scripts/corpus.sh" search --source confluence --spaces EXAMPLE --query 'configuration'
bash "$HOME/claude-kit/scripts/corpus.sh" index --source confluence --spaces EXAMPLE --mode update
```

Index and search run with Docker networking disabled and no credential mount.
Omitting `--source` searches or indexes both sources. Search defaults to 20
results and supports project/space, exact key and updated-date filters. The
SQLite database stores relative paths; results resolve local links using the
roots provided at query time. JSON output is suitable for deterministic reports.

The first command indexes structured text and attachment names. The update adds
supported attachment contents and reuses existing documents. Plain text, SQL,
logs, CSV, JSON/XML, PDF and modern Office/OpenDocument files are supported.
Images, audio, video and legacy Office files retain metadata only. There is no
OCR or transcription. Files above 256 MiB, oversized Office XML, unreadable PDFs
and extraction failures have explicit coverage statuses. SQL evidence excerpts
are limited to 16,000 characters and mark truncation; original raw files remain
available. Detector matches are candidate fixes, not automatically verified
resolutions.

Extractor/detector versions participate in fingerprints. Bumping either and
running `index --mode update` reprocesses affected local documents without
downloading anything. Scope updates use transactions; a failed rebuild leaves
the prior database available. Existing corpus analysis databases are untouched.

See [general corpus-indexing lessons](../Tooling/corpus-indexing.md) for benchmark
interpretation and the SQL-evidence model. Run the synthetic recovery, API and
index tests inside the same container:

```bash
bash "$HOME/claude-kit/scripts/corpus.sh" test
```

Rebuilds include full FTS and SQLite integrity checks. Ordinary incremental
updates validate source receipts and use transactions without rescanning every
database page. For a deliberate deep check, run
`bash "$HOME/claude-kit/scripts/corpus.sh" index --mode update --hashes`.
This hashes every source file as well as checking the database, so allow time
proportional to the entire corpus. The same `--hashes` option on a delta repairs
damage even when a file's size and modification time were preserved.

The container launcher uses `exec` for its final Docker command. This also avoids
the shell rereading changed script text if the launcher is edited while a long
container job is running.

The API contracts used here are the official
[Jira enhanced search](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/),
[Confluence content search](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-content/),
[Confluence CQL fields](https://developer.atlassian.com/cloud/confluence/cql-fields/)
and [Confluence spaces](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space/).
