# Indexing a large local corpus

Keep the downloaded source documents as the durable record and make the search
index disposable. An index should be rebuildable without credentials, network
access, or a model service. Downloading, extracting text, detecting SQL and
building full-text search can all run in ordinary scripts with zero model
payload tokens.

## What the corpus size actually means

For a 35 GB Jira corpus, indexing text from approximately 27,000 tickets and
their comments took 24 seconds in an in-memory prototype and produced a 118 MB
full-text index. Seven sample searches returned their top results in approximately
0.3-2.4 milliseconds over repeated warm runs.

That measurement covered ticket descriptions, comments and attachment names.
It did not extract the contents of every attachment. Images, recordings and other
binaries made up most of the source bytes. Source size alone is therefore a poor
predictor of text-index size or build time. Report the extraction coverage,
document count, elapsed time, storage size and whether queries were warm or cold
alongside any benchmark.

A subsequent durable build against a refreshed corpus of approximately 36 GB
indexed 27,500 tickets in 80 seconds. The 233 MB SQLite database included about
9,700 SQL evidence candidates as well as full-text search. Seven warm top-result
queries took approximately 0.2-2.0 milliseconds; filtering duplicate-related
results to data-changing SQL took 6.3 milliseconds over repeated warm runs.
That SQL query's first measured execution took 92 milliseconds. These are
database query times, excluding container startup and result display, and still
describe structured text rather than attachment-content extraction.

Adding supported attachment text and a Confluence corpus took another eight
minutes and produced 85,000 searchable documents in a 2.72 GB database. About
2,800 attachments yielded text; unsupported media retained searchable metadata.
Coverage also recorded PDFs without extractable text, an unreadable PDF and unavailable remote
binaries. Keeping those statuses visible prevents a large document count from
being mistaken for complete attachment-text coverage.

The larger index returned the same seven sample query sets in approximately
0.2-3.0 milliseconds over warm runs. The SQL data-change filter took about
8.6 milliseconds. An unchanged incremental pass reused all 85,000 documents in
21 seconds, with no re-extraction or download.

## A repeatable pipeline

1. Download raw JSON and binaries directly to disk. Use the remote API only to
   discover and fetch source data; do not route payloads through a model.
2. Give each entity a stable identity comprising its site, source type and remote
   ID. Names, titles and keys are searchable metadata, because they can change.
3. Keep a manifest with relative file references, remote versions, completeness,
   byte counts and checksums. Keep the successful sync checkpoint separate from
   this inventory. A cursor alone cannot prove that a file still exists.
4. Extract structured text first. Descriptions and comments usually provide the
   quickest useful search coverage. Follow with plain text, SQL, logs, PDFs and
   modern Office documents. List unsupported formats and extraction failures.
5. Store searchable documents in SQLite FTS5, with ordinary relational columns
   for source, project or space, key, dates and provenance. Return a small number
   of ranked snippets with links to the source and local file.
6. On later runs, compare content fingerprints and extractor/detector versions.
   Replace changed documents and their derived evidence in transactions. Reuse
   unchanged documents. Changing a detector should require local reprocessing,
   not another download.
7. Verify missing files, hashes and database integrity. Test a copied corpus with
   a missing index, then with missing manifests. An intact copy should reuse its
   payloads; metadata discovery may still be needed to establish a safe cursor.

[SQLite FTS5](https://www.sqlite.org/fts5.html) supplies token and phrase matching,
BM25 ranking and highlighted snippets. Exact ticket lookup and source/date
filters belong in ordinary indexed columns. This provides useful lexical search
without embedding costs or an external search service.

## Finding tickets containing SQL fixes

Keyword search for `SQL` is a starting point, but mixes error reports, diagnostic
queries and repair instructions. Add a derived SQL-evidence table linked to each
source document. Record the statement, statement type, referenced tables,
surrounding text and its location within a description, comment or attachment.

| Query intent | Evidence and filters |
|---|---|
| Find an exact ticket | Exact key lookup, with its comments and attachments |
| Find repeated wording | FTS phrase matching, source and date filters |
| Find possible data repairs | Actual UPDATE, INSERT, DELETE or REPLACE syntax, optionally filtered by table |
| Find schema changes | ALTER, CREATE, DROP or TRUNCATE statements |
| Find investigations | SELECT statements kept separate from data changes |
| Prioritize likely resolutions | SQL evidence near words such as fixed, resolved or workaround |

A file ending in `.sql` is metadata evidence, not proof that its contents were
extracted or that a repair was executed. Likewise, SQL near a resolution comment
is a candidate fix, not a verified safe operation. Preserve enough context for a
person to inspect the statement in the original ticket. Do not execute extracted
SQL as part of indexing or search.

Version the SQL detector separately from the downloader. Improving recognition
of quoted identifiers or adding another repair pattern can then update the
index entirely offline. Keep diagnostics separate from changes and test loose
prose and filename-only mentions as negative examples.

## Operational lessons

- Authentication checks must verify an authenticated identity. A successful HTTP
  response containing no results can otherwise hide an expired credential.
- Compare versions before downloading bodies, and reuse attachment binaries by
  stable ID and verified file receipt. Some older metadata reports size zero for
  nonempty files; record this uncertainty instead of repeatedly downloading them.
- Discover comments and attachments independently of their parent page's update
  time. A page-only cursor can miss an edited comment or a replaced attachment.
- Use overlapping update windows and periodic complete metadata reconciliation.
  A full metadata scan is much cheaper than fetching all bodies and binaries.
- Advance each scope's checkpoint only after its required components succeed.
  Retain failed selections, completed receipts and old source files for resume.
- Keep source URLs, query results, detailed timing logs and credentials outside
  the tools repository. Generic lessons and synthetic tests are sufficient there.
- Measure phases separately. First-time adoption and checksumming, API discovery,
  body transfer, binary transfer, text extraction and FTS construction have
  different bottlenecks. Estimates should cite their measured basis and range.

The accompanying [download and search runbook](../Process/corpus-downloads.md)
describes the reusable scripts, recovery commands and extraction boundaries.
