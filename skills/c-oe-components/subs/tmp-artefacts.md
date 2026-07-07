# Rendering/import tools and the temp artefacts they create

Which third-party tool OpenEyes drives for each render/import job, where in the app it is invoked, and what it writes into the system temp directory. In the containers `/tmp` is tmpfs - leaked artefacts consume RAM, and zero-byte/empty entries still consume the mount's finite inode budget. Verified on v11.0.18; the same call sites exist on 26.x.

| Tool | Invoked from | Used for | Temp artefacts |
|---|---|---|---|
| ImageMagick (`Imagick` PHP ext) | `BaseEventTypeController::createPdfPreviewImages()` (PDF pages -> PNG at 300 dpi); `OphCoDocument/DefaultController::actionCreateImage()` (GIF preview, video thumbnail) | Lightning-viewer page previews, document thumbnails | `magick-*` pixel-cache spill blobs - 200-420 KB per text-PDF page, 60-70 MB per scanned page; freed only when the Imagick object is destroyed |
| Ghostscript (`gs` binary via `exec`) | `OphCoDocument_API::convertPDF()` and the identical block in `OphCoDocument/DefaultController::convertPDF()` | Down-convert attachment PDFs newer than v1.4 so TCPDF/FPDI can embed them in print bundles (Document print, Correspondence) | `OE??????` converted PDFs (`tempnam("/tmp","OE")`), 59-900 KB each |
| Puppeteer / headless Chromium (`zoon/puphpeteer` + Rialto -> node) | `DocumentRenderServicePuppeteer` - every HTML->PDF/image render (event prints, correspondence, consent forms, event preview images); also `UrlBenchmarkCommand` (dev CLI) | HTML -> PDF and HTML -> image rendering | `puppeteer_dev_chrome_profile-*` (~9 MB) + `org.chromium.Chromium.*` shmem (2 MB each); `footer_*.html` scratch page in `event_<id>_images/` that Chromium navigates to for the footer template |
| TCPDF/mPDF + FPDI | `OphCoDocument/DefaultController::actionPDFPrint` (`pdf_output`) | Assemble the print bundle; a PDF-only Document print is a pure FPDI merge and skips Puppeteer entirely | `event_print.pdf` written into `event_<id>_images/` before streaming |
| GD (native PHP) | `imagecreatefrompng()` in the preview loop; `EventImageGenerator` re-encode to cached WebP/PNG | Imagick->GD bridge, preview cache encoding | none of its own - reads/writes paths owned by its callers |
| libcurl (PHP curl ext) | `EventImageCommand` (CLI logs into the webapp over HTTP to drive image endpoints); `protected/components/Curl.php` | CLI HTTP sessions | `cookie.txt` / `curl_cookie.txt` cookie jars (<1 KB, fixed paths - also a parallel-run race) |
| native PHP (`tempnam`, `mkdir`) | `createPdfPreviewImages()`; `EventImageGenerator::getTempImageDirectory()`; `Event::getImageDirectory()` | scratch paths for the tools above | zero-byte `oe_pdf*` stubs (tempnam creates the file, the `.png` suffix makes a second path); `oe_pdf*.png` page rasters (~200-400 KB, orphaned on crash); `event_images/<microtime>/` per-call dirs; `event_<id>_images/` per-event dirs |

Notes that shape fixes:

- Relocation chain: ImageMagick honours `MAGICK_TMPDIR` -> `TMPDIR` -> `/tmp`; Chromium's shmem honours `XDG_RUNTIME_DIR` -> `TMPDIR`. The Puppeteer profile dir does NOT honour any env var - only `temporaryDirectory` in `.puppeteerrc.cjs` moves it, and its parent must pre-exist (`mkdtemp` doesn't create parents) with 1777 perms (web renders run node as www-data, CLI/cron as root).
- Browser lifecycle: one browser per rendering request/CLI run, closed by `BaseController::afterAction()` (web). On an exception the Rialto `ProcessSupervisor` destructor tears it down at request shutdown via SIGTERM with a 3 s (default `stop_timeout`) grace before SIGKILL - small renders win that race, heavy ones and killed workers orphan the profile+shmem pair.
- A v11.0.18 /tmp-leak PR set (2026-07) fixes the leaks per call site: `~/pullrequests/oe-pr-tmp-*`.
