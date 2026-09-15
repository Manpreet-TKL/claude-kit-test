# OpenEyes DocMan delivery performance analysis (`test-web-1`, 2026-08-28)

This note records source analysis and destructive benchmark work against
OpenEyes commit `18e27fea9d`. The requested 1,000-document test was reduced to
100 because a stock 1,000 run was projected to take about 40 minutes and each
candidate needed a reset and repeat. The 1,000 figures below are linear
extrapolations, not measurements.

## Outcome

The database selector is badly under-indexed, but it is not the main wall-time
cost. The stock command starts a new authenticated web/PDF pipeline and a new
Chrome process tree for every output. Adding the selector index and reusing a
cURL login cut database work by 98% but wall time by only 6%. Keeping Chromium
alive and adding bounded workers was the material change:

| Case (100 outputs) | Time | vs stock | Linear 1,000 estimate |
|---|---:|---:|---:|
| Stock `docmandelivery` | 239.552s | baseline | 39m 55.5s |
| Minimal: queue index + one cURL session | 225.079s | 6.0% faster | 37m 30.8s |
| One persistent full-Chrome worker | 166.866s | 30.3% faster | 27m 48.7s |
| Two persistent full-Chrome workers | 86.060s | 64.1% faster | 14m 20.6s |
| Two persistent headless-shell workers | 82.013s | 65.8% faster | 13m 40.1s |
| Four persistent headless-shell workers | **41.360s** | **82.7% faster (5.79x throughput)** | **6m 53.6s** |

The four-worker result is an architectural ceiling test, not production-ready
code. It directly rendered the recipient page and deliberately used a cohort
without attachments or file-backed signatures. A production rewrite must
preserve the outer controller's attachment merge and PDF post-processing.

The four headless-shell browsers were created at worker startup. The slowest
worker reported 37.565s of generation versus 41.360s end to end, so moving all
authentication/browser startup/copy overhead before the request can save no
more than 3.795s (9.2%) in this 100-output case. A long-lived service is still
valuable for cross-request reuse and cold latency, but "pre-initialising" does
not explain the 5.79x gain; bounded parallel reuse does.

## Second round: ten experiments and measured 100-item result

The requested SQL-only round used 100 fixed, unique correspondence events and
100 fixed generic events. The correspondence set had active, complete DocMan
outputs and excluded associated attachments and every non-secretary signature.
This was necessary because this partial instance still has no corresponding
`/protected/files` payloads. The exclusion does not change the fact that real
correspondence signatures are `ProtectedFile` records reached through
`ophcocorrespondence_signature.signature_file_id`; it only makes this timing
cohort renderable. Production acceptance still requires file-backed signatures
and attachments.

The best three PDF candidates were promoted from five to 100 outer-controller
requests. These requests retained the current recipient resolution, footer,
PDF post-processing and outer merge, but used four authenticated sessions made
before timing and did not run XML/copy/status handling.

| 100 PDFs, concurrency 4 | Time | Throughput | Renderer peak | Renderer PIDs | Web cgroup peak | DB rows read / queries / physical reads | DB threads peak |
|---|---:|---:|---:|---:|---:|---:|---:|
| One shell browser, four isolated contexts/pages | 19.868s | 5.03/s | 853MiB Chrome RSS | 11 | 2.28GiB | 107,516 / 19,971 / 2,003 | 3 |
| Two shell browsers, two contexts/pages each | **14.249s** | **7.02/s** | 1,194MiB Chrome RSS | 17 | 2.36GiB | 107,403 / 19,357 / 0 | 2 |
| Gotenberg, one stateful Chromium, concurrency 4 | 17.337s | 5.77/s | **505MiB cgroup peak** | 180 | 1.99GiB | 107,527 / 20,087 / 0 | 2 |

