# IOLMasterImport - build, package, run, configure

## Build (Ant)

- `compile.sh` is one line: `ant -f ./ -Dnb.internal.action.name=rebuild clean jar`.
- `build.xml` just `<import>`s `nbproject/build-impl.xml` (a NetBeans-generated
  build). The `jar` target compiles and writes `dist/OE_IOLMasterImport.jar` with
  `Main-Class: uk.org.openeyes.OE_IOLMasterImport`.
- **Java source/target is 1.7** (`nbproject/project.properties`), built with a
  JDK 8 image.
- **No Maven/Gradle** - dependencies are vendored under `lib/` and
  `lib/httpclient/`: dcm4che-core 3.3.7 (DICOM), Hibernate 5.0.0.Final,
  mysql-connector 5.1.49, pdfbox 2.0.0-RC3 (IOLMaster 700 PDF extraction),
  json-simple, commons-cli, ini4j, log4j 1.2.17, Apache httpclient 4.5.1 (FHIR).
- The jar is **not** a fat jar; at run time deps come via `-cp ./lib/*:./jar`, and
  `lib/` is copied next to the jar in the image.

## Package & run (Docker)

Two-stage `Dockerfile`:

- **Builder** (`eclipse-temurin:8-jdk`): installs Ant 1.10.3, copies the repo,
  runs `compile.sh`, copies `lib/` next to the jar in `dist/`.
- **Runtime** (`ubuntu:noble`): adds the Ondrej Sury PHP PPA and installs
  `php8.3-{cli,mysql,zip}` + `openjdk-8-jre-headless` + `mariadb-client`, `cron`,
  `tini`, etc. Copies the builder's `dist/` to `$APPROOT` (`/jar`) and
  `cli_commands/` to `$CLI_ROOT` (`/cli_commands`). `VOLUME /incoming`.
  `ENTRYPOINT ["/tini","--","/init.sh"]` - **no CMD** (the watcher launch is
  hard-coded as the tail of `init.sh`).

### `init.sh` step-by-step

1. Banner + `java -version`/`php --version`.
2. Set system + PHP timezone from `TZ`.
3. Run `set_php_vars.sh` (builds `99-openeyes.ini` from `PHPI_*` env vars; toggles
   LIVE-mode hardening when `OE_MODE==LIVE`).
4. Read DB password/user from `/run/secrets/*` else env.
5. Ensure DB host in `WAIT_HOSTS`; run `/wait`.
6. Poll `mysql ... USE <db>` up to 200x2s (waits for the OpenEyes web container to
   create the schema on first boot).
7. Write `/env.sh` for cron; `service cron start` unless `ENABLE_CRON=FALSE`.
8. **`cd $CLI_ROOT && php runFileWatcher.php`** (`init.sh:123`) - the watcher.

> `init.sh:71` runs `if ! /wait = 1; then` - the `= 1` is a stray argv token the
> `/wait` binary ignores (it reads `WAIT_*` env). Fragile but functional.

### Secrets

DB and FHIR creds are read from Docker secrets first, env second - in `init.sh`,
`connectDatabase.php`, `DatabaseFunctions.java`, `APIUtils.java`. Secret files:
`/run/secrets/{DATABASE_PASS,DATABASE_USER,DATABASE_NAME,FHIR_API_USER,FHIR_API_PASSWORD}`.

### Image build

`.github/workflows/trigger-image-build.yml` fires a `repository_dispatch`
(`event_type: build-iolmaster_<ref>`) to the private
`toukanlabs/external-action-runner` repo on tag/`release/**` push; the actual
image build runs externally. Locally: `docker build .`.

## Configuration

All env vars are defaulted in the `Dockerfile`. PHP reads via `getenv()`
(`fileWatcherConfig.php`, `connectDatabase.php`); Java via `System.getenv()`
(`DatabaseFunctions.java`, `APIUtils.java`).

| Env var | Default | Effect |
|---|---|---|
| `DATABASE_HOST` | `host.docker.internal` | OpenEyes DB host (PHP uses persistent `p:` conn) |
| `DATABASE_PORT` | `3333` | DB port (note: not the conventional 3306) |
| `DATABASE_NAME` | `openeyes` | schema name |
| `DATABASE_USER` | `openeyes` | DB user (secret overrides) |
| `DATABASE_PASS` | `openeyes` | DB password (secret overrides) |
| `INCOMING_FOLDER` | `/incoming` | watched folder / volume |
| `APPROOT` | `/jar` | where jar+lib live; `cd`-ed before `java` |
| `CLI_ROOT` | `/cli_commands` | PHP scripts dir |
| `ENABLE_CRON` | `TRUE` | `=FALSE` disables the cron queue drain |
| `DOCKER_CONTAINER` | `TRUE` | skips the legacy `dicom-file-watcher` service check |
| `OE_MODE` | `DEV` | `LIVE` = hardened PHP ini (the Java `OE_MODE` check is broken - see gotchas) |
| `TZ` | `Europe/London` | timezone |
| `HOSNUM_REGEX` | `""` -> `-r` | Java regex to extract the hospital number (`EXACT` disables padding) |
| `HOSNUM_PAD` | `""` -> `-p` | `String.format` pad spec for the hospital number |
| `PATIENT_IDENTIFIER_TYPE` | `""` -> `-t` | `patient_identifier_type.unique_row_string` to match |
| `INSTITUTION_IDS` | unset -> `-i` | comma list; scopes auto-created lenses to institutions |
| `FHIR_API_ENABLE` | `""` -> `-a` | truthy/config-file enables the experimental PAS lookup |
| `FHIR_API_{HOST,PORT,USER,PASSWORD}` | `host.docker.internal`/`7070`/`api`/`Password!` | FHIR endpoint (secrets override user/pass) |
| `QUEUE_SLEEP_INTERVAL` | code default 300 (not in Dockerfile) | watcher loop sleep - **buggy when unset, see gotchas** |
| `WAIT_HOSTS` / `WAIT_HOSTS_TIMEOUT` / `WAIT_SLEEP_INTERVAL` | unset / unset / 3 | startup dependency gating |

### INI alternative - `/etc/openeyes/file_watcher.conf`

If this file exists, `fileWatcherConfig.php:4` `parse_ini_file()`s it and it
**wholly replaces** the env-built config - so it must supply `[general]`,
`[biometry]` (`inputFolder`, `importerCommand`) and `patientidentifiertype`.
There is also a legacy Java-side INI path (`-c <file>` not ending in
`hibernate.cfg.xml`), but PHP never passes `-c`.
