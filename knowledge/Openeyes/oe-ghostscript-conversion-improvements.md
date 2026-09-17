# Ghostscript improvements beyond the saved PRs

This note covers gaps remaining after the PDF-conversion changes already represented in `~/pullrequests`. It proposes follow-up work; it does not establish that the saved patches are merged or deployed. Compare the target branch with those patches before implementation.

The application baseline examined was OpenEyes **v10.0.30**, commit `77438f14e9f4124df8c66effb4bc2b6a28e44435`. The [usage profile](oe-v10-typical-usage-and-load-profile.md) records XREF-table and incomplete-content diagnostics. They indicate PDF-processing problems but do not identify individual input files or count distinct failed conversion jobs.

## What was checked in the PR archive

The most relevant material is `oe-pr-document-pdf-temp-cleanup-review` (OE-18226), particularly `changes.patch` and `fixes.patch`, together with its earlier counterpart `pushed/oe-pr-tmp-ghostscript-pdf-leak`. The saved code already covers temporary-file creation checks, quoted arguments, nonzero exit status and cleanup of converted paths. Those fixes are not proposed again here.

Related reviews checked were `oe-pr-imagick-cache-release-review`, `oe-pr-document-render-temp-cleanup-review`, `oe-pr-event-image-scratch-cleanup-review` and `oe-pr-tmp-savepdfprint-source-leak`. Their existing cleanup work is outside this follow-up. These archives were inspected without modification; their recorded test results are historical and were not rerun for this documentation update.

One gap requires particular care: the OE-18226 review prose says failed or empty conversion is rejected, but its inspected `fixes.patch` checks `tempnam()` and a nonzero process exit code. It does not explicitly check output size, readability or PDF validity after a zero exit status. The patch is the evidence for what is implemented.

## Direct conversion paths affected

| Application source | Consumer and boundary |
|---|---|
| `protected/modules/OphCoDocument/controllers/DefaultController.php::convertPDF()` | Produces PDF 1.4 output for `addPDFToOutput()` to import into a print bundle. |
| `protected/modules/OphCoDocument/components/OphCoDocument_API.php::convertPDF()` | Returns a converted attachment path through `getDocumentAttachments()` for a later document/correspondence consumer. |

Both paths use the Ghostscript `pdfwrite` device. Imagick PDF previews and thumbnails can use a Ghostscript delegate too, but changes to the direct PHP subprocess calls do not automatically change the delegate path. Measure and handle that separately.

## Remaining changes to assess

### 1. Capture bounded diagnostics and correlate conversions

Capture stderr separately from stdout and exit status. Record elapsed time, converter version, an opaque request/job ID and a non-identifying source-content hash in restricted operational logs. Classify the outcome so malformed input, password requirements, unsupported content and deadline/resource failures can be distinguished.

The saved use of `exec($command, $output, $exit_code)` does not capture stderr by itself. Use a process runner that can drain both output streams while running, cap retained diagnostic bytes and report termination reason. Avoid deadlocking on a full pipe or accumulating unlimited output in PHP memory. Do not log document contents, patient-bearing filenames or complete command lines containing sensitive paths.

This turns raw, undated XREF/content messages into evidence tied to a conversion. It does not repair a damaged source PDF or establish the cause of historical messages retrospectively.

### 2. Validate output after a zero exit code

Require an existing, nonempty output that the actual downstream importer can read, with usable pages. A PDF header alone is insufficient. A zero process exit code plus a readable PDF still does not prove that recovery preserved all clinical content; define how conversion warnings affect acceptance and compare representative rendered output in regression tests.

Do not publish partial output as a successful complete document. Keep the original protected file intact and return a clear conversion failure when acceptance checks fail. Extend the existing cleanup paths to include output-validation failures rather than introducing a second cleanup owner.

### 3. Give the subprocess a deadline and bounded resource use

Add an explicit wall-clock deadline with termination, diagnostic capture and cleanup on expiry. PHP request execution time is not a substitute for a subprocess deadline. Bound concurrent direct conversions using measured container headroom; PHP's memory limit does not cap the external Ghostscript process.

Retain Ghostscript's file-access restrictions. Modern versions use `SAFER` by default; `-dNOSAFER` broadens filesystem access and is not a remedy for a broken or encrypted PDF. Configure only the input/output permissions required by the job, and verify options against the installed image version. [Ghostscript usage and access controls](https://ghostscript.readthedocs.io/en/latest/Use.html).

A deadline should produce a diagnosable failed job, not a truncated PDF that the next stage mistakes for valid output. Shutdown/finally cleanup cannot be assumed to run after every process/container termination; abandoned-job handling must preserve active work and the original source.

### 4. Reduce repeated direct conversions if measurement justifies it

These candidates concern the two direct `convertPDF()` paths above. Existing event-image generation locks or caches do not establish that these attachment conversions are shared or cached.

| Candidate | Expected gain | Conditions |
|---|---|---|
| Cache validated conversion output by source content, converter version and conversion settings | Avoids converting an unchanged attachment on every print/assembly | Protected storage, correct invalidation, bounded retention and atomic publication. Retrieval must retain authorization checks. |
| Coordinate concurrent conversion of the same input | Avoids duplicate converter processes and temporary I/O | A bounded acquisition policy and recovery when the producer fails. Do not leave duplicate requests indefinitely occupying workers. |
| Apply a short retry delay to an unchanged failed source/settings combination | Avoids repeatedly processing known-bad input and flooding logs | Changed content or converter/settings must be retryable; preserve a deliberate retry/recovery path. |
| Check whether the actual downstream importer still needs PDF 1.4 conversion | May avoid conversion for inputs supported directly | Verify dependency versions and output fidelity. A newer PDF is not inherently corrupt, and conversion cannot be removed solely on that basis. |

No percentage CPU, latency or disk gain has been measured for these proposals. Count actual direct conversions, their duration and repeated source hashes before adding caching or coordination. Do not infer converter cost from the number of Ghostscript diagnostic lines.

## Verification for the additional work

1. Exercise both the document-print path and API/correspondence consumption. Cover PDF 1.4 and newer input, multi-page documents, passwords, malformed XREF/content, zero-exit empty output and zero-exit unreadable output.
2. Force a converter timeout, excessive stderr and output-validation failure. Confirm bounded process/output handling, no invalid publication and preservation of the original file.
3. Compare page count, dimensions, extracted text and representative rendered pages, including fonts, annotations, rotation and transparency. Readability alone is not a completeness check.
4. If caching/coordination is added, test concurrent requests, producer failure and invalidation after content/settings/version changes. Confirm authorization and cleanup remain correct.
5. Measure direct-conversion count, wall time, peak container memory, scratch usage and retry/error categories with the same fixtures before and after. Separate cold conversions from cache hits.

Related context: [event-image pipeline](oe-event-image-pipeline.md), [temporary-file origins](oe-tmp-file-origins.md) and [Apache/container performance](../Infrastructure/oeimagebuilder-apache-logging-and-performance.md). Those notes include other versions; verify their specifics against the target release.