All three are well below the 100-second target. The two-browser pool is the
fastest measured design and remains under the 1.5GiB browser target. The
one-browser/four-page pool is 39% slower but saves about 341MiB of summed
Chrome RSS. Gotenberg has the smallest and best-contained renderer peak, a
2GiB hard limit, 1.5GiB reservation, no extra swap, 512MiB `/dev/shm`, PID
limit 256, queue 100, auto-start, and restart after 100 jobs.

For the first five documents, both Node pool configurations had zero page or
extracted-token-count mismatches. Their maximum pixel difference from the
stock full-Chrome references was 0.113%; the minimum token-multiset recall was
0.944 because generated PDF text ordering/dynamic values are not byte-stable.
Gotenberg also preserved every page and stayed below 0.134% changed pixels,
but all five extracted-text counts differed and minimum token recall was 0.843.
That text-layer/accessibility/search difference blocks a production switch
until explained, even though the pages look nearly identical by pixel metric.

### Five-item screens

| # | Experiment | Five-item result | Decision |
|---:|---|---|---|
| 1 | One warm shell browser, four isolated pages | 1.196s on the repeat (the first cold/cache run was 4.652s); about 0.75-0.80GiB Chrome RSS | Promoted |
| 2 | Two warm shell browsers, two pages each | 1.363s; about 1.05GiB Chrome RSS | Promoted |
| 3 | Gotenberg concurrency 1 / 2 / 4 | 2.508s / 1.644s / 1.279s; 323MiB / 381MiB / 494MiB cgroup peaks | Concurrency 4 promoted |
| 4 | Raw CDP `Page.printToPDF` `ReturnAsStream` | 1.480s with an approximate A4 size but 4.12% pixel change; exact A4 preserved fidelity but a cold screen took 5.809s | Rejected; no measured memory/time win |
| 5 | Fetch prepared HTML and use `setContent()` | 4.111s; all five token counts differed, recall fell to 0.759 and pixels changed by up to 3.72% | Rejected; relative URL/origin/async work needs a real HTML contract |
| 6 | Explicit ready condition versus `networkidle0` | 1.196s versus 2.569s with matching page/token counts | Use a bounded ready contract |
| 7 | Record/allowlist requests and block non-local resources | 1.211s, zero requests blocked: all document resources were already local | Safe but no gain on this view |
| 8 | Renderer/Node caps, recycling and aggressive Chrome flags | No cap/flag beat the 1.196s repeat or materially reduced peak RSS | Keep only operational recycling/limits |
| 9 | Direct WebP event screenshot | 10.704s, 1.40GiB Chrome RSS and 9.29% changed pixels for five | Rejected; see event-image note |
| 10 | Typst letter and SVG/resvg event pilots | Five representative letters in 0.23s; five 800x600 previews plus WebP conversion in 0.84s, resvg Node RSS 93MiB | Architectural ceiling only; both require template rewrites |

Gotenberg cookie/storage clearing must not run globally between concurrent
conversions. With concurrency two and `clear-cookies`/`clear-storage` enabled,
one five-item output lost a page/content. The same case without global clearing
finished in 1.644s with all pages present. Authenticated jobs need isolated
browser contexts, not global state clearing while another conversion is live.

### The useful and harmful Chrome knobs

Printing as soon as the persistent page emitted `load` was exceptionally fast
(0.346s for one outer PDF), but the PDF had only 242 extracted words versus
288 stock and the bottom of both pages differed materially. The page had one
late XHR. Waiting for a 250ms bounded quiet window, `document.fonts.ready`, and
outstanding images restored all 288 words in 0.633s. Blind startup flags are
less important than this explicit application readiness contract.

Individually screened settings were:

- `--renderer-process-limit=2`: 1.391s, about 733MiB Chrome RSS;
- renderer `--js-flags=--max-old-space-size=256`: 1.408s, about 727MiB;
- Node `--max-old-space-size=256`: 1.762s with no useful peak reduction;
- recycle after two jobs: 1.228s and one successful replacement, but no
  five-job memory benefit;
- the common bundle `--disable-background-networking`, component updates,
  default apps, extensions, sync, metrics, first-run work, Translate,
  MediaRouter, OptimizationHints, Autofill server communication and the CT
  component updater: 1.347s and about 772MiB;
