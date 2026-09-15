# Benchmarking OpenEyes page loads (2026-07, delivered)

Learnings from building `UrlBenchmarkCommand.php` (a yiic command that logs in
with curl, hands the session to Puppeteer, times pages and writes CSV). Read
before any OE page-performance or page-enumeration work.

## Timing without the debug toolbar

- `BaseController::afterRender()` (`protected/controllers/BaseController.php:236-239`)
  registers `window.execution_time` (seconds) and `window.memory_usage` ("N MB")
  as bare `POS_HEAD` globals, from `Yii::getLogger()->executionTime` /
  `->memoryUsage`. **Core OpenEyes, no debug gate** - so a per-request PHP time
  and peak memory are readable from any loaded page with the bar absent. This is
  the same clock and expression the `_brand.php` footer prints.
- `executionTime` is `microtime(true) - YII_BEGIN_TIME`, sampled at
  `afterRender`, i.e. before output flush and session close: a few ms low
  against a toolbar reading, by a near-constant offset. Excludes Composer
  autoload, which runs before `YII_BEGIN_TIME`.

## The debug bar contaminates every perf number on the box

`protected/config/core/main.php:47-64` gates on `YII_DEBUG && YII_DEBUG_BAR_IPS`
and merges the bar **together with**:

```php
'db' => array('enableProfiling' => true, 'enableParamLogging' => true),
```

Per-statement cost, so it is worst exactly on the pages perf work targets
(pages here issue 14k-42k statements). Check `printenv | grep YII_DEBUG_BAR_IPS`
in the web container and the mtimes in `protected/runtime/debug/*.data` before
trusting any measurement. Parsing those `.data` files programmatically:
`oe-debugbar-data-analysis.md`. Turning it off needs the env var unset and a container
restart - the human's call, since the bar is also their yardstick.

## Per-page SQL time, measured by the database

- `mysql.slow_log` (`log_output=TABLE`, `long_query_time=0`) records every
  statement with a microsecond duration. Truncate immediately before each
  recorded load; exclude your own connections by `thread_id`.
- **`min_examined_row_limit` must go to 0.** `my.cnf` here sets it to 2, which
  silently drops any slow-log row examining fewer than two rows.
- `SET GLOBAL` needs root - the app user has global `USAGE` only (ERROR 1227).
  Open a second connection: `/run/secrets/MYSQL_ROOT_PASSWORD` first, then env.
- Save and restore all of `slow_query_log`, `long_query_time`,
  `min_examined_row_limit`, `log_output`, from a `finally` **and**
  `register_shutdown_function()` **and** `pcntl_signal()` on SIGINT/SIGTERM,
  guarded by a once-flag. Overnight runs get killed.
- `mysql.slow_log` is `ENGINE=CSV` with no index: every read is a full scan, so
  keep it truncated. Client inside the db container is `mariadb`, not `mysql`.

## Scope mismatches that produce nonsense ratios

- Slow-log SQL time is **page-load-scoped** (every statement the server ran
  during the load, XHRs included). `window.execution_time` is
  **main-document-scoped**. Dividing the first by the second yields >100% on any
  XHR-driven page - one admin page read 6050%. Share SQL against the settled
  page time instead, and put the denominator in the output so the division is
  checkable.
- Settle detection (load fired, no pending XHR, images complete, DOM quiet) can
  call a page finished while the server is still working, so the page time is
  itself an under-measurement on such pages. A ratio over 100% is then a
  legitimate diagnostic, not a bug - read the statement count.
- Warm-up runs: exclude their `had_error` / `timed_out` from the final result,
  and count and divide by the same set (accumulating a time only when non-zero
  shrinks the divisor without moving the run count).

## Enumerating every page from a console command

No session needed, all readable from `CConsoleApplication`; union reaches ~99%
of the read-only routes in `c-oe-nav`'s page index:

1. `Yii::app()->params['admin_structure']` - 24 sections, 211 items.
2. `ModuleAdmin::getAll()` - `admin_menu` intersected with loaded modules.
   With (1): **267 unique admin URIs, 254 read-only**.
3. `Yii::app()->params['menu_bar_items']` - core plus 11 module contributions
   merged into the same param. Recurse `sub` at every level; expand
   `['api' => X]` entries via `Yii::app()->moduleAPI->get(X)->getMenuItems()`
   (null-guard - `get()` returns null for a disabled module); add
   `custom_menu_item` rows as `/customMenuItem/redirect?customMenuItemId=<id>`;
   filter with the static `MenuHelper::requiredMenuSettingsMet()`.
4. `ModuleReports::getAll()`.
5. Event views: newest `event.id` per `event_type`, built as
   `/{class_name}/default/view/{id}`.

Some menu entries have no URL (`uri => ''` with `requires_patient`, or
`javascript:...`). Print them as skipped with the reason, so "all menu items"
stays auditable.

`WorklistController::actionView()`: dated `/worklist/view` writes the dates into
`Yii::app()->session['worklist']`, so time the bare URL **first**; sending only
one of `date_from`/`date_to` causes a 302; a stored `WorklistFilter` /
`WorklistRecentFilter` row overrides the URL dates entirely.

## Yii 1.1 console footguns

- **Unmatched named options are appended as trailing positional args**, not
  ignored. Every action must declare every flag it honours or the flag silently
  lands in the wrong parameter. A `--flag` added later means editing every
  action signature - assert the count after a bulk edit.
- `--url=/a,/b` does not split; single-value flags are single-value. Use a file.
- Yii ships no table printer. ~25 lines does it: measure each column from its
  own widest cell (never guess widths up front), right-align all but the last,
  put the one variable-length field (URL) last, and print a long note on its own
  indented line under the row rather than as a column.
