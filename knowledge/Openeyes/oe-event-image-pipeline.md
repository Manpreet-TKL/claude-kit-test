# OpenEyes event-image pipeline: storage, serving, Puppeteer boot cost (2026-08)

Findings from investigating slow/broken lightning-viewer previews on a develop
instance. The lightning viewer serves pre-generated preview images of events;
Correspondence previews are Puppeteer re-renders of the letter, made lazily on
first view - lazy-by-design, since most event images are never looked at, so
never recommend bulk pre-generation as a perf fix (`yiic eventimage create`
exists but mass-produces redundant files).

## Storage - DB blob is legacy, files are current

- `event_image` table: one row per page per eye per document; has BOTH
  `image_data` (mediumblob, legacy) and `file_name`. Check with
  `SELECT id, file_name, status_id, LENGTH(image_data) FROM event_image WHERE event_id = <id>;`
- `EventImage::getImageContent()`: a non-null blob is served straight from the
  table and `EventImageDumpCommand` then migrates it to a file; otherwise
  `file_name` is a path relative to `protected/event_images`, shaped
  `<sha1(event_id)-sharded dirs>/<event_id>_<eye>_<page>_<docnum>.webp`, read
  via the `storage` component.
- The letter itself is never stored as a PDF - correspondence content is DB
  rows re-rendered on demand; only the preview webp persists. Letter signature
  images are ProtectedFile rows with bytes under `protected/files` (partial
  test datasets often lack the file bytes - expected, not a bug).

## The render storm (root-caused 2026-08, fixes in oe-pr-event-image-storm)

Why one lightning click could wedge a container:

- `lightning_viewer.php` listed EVERY `event_image` row for the patient with no
  status filter; the JS fetches all of them eagerly. FAILED (23k rows on a
  production-scale restore) and orphaned GENERATING (3.3k) rows have no file,
  and each such `<img>` forces a SYNCHRONOUS in-request Chrome render. Cold
  click on a long-history patient = ~31 launches; each render chain holds 3
  Apache prefork workers (image request -> in-process CLI command -> Chrome
  fetching the render page) for up to read_timeout 65s, so ~50 concurrent
  renders exhaust a 150-worker container.
- NO dedup existed anywhere: STATUS_GENERATING is written but read nowhere
  (dead code), so double-clicks and multiple users spawn racing duplicates -
  and regeneration DELETES the event's existing images first, so races destroy
  good previews and 500 (TypeError on the null find). The batch repair path
  compares against the literal string 'GENERATED' which matches no status
  (more dead code) - FAILED events retried on every view forever.
- Failures were served as zero-byte HTTP 200 `image/webp` with
  `Cache-Control: private, immutable, max-age=31536000` - browser poisoned for
  a year, silent broken glyph, no console error.
- Secondary vector: episode sidebar fired a preview fetch per un-debounced
  mouseenter (a sweep down the sidebar = a render per event crossed).

Fix shape that survived review of alternatives (all DB-backed because ~100
users/container x multiple containers share one DB): CREATED-only filter in
the view; non-blocking `GET_LOCK('openeyes.event_image:<id>', 0)` around
generateImage() with RELEASE_LOCK in finally (loser returns immediately - a
waiting loser ties up another worker; self-releases on connection death, so
stuck GENERATING rows become inert, no reclaim code); 1h FAILED backoff via
last_modified_date (fleet-wide, one constant); controller 404 + no-store when
unservable, forced regen gated to CREATED (preserves moved-volume self-heal);
200ms sidebar dwell timer; LightningViewer early-return keeps "No preview" on
empty responses. GET_LOCK needs MySQL 5.7+/MariaDB 10.0.2+ for multiple named
locks per connection; key deliberately distinct from Event::lock().

Residual gap (follow-up ticket material): `imagewebp(): gd-webp encoding
failed` (WebP hard limit 16383px vs very tall fullPage screenshots) throws in
EventImageGenerator (~:88) BEFORE the controller's STATUS_FAILED write
(BaseEventTypeController ~:3214), leaving GENERATING rows that the hourly
backoff never sees - the lock still caps them at one concurrent attempt.

## Puppeteer launch cost (fixes in oe-pr-puppeteer-launch-options)

- `documentRenderService` (`core/common.php`) wraps nesk/puphpeteer bridging
  puppeteer 24.x. Key finding that invalidates most flag-list folklore:
  **puppeteer 24 already applies `--disable-dev-shm-usage` and nearly all of
  the classic "headless trim" flags by default** - re-adding them is noise,
  and `ignoreDefaultArgs` must never be passed. The historically hardcoded
  `--window-size=1280,720` was inert (every render path sets its own
  viewport/page size). Useful base set is just
  `--disable-gpu --no-sandbox --no-default-browser-check`.