- `--disable-site-isolation-trials`: 2.113s, slower and a security regression;
- `--single-process --no-zygote`: immediate HTTP 500s and wedged outstanding
  renders; the case was terminated rather than waiting for request timeouts.

Headless Shell remains useful for correspondence PDFs, but it is not a safe
global renderer switch: the event-image trial found a 30.32% screenshot pixel
difference while full Chrome was byte/pixel identical. The long-lived service
should expose separate PDF and screenshot capabilities with independently
tested binaries/settings.

## `/dev/shm` and explicit finished-signal add-on

A follow-up isolated the renderer in a dedicated container with a 2GiB hard
memory limit, 1.5GiB reservation, 512MiB `/dev/shm` and PID limit 256. Because
`test-web-1` cannot have its 64MiB tmpfs resized in place, the temporary adapter
returned rendered bytes to PHP; that equal serialization cost applies to every
case in this table. Browsers were launched and health-checked before timing.

| Warm PDF case, two shell browsers x two pages | Five PDFs | Chrome RSS peak | `/dev/shm` peak | Fidelity against fixed reference |
|---|---:|---:|---:|---|
| 512MiB shm, retain `--disable-dev-shm-usage`, bounded ready wait | 1.619s | 1,116,392KiB | 0 | gate passed |
| 512MiB shm, remove `--disable-dev-shm-usage`, bounded ready wait | 1.611s | 1,115,672KiB | 0 | gate passed |
| 512MiB shm, native mode, injected finished signal | 0.982s; repeat 1.051s | 1,121,596KiB | 0 | gate passed |

The shm A/B is effectively identical. Chrome 148 did not allocate observable
space from `/dev/shm` for any tested PDF or full-Chrome screenshot case, even
after removing `--disable-dev-shm-usage`. Increasing the tmpfs remains sensible
reliability headroom for other pages/Chrome versions, but it is not a speed
change on this workload and does not justify restarting the web container.

The temporary signal was installed before navigation. It tracked `fetch` and
XHR completion, DOM mutations, the load event, two animation frames,
`document.fonts.ready` and incomplete images, then set
`window.__OE_RENDER_FINISHED__`. All five PDFs retained their page and token
counts; maximum changed pixels were 0.142% and minimum token-multiset recall
was 0.944, the same dynamic/text-order variation seen in the other shell runs.

Promoting the signal to the fixed 100-PDF cohort produced 100/100 files in
14.294s, essentially tied with the prior 14.249s bounded-ready result. Chrome
RSS peaked at 1,209,780KiB, renderer PIDs at 186, and sampled browser processes
at 47. MariaDB deltas were 107,462 rows read, 19,489 questions and 27 physical
buffer-pool reads; `Threads_running` peaked at three. The renderer reported
p50 434ms and p95 512ms. The signal therefore improves small-batch latency but
does not move sustained four-slot throughput, whose bottleneck is the outer
PHP/controller/PDF path rather than the 250ms quiet window alone.

Production should use an application-owned marker, emitted only after the
letter's known async data and final DOM update complete. Keep
`document.fonts.ready` and image completion in the renderer, enforce a bounded
timeout, and fail/retry rather than silently capture an incomplete document.
The generic injected observer is evidence for the contract, not production
code. It still waits for protected-file signatures when they exist; it must
never treat their absence as completion.

