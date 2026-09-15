# OpenEyes event-image performance analysis (`test-web-1`, 2026-08-28)

This note is a source-and-query-plan review of the event-image generation path
at OpenEyes commit `18e27fea9d`. It complements
`oe-event-image-pipeline.md`, which contains the render-storm investigation and
measured Chrome versus headless-shell costs.

## Executive summary

The slow part is not writing the final WebP. One event currently crosses the
web boundary, renders the event in a fresh Chrome process tree, takes a
full-page PNG screenshot, decodes that PNG into GD, re-encodes it as WebP, and
then tears Chrome down. The outer cURL is an authentication/controller
workaround; it is not intrinsically required to make an event image.

The highest-value changes are, in order:

1. Do not start renders that are unnecessary or duplicates. Filter preview
   rows to `CREATED`, lock per event, back off failures, and debounce callers.
2. Stop discovering work by sorting the 22.6-million-row `event` table. Record
   dirty event IDs in a small queue when events change.
3. Keep a bounded pool of long-lived headless browsers and feed it queued
   events. A browser per event is the dominant fixed cost.
4. Keep the measured PNG-to-GD-WebP path until a different encoder/resize
   implementation proves faster. Chromium direct-WebP was slower and less
   faithful in the live trial below.
5. Extract event-to-preview-HTML generation from the authenticated controller.
   The worker can then call an application service directly and cURL disappears.

Do not use bulk pre-generation as a speed fix. It spends CPU, memory, database
I/O, and storage on previews that may never be viewed.

## What happens today

For the general batch path, `EventImageCommand::actionCreate()` does the
following:

1. Calls `actionClean()`, which loads every non-`CREATED` `event_image` model
   and deletes it one row and one storage lookup at a time.
2. Calls `EventImage::getNextEventsToImage()` to find recent missing/stale
   events.
3. Groups the result by institution/site and performs a login GET plus login
   POST for each group.
4. Deletes every existing image for an event, then cURLs
   `/<event-module>/default/createImage/<event-id>`.
5. The web controller builds a render URL. `EventImageGenerator` resolves
   `DocumentRenderService`, which launches Chrome, navigates a new page with an
   authenticated session cookie, and waits for `networkidle0`.
6. Chrome writes a full-page PNG. PHP GD reads the PNG and writes a quality-50
   WebP. The PNG is deleted and the request-bound Chrome process exits.

The explicit `--event` path is worse for a list: it opens and closes the login
session for every event instead of grouping the list by institution/site.

Correspondence is a special event-image path. Its controller first uses the
same PDF renderer as DocMan, including recipient/letter HTML and footers, then
splits the PDF into one WebP per page. Other event types generally use
`EventImageGenerator`'s full-page PNG screenshot followed by GD WebP encoding.
This means a shared Chromium change must pass both PDF and screenshot gates.

The outer cURL exists because generation is hidden behind a web controller
that establishes user, institution, site, module, theme, and PHP-session
context. Chrome also needs that authenticated session when it navigates to the
HTML render URL. Neither requirement means the CLI must use HTTP: a rendering
application service can accept the event, institution/site context, and a
render principal directly. Until that refactor, one session per batch is a
safe compromise; one login per event is not.

## Database findings on this restore

`SHOW TABLE STATUS` estimated 15,600,254 `event_image` rows, about 1.70 GiB of
data and 2.45 GiB of indexes. The queue query's `EXPLAIN` estimated a scan of
all 22,561,254 `event` rows, using `event_deleted_idx`, followed by a filesort.
For each event it probes the single-column `event_image(event_id)` index.

There are three correctness/performance problems in the selector:

- It tests status name `GENERATED`, but the model uses `CREATED`. Stale created
  images therefore do not match the documented regeneration rule.
- A multi-page event can contribute multiple joined rows. There is no
  `DISTINCT`/grouping, so the limit is a row limit rather than an event limit.
- It orders the entire eligible event population by `last_modified_date` to
  obtain a small batch. Existing indexes do not support the filter and order
  together.

