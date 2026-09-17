# OEImageBuilder: Apache logging, rotation and performance

These recommendations follow analysis of a representative OpenEyes **v10.0.30** workload and inspection of OEImageBuilder tag `v10.0.30`, commit `4622a2596438641720f448894f1a87b6c316d60f`. They describe image defaults and changes to assess, not a record of production configuration changes. Deployment environment variables, included files and runtime limits can override the source defaults. No client identifiers or capture dates are retained here.

The paired [typical usage and load profile](../Openeyes/oe-v10-typical-usage-and-load-profile.md) explains the foreground workload, background traffic, error hotspots and representative hours. Runtime measurements are needed before choosing final tuning values.

## Why access logs are duplicated

`Web-Base/apache_configs/include_all/logging.conf` contains two global piped `CustomLog` directives. Both use the same `combined` format and rotation controls, with destinations `/var/log/apache2/access.log` and `/var/log/apache2/other_vhosts_access.log`. `Web-Base/init_scripts/90-setup-apache-virtual-host.sh` includes these common files at server scope. The name `other_vhosts_access.log` does not itself select different traffic.

The distribution can also enable `/etc/apache2/conf-enabled/other-vhosts-access-log.conf`, which writes `vhost_combined` records directly to `other_vhosts_access.log`. The inspected image recipe does not disable that configuration. An enabled copy was verified in a locally cached release image; that image is supporting evidence, not proof of the exact remote image. The supplied records independently confirm the relevant pattern: plain and virtual-host-prefixed copies of requests occur in the same alternative file.