Two emerging engines were also screened. [Lightpanda](https://github.com/lightpanda-io/browser)
is unsuitable because its own project documents no graphical rendering engine,
text-only PNG output and a fake `Page.printToPDF` compatibility method.
[Obscura 0.2.1](https://github.com/h4ckf0r0day/obscura/releases/tag/v0.2.1)
does implement an independent renderer and connected through Puppeteer CDP at
only about 3.5MiB idle, but the first real correspondence navigation hit its
30-second deadline and produced no PDF. Obscura is not a component swap until
OpenEyes pages pass the complete visual/text regression matrix.

## Why the command cURLs itself

`DocManDeliveryCommand` asks `DocmanRetriever` for each PDF. For every output,
the retriever creates a cURL handle and performs:

1. an OpenEyes login-page GET;
2. an OpenEyes login POST;
3. an authenticated GET of the correspondence PDF controller.

The PDF controller then resolves `DocumentRenderServicePuppeteer`. Chromium
navigates to another authenticated OpenEyes URL,
`printForRecipient/<event-id>`, to obtain the HTML, prints that page, and the
controller merges the letter and any attachments before returning the PDF to
the CLI's cURL request.

This is a reuse of the interactive web-print path from a CLI command. It
conveniently establishes user, institution, site, module, theme and session
context, but cURL is not intrinsically required for PDF generation. The proper
rewrite is an application service which accepts the document output and render
principal/context, renders correspondence HTML internally, and sends prepared
HTML to a persistent PDF service. The cURL can then disappear completely.

As an interim step, one authenticated cURL session per institution/site is
safe and simple. The stock `CURLOPT_FRESH_CONNECT`, shared
`/tmp/cookie.txt`, and login per document should be removed.

## Protected files and signatures

The first candidate cohort failed and was discarded because this partial
instance has database references to signature files but does not have the
corresponding protected-file payloads. Correspondence signatures are protected
files:

- `ophcocorrespondence_signature.signature_file_id` belongs to
  `ProtectedFile` as relation `signatureFile`;
- non-secretary signatures require a `signature_file_id`;
- printing calls `signatureFile->getThumbnail("150x50")`, reads the thumbnail,
  and embeds it as a base64 image in the letter;
- secretary verification signatures are text/timestamp based and do not need
  a signature file.

With the payload absent under `/protected/files`, the inner recipient page
returned HTTP 500 and the outer command reported `File is not a PDF`. This was
missing fixture/storage data, not a DocMan timing result.

The valid 100-row cohort therefore used unique events and excluded:

- every event with `event_associated_content` attachments; and
- every event whose correspondence e-sign element had a non-secretary
  `ophcocorrespondence_signature` row.

It also required active, non-deleted, non-draft correspondence for institution
1/site 1 and a previously complete DocMan output. Five rows distributed across
the cohort were smoke-rendered before the timed cases. This makes the timing
repeatable on this restore, but it does **not** validate signature image I/O,
thumbnail generation, attachment merge time, or attachment fidelity. A full
acceptance run needs a complete protected-files restore and a stratified cohort
containing both.

## Database finding and minimal change

Before the change, `EXPLAIN` chose a broad `document_output` scan and the stock
case read 10,164,405 rows for 100 outputs. The tested index was:

```sql
ALTER TABLE document_output
  ADD INDEX idx_document_output_delivery_queue
    (output_status, output_type, deleted, document_target_id),
  ALGORITHM=INPLACE,
  LOCK=NONE;
```

The post-index plan estimated about 930 queue rows. Creating it took 10.26s,
held MariaDB near one core (99.98% sampled CPU), and caused approximately
1.62GB of block writes. It should be deployed as a separately scheduled online
DDL, not hidden inside the delivery command.

The minimal command kept the stock PDF/controller/Chrome path but reused one
in-memory cURL cookie engine and authenticated session per institution/site.
Together with the index, that reduced `Rows_read` to 184,267 (98.19% lower)
and eliminated physical InnoDB reads in the timed interval. Time fell only
from 239.552s to 225.079s because a fresh Chromium tree still dominated every
document.

## Resource and database measurements

The monitor sampled Docker CPU/memory/PIDs, Chromium process count/RSS,
MariaDB threads, and global status deltas every four to six seconds. MariaDB's
~29.8% container-memory reading was essentially constant and is mainly its
configured buffer pool, not incremental memory from a case.

| Case | Web CPU avg/max | Chrome peak processes/RSS | DB CPU avg/max | DB threads running peak | DB rows read | DB queries |
|---|---:|---:|---:|---:|---:|---:|
| Stock | 60.90% / 107.36% | 11 / 876MiB | 2.97% / 82.93% | 2 | 10,164,405 | 25,171 |
| Minimal | 60.40% / 102.91% | 12 / 956MiB | 1.08% / 9.32% | 1 | 184,267 | 23,749 |
| Persistent Chrome, 1 worker | 29.64% / 102.87% | 12 / 969MiB | 0.82% / 5.94% | 1 | 129,147 | 15,284 |
| Persistent Chrome, 2 workers | 51.50% / 88.30% | 25 / 1,989MiB | 2.11% / 11.90% | 1 | 192,024 | 15,286 |
| Headless shell, 2 workers | 39.43% / 158.58% | 14 / 917MiB | 2.53% / 11.65% | 1 | 191,989 | 15,341 |
| Headless shell, 4 workers | 57.16% / 80.63% | 28 / 1,782MiB | 6.58% / 22.09% | 1 | 318,711 | 15,530 |

The high stock DB peak occurred during its unindexed selector. The optimized
runs made the render/web tier the bottleneck. Even four workers did not create
database concurrency pressure on this cohort: `Threads_running` peaked at one,
with eight physical buffer-pool reads during the final case.

## Five-document Chromium screens

Before promoting another 100 run, five fixed documents were tested. The first
attempt at custom renderer settings accidentally omitted the normal OpenEyes
margins/footer component configuration; those misleading results were rejected
after extracted PDF text showed missing content. Corrected results were:

| Renderer | 5-output time | Finding |
|---|---:|---|
| Production-config full Chrome | 9.374s | baseline |
| Headless shell | 8.544s | 8.9% faster; about half Chromium RSS |
| Reuse the same main page | 8.925s | only 4.8%; state-leak risk not justified |
| Headless shell + page reuse | 8.576s | no improvement over shell alone |
| Shell, GPU enabled, extra lean flags | 9.046s | slower; rejected |

Headless shell was the only setting promoted. On the 100-output/two-worker
test it improved 86.060s to 82.013s and reduced peak Chromium RSS from
1,989MiB to 917MiB. The shell and full-Chrome extreme outputs had 100/100
byte-identical XML files and the same extracted PDF word count for 100/100
documents. PDFs were not binary-identical and their extracted text ordering
differed, so pixel/page-count regression testing is still mandatory.

## What the extreme prototype changed

Each worker:

- selected an assigned, disjoint set of benchmark output IDs;
- authenticated once to obtain a PHP session;
- resolved one Puppeteer renderer and retained its browser for the worker's
  whole batch;
- rendered the recipient-specific HTML URL directly;
- generated the same XML and copy instructions and updated delivery status;
- ran the copy scripts after generation.

The extreme PDF skips the outer `generatePDFPrint()`/`PDF_JavaScript` merge.
Against the minimal run, XML was byte-identical for 100/100 files and extracted
PDF word counts matched for 100/100, but PDFs were not binary-identical and
extracted text order differed. That is expected from bypassing the merge, but
it means the prototype is performance evidence only. It was also allowed to
skip the post-success `ElementLetter`/patient-identifier lookup that the stock
command performs even when CSV output is disabled.

## Low-hanging changes, in order

1. Add the composite queue index after validating it on production-like data
   and scheduling the write-heavy online DDL.
2. Keep one authenticated cURL/cookie session per institution/site; remove
   `CURLOPT_FRESH_CONNECT` and the global cookie file.
3. Disable Xdebug in CLI workers and the web render pool unless actively
   debugging.
4. Skip the `ElementLetter` and patient-identifier queries when
   `correspondence_create_csv` is off.
5. Select/claim IDs, then hydrate and process small batches. The current
   `findAll()` loads the full queue and is unsuitable for thousands of rows.
6. Use headless shell after a representative visual-fidelity suite. It was a
   modest speed win and a large memory win here.
7. Replace generated `sudo cp`/`mv` scripts with direct, atomic application
   file operations and explicit retry/status recording. Copying was not the
   main bottleneck, but the current mechanism is fragile.

The index/session changes alone will not make the command fast. The largest
low-risk architectural step is a persistent render daemon or bounded worker
pool using the existing Chromium engine.

## Recommended rewrite

1. Introduce a small delivery queue/claim service. Claim rows atomically so
   workers cannot render the same output, and record attempts/backoff.
2. Extract correspondence-to-render-HTML from the controller into an
   application service. Pass a dedicated render principal and institution/site
   context directly, eliminating CLI login cURL.
3. Keep attachment/signature resolution in that service and fail early with a
   clear missing-protected-file error rather than returning a non-PDF 500 body.
4. Send prepared HTML to a bounded persistent renderer pool. Start with two
   headless-shell workers; allow four only where the 1.8GiB browser peak and
   other web workloads leave safe headroom.
5. Preserve the existing attachment merge, footer, margins, auto-print/scaling
   options, XML, audit/status transitions and destination semantics.
6. Render to a temporary path, validate `%PDF` and expected pages, atomically
   publish, then mark complete. Make retries idempotent.
7. Add timings for claim, HTML construction, browser navigation, PDF print,
   attachment merge, XML and copy so regressions are attributable.

This can retain Chromium while removing cURL. It is less risky than replacing
both orchestration and PDF layout engine at once.

## Alternative PDF components

There is no drop-in alternative renderer in this checkout.
`DocumentRenderServiceInterface` is a useful seam, but the only implementation
is `DocumentRenderServicePuppeteer`. Installed PDF-related packages are
`zoon/puphpeteer 2.4.3`, `setasign/fpdf 1.8.6`, and `setasign/fpdi 2.6.8`.
FPDF/FPDI can create or merge PDFs, but they do not render the existing
HTML/CSS/JavaScript correspondence views.

The best packaged compatible trial is Gotenberg. It auto-starts one stateful
Chromium, supports URL/HTML-to-PDF and screenshots, bounds concurrent jobs,
queues excess work and recycles the browser. A small custom Node/CDP service
(Puppeteer, or Playwright if introduced) gives more exact control over a
persistent headless-shell pool. Both still use Chromium, but remove
Puphpeteer's per-request process lifecycle and give explicit concurrency,
timeouts and health/recycle controls. Gotenberg should be benchmarked first at
concurrency one, two and four against the fixed correspondence cohort.

Non-Chromium choices require a layout migration rather than a component swap:

- a PHP renderer such as mPDF/Dompdf could be fast for a purpose-built,
  restricted correspondence template generated from structured data, but the
  existing browser CSS/JavaScript, headers/footers, page breaks, fonts and
  embedded signatures need a new fidelity suite;
- WeasyPrint is suitable for print-oriented HTML/CSS but does not provide the
  same JavaScript execution model and is not installed here;
- Typst is a strong extreme option for structured, data-driven clinical
  templates and can emit PDF plus PNG/SVG, but it is a template rewrite rather
  than an HTML-renderer replacement;
- Prince is a commercial paged HTML/CSS engine with a PHP/server integration
  and document JavaScript support; it is the most credible non-Chromium
  compatibility trial, but still needs full visual regression;
- LibreOffice 24.2 is installed and already supports ODT-to-PDF workflows, but
  moving correspondence to ODT templates changes layout semantics and a
  persistent office service would be needed to avoid another heavyweight
  process-per-document pattern;
- `wkhtmltopdf` is not installed and its older browser engine is not a good
  target for the current views.

Recommendation: first implement the renderer interface with a persistent CDP
pool or Gotenberg and prove full signature/attachment equivalence. Evaluate
Typst, Prince, WeasyPrint or a PHP engine only as a separate structured-template
project with measured fidelity and throughput. ChromeDriver is not a rendering
alternative: it adds WebDriver/Selenium orchestration around the same Chromium
engine, whereas Puppeteer already uses the lower-level DevTools Protocol.

The pool must not be a silent global switch. `DocumentRenderService` also
backs generic event printing/images, Event Export, Operation Booking, CVI,
Prescription and Therapy Application paths. Use separate PDF/screenshot
capabilities and retain consumer-specific options. The companion
`oe-event-image-performance-analysis.md` records the shared-consumer inventory,
pool limits and a five-event high-concurrency trial.

## Benchmark safety and restoration

Before mutation, a full hot physical MariaDB backup was taken with
`mariadb-backup` (server 11.8.9, backup UUID
`125cbccf-a30d-11f1-ad3d-5a7b3c0cd7e2`). Timed rows were snapshotted, cron was
stopped to exclude unrelated delivery/email work, Xdebug was disabled for the
CLI/web render path, and every case restored the same 100 document outputs to
pending. No patient names, identifiers, addresses or document content are
recorded in this note or command logs quoted here.

After documenting the results, the prepared physical backup was copied back to
the exact `test_oe-db` volume. MariaDB 11.8.9 started normally;
`CHECK TABLE ... QUICK` returned `OK` for both `document_output` and
`event_image`; the three benchmark tables and
`idx_document_output_delivery_queue` were absent. `test-web-1` returned to a
healthy state, cron was running, no Chrome process remained, the local shared
renderer configuration and Apache Xdebug configuration matched their original
SHA-256 hashes, and temporary benchmark components/files were absent. The
temporary full-backup volume was then deleted and is no longer recoverable.

Future experiments should not repeat this full physical backup on the large
test database. The companion event-image note defines the requested targeted
SQL/file-manifest rollback, ten five-item screening experiments and resource
gates. That method restores the allowlisted application rows and generated
files but intentionally does not attempt to reverse auto-increment gaps, redo
or binary history.

The second round used that targeted method. Before testing, complete copies of
the selected `document_output` rows and selected `event_image` rows were made
in dedicated SQL tables. Generated PDFs went only to `/tmp`; selected generic
events started with no image rows/files. At the end, every non-key
`document_output` column was restored with an `UPDATE ... JOIN` from the
snapshot and a generated null-safe comparison across every column returned
zero mismatches (100 current and 100 snapshot rows). Selected `event_image`
rows were returned to zero current/zero snapshot rows, and a deterministic
path check found zero selected image files. `CHECK TABLE ... QUICK` returned
`OK` for both tables before all four benchmark tables were dropped.

The original renderer and event-image-generator hashes were restored
(`c4c10e...` and `fee058...` respectively), cron was restarted, the web route
was healthy, and no Chrome, pool process, temporary component/command, DocMan
test directory, Gotenberg container, pulled trial image or generated output
remained. Four render sessions were authenticated before the logical baseline,
as planned. This busy test instance was simultaneously receiving unrelated
audit logins, so no broad audit-ID deletion was attempted. Login audit rows,
auto-increment gaps, redo/binary history and filesystem cache history are not
byte-for-byte restored; the allowlisted application rows and generated files
are logically restored.

The `/dev/shm`/signal follow-up did not run the delivery command or modify
`document_output`; all PDFs were direct outer-controller requests into `/tmp`.
Its five generic events again began and ended with zero selected `event_image`
rows and zero selected files. After the final Obscura smoke test, the temporary
Node and Obscura containers, copied dependencies, adapter, sessions/cookies,
outputs and pulled Obscura image were removed. Core `common.php` and the stock
Puppeteer component matched their pre-follow-up SHA-256 hashes
(`b49fe1...` and `3558ec...`), both quick table checks returned `OK`, the web
route was healthy and cron was running. The follow-up's four `docman_print`
sessions and ten exact `/TestHelper/default/login` audit rows were deleted by
explicit primary keys, and `user_authentication.last_successful_login_date`
was restored to its immediately preceding evidenced value (`2026-08-28
20:56:50`). Auto-increment gaps, redo/binary history and cache history remain
intentionally unreversed; no broad deletion was attempted on the busy shared
test instance.