Low-risk SQL improvements while the queue is being designed:

- Correct `GENERATED` to `CREATED` and express the test with `EXISTS`/
  `NOT EXISTS`, so one event is returned once regardless of its page count.
- Trial `event(deleted, last_modified_date, id, episode_id)` for newest-first
  batch discovery and `event_image(event_id, status_id, last_modified_date)`
  for the correlated check. Validate both with `EXPLAIN ANALYZE`; these are
  large indexes, not free changes.
- Replace `actionClean()`'s unbounded `findAll()` with primary-key batches.
  Preserve per-row file deletion, but commit and release models every few
  hundred rows.

The durable design is a small `event_image_generation_queue` keyed uniquely by
`event_id`, populated when an imageable event is created/changed or its image
file is found missing. Workers claim rows with `FOR UPDATE SKIP LOCKED` (or an
atomic status update), so there is no 22.6-million-row discovery query and no
duplicate work.

## Low-hanging application changes

- Reuse one authenticated cURL handle per institution/site for every command
  mode. Remove `CURLOPT_FRESH_CONNECT`; use an isolated in-memory cookie engine
  or `tempnam()` instead of the shared `/tmp/cookie.txt`.
- Fix the null-site comparison in the bulk grouping path: `explode()` returns
  string `"0"`, so the strict `$site_id === 0` test never selects the default
  site.
- Do not delete good images before their replacements exist. Render to a new
  path, atomically swap the database/file reference, then remove old pages.
- Make the render component lazy. Merely resolving it must not launch Chrome.
- Do not use `headless: "shell"` globally for event images. It saves PDF
  memory, but the generic event-image gate below found a 30.32% pixel change.
- Decide and document the viewport contract before wiring through `width` and
  `viewport_width`. The current renderer ignores them; honoring the configured
  width changed all five output dimensions and was correctly rejected as an
  unintentional compatibility change.
- Do not request direct WebP from four concurrent Chromium pages on the current
  evidence. It made five screenshots slower, increased Chrome RSS and changed
  9.29% of pixels. A purpose-built SVG/resvg or native image service remains a
  separate template-migration option.
- Replace unconditional `networkidle0` with an explicit "preview ready"
  marker plus a bounded timeout. Long polling or unrelated requests should not
  hold a browser indefinitely.
- Turn Xdebug coverage/debug off in worker and render containers outside an
  active debugging session.

## Live five-event trial on `test-web-1`

Five correspondence events with no existing `event_image` rows, attachments,
or file-backed signatures were regenerated. Each produced two 950x1342 WebP
pages. The same Docker/DB monitor used for the DocMan benchmark sampled every
two seconds:

| Case | Time | Web CPU avg/max | Chrome peak processes/RSS | Web PIDs peak | DB CPU avg/max | DB threads running peak |
|---|---:|---:|---:|---:|---:|---:|
| Full Chrome, sequential | 25.547s | 51.21% / 107.21% | 12 / 936MiB | 156 | 2.04% / 11.05% | 1 |
| Full Chrome, limit 2 | 18.235s | 123.96% / 192.65% | 22 / 1,783MiB | 277 | 0.70% / 1.88% | 2 |
| Full Chrome, limit 4 | 12.350s | 156.44% / 354.84% | 44 / 3,240MiB | 524 | 3.10% / 10.46% | 1 |
| Headless shell, limit 4 | 17.837s | 85.42% / 237.63% | 24 / 1,409MiB | 281 | 0.80% / 1.63% | 1 |

The four-render full-Chrome burst reproduces the operational problem: latency
falls, but four independent requests create 44 Chromium processes and consume
about 3.2GiB before considering other Apache work. A limit of two halves the
browser memory/PIDs but does not reuse anything. Headless shell substantially
reduced the burst footprint, but was slower on this small run, so it is not a
concurrency controller and should not be enabled globally on this result.

