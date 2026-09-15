# v26 in-container aliases and diagnostics

Read when reviewing or extending `Web-Base/profile.d/oe-shortcuts.sh`, especially ports from oe-deploy's host `.bash_aliases`.

Verified 2026-09-10 against the packaged source and tools in `toukanlabsdocker/oe-web-live:26.0.6`; SQL and queue checks used disposable MariaDB 11.8.9 and Redis 8 with synthetic fixtures. Recheck the target image and branch before assuming a proposed alias is installed. Paths below are relative to `$WROOT` unless stated otherwise.

## Runtime boundaries

- Respect `$WROOT` (default `/var/www/openeyes`). Host aliases resolve compose projects and invoke `docker exec`; image functions already run inside the container and should use its environment and Docker secrets directly.
- The inspected image has GNU grep, jq and **mawk**, not gawk. It has neither `column` nor `logrotate`. Do not rely on tools available only on the development host.
- CLI `apcu_cache_info()` reports that CLI process's cache, not Apache's cache. It cannot validate web cache occupancy or a web cache clear.
- If a config dump can contain credentials, use a unique `mktemp` file with mode 0600, not a predictable world-readable path. Shortened diagnostic output is not automatically safe to share.

## Session queries

`index_yii.php` sets `session.serialize_handler` to `php_serialize`. Username extraction from `user_session.data` must match the stored serializer, not just an older host alias.

| Stored form | Username marker |
|---|---|
| v26 `php_serialize` | `__name";s:<length>:"..."` |
| Older PHP `php` serializer | `__name\|s:<length>:"..."` |
| Legacy fallback handled by imported aliases | `"username";s:<length>:"..."` |

- Use literal marker checks such as `LOCATE('__name";s:', data) > 0` before extracting. SQL `LIKE '%__name...%'` treats underscores as wildcards and can incorrectly select the `__name` branch for a `username` fallback record. A regex character class `[|]` avoids nested shell/SQL backslash escaping for the old pipe marker.
- Count actual session rows before grouping users. `DISTINCT Username, expire` loses separate sessions whose expiry values happen to match. Use `COALESCE` for aggregate results that would otherwise be NULL on an empty table.
- `protected/components/OESession.php::getTimeout()` returns the effective `session.gc_maxlifetime - 10`. The inspected image defaults to 14400, but deployment PHP overrides can change it; oe-deploy normally supplies 1800. Do not hardcode either as the effective lifetime.
- `expire` is sliding session expiry, not login time. Subtracting the OE timeout estimates the last expiry-extending activity; polling with `extend_session=false` can update data without extending expiry. Label that estimate honestly.

## Application log searches

- Yii records begin with `YYYY/MM/DD HH:MM:SS [severity] [category]` and can span multiple lines. Flush a record on **every** timestamp header, each file boundary and EOF. Adjacent errors must not merge; a match on a stack-trace line must return its whole record.
- Case-insensitive file selection does not make an awk record filter case-insensitive. mawk does not implement gawk's `IGNORECASE`. A verified approach frames complete records with NUL, filters with GNU `grep -zEi -- "$pattern"`, then removes framing NULs while preserving original text.
- Select the requested file window before matching: the current `protected/runtime/application.log` and native numbered rotations `application.log.N`. A limit on files scanned is not a limit on matching files or records. Do not search older files merely to fill a quota of matches.
- Keep search results on stdout and diagnostics on stderr. Decide terminal colour from the caller's stdout, not an intermediate pipe. Check mixed-case matches, adjacent errors, multiline matches, empty searches, no matches, invalid regexes and filenames containing spaces.

## OEExceptionHandler reports

Source: `protected/modules/OEExceptionHandler/config/common.php` and `components/CaptureRequestDetailsHandler.php` in that module. Inspect the packaged module, which may be absent from a base application checkout.

- `OE_EXCEPTION_HANDLER_LOG_PATH` configures the writer directory. Otherwise the handler uses Yii's runtime path plus `/OEExceptionHandlerLogs`. Image init 52 links the top-level `/OEExceptionHandlerLogs` volume into `protected/runtime/`; follow that directory symlink when finding reports.
- `OE_EXCEPTION_HANDLER_FORCE_ENABLED` is consumed: `override_enabled` is true when the value is exactly `true` **or** `YII_DEBUG` is false. Setting it to `false` does not disable the override outside debug mode.
- Each `<support_identifier>.log` is one pretty-printed JSON object, not JSON Lines. The writer opens it in `w` mode.

| JSON path | Meaning |
|---|---|
| `support_identifier.id` | Support identifier; sibling `parts` and `context_decoded` hold context |
| `error.oe_version`, `error.error_hash` | Version and error fingerprint |
| `error.error.message`, `.file`, `.line` | Error details; Throwable reports also have `.class` and `.trace`, but CErrorEvent reports need not |
| `request.when`, `.method`, `.url`, `.parameters` | Request details |
| `user`, `patient_id` | Potentially identifying context |