Multiple global `CustomLog` directives can record overlapping requests. Their placement and any per-virtual-host overrides determine coverage; filenames do not. [Apache access-log configuration](https://httpd.apache.org/docs/2.4/mod/mod_log_config.html#customlog).

| Pattern to expect in future exports | What it means | Analysis rule |
|---|---|---|
| Byte-identical files at the export root and under `apache2/` | Repeated downloaded copies | Select one copy and record the excluded names and hashes. This adds no live request-processing cost. |
| Plain combined records in both access families | Two global piped loggers record the same requests | Prefer the complete canonical `access.log` family and compare the other family for additional coverage. |
| Plain and virtual-host-prefixed records in one alternative file | Piped and distribution-provided direct writers share a destination | Compare each format separately after removing only the virtual-host prefix. |
| Different boundaries or sizes | Independent writers, rotation and export timing retained different subsets | Verify coverage and record multiplicity; do not assume an exact two-to-one or three-to-one ratio. |
| A numbered slot is newer than the base filename | Circular rotation | Use timestamps inside files rather than suffixes to establish coverage. |
| Identical complete records within the chosen canonical stream | Requests can legitimately have identical logged fields | Preserve multiplicity. Do not globally deduplicate lines. |

In the reference analysis, the two canonical access files contained 2,932,635 valid records. Every complete record in the alternative streams matched that canonical set while preserving multiplicity; they added no coverage. A partial trailing record in one alternative export was excluded. This establishes the selection for that export, not permission to assume every future export is complete.

Use the pattern as a standing expectation for these image configurations, with a quick verification on each collection. Compare file hashes first, then timestamp coverage and per-format record multisets. Overlapping timestamp ranges alone do not prove duplicate records: a request's logged start time and its completion/write order need not agree.

## Performance impact and whether to leave it alone

Duplicate live writers add log formatting, pipe operations, file writes and storage consumption. They can add latency under I/O pressure, but this access-log dataset has no CPU, disk-wait or request-duration measurements with which to quantify the effect. It does not establish duplicate logging as the main performance bottleneck.

There is a more concrete correctness problem: a direct writer and a circular rotating writer share `other_vhosts_access.log`. The direct writer is not controlled by the piped writer's size/age checks, and reusing a circular slot can truncate records produced by either writer. Retention becomes harder to reason about. Leave the configuration temporarily if a collector dependency requires it, but plan a tested cleanup rather than treating the shared destination as harmless.

Separate streams can have a valid purpose when they provide different fields, access controls, retention or consumers. If virtual-host attribution is needed, one `vhost_combined` stream is useful. Two equivalent `combined` streams add no extra information. Intentional separate streams should have separate destinations and one rotation owner each.

### Recommended image change

1. Keep one canonical piped access logger in `Web-Base/apache_configs/include_all/logging.conf`.
2. Remove the second piped logger to `other_vhosts_access.log`.
3. Disable the distribution's `other-vhosts-access-log` configuration during image construction so that rebuilding does not restore the direct writer. The container image-build command is:

   ```bash
   a2disconf other-vhosts-access-log
   ```

4. Check collectors, dashboards and support procedures for filename and log-format dependencies. If they need virtual-host fields, use a single appropriately formatted canonical stream and update the parser.
5. Test all configured virtual hosts and rotation in an isolated container before deploying the new image. Do not remove the only remaining source required by a log collector.

These are proposed changes only. The analysis did not edit or restart a running service.

## Rotation defaults and alternatives

The source defaults are in `Web-Base/dockerfile`; `logging.conf` passes them to each piped `rotatelogs` instance.

| Environment variable | Source default | Effect |
|---|---|---|
| `OE_APACHE_MAX_NUMBER_OF_LOG_FILES` | `4` | Four circular slots per piped writer. |
| `OE_APACHE_LOG_FILES_ROTATION_TIME` | `2630000` | About 30.4 days between time-based rotations. |
| `OE_APACHE_MAX_LOG_FILE_SIZE` | `500M` | Size-based rotation threshold for a piped stream. |

When both time and size limits are supplied, either condition can trigger rotation. With `-n`, names form a circular list and a reused slot is truncated; `.1` is not necessarily yesterday's log. Four roughly 500 MB slots imply an approximate 2 GB bound per correctly managed piped stream, not a guaranteed number of retained days, and a write can overshoot a threshold. The separate direct writer invalidates that bound for its shared pathname. Rotation time boundaries default to UTC unless local-time mode is requested. [Apache rotatelogs](https://httpd.apache.org/docs/2.4/programs/rotatelogs.html).

| Rotation approach | When useful | Limitation |
|---|---|---|
| Keep the circular design, shorten the interval | Small change with bounded slot count and easier collection of recent periods | A size-triggered rotation consumes another slot, so retention in days remains variable. |
| Example trial: 14 slots, 86,400 seconds, 250M | Roughly daily boundaries and about 3.5 GB of nominal space per canonical stream | This does not guarantee 14 days when more than one slot is consumed per day. Size it from measured log growth. |
| Timestamped filenames with an explicit retention job | Easier discovery and collection by time period | Requires an additional, tested cleanup owner; timestamp names alone do not bound disk usage. |
| Central collection with short local retention | Survives container replacement and enables searches across the full backend group | Verify shipping lag, gaps, duplicate ingestion, privacy and retention at the collector as well as locally. |

The same piped controls do **not** rotate `/var/log/apache2/error.log` or `/var/log/php/errors.log`, which are configured as direct file destinations. Audit their effective rotation, plus application files and the container log driver's limits. A deployment may already provide external rotation; absence from this particular source file does not prove absence in production. Do not put two competing rotation mechanisms over one path.

`Web-Base/init_scripts/97-output-logs.sh` tails application, PHP, Apache error and other selected logs to stdout unless `OUTPUT_APPLICATION_LOGS=FALSE`. Access-log tailing is commented out. Thus the stdout forwarding is not the cause of the duplicate access streams described above. Forwarding errors to the container collector is intentional observability; disabling it broadly can remove the evidence needed to diagnose HTTP 500s. `OE_QUIET_DEBUG_LOG` suppresses the optional debug-file forwarding, but does not itself prove debug-file generation has stopped.

## Apache worker and connection settings

The image installs Apache's PHP module and configures `mpm_prefork`. Each busy request occupies a process. Long polls and processes waiting for nested document-rendering requests compete with normal clinical requests. An event-MPM switch requires a compatible PHP-FPM architecture and testing; it is not a drop-in setting for this mod_php arrangement.

`Web-Base/apache_configs/include_all/mpm_prefork.conf` maps these environment variables to Apache directives:

| Variable | Default | What to assess |
|---|---|---|
| `OE_APACHE_START_SERVERS` | `5` | Initial worker count; modest pre-spawning can help a morning burst if there is sufficient memory. |
| `OE_APACHE_MIN_SPARE_SERVERS` | `5` | Minimum idle workers; measure process creation and queueing before increasing. |
| `OE_APACHE_MAX_SPARE_SERVERS` | `10` | Maximum idle workers; balance retained warm processes against memory. |
| `OE_APACHE_MAX_REQUEST_WORKERS` | `150` | Concurrency cap, constrained by container memory, database connections, CPU and rendering headroom. Increasing it can worsen an overloaded database. |
| `OE_APACHE_MAX_CONNECTIONS_PER_CHILD` | `0` | Unlimited connections before worker recycling. A finite value can limit long-term process growth, at the cost of more churn. |

For a first controlled recycling trial, 1,000-5,000 connections per child is a range to measure, not a release-wide recommendation. Retain enough throughput and avoid synchronized churn. Check the effective `ServerLimit` as well as `MaxRequestWorkers`; the former can constrain the latter. [Apache MPM limits and recycling](https://httpd.apache.org/docs/2.4/mod/mpm_common.html).

A useful sizing estimate is available web-worker memory divided by a representative high-water private-memory footprint per worker. Deduct shared caches once, plus headroom for the parent process, filesystem cache, Ghostscript, image processing and concurrent Chromium jobs. Summing worker RSS can double-count shared memory. Confirm the result against the container's memory limit and measured peak usage, then check the database connection budget across all web containers.

Do not use hourly average request rates to size concurrency. The device-poll route can execute repeated SQL while occupying one worker with no completed access record; a rendering parent can wait while its child browser makes additional requests back into Apache. A full worker pool waiting for internal requests can create queueing even at a modest completed-request rate. [Apache performance considerations](https://httpd.apache.org/docs/2.4/misc/perf-tuning.html).

`KeepAliveTimeout`, general `Timeout` and `ServerLimit` are not explicitly overridden in the inspected common configuration. Their effective values must be read from the rendered container setup and Apache/package defaults. A short keep-alive timeout, for example a 1-2 second trial, can reduce idle prefork occupancy; test it against proxy connection reuse and normal page loading. Do not blindly disable keep-alive or shorten request timeouts to hide application delays. [Apache KeepAliveTimeout](https://httpd.apache.org/docs/2.4/mod/core.html#keepalivetimeout).

Prioritize bounding the application device poll and reviewing external-assignment locks before increasing worker limits to accommodate unbounded waits. If document generation is the dominant concurrent workload, a bounded rendering queue/pool is a more targeted architectural option than allowing every web request to spawn unconstrained work.

## PHP, OPcache and application settings

The following source defaults are in `Web-Base/php_configs/97-openeyes.ini`. Read the effective **web SAPI** configuration because CLI settings and overrides can differ.

| Setting | Source default | Recommendation to assess |
|---|---|---|
| `memory_limit` | `-1` | Measure peak PHP usage for ordinary pages and large document jobs, then choose a finite tested limit with headroom. An unlimited per-request limit makes worker concurrency harder to bound. |
| `max_execution_time` | `120` | Keep it consistent with intended request behavior and upstream timeouts. It is not a reliable wall-clock deadline for database/sleep/system waits on Unix. |
| `opcache.enable` | `1` | Already enabled; do not present enabling it as a new optimization. |
| `opcache.memory_consumption` | `396` MB | Inspect used/free/wasted memory, cache-full conditions and restart counters before changing capacity. |
| `opcache.file_cache` | `/usr/local/php/opcache` | Check its actual use, lifecycle and invalidation with the deployment model. |
| `apc.enabled` / `apc.shm_size` / `apc.ttl` | `1` / `64M` / `3600` | Measure APCu hit rate, allocation failures and eviction pressure before increasing its shared memory. |
| `session.gc_maxlifetime` / `session.cookie_lifetime` | `14400` / `43200` seconds | These are PHP defaults, not proof of effective OpenEyes authentication lifetime. Do not extend them to reduce overlay traffic. |

PHP's memory limit does not cap the memory of external Chromium or Ghostscript processes; container limits and bounded job concurrency are also needed. A finite PHP limit must be tested with clinically representative large documents to avoid introducing new failures.

If OPcache measurements identify pressure, assess `opcache.max_accelerated_files` and interned-string storage as well as total memory. Disabling timestamp validation is only suitable for an immutable deployment with reliable replacement/invalidation. It is unsuitable when code can change in a running container without a corresponding reset. Keep diagnostic status access restricted. [PHP OPcache configuration](https://www.php.net/manual/en/opcache.configuration.php).

OpenEyes v10.0.30 already configures schema caching; inspect effective application configuration before assuming it is absent. Its core config also enables SQL profiling and parameter logging with the debug-bar configuration. Ensure performance measurements use the intended production debug settings; profiling can alter the work being measured. The database session implementation still performs writes for requests marked `extend_session=false`. See the paired usage article for eliminating unnecessary overlay/expiry requests while retaining correct session behavior.

## Assets, compression and rendering

`Web-Base/apache_configs/include_all/default.conf` already configures compression and expiry rules, with a two-minute default expiry and immediate expiry for HTML/JSON types. Confirm effective response headers through the deployed proxy rather than assuming the source rules win.

| Opportunity | Conditions and measurement |
|---|---|
| Longer caching for fingerprinted public JS/CSS/assets | Validate content-hashed URLs and deployment invalidation first, then consider a long lifetime and `immutable` for that restricted asset set. Do not apply this to patient pages, protected files or clinical PDFs. |
| Reuse caches in a bounded document-rendering pool | Measure cold versus warm headless-browser asset loads and memory use. Preserve isolation of patient/session context and do not share authentication state between jobs. |
| Reuse validated PDF/event-image output | Key it by source content and relevant rendering settings; invalidate correctly. Repeated downloads do not prove repeated generation. |
| Capture conversion exit status and stderr | Prevent malformed PDF input from silently producing incomplete output and repeated expensive retries. Add timing and opaque job correlation. |
| Measure compression CPU versus bytes saved | Compression is already present. Avoid redundant compression of already compressed images/PDFs and check proxy behavior. |

The reference workload had 47.80% static requests and 42.22% requests explicitly marked as Headless Chrome, with overlap between those categories. Do not add those percentages. This motivates measurement of rendering/asset behavior, not a claim that all those requests can be removed.

## Improve the next log collection

The current combined records support counts and byte totals but do not include verified response duration. Keep a single canonical stream and consider adding the following after checking collector/GoAccess format compatibility:

| Field or practice | What it enables |
|---|---|
| Final status `%>s` | Outcome after internal redirects. |
| Duration `%D` | Completed-request time in microseconds for latency analysis. Long polls need a separate category from page loads. |
| Logged bytes `%O` | Bytes including headers when the required module is active; label this consistently. |
| Request correlation such as `%L`, plus a propagated request ID where supported | Connect access records, Apache/PHP exceptions, integration calls and proxy records. `%L` alone can be `-` when no error-log ID was assigned. |
| Process ID `%P` and controlled error-log context | Diagnose worker/restart behavior and correlate converter output once the application captures it. |
| Explicit virtual-host field when needed | Distinguish multiple virtual hosts in one canonical stream. |
| Trusted proxy address handling | Interpret backend peer/client fields correctly. Configure trusted proxy ranges instead of accepting arbitrary forwarded headers as truth. |

Apache's format definitions describe the modules and semantics needed for these fields. Avoid logging cookies, authorization headers, response bodies or additional patient-bearing query values merely to gain correlation. [Apache LogFormat reference](https://httpd.apache.org/docs/2.4/mod/mod_log_config.html#formats).

Collect front-end proxy access/error records and application/PHP errors over the same bounded interval as Apache access logs. This is required to investigate a user-visible 504 that the backend did not log as 504. Undated child-process diagnostics need application-level capture; adding a date to the Apache access format cannot retrospectively date them.

In Kubernetes/Container Insights, a cluster application log group can contain more than one deployment namespace. Select the intended namespace and container from structured metadata, not the cluster name alone. The log collector may combine several application lines into one CloudWatch event, so count matching exception lines carefully and distinguish event counts from exception/request counts. Check retention before expecting a downloaded access-log period to remain searchable remotely.

## Verification before release

1. Build an isolated image with only the intended changes. Inspect included configuration, enabled modules, environment overrides and PHP web-SAPI settings. Run Apache's configuration check and virtual-host dump inside that container.
2. Issue distinguishable requests to every relevant virtual host and verify exactly one canonical access record per request, with the intended format and correlation fields. Confirm all collectors still receive the chosen stream.
3. Force small size/time rotations in that isolated test. Verify slot reuse, bounded growth, record coverage and behavior after restart. Test error/PHP/application retention separately from access rotation.
4. Run representative patient/worklist views, forms, device waiting and document rendering at controlled concurrency. Measure latency, errors, busy workers, queueing, memory, CPU, disk wait, database connections and query time. Include large PDFs and an idle device; normal short page requests alone will miss those risks.
5. Compare before/after results with the same workload. Roll out one tuning change at a time with defined rollback values. Keep canonical logs and error collection available throughout.

For read-only checks against an already running test container, replace `WEB_CONTAINER` with its name:

```bash
docker exec WEB_CONTAINER apache2ctl -t
docker exec WEB_CONTAINER apache2ctl -S
docker exec WEB_CONTAINER apache2ctl -M
docker exec WEB_CONTAINER apache2ctl -t -D DUMP_RUN_CFG
docker exec WEB_CONTAINER sh -c 'grep -R -nE "CustomLog|ErrorLog|KeepAlive|Timeout|ServerLimit|MaxRequestWorkers" /etc/apache2'
```

The dump and file search complement one another: not every inherited default appears in every dump, and a file search can include disabled configuration. Match findings to the effective include/module list. Configuration dumps can contain deployment details and should stay outside a shared knowledge repository.