All ten shell WebPs had the same dimensions as stock. They were not
byte-identical: ImageMagick reported 4.88% changed pixels and normalized RMSE
averaged 0.0181. This includes Chromium antialiasing and a second lossy WebP
encode, but the result still needs human crop review before approval. The
shared renderer configuration was restored byte-for-byte immediately after the
trial.

## Second-round generic event-image trial

The second round used five recent `OphCiExamination` events from institution 1,
site 1. They had no pre-existing `event_image` rows or files, so each case could
be reset exactly by deleting only the five generated rows and their recorded
paths. This generic cohort does not exercise Correspondence signatures.
Correspondence event images share the PDF path, where
`ophcocorrespondence_signature.signature_file_id` points to a `ProtectedFile`;
this partial instance has none of those payloads, so a production gate still
needs a complete protected-files restore.

| Five generic events | Time | Fidelity / decision |
|---|---:|---|
| Current fresh full-Chrome path, sequential | 12.166s | 92,364 final bytes; reference |
| Persistent full Chrome, four isolated pages, bounded ready | **3.876s** | output bytes, dimensions and pixels exact |
| Same pool with `networkidle0` | 6.366s | exact, but 64% slower than explicit readiness |
| Headless shell, bounded ready | 5.013s | 30.32% maximum changed pixels; rejected |
| Start honoring configured viewport width | 10.391s | all five dimensions changed; rejected compatibility change |
| Direct Chromium WebP | 10.704s | 1.40GiB Chrome RSS and 9.29% changed pixels; rejected |

The bounded-ready run recorded 527 local requests: 445 scripts, 20 stylesheets,
25 fonts, 22 images and 15 XHRs. There was no remote analytics/media request to
remove. The meaningful wait change is therefore an application-ready contract,
not a broad request-blocking list. A separate fixed-layout SVG + `resvg` pilot
rendered five 800x600 previews and converted them to WebP in 0.84s at about
93MiB Node RSS, but that is a template rewrite rather than arbitrary event-HTML
compatibility.

### 512MiB shm and finished-signal follow-up

An isolated 2GiB-capped renderer repeated the full-Chrome four-page case with
512MiB `/dev/shm` and without `--disable-dev-shm-usage`. The bounded-ready run
took 4.006s (4.096s repeat), with 1,485,400KiB peak Chrome RSS. An injected
finished signal that tracked load, fetch/XHR, DOM mutations, fonts, images and
paint frames completed in **3.286s**, with 1,456,628KiB peak Chrome RSS. All
five signal WebPs were dimension- and pixel-identical to the bounded-ready
references; MariaDB `Threads_running` peaked at one.

Both full-Chrome cases used zero observable bytes from `/dev/shm`. The same was
true for headless-shell PDFs. Removing the bypass flag and increasing the tmpfs
therefore gave no speed benefit on Chrome 148; keep 512MiB in a dedicated
renderer as reliability headroom, not as the optimization itself.

The injected marker is a benchmark probe. Production should have each event
render view set an application-owned marker after its known data/XHR and final
DOM update, while the renderer separately waits for fonts and images and
enforces a bounded failure timeout. A generic mutation observer can miss work
scheduled by unsupported channels and should not define clinical output
correctness.

