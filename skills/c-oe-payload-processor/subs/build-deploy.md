# PayloadProcessor - build, package, run, configure

## Build (Maven)

- `mvn package`. **Java 21** (`maven.compiler.release=21`). README says "JDK 1.8+"
  and the CodeQL workflow still uses JDK 8 - both stale.
- **No shade/assembly fat jar.** Packaging is `jar` + the
  **`appassembler-maven-plugin`**, which emits launch scripts at
  `target/appassembler/bin/dicomEngine` (+`.bat`) and a `repo/` of dependency
  jars. Main class `com.abehrdigital.payloadprocessor.DicomEngine`.
- Key deps: GraalVM JS 21.3.14 (`org.graalvm.js:js` + `js-scriptengine`),
  Hibernate 5.6.15 + `hibernate-hikaricp`, HikariCP 5.0.1, **both** mysql-connector
  8.0.33 and mariadb-java-client 3.5.3, dcm4che 5.25, PDFBox 2.0.33, tess4j 5.4,
  thumbnailator, gson/guava/json-simple/ini4j, httpclient 4.5.14, SLF4J +
  `slf4j-log4j12` (logging is **log4j 1.x**).
- `settings.xml` is an empty stub and the Dockerfile `COPY settings.xml` is
  commented out - effectively unused.

## Package & run (Docker)

Two-stage `Dockerfile` (base `MAVEN_TAG=3.9-eclipse-temurin-21-noble`):

- **Builder:** copies the repo, `mvn package`.
- **Runtime:** installs `libtesseract-dev` + tools, **symlinks `liblept.so` /
  `libtesseract.so` into `/usr/lib`** (tess4j needs them), sets default ENV,
  copies `target/` -> `$PROJROOT` (`/dicomprocessor`) and the routine library ->
  `/routineLibrary`, and **downloads `eng.traineddata` into `/tessdata` at build
  time**. `ENTRYPOINT ["/init.sh"]`.

### `.docker_build/init.sh` (entrypoint)

Reads DB password from `/run/secrets/DATABASE_PASS` (else env), prints a banner,
sets timezone, ensures the DB host is in `WAIT_HOSTS`, runs `/wait`, then builds
the switch string and launches the appassembler binary:

```
switches="-sf /routineLibrary/ -rq ${PROCESSOR_QUEUE_NAME} -sy ${SYNCHRONIZE_ROUTINE_DELAY} -rq ${RETRY_DATABASE_CONNECTION}"
...
"${PROJROOT}/appassembler/bin/dicomEngine" ${switches}
```

> **Bug to know (`init.sh:65`):** the DB-retry value is passed as a **second
> `-rq`** where `-rd` was intended. Apache Commons CLI takes the *first* value, so
> the queue name is still honoured, but `-rd` is never set -> DB-retry window
> defaults to 0 (no retry). Also `/wait = 1` (`:60`) has a stray `= 1` argv token
> the binary ignores. `-sa` is appended only if `PROCESSOR_SHUTDOWN_AFTER > 0`.

### compose variants

- **`docker-compose.yml`** - local/dev: `build: ./` a single `dicom` service,
  DB at `host.docker.internal`. No web/db services.
- **`docker-compose-full.yml`** - full demo stack: pulls
  `appertaopeneyes/payloadprocessor:latest` + `appertaopeneyes/web:latest` +
  `mariadb:10.1`, `WAIT_HOSTS: "web:80"`, SSH-key secret for the web build.

> **Image-name drift:** README says `appertaopeneyes/dicomprocessor`,
> compose-full says `appertaopeneyes/payloadprocessor`, CI publishes to
> `toukanlabsdocker/payloadprocessor`. CI build is multi-arch (amd64+arm64).

## CLI args (`DicomEngine.initialiseParametersFromCommandLineArguments`)

| Flag | Meaning | Default |
|---|---|---|
| `-sf` | routine-script directory | `src/main/resources/routineLibrary/` (`/routineLibrary/` in container) |
| `-rq` | queue name to process | `dicom_queue` |
| `-sa` | run for N minutes then exit; **absent => run as service forever** | unset |
| `-sy` | routine-library sync delay (minutes) | 0 |
| `-rd` | DB-connect retry window (minutes) | 0 |

## Configuration (env vars + secrets)

| Env var | Default | Read at |
|---|---|---|
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_NAME` | `db` / `3306` / `openeyes` | `DatabaseConfiguration.java` -> `jdbc:mysql://host:port/name` |
| `DATABASE_USER` / `DATABASE_PASS` | `openeyes` / `openeyes` | same (secret overrides) |
| `POOL_SIZE` | unset | HikariCP `maximumPoolSize` |
| `API_HOST` / `API_PORT` | `host.docker.internal` / `80` | `ApiConfiguration.java` - OpenEyes web/API |
| `API_USER` / `API_PASSWORD` | `api`(Docker)/`admin`(code) / `admin` | same (secret overrides) |
| `API_DO_HTTPS` | `false` | `"true"` => HTTPS (with all-trusting TLS - see gotchas) |
| `PROCESSOR_QUEUE_NAME` | `dicom_queue` | -> `-rq` |
| `PROCESSOR_SHUTDOWN_AFTER` | `0` | -> `-sa` (seconds per README; usually leave 0) |
| `SYNCHRONIZE_ROUTINE_DELAY` | `99999` | -> `-sy` (~ "sync once at startup") |
| `RETRY_DATABASE_CONNECTION` | `2` | -> second `-rq` (see init.sh bug) |
| `DEFAULT_SUBSPECIALTY` / `DEFAULT_SERVICE` / `DEFAULT_FIRM_NAME` | `Eye Casualty[...]` | injected to JS as `env[...]`, used as routine fallbacks |
| `HOSPITAL_NUMBER_CONSTRUCT_REGEX` | unset | consumed in JS `extractHospitalNumber` |
| `WAIT_HOSTS` / `WAIT_HOSTS_TIMEOUT` / `WAIT_SLEEP_INTERVAL` | unset / 1500 / 2 | `/wait` startup gate |

**Docker secrets** (file beats env, from `/run/secrets/`): `DATABASE_USER`,
`DATABASE_PASS`, `API_USER`, `API_PASSWORD`.

**Per-queue runtime tuning** lives in the `request_queue` table (re-read each
cycle): `maximum_active_threads`, `busy_yield_ms`, `idle_yield_ms`. The executor
also **writes back** `total_active_thread_count`, `total_execute_count`,
`total_success_count`, `total_fail_count`, `last_thread_spawn_*`.