- The PR makes init() lazy (browser launches on first getBrowser(), proven: 0
  processes on component resolution) and adds `headless_mode` ('chrome'
  default | 'shell') + `extra_browser_args` (APPENDED - Chromium is last-wins
  on repeated switches) behind one `getLaunchOptions()` seam, env override
  `PUPPETEER_HEADLESS_MODE` mirroring `PUPPETEER_BASE_URL`.
- chrome-headless-shell measurements (same 4-page doc, same box): RSS 407-428MB
  vs full chrome ~813MB (half), cold PDF 1.73s vs 1.87-1.90s (~8% faster),
  warm equal (~1.5s), max 7 processes vs 10. Fidelity gate PASSED: extracted
  PDF text identical, footers/geometry identical, raster diff = footer glyph
  antialiasing only (constant AE=512/page in a 710x38 strip - inspect crops
  before believing a nonzero AE); screenshots byte-identical; real webp regen
  via the web self-heal path identical dims, AA + lossy-webp noise only.
  Default deliberately NOT flipped - that is its own change, paired with an
  OEImageBuilder PR dropping full chrome from the image (live image ships TWO
  browsers: chrome 377MB + headless-shell 260MB, plus 615MB node_modules).
- Riskier `extra_browser_args` to trial under load, never defaults:
  `--renderer-process-limit=2`, `--js-flags=--max-old-space-size=256`,
  `--enable-low-end-device-mode` (RAM for speed). Never
  `--single-process`/`--no-zygote` with current puppeteer.
- Browser re-use across requests is STRUCTURALLY impossible under mod_php
  prefork: the Rialto node bridge dies at request teardown. The real lever
  stays `connect(browserWSEndpoint)` to a long-lived Chrome (authored as
  oe-pr-remote-puppeteer-browser); this round was the low-hanging fruit that
  clears its runway.
- Gotchas kept: Rialto idle_timeout 60s < read_timeout 65s (a >60s render can
  lose its node bridge mid-wait - follow-up ticket); EventImageGenerator
  passes width/viewport_width options the renderer never reads (dead);
  `lightning_viewer.compression_quality` in `core/common.php` is a DEAD knob -
  real values hardcoded 50 in `BaseEventTypeController` and
  `EventImageGenerator::IMG_QUALITY`; `image_width`/`viewport_width` 1720
  screenshots stored un-downscaled (displayed ~800px; Correspondence 950).

## Performance gain - the before/after ledger, especially under concurrency

The win is NOT per-render speed (warm render time is unchanged, ~1.5s); it is
eliminating renders that should never happen and bounding the ones that
should. Before/after on the same long-history patient and container:

- Page open: ~31 forced synchronous Chrome launches on a cold lightning click
  (21 observed in 3 min) -> 0 at page open; the viewer is interactive
  immediately and imageless events show "No preview".
- Concurrency bound: previously UNBOUNDED - every duplicate click/user
  multiplied renders (no dedup existed), each chain pinning 3 prefork workers
  for up to 65s, so ~50 concurrent renders (workers/3) wedged a 150-worker
  container; two clicks of one icon could take a container most of the way
  there. Now at most 1 render per event FLEET-WIDE: k users piling onto the
  same patient cost one render per genuinely-missing image, and every loser
  returns in milliseconds (404/no-store) instead of holding workers. The
  concurrent-render ceiling becomes "distinct events currently being healed,
  once each" instead of "requests x rows".
- Standing tax: FAILED events used to re-render on EVERY view (x4 imageLoader
  retries), each a fresh session + full event-page render + N+1 image queries
  on the shared DB - now at most 1 attempt/hour/event fleet-wide, so the
  background DB + worker load from the 23k-row FAILED backlog drops to noise.
  Sidebar sweeps: was 1 fetch per event crossed, now 0 unless the pointer
  dwells 200ms.
- Memory during a burst: each full-Chrome render tree is ~813MB RSS, so a
  storm was memory-bound as well as worker-bound (~31 trees is theoretical
  ~25GB - in practice the box thrashes first). Dedup caps trees at one per
  event; shell mode halves each tree (407-428MB), so N concurrent renders
  need ~N x 0.4GB instead of an unbounded multiple of 0.8GB.
- Non-render paths: lazy launch removes a ~1.9s Chrome cold boot + ~813MB
  tree from every request that resolves documentRenderService without
  rendering (previously paid in init() just for touching the component).
  Shell cold launch is ~8% faster (1.73s vs 1.87-1.90s).

Related: `oe-page-benchmarking.md`. Team-facing storage note lives outside the
kit at `~/oe-lightning-image-storage-note.txt`.