[Obscura 0.2.1](https://github.com/h4ckf0r0day/obscura/releases/tag/v0.2.1)
was trialled because it now ships native screenshots and PDFs without Chromium.
Its self-hosted container used only 28-35MiB during one event render, but the
single outer request took 6.049s and the same-size WebP changed 53.04% of
pixels. Its first Correspondence PDF also timed out after 30 seconds. It is
rejected for current OpenEyes output despite the attractive footprint.
[Lightpanda](https://github.com/lightpanda-io/browser) is not trialable for
fidelity: its official project still states that it has no graphical rendering
engine, its PNG is text-only, and `Page.printToPDF` is a fake compatibility
handler.

Cleanup returned the five selected events to their original zero-row,
zero-file state. The temporary render containers, adapter, copied browser
dependencies, outputs and pulled Obscura image were removed; the stock renderer
configuration was restored, both quick table checks returned `OK`, cron was
running and the web route was healthy.

## Everything affected by the shared renderer

At commit `18e27fea9d`, non-test calls to `DocumentRenderService::resolve()`
come from:

- generic event PDF/print actions in `BaseEventTypeController`;
- generic event-image screenshots and Correspondence event-image PDFs;
- Event Export's `EventPdfDrop`;
- Operation Booking and waiting-list documents;
- CVI documents/labels;
- Prescription PDFs;
- Therapy Application documents;
- Correspondence/DocMan indirectly through the base PDF path.

`Document`, Consent and other modules also reach inherited base print actions,
so a grep of direct resolver calls is a lower bound. This is why globally
changing the existing component to shell mode, new wait conditions, request
blocking, or a different layout engine is unsafe without a matrix covering
these consumers. Prefer capability-specific clients (`pdf`, `screenshot`) to a
shared pool so settings can be rolled out independently.

## Bounded warm browser-pool design

Apache prefork PHP cannot provide fleet-wide reuse. Each request has its own
PHP object and Rialto Node bridge, which die at request teardown; a
`max_browsers=4` variable inside that component would be four **per Apache
process**, multiplied again by container replicas.

Use a long-lived Node/CDP pool process, either in a dedicated renderer or
started conditionally inside the shared application image:

```text
min_warm_browsers=1
max_browsers=4
max_active_pages_per_browser=1   # first safe rollout; trial 2 later
max_queued_jobs=100
acquire_timeout_seconds=5
render_timeout_seconds=65
max_jobs_per_browser=500
max_browser_age_minutes=60
```

`min_warm_browsers=1` guarantees a launched, health-checked browser process,
not an unused slot during saturation. Guaranteeing one *idle* browser would
require reserving capacity and wasting it during a queue. Instead, readiness
should wait for the warm browser, the pool should launch replacements before
retiring old ones, and queued work should receive explicit backpressure.
Pre-initialising all four would impose roughly the measured 1.8GiB shell RSS
as a permanent standing cost; start one warm and scale toward four.

Every job gets a fresh incognito browser context/page with its scoped session,
then closes the context while retaining the browser. Recycle on job count,
age, crash, failed health check, or an RSS ceiling. Do not expose an arbitrary
URL renderer publicly: use a Unix/private socket or mTLS, authenticate clients,
allow only internal render targets (or prepared HTML), and prevent SSRF.

### Configuring the shared image for web and manager workloads

Cron is not the role switch for rendering and should remain unchanged. The web
and `oe-manager` containers can run the same application/image code with
different pool environment values. Configuration must be capability-specific,
not a single container-wide Chrome mode: event images require full Chrome,
whereas the approved high-throughput PDF case uses headless shell. This also
keeps a manually invoked event-image job on `oe-manager` from silently using
the visually incompatible PDF engine.

The lowest-overhead implementation is to prelaunch Chrome with CDP enabled and
have `DocumentRenderServicePuppeteer` use the already-supported
`Puppeteer::connect()` path. A small process-wide slot broker (or `flock`-based
slot table) bounds all Apache and CLI callers in the container. Requests close
their isolated context/page and disconnect the Puphpeteer bridge; they do not
close the shared browser. This avoids the Browserless `/function` API and the
extra cURL/base64 render transfer.

Suggested environment contract:

```text
OE_RENDER_POOL_ENABLED=false                 # safe rollback default
OE_RENDER_POOL_CAPABILITIES=image|pdf|image,pdf
OE_RENDER_POOL_ACQUIRE_TIMEOUT_MS=5000
OE_RENDER_POOL_QUEUE_LIMIT=100
OE_RENDER_POOL_MAX_JOBS_PER_BROWSER=500
OE_RENDER_POOL_MAX_BROWSER_AGE_MINUTES=60

OE_RENDER_IMAGE_ENGINE=chrome
OE_RENDER_IMAGE_BROWSERS=1
OE_RENDER_IMAGE_PAGES_PER_BROWSER=4
OE_RENDER_IMAGE_READY_MODE=signal
OE_RENDER_IMAGE_READY_TIMEOUT_MS=65000

OE_RENDER_PDF_ENGINE=chrome-headless-shell
OE_RENDER_PDF_BROWSERS=2
OE_RENDER_PDF_PAGES_PER_BROWSER=2
OE_RENDER_PDF_READY_MODE=signal
OE_RENDER_PDF_READY_TIMEOUT_MS=65000
```

Start with `OE_RENDER_POOL_CAPABILITIES=image` on `web` and `pdf` on
`oe-manager`. If a disabled capability is requested in either container, fall
back to the current local full-Chrome path rather than changing output. Once
both profiles have passed the complete consumer matrix, either capability can
be enabled on either container without a new image. The ready mode must also
fall back to the existing wait unless the target page emits the application-
owned marker; protected signatures remain required images before that marker.

The measured initial presets are one full-Chrome browser with four image slots
on `web`, and two headless-shell browsers with two PDF slots each on
`oe-manager`. Prewarm means launched and health-checked, not a promise to keep
one browser idle during saturation. Allocate at least the measured footprint:
about 1.46GiB peak Chrome RSS for the five-event image profile and 1.18GiB for
the 100-PDF profile, plus PHP/Apache headroom. A 512MiB `/dev/shm` and PID limit
of 256 are reliability guardrails; `/dev/shm` did not improve speed in the live
A/B test.

For event images, put an idempotent database/queue claim before pool
acquisition. Requests should enqueue and return a placeholder/202 rather than
occupy Apache while waiting. A single shared pool naturally caps all distinct
events; if every web replica has its own pool, add a fleet-wide Redis/DB lease
semaphore or divide the maximum across replicas. The existing per-event lock
prevents duplicate work for one event but does not cap many distinct events.

The lowest-code alternative-tool trial is **Gotenberg**. It exposes the two
capabilities OpenEyes uses (`HTML/URL -> PDF` and `HTML/URL -> screenshot`),
can return WebP directly, auto-starts one stateful Chromium, limits concurrent
conversions, queues excess work and recycles Chromium after a configured
number of jobs. It also supports cookies/headers and explicit ready selectors
or expressions. This is a close packaged match for the requested warm,
bounded renderer. It still uses Chromium and an HTTP service call, but that
call can carry prepared HTML or an authenticated render URL; it does not need
to reproduce the current CLI -> login controller -> inner browser lifecycle.
Trial it at `auto-start=true`, concurrency one and queue 100, then two and four.
Its documented per-instance maximum is six, but the measurements here do not
justify starting that high.

A custom Node Puppeteer/CDP service remains the best choice when OpenEyes needs
precise pool semantics that Gotenberg cannot provide. Playwright is not
installed in this image and using it would change orchestration, not the
Chromium renderer. A prototype must accept both `printToPDF` and screenshot
jobs, reuse pre-launched browsers, and compare PDF pages/WebPs for every
consumer above. For correspondence images it must retain PDF footers and
PDF-to-page behaviour; a raw screenshot is not equivalent.

Browserless is another packaged CDP service with hard concurrent-session and
queue limits, load checks and pressure metrics. It is more general than this
use case, and its current v2 configuration removed the old global
`PREBOOT_CHROME` switch, so Gotenberg or a small purpose-built service is the
better first trial for deterministic PDF/screenshot workers.

### ChromeDriver and Chrome knobs

ChromeDriver is the WebDriver server used by Selenium-style clients. It would
add a driver process and another protocol layer while ultimately asking the
same Chromium renderer to navigate, screenshot or print. Puppeteer already
talks directly to Chromium's DevTools Protocol, so ChromeDriver cannot remove
the measured layout/paint/PDF work and is unlikely to improve throughput.

There is no flag set that turns full Chrome into a tiny PDF library. The useful
knobs left for a capability-specific, visually gated pool are:

- use `chrome-headless-shell` for approved consumers, rather than changing the
  shared renderer globally;
- trial `--renderer-process-limit=2` and a bounded V8 heap such as
  `--js-flags=--max-old-space-size=256`, one at a time, while recording crashes,
  RSS and latency;
- intercept requests and allow only the CSS, fonts, images and scripts proven
  necessary for that render capability;
- retain a controlled profile/cache for static assets, but create a fresh
  incognito context for each job so sessions and patient data cannot leak;
- replace `networkidle0` with a document-ready marker and `document.fonts.ready`;
- for generic images, set the final viewport and ask Chromium for WebP with
  speed-oriented encoding, avoiding full-page PNG and GD transcoding.

Puppeteer already supplies many background-service-disabling defaults. Avoid
`--single-process`, `--no-zygote`, disabling site isolation/sandboxing,
disabling JavaScript/images/fonts, or blindly replacing Puppeteer's default
arguments. Those settings either reduce crash/security isolation or remove
content such as logos and protected-file signatures. `--disable-dev-shm-usage`
is a reliability workaround for a small `/dev/shm`, not a speed switch, and
can move I/O to slower storage. The live GPU-lean five-document trial was also
slower, so those flags are rejected on this instance.

### More radical non-browser tools

The true extreme speed path is to stop feeding known templates to a web
browser:

| Candidate | Best OpenEyes scope | Migration/fidelity risk |
|---|---|---|
| Typst | Structured correspondence, prescriptions and other known documents; direct PDF plus PNG/SVG output | Templates must be rewritten from structured data; attachments, signatures, fonts and pagination need a new golden suite |
| SVG + Rust `resvg`, followed by WebP encoding | Fixed generic event cards/previews | Very fast and bounded, but only for layouts deliberately expressed as SVG; not arbitrary event HTML |
| WeasyPrint in a long-lived service | Server-rendered print HTML that does not require browser JavaScript | Existing CSS must be ported/verified; no full browser DOM/runtime |
| Prince | High-fidelity paged HTML/CSS PDF where a commercial component is acceptable | Commercial licence and a different layout/JavaScript engine; visual regression still required |
| mPDF/Dompdf or direct FPDF | Small purpose-built PHP document templates | Largest CSS/template rewrite and easy to diverge from current output |
| LibreOffice service | ODT-based document templates | Appropriate for office templates, not event-page screenshots |

Typst can emit both PDF and page images from one deterministic template. For
generic event images, an even smaller path is data -> fixed SVG -> `resvg` ->
WebP, eliminating DOM, HTTP, JavaScript and browser processes. Neither can be a
global swap because the current renderer also accepts arbitrary module HTML.
A practical migration is hybrid: Gotenberg first as the compatibility and
resource-control boundary, then move high-volume known templates to Typst (or
Prince/WeasyPrint) and fixed event images to SVG/resvg.

References: [Gotenberg configuration](https://gotenberg.dev/docs/configuration),
[Gotenberg routes](https://gotenberg.dev/docs/getting-started/routes),
[Gotenberg WebP screenshots](https://gotenberg.dev/docs/convert-with-chromium/screenshot-url),
[Browserless limits](https://docs.browserless.io/enterprise/docker/config),
[WeasyPrint](https://doc.courtbouillon.org/weasyprint/stable/index.html),
[Typst PDF](https://typst.app/docs/reference/pdf/),
[Prince server integration](https://www.princexml.com/doc/server-integration/)
and [`resvg-js`](https://github.com/thx/resvg-js).

## Extreme rewrite

Run image generation as an idempotent queue worker, not inside the image GET
request and not as a cURL-driven controller loop:

1. Claim a bounded batch of unique dirty event IDs.
2. Resolve event data and render context in PHP without a web login.
3. Send prepared HTML (or a short-lived internal render URL) to one of a small
   number of persistent browser workers.
4. Capture WebP directly at the final dimensions.
5. Write to a temporary object/path, atomically publish it, and mark the queue
   row complete in a short transaction.
6. On failure, record an attempt count and exponential backoff. Never retry on
   every viewer request.

Start with one or two browser workers per container. The measured browser-tree
RSS means unbounded parallelism converts latency into memory pressure and
database contention. Increase concurrency only while monitoring browser RSS,
Apache/worker occupancy, MariaDB `Threads_running`, buffer-pool reads, and
render p95/p99.

This rewrite eliminates the outer cURL entirely. If extracting HTML generation
must be staged, use one programmatically created render session per batch and a
persistent browser first; that removes per-event login and browser launch while
preserving the current HTML endpoint.

## Acceptance benchmark

Use a fixed cohort split by event type and page height, including a tall
Correspondence event and attachments. Record:

- total and p50/p95 time per event;
- browser launches and peak Chrome RSS;
- web-worker occupancy;
- MariaDB queries, rows read, buffer-pool physical reads, and peak
  `Threads_running`;
- temporary bytes written and final WebP bytes;
- screenshot dimensions and pixel/fidelity differences;
- duplicate requests for the same event and failure/backoff behaviour.

Compare cold start, warm single-worker, and bounded concurrent runs. A speedup
does not pass if it produces stale pages, drops attachments/laterality, changes
the preview materially, or allows duplicate generation.

## Next round: ten new experiments with SQL-only rollback

Do not take another full-instance physical backup for this test instance. The
physical snapshot used for the first investigation was roughly hundreds of
gigabytes of I/O in each direction and is disproportionate for repeated
experiments. The next round should use a fixed, allowlisted mutation surface:

1. Stop cron and create the authenticated benchmark session before taking the
   logical baseline, so login/audit setup is outside each timed case.
2. Put the fixed DocMan/event cohorts in a dedicated benchmark table. Use
   event-image candidates with no existing rows/files wherever possible.
3. Copy the complete selected `document_output` rows into a restore table. The
   observed command changes status and ActiveRecord modification metadata;
   restore those columns from the snapshot and compare hashes of every column.
4. Copy any selected `event_image` rows into a restore table. After each case,
   delete all rows for the selected event IDs and reinsert the snapshot. Delete
   only files named in the case manifest. Direct DocMan exports go to a unique
   temporary output directory, never the normal destination.
5. Record row counts/high-water marks for any append-only audit table touched by
   the dedicated benchmark principal. Delete only rows attributable to that
   principal and run window. Do not delete a broad ID range on a shared test
   instance.
6. Drop case-specific indexes/configuration after the case. Verify the shared
   renderer config hash and absence of temporary command/components.
7. Compare pre/post row counts and deterministic whole-row hashes for every
   allowlisted table. Abort if a dry run changes an unlisted table. Auto-
   increment gaps and redo history are intentionally not restored; the scoped
   application data is restored logically, not byte-for-byte.

Screen each idea on five fixed documents/events first. Run 100 only for the
three candidates that pass fidelity and improve either time or peak memory.
Use the already measured stock cases as baseline; do not spend another four
minutes repeating stock for every idea.

| # | Experiment | Main question |
|---:|---|---|
| 1 | One persistent headless-shell browser, four simultaneous isolated contexts/pages | Can process sharing retain four-worker speed below the 1.8GiB DocMan and 3.2GiB event-image multi-browser peaks? |
| 2 | Two persistent shell browsers, two contexts/pages each | Is this a better crash-isolation/memory compromise than one-by-four or four-by-one? |
| 3 | Gotenberg with auto-start, one stateful Chromium, queue 100 and concurrency 1/2/4 | Can a supported packaged service match the custom pool while supplying backpressure, recycling and telemetry? |
| 4 | Raw Node/CDP with `Page.printToPDF` stream mode and file streams | How much RSS/time is lost by returning whole PDF buffers/base64 through Rialto/PHP? |
| 5 | Send prepared HTML to the renderer (`setContent`/HTML upload), with scoped local assets | How much do the inner authenticated OpenEyes navigation, Apache worker and duplicate DB hydration cost? |
| 6 | Replace `networkidle0` with an explicit render-ready marker plus `document.fonts.ready` | Can the unavoidable network-idle wait be removed without missing fonts/images? |
| 7 | Record the request waterfall, allowlist only required assets and retain a safe warm static-asset cache | Which analytics/UI/API resources can be removed, and what does font/CSS/logo caching save? Protected signatures remain required image resources. |
| 8 | Independently trial `--renderer-process-limit=2`, a 256MiB renderer V8 cap, a 256MiB Node old-space cap, and RSS/job-count recycling | Which constraint reduces peak memory without moving time into GC or causing renderer crashes? Do not combine flags until isolated results are known. |
| 9 | Generic event image directly to final-size WebP with speed-oriented encoding | What is saved by removing full-page PNG, temporary I/O, GD decode and second encode? |
| 10 | No-browser specialist pilot: Typst for one correspondence template and SVG + `resvg` for one generic event-image template | What is the attainable extreme when arbitrary HTML/DOM compatibility is deliberately traded for structured templates? |

WeasyPrint should be the fallback experiment for existing prepared print HTML
if the Typst migration cost is too high; Prince is the commercial fidelity
comparison. ChromeDriver, Selenium and Playwright are not separate speed
experiments because they change the controller while retaining Chromium's
rendering cost (Playwright may still be considered as an implementation API).

### Memory and resource acceptance gates

At the time of this investigation `test-web-1` and `test-db-1` had no cgroup
memory, swap, CPU or PID limits, and both had the Docker-default 64MiB
`/dev/shm`. Idle usage was about 187MiB for web and 8.15GiB for MariaDB; the
InnoDB buffer pool was configured at 18GiB. The transient Chrome tree, rather
than idle Apache, caused the measured multi-GiB application burst.

Run the renderer in its own container/cgroup. Initial test guardrails, to be
tuned from the one-by-four and two-by-two results, are a 2GiB hard memory
limit, 1.5GiB reservation, no swap, 512MiB `/dev/shm`, a PID limit of 256 and
an application queue of 100. Do not put this hard limit around Apache and its
renderer children together: an OOM should restart/fail a render worker, not
the clinical web process. Increase the PID limit if a single healthy browser
demonstrably needs it; never increase it merely to accommodate unbounded
browsers.

For every five- and 100-item run capture:

- renderer, Node, PHP/Apache and total-cgroup current/peak RSS;
- browser process trees, cgroup PID peak, OOM/pressure events and idle RSS;
- output bytes held in memory versus streamed, temporary I/O and `/dev/shm`;
- CPU average/peak and per-item p50/p95;
- MariaDB CPU, queries, rows read, physical reads and `Threads_running`;
- queue wait, active slots, failures/retries and browser restarts;
- RSS after 1, 100 and 500 jobs to detect leaks.

The target remains 100 DocMan outputs in under 100 seconds, with browser-side
peak RSS below 1.5GiB if possible. An event-image configuration should stay
below the 1.5GiB shell-four result while improving its 17.837-second five-event
time. No winner may exceed the measured four-worker DB peak, lose content, or
show sustained post-run memory growth.

Streaming is a concrete memory target, not speculation: the DevTools protocol
supports `Page.printToPDF` with `ReturnAsStream`, and current Puppeteer exposes
`page.createPDFStream()`. A fresh Puppeteer browser context isolates cookies
from other contexts, allowing process sharing without sharing authenticated
sessions. Docker hard/soft memory and PID constraints protect the host, but
swap is slower and should not be used to disguise renderer overcommit.

References: [CDP PDF streaming](https://chromedevtools.github.io/devtools-protocol/tot/Page/),
[Puppeteer PDF streams](https://pptr.dev/api/puppeteer.page.createpdfstream),
[Puppeteer isolated contexts](https://pptr.dev/api/puppeteer.browser.createbrowsercontext),
[Chrome Headless Shell](https://developer.chrome.com/docs/automation-and-testing/headless-chrome-shell),
[Docker resource constraints](https://docs.docker.com/engine/containers/resource_constraints/)
and [Gotenberg telemetry](https://gotenberg.dev/docs/telemetry).