- `request.when` uses `Y-m-d h:i:s`: 12-hour time with no AM/PM. Order newest reports by filesystem mtime rather than interpreting that field as unambiguous 24-hour time.
- Search the full decoded JSON independently of the compact display, and apply any result limit after matching. Omitting user details, request parameters, traces and URL query strings reduces noise, but messages, paths and support identifiers can still contain sensitive context. Never describe this as anonymisation or copy real reports into the kit.
- `jq -er` returns 4 for both a successful filter producing no results and some JSON parse failures. With `jq -r` and `select`, successful empty output can mean no match while a nonzero exit remains an error. Test malformed reports separately from legitimate no-match reports.

## Apache diagnostics

Inside the web image, the following syntax checks print configuration without enabling modules persistently or reloading Apache:

```bash
apache2ctl -t -D DUMP_VHOSTS -D DUMP_RUN_CFG -D DUMP_MODULES -D DUMP_INCLUDES
apache2ctl -t -D DUMP_CONFIG -c '<IfModule !info_module>' -c 'Include /etc/apache2/mods-available/info.load' -c '</IfModule>'
```

The second command temporarily loads the installed but disabled `mod_info` **after** normal config parsing (`-c`, not `-C`), avoiding changes to earlier `<IfModule>` decisions. Its output is parsed directives, not fully merged per-request or `.htaccess` configuration. Dumps can contain secrets.

Image Apache logging uses `rotatelogs -n` rings. A numbered `.log.N` file can be the active output; its suffix is not evidence that it is safe to delete or truncate.

## MariaDB diagnostics

- Compare `INFORMATION_SCHEMA.GLOBAL_VARIABLES.VARIABLE_VALUE` with `SYSTEM_VARIABLES.DEFAULT_VALUE`, joined by `VARIABLE_NAME`. `NOT (BINARY default_value <=> BINARY variable_value)` preserves NULL, case and trailing-space distinctions. Report `GLOBAL_VALUE_ORIGIN` too: a difference from the reported default is not necessarily an operator change (`AUTO`, `CONFIG` and `COMPILE-TIME` are distinct origins).
- The reviewed `_oe_sql_root` helper forces `--table`. Adding `-N -B` alone did **not** disable tables with the actual MariaDB client; add `--skip-table` for scalar/batch output and test the real wrapper.
- A watch process cannot reuse a one-shot process-substitution credential descriptor. Recreate the secret-backed client options inside each iteration; do not expose passwords in the watch header or process arguments.
- MariaDB 11.8 lock-wait diagnostics can join `INNODB_LOCK_WAITS` to `INNODB_TRX` for waiting/blocking connection IDs. DDL progress comes from processlist `STAGE`, `MAX_STAGE`, `PROGRESS`; label stage progress rather than promising overall completion. An idle report should explicitly say there are no waits or active DDL.
- If porting Mirth SQL, use its independent `MIRTH_DB_HOST`, `MIRTH_DB_PORT`, `MIRTH_DB_NAME`. The inspected BridgeLink 4.6.1 `CHANNEL` table has `ID`, `NAME`, `REVISION`, `CHANNEL`, not `IS_ENABLED`; check its schema instead of borrowing OE assumptions.

## Laravel diagnostics without application boot

- v26 has `oe-laravel/artisan` with shared root `vendor/`. Resolve the nested application first; only use root `artisan` as a checked fallback.
- For configuration-only diagnostics, require the autoloader and `bootstrap/app.php`, then bootstrap `LoadEnvironmentVariables` and `LoadConfiguration`. Set `Illuminate\Support\Facades\Facade::setFacadeApplication($app)` directly if needed. `RegisterFacades` also consults the package manifest and can write a missing manifest; full application/provider boot can have other side effects.
- Find logs from `logging.default` and standard `stack`, `single`, `daily` channel metadata, not a guessed `storage/logs/laravel.log`. Do not instantiate `LogManager::channel()` just to discover paths: it executes taps and can write an emergency log on failure. Report custom, tapped or non-file channels explicitly. Standard daily rotation puts `-YYYY-MM-DD` before the final extension; deduplicate shared paths.
- For queue reads, register only the framework database, Redis and queue providers required by the diagnostic. Resolve `queue.default` as a **connection name**, then its configured driver and queue. The packaged database/Redis drivers expose `pendingSize`, `delayedSize`, `reservedSize`, `size`; reserved is not necessarily running, and separately read counts are not an atomic snapshot.
- Use `CountableFailedJobProvider::count($connectionName, $queue)` when supported, rather than loading every failed payload. Initialise `Horizon::use(config('horizon.use'))` before the Redis manager is first resolved; that manager snapshots connection config. `RedisMasterSupervisorRepository` requires the Redis factory in its constructor. Horizon's master status is global, not proof that the selected queue has healthy workers.

## Verification boundary

Run syntax and lint checks plus fixture tests in the target image, not just the host shell. Use disposable databases/Redis for SQL and queue semantics; include empty states, duplicate sessions, custom config and malformed logs. A passing synthetic fixture suite does not establish live deployment configuration or worker health.
