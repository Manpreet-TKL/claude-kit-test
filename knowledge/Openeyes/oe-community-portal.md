# OpenEyes and the community (optom) portal: the whole round trip

How a cataract patient's record gets from OpenEyes out to a high-street optometrist and
back again: minting the PUC, printing it, the optometrist's submission, and the hourly
pull that turns that submission into an Examination event.

Contents: [repositories](#1-the-two-portal-repos-are-not-two-systems),
[architecture](#2-the-parts), [configuration and accounts](#3-configuration),
[outbound codes](#4-phase-1---openeyes-mints-the-puc-and-prints-it),
[portal submission](#5-phase-2---the-optometrist-submits),
[import and messages](#6-phase-3---openeyes-pulls-it-back),
[signatures](#7-signatures-wired-up-not-connected),
[troubleshooting](#8-troubleshooting-by-the-point-where-the-flow-stops),
[source map](#9-file-map), [repository guide](#10-repository-guide),
[support history](#11-support-history-and-reusable-lessons).

Version scope (deployed images can differ):

| Repo | Commit | Date |
|---|---|---|
| `openeyes` | `ad23240847` | 2026-08-18 |
| `oe-community-portal` | `1277ed4` | 2024-11-01 |
| `oe-community-portal-api` | `e07c028` | 2018-03-15 |
| `oe-deploy` | `7d5787a41` | 2026-08-05 |

The companion [unique-code reference](../Database/oe-unique-codes.md)
covers allocation locking and duplicate-code repair. Its statement that no consumer checks
the digits applies to the OpenEyes return path: the portal DOES validate them. Pool fixes
described there are version-dependent, not evidence that a particular deployment has them.

## 1. The two portal repos are not two systems

There is one portal. It is split across two checkouts and they overlap:

| Repo | Contains | Status |
|---|---|---|
| `oe-community-portal` | the AngularJS 1.x frontend (`app/`) **and** a full Laravel 5.2 API (`api/`) | newer combined source tree |
| `oe-community-portal-api` | the API only | the older standalone copy, last touched 2018 |

`diff -rq oe-community-portal/api oe-community-portal-api/api` shows only a handful of real
differences. The main integration differences:

1. `IdentifierValidator::generateCheckDigit()` in `oe-community-portal` carries the PHP 7.1
   fix (coerce non-numeric characters to `0`) that keeps it behaviourally identical to
   OpenEyes' `CheckDigitGenerator`. The older repo does not. **If the two check-digit
   implementations drift, identifiers can stop validating.** They are duplicated by hand
   across two codebases with no shared test.
2. `oe-community-portal` routes `oauth/access` through `OAuthController@access`; the older
   repo uses an inline closure. Same behaviour.
3. The combined repo autoloads `app/helpers.php`, whose `read_secret()` reads Docker
   secrets before environment values. Its API/app/database/mail/services configuration
   uses this helper. The standalone repo lacks that helper and those secret-reading changes.
4. Three migrations change column defaults: trust, examination date and signature image.
   Compare them before replacing
   the standalone API with the embedded copy; do not run both copies as separate services
   merely because two repositories exist.

`composer.json` and `bootstrap/app.php` identify Laravel 5.2, with Dingo routing, Fractal
transformers and OAuth2. Some route comments say Lumen; that is stale wording. Repository
history does not establish which image or source revision a running deployment uses.

Everything below cites `oe-community-portal/api`.

## 2. The parts

    OpenEyes (Yii 1.1, PHP)                     Portal (Laravel 5.2 + AngularJS)
    ------------------------                    --------------------------
    unique_codes pool                           MySQL: users, oauth_clients,
    OphTrOperationnote_API::getPatientUniqueCode()      patients, examinations,
    [puc] / [pul] correspondence shortcodes            eyes, readings, signatures
                |                                          ^
                | paper / PDF letter                       | HTTPS, optometrist's browser
                v                                          |
         high-street optometrist  ------------------------>+
                                                           |
    OptomPortalConnection (curl)  <--- OAuth2 password grant, hourly cron
    PortalExamsCommand                          POST /examinations/searches
    ExaminationCreator                          POST /gocs/searches
    automatic_examination_event_log             GET  /identifiers/{uid}
    /oeadmin/eventLog/list                      POST /examinations

The direction of travel is asymmetric, and it is worth fixing in your head early:

- **Outbound patient-code handoff**: no patient registration API call. The PUC crosses
  on paper (or in a PDF letter) via the patient or the post.
- **Portal to OpenEyes**: also no push. OpenEyes pulls, hourly, over OAuth2.

The examination workflow has no portal-to-OpenEyes webhook or HL7 channel. OpenEyes
initiates the authentication and polling requests. An upstream system such as Opera can
submit via the portal API, but its own adapter and mappings are outside these repositories.

## 3. Configuration

### 3.1 OpenEyes side

The connection block is `protected/config/core/common.php`, under `params['portal']`:

| Key | Env var | Notes |
|---|---|---|
| `uri` | `OE_PORTAL_URI` | API base |
| `frontend_url` | `OE_PORTAL_EXTERNAL_URI` | what the `[pul]` shortcode prints into the letter |
| `endpoints.auth` | hardcoded | `/oauth/access` |
| `endpoints.examinations` | hardcoded | `/examinations/searches` |
| `endpoints.signatures` | hardcoded | `/signatures/searches` |
| `credentials.username` | `/run/secrets/OE_PORTAL_USERNAME` or `OE_PORTAL_USERNAME` | the portal user's **email** |
| `credentials.password` | `/run/secrets/OE_PORTAL_PASSWORD` or `OE_PORTAL_PASSWORD` | |
| `credentials.grant_type` | hardcoded | `password` |
| `credentials.client_id` | `/run/secrets/OE_PORTAL_CLIENT_ID` or `OE_PORTAL_CLIENT_ID` | **doubles as the check-digit salt** |
| `credentials.client_secret` | `/run/secrets/OE_PORTAL_CLIENT_SECRET` or `OE_PORTAL_CLIENT_SECRET` | |

Docker secrets win over env vars. Related settings elsewhere:

| Setting | Where | Effect |
|---|---|---|
| `institution_code` | `OE_INSTITUTION_CODE`, default `NEW` | the three-character prefix of every PUC |
| `OE_PORTAL_ENABLED` | env only, read by the cron line | anything but `TRUE` (case-insensitive) and the hourly job prints `disabled` and exits |
| `portal_user` | `SettingMetadata`, default `portal_user` | username of the OE user that owns imported events |
| `disable_auto_import_optoms_from_portal` | Admin Settings metadata and installation/institution setting; importer reads `params` directly | see 3.4 and 6.4 - the sense is inverted |
| `optom_comment_alert` | `SettingInstallation` | comma-separated email list alerted on a new optom comment |
| `curl_proxy` | `SettingMetadata` | applied to every portal call |

`SettingMetadata::getSetting('portal')` returns `Yii::app()->params['portal']` directly,
because a key present in the file config always beats the database. The portal block is
file/env configuration, not an admin screen.

### 3.2 Portal side

Laravel configuration/environment, plus two database rows that have to agree with OpenEyes:

1. a `users` row whose `email` and `password` are the OE `credentials.username` /
   `credentials.password`, and whose **`trust` column equals the OE `institution_code`**;
2. an `oauth_clients` row whose `id` / `secret` are the OE `client_id` / `client_secret`,
   and whose **`name` equals that same trust code**.

The importer authenticates as that portal user. Section 4.2 explains how the trust and
OAuth-client lookup also affect printed-code validation.

### 3.3 Deployment settings and the two endpoint pairs

| Deployment | Browser URL: `OE_PORTAL_EXTERNAL_URI` | API base: `OE_PORTAL_URI` |
|---|---|---|
| Live | `https://oegateway.org.uk` | `https://api.oegateway.org.uk` |
| UAT | `https://uat.oegateway.org.uk` | `https://api.uat.oegateway.org.uk` |

These are the public Live and UAT endpoint pairs.
`OE_PORTAL_ENABLED=true` enables the scheduled pull in either environment. The other four
values (`OE_PORTAL_USERNAME`, `OE_PORTAL_PASSWORD`, `OE_PORTAL_CLIENT_ID`,
`OE_PORTAL_CLIENT_SECRET`) must be the credentials issued by that environment's portal.
Blank values are placeholders and are not a working account. Keep browser URL, API URL,
credentials, trust code and letter macros aligned to the same environment. A test patient
does not make a production portal safe for UAT: bare codes can overlap between databases.

The oe-deploy chain is:

1. The deployment's `.env` selects services and modules. Add `optom` to the existing
   space-separated `MODS` value; do not replace the other modules. Merely adding the
   `OE_PORTAL_*` values to `.env` does not pass them into containers.
2. `build.sh` adds `templates/modules/optom.yml` to the Compose inputs and renders the
   combined configuration. That module supplies the five non-password environment values
   to both `web` and `oe-manager`: client ID, enable flag, browser URL, username and API URL.
3. The module mounts `secrets/OE_PORTAL_PASSWORD` and `secrets/OE_PORTAL_CLIENT_SECRET`
   at `/run/secrets/OE_PORTAL_PASSWORD` and `/run/secrets/OE_PORTAL_CLIENT_SECRET`.
   Use the values issued by the portal, not independently generated replacement secrets.
4. OpenEyes `protected/config/core/common.php` reads those values into `params['portal']`.
   It also supports secret files for username and client ID, although the stock `optom`
   Compose module supplies those two as environment values. A custom secret mount must
   actually exist before that alternative takes effect.
5. The manager's cron invokes `portalexams`. `ENABLE_CRON`, `OE_PORTAL_ENABLED` and the
   installed crontab all matter. Refresh generated Compose/container configuration using
   the deployment's normal change procedure; an edited host `.env` does not alter a
   running container's environment.

The template includes portal keys even when `MODS` does not include `optom`. Its sample
URLs are development defaults, not the endpoint pair to assume for a deployment.
`OE_INSTITUTION_CODE` is passed by `templates/web.yml`; OpenEyes defaults it to `NEW`.
Use the agreed three-character trust code, not an arbitrary hospital name or database ID.

`CRON_PORTALEXAMS_SCH` is supported by the application cron template, but is absent from
the inspected oe-deploy environment pass-through. Adding it only to `.env` therefore does
not change the schedule: arrange the manager environment/approved Compose override too.
By contrast, `CRON_GENERTAEUNIQUECODES_SCH` is passed through by `templates/web.yml`.
The `|| echo disabled` in the portal cron also runs when the import command fails, so
that final word alone does not prove the enable flag was false.

### 3.4 OpenEyes configuration alternatives and precedence

| Mechanism | Scope and precedence | Appropriate use |
|---|---|---|
| Docker secrets and environment | Core `common.php` prefers an existing secret file, then environment, then its fallback | Normal oe-deploy configuration; keep passwords and client secrets in deployment secret files |
| `protected/config/local/common.php` | Merged after core and module config; applies to web and console | Deployment-specific `params['portal']`, endpoint paths or `institution_code` overrides |
| `protected/config/local/main.php` / `local/console.php` | Environment-specific local config overrides common values | Deliberate web-only or command-only differences; check both when letters validate differently from imports |
| Admin Settings | Database-backed settings such as the Portal contact-import toggle | Application behavior, not the portal URL/OAuth connection block |

`OEConfig::getMergedConfig()` merges core, modules, then local config, using `common.php`
and the environment file at each level, plus core/local `admin.php` when present. Therefore
a local file can override the environment-derived portal block. It also caches the merged
configuration in APCu where available; account for the web process cache after changes.
Do not edit the core defaults to configure an individual deployment.

Non-secret endpoint overrides can be expressed under the existing local configuration's
`params` key, for example `portal.endpoints.examinations = '/examinations/searches'`.
The other paths are `/oauth/access` and `/signatures/searches`; `grant_type` is `password`.
There are no `OE_PORTAL_*` variables for these paths in core config. Do not add credentials
to a tracked PHP file. An empty secret file still takes precedence over an environment
value, because core tests whether the file exists, not whether its contents are non-empty.
The client's required-key check rejects missing/null keys, not empty strings, so passing
that check does not prove the credentials are usable.

Admin > Settings > Portal exposes **Disable Auto Import Of Optometrists From Portal**,
default **On**, with institution overrides in the settings model. **Off** permits contact
creation; it does not enable/disable examination polling. There is a source-level caveat:
`PortalExamsCommand` reads `Yii::app()->params['disable_auto_import_optoms_from_portal']`
directly and compares it strictly with `'off'`, rather than calling `SettingMetadata`.
Verify the effective console value before assuming a database toggle controls this branch.

`portal_user` selects the OpenEyes user by username, default `portal_user`.
`m160525_092545_user.php` originally creates that internal account. It is not the portal
login email. `optom_comment_alert` is read directly from `setting_installation` when
sending email, not through the usual institution-aware settings resolver. A value in
`params` alone is not enough for that email path, even though the creator's constructor
prints the param. `curl_proxy` is obtained through `SettingMetadata::getSetting()`.

### 3.5 Creating a portal trust account

`oe-deploy/scripts/optom_portal_new_client.sh` runs against the deployment HOSTING the
portal, not every OpenEyes deployment consuming it. The corresponding script also exists
in `oed`. Its identity model is:

| Identity | Created or configured where | Purpose |
|---|---|---|
| Portal `users` row | Account script: name, email, bcrypt password, `trust` | OAuth resource owner and examination routing |
| Portal `oauth_clients` row | Account script: random `id`, random `secret`, `name = trust` | OAuth client authentication; ID is also the PUC salt |
| OpenEyes `user` row | OpenEyes migration/admin user management | Audit owner and sender of imported events/messages |
| Optometrist | Anonymous form's GOC/name/address; optional OE contact import | Clinical submission provenance, not an OAuth account |

The script prompts for trust name, email and trust code, sources `.oedeploy`, finds the
project's `optom-portal` container, reads `DATABASE_HOST`/`PORTAL_DB_NAME` from `.env`, and
reads the database root password from the deployment's secrets directory. It obtains a
password from an external password service, hashes it with `php api/artisan tinker` in
the portal container, generates OAuth ID/secret with OpenSSL, then inserts the two rows.
It refuses a user already matching trust, email OR name. Finally it appends a password
manager CSV containing the issued credentials to the filename configured in `.oedeploy`.
That output is sensitive and belongs outside the kit and source repositories.

After provisioning, map email/password to the OE username/password, OAuth id/secret to
the OE client ID/secret, and trust code to `OE_INSTITUTION_CODE`. Configure the browser/API
URL pair and letters separately. The script does not write the consuming OpenEyes `.env`,
its secret files, its local user, or its correspondence macros.

Operational limits of the existing script:

1. Although it derives its deployment root, its `.env` read is relative to the current
   directory. A human invoking it must first enter the portal deployment directory.
2. It runs the MySQL/MariaDB CLI, curl and OpenSSL on the host; only bcrypt runs in the
   container. It therefore does not meet a container-only execution policy as written.
   Do not install host tools or treat the script as a container-only recipe; adapt the
   same provisioning steps to an approved container workflow before use under that policy.
3. Its `docker ps -a` lookup can match a stopped container despite saying "RUNNING".
   It also relies on the expected project/container naming convention and the second
   line of tinker output containing the hash.
4. The two inserts are not transactional, inputs are interpolated into SQL, and the
   duplicate check covers `users`, not a pre-existing orphan `oauth_clients` row. A failed
   run needs inspection of both tables before retrying. It is not a credential-rotation tool.

## 4. Phase 1 - OpenEyes mints the PUC and prints it

### 4.1 Allocation

The code is an event reference, not an OpenEyes patient number. `GenerateUniqueCodeCommand`
pre-generates six characters from `A-Z` and `2-9` into `unique_codes`. A free code is active
and has no row in `unique_codes_mapping`. Its positional argument is the target number
of FREE codes, default 1500 in this source, not a number added unconditionally each run.

Saving a cataract operation note (`Element_OphTrOperationnote_Cataract`) or a CVI
(`Element_OphCoCvi_EventInfo`) calls `BaseEventTypeController::updateUniqueCode()` from
both create and update hooks. If the event has no mapping, `BaseController::createNewUniqueCodeMapping()`
locks the mapping/pool tables, selects a free code and stores its ID against the event ID.
An empty pool returns an unsaved mapping without preventing the event save. Generating
more pool rows alone does not repair those existing events. A qualifying event re-save
can allocate a missing code; any bulk backfill must match the deployed version.

`unique_codes_mapping` has unique indexes on `event_id` and `unique_code_id`. Those constrain
row IDs, not the text in `unique_codes.code`. The baseline source here has no unique index
on that text and `eventFromUniqueCode()` takes one matching row; do not assume it refuses
ambiguous codes. Read the companion reference before repairing duplicates or mappings.

The application cron defaults to weekly at `55 5 * * 0`, using the intentionally misspelled
`CRON_GENERTAEUNIQUECODES_SCH`. The oe-deploy `.env` template instead supplies a daily
`55 5 * * *` override. Check the actual manager environment and crontab. Capacity depends
on both the free-code target and consumption between runs. Existing generated letters
remain static after a mapping repair; the letter must be regenerated to show the PUC.

### 4.2 The printed form

`OphTrOperationnote_API::getPatientUniqueCode($patient)` builds what the optometrist
actually types:

    <institution_code><cd1>-<CODE>-<cd2>

- `cd1 = CheckDigitGenerator(institution_code . CODE, salt)`
- `cd2 = CheckDigitGenerator(CODE . patient->dob, salt)` with `dob` as `Y-m-d`
- `salt = params['portal']['credentials']['client_id']`

The algorithm (`protected/components/CheckDigitGenerator.php`) reverses the salted string,
maps `A-Z` to `1-26`, coerces anything still non-numeric to `0`, doubles alternate
positions, sums the digits, and returns `($sum * 9) % 10`.

The portal reimplements this in `App\DataAccess\Validators\IdentifierValidator`, and it
derives its two inputs differently:

| Input | OpenEyes | Portal |
|---|---|---|
| prefix | `params['institution_code']` | `substr($identifier, 0, 3)`, looked up as `users.trust` |
| salt | `params['portal']['credentials']['client_id']` | `oauth_clients.id` where `name = users.trust` |
| date | `$patient->dob` | the date the optometrist typed, formatted `Y-m-d` |

The intended setup uses the same client ID on both sides. Multiple trusts are supported;
the problem is a missing, mismatched or ambiguous `oauth_clients.name = users.trust`
lookup. A changed client ID can invalidate already printed PUCs because it is also the
salt. Keep the salt stable when rotating only the password or client secret. Check digits
are a checksum, not a cryptographic identity proof; collisions remain possible.

The validator regenerates the whole string and compares it exactly. Prefix, case, spaces,
hyphens and entered DOB matter. It does not ask OpenEyes whether the code exists or fetch
demographics from OpenEyes. The portal learns the PUC and DOB at submission time.

The PUC checksum incorporates DOB while the middle code identifies the source event.
Different DOBs can produce the same decimal check digit. Neither the printed prefix nor
the DOB protects the return lookup against code collisions across OpenEyes databases.

### 4.3 Getting it onto paper

Two correspondence shortcodes, both rows in `patient_shortcode`:

| Code | Method | Description |
|---|---|---|
| `[puc]` | `OphTrOperationnote_API::getPatientUniqueCode` | Patient Unique Code for portal |
| `[pul]` | `OphCoCorrespondence_API::getPortalUrl` | Portal Url (returns `params['portal']['frontend_url']`) |

`OphCoCorrespondence_Substitution::replace()` matches
`/\[(?<shortcode>[a-z]{3})(?::(?<parameters>...))?\]/is` and delegates to
`PatientShortcode::replaceText()`. An uppercase first letter in the shortcode (`[Puc]`)
upper-cases the first letter of the substitution.

`getPatientUniqueCode()` resolves the **latest** operation note for the patient
(`getLatestEventUniqueCode` -> `UniqueCodes::codeForEventId`). If that event never got a
pool code, the method returns an empty string and the letter goes out with a blank where
the identifier should be. There is no warning.

The discharge letter to the optometrist carries the URL and the identifier, and that is the
entire outbound half of the integration.

## 5. Phase 2 - the optometrist submits

Frontend: AngularJS 1.x (`opTomApp`), form route (`/`) and success route (`/success`),
controller `OpTomFormCtrl`, Restangular over ngMaterial. The API base URL per environment
comes from `environments.json`. There is no login: the form is anonymous, which is why the
identifier is the only thing standing between a stranger and a write.

Three unauthenticated API calls back the form.

### 5.1 `GET /identifiers/{uid}?date=<ISO8601 dob>`

`app/scripts/directives/checkIdentifier.js` watches the identifier field and the date of
birth field together and fires as soon as both are non-empty (DOB parsed as `DD/MM/YYYY`
with moment). `IdentifierController@view` regenerates the identifier from the code plus the
submitted date and returns `{"valid": true|false}`; a missing or unparseable date, or an
unknown trust prefix, throws `InvalidIdentifierException` and comes back as a 404.

Two quirks in `IdentifierValidator`:

- `if (!count($exploded) === 3)` is a precedence bug. `!count(...)` is a boolean, never
  `=== 3`, so the malformed-identifier guard never fires and a one-segment identifier falls
  through to `$exploded[1]`.
- the directive calls `$setValidity('invalidIdentifier', false)` synchronously after issuing
  the request, and only the success branch sets it back to `true`. A `valid: false` response
  leaves the field invalid, which is the right outcome by accident.

### 5.2 `POST /gocs/searches`

`GocController@search` -> `App\DataAccess\Scrapers\Goc`, which **screen-scrapes** the GOC's
public online register with Goutte, submits the registration number into
the register form, and parses the result list for the optometrist's name and practice
addresses. Results are `Cache::rememberForever($gocNumber, ...)`.

The implementation depends on the external register's markup: a redesign can break
optometrist lookup, and because the cache is keyed by GOC number
and never expires, a bad scrape is sticky until the cache is cleared. The frontend also
mirrors results into `$localStorage.gocKeys` so a repeat visitor keeps their own details.

### 5.3 `POST /examinations`

The JSON submission has these structural fields (no clinical example values):

| Field | Contract |
|---|---|
| `examination_date` | ISO8601 examination date |
| `op_tom` | GOC number, name and practice address |
| `patient.unique_identifier`, `patient.dob` | Full PUC and entered DOB |
| `patient.ready_for_second_eye`, `patient.comments` | Readiness and free text |
| `patient.eyes` | Selected Left/Right entries |
| `eyes[].reading` | Distance/near VA arrays, refraction and IOP object |
| `eyes[].complications` | Complication label objects |

`CreateExaminationRequest` validates it. The rule that matters is

    'patient.unique_identifier' => 'Required|Regex:/[\d\w]{4}-[\d\w]{6}-[\d\w]{1}/|PatientIdentifier:patient.dob'

where `PatientIdentifier` is the custom rule registered by `ExaminationValidationProvider`
and runs the same `IdentifierValidator` server-side. The client-side check in 5.1 is
convenience, not the gate.

Bounds enforced here and nowhere else: sphere -45..45, cylinder -25..25, axis 0..180, IOP
1..80 mmHg, distance VA measure in `ETDRS Letters | Snellen Metre | logMAR | logMAR
single-letter`, near VA measure in `Jaeger (Approx) | N Scale | Reduced LogMAR | Reduced
Snellen`. The form defaults to `Snellen Metre` and `Reduced Snellen`, splices out any eye
the optometrist disabled, and drops `ready_for_second_eye` when it is the string `'null'`.

`ExaminationController@create` then:

1. `Patient::firstOrNew(['unique_identifier' => ...])` - **the identifier is the portal's
   patient key**. A second submission for the same PUC updates the same portal patient row,
   after `$patient->eyes()->detach()` discards the previous eyes.
2. saves the optometrist, eyes, readings and complications through the transformers'
   `reverse()` methods;
3. `Examination::firstOrNew(['op_tom_id' => ..., 'patient_id' => ...])`, sets `user_id` from
   `User::where('trust', substr($unique_identifier, 0, 3))`, `touch()`es it and saves.

That `user_id` is the routing: searches return records owned by the authenticated portal
user. Any OpenEyes instance using that account can pull them. The `touch()` makes the row
visible to the next pull, because
the pull is keyed on `updated_at`.

There is no transaction around any of it, and the method returns no body. The controller
redirects the browser to `/success`; any failure raises an `$mdDialog` reading "Adding the
Examination failed, please try again", with no detail.

## 6. Phase 3 - OpenEyes pulls it back

### 6.1 The cron

`protected/scripts/.cron/portalexams`:

    ${CRON_PORTALEXAMS_SCH:-0 * * * *}  bash $WROOT/protected/scripts/cronrunner.sh '[ "${OE_PORTAL_ENABLED^^}" = "TRUE" ] && bash $WROOT/protected/scripts/portalexams.sh || echo disabled'

Hourly on the hour by default. `portalexams.sh` is a thin wrapper around
`php $WROOT/protected/yiic portalexams`. A manual import writes examinations, logs and
possibly messages/email; it bypasses the cron's enabled check. When a replay is intended,
run from the OpenEyes deployment using the manager's configuration:

```bash
docker compose exec -T oe-manager php /var/www/openeyes/protected/yiic portalexams
```

### 6.2 Authenticating

`new OptomPortalConnection()` (`protected/components/OptomPortalConnection.php`) does three
things in its constructor: reads `curl_proxy`, validates the config block, and immediately
fetches a token. Every instantiation is a fresh token; tokens are not cached and the TTL is
3600s (`config/oauth2.php`).

    POST {uri}/oauth/access
    Accept: application/vnd.OpenEyesPortal.v1+json
    body: username, password, grant_type=password, client_id, client_secret

The portal's `PasswordGrantVerifier::verify()` authenticates `email` + `password` against
`users` and returns the user id as the resource owner. The response `access_token` is
appended to the header list as `Authorization: Bearer ...`. `password` is the only grant
configured.

Things to know about the transport:

- `CURLOPT_SSL_VERIFYPEER` is **false** on every call.
- `CURLOPT_FAILONERROR` is true, so any HTTP 4xx/5xx surfaces as a curl error and becomes an
  `Exception` with the response body already discarded. A wrong password looks much like a
  DNS failure.
- params go to `CURLOPT_POSTFIELDS` as a PHP array, so curl sends `multipart/form-data`,
  not `application/x-www-form-urlencoded`.
- `$required_config_keys` validates `endpoints.auth` and `endpoints.signatures` but **not**
  `endpoints.examinations`, the one endpoint the command actually uses.

### 6.3 Fetching

`PortalExamsCommand::examinationSearch()` finds the most recent
`automatic_examination_event_log` row that is not `Import Failure` or `Dismissed Event`,
pulls `updated_at` out of its stored `examination_data` JSON, and sends that as
`start_date`:

    POST {uri}/examinations/searches      start_date=<ISO8601>

`ExaminationController@search` filters `Examination::where('user_id', resourceOwnerId)` by
`updated_at >= start_date`, ordered ascending. The API also accepts `end_date`, but the OE
command sends no end bound, page size or separate pagination cursor. The
comparison is inclusive, so the last successfully imported examination is re-fetched on
every run - which is exactly what the duplicate check in 6.4 exists to absorb. On a first
ever run there is no log row and no `start_date`, so the portal returns everything it holds
for that trust.

The response is the Fractal-transformed shape, which is **not** the shape that was posted:

| Posted | Returned |
|---|---|
| `reading` is an object | `reading` is a **collection**, hence `reading[0]` everywhere in OE |
| `visual_acuities` | `visual_acuity` |
| `near_visual_acuities` | `near_visual_acuity` |

`OptomPortalConnection::getExaminations()` hands the raw body to
`AutomatedExaminationDTO::fromOptomPortalResponse()`, which runs every value through
`CHtmlPurifier` - every value except `patient.eyes.*.complications`, which is explicitly
skipped. The DTO exists purely to treat the portal as untrusted input; it does no schema
validation.

### 6.4 Importing

Per examination, `PortalExamsCommand::run()`:

1. `explode('-', $unique_identifier)[1]` - the **middle segment only**. The check digits are
   never verified on this side. See `oe-unique-codes.md` section 1.1.
2. `UniqueCodes::eventFromUniqueCode($code)` to find the operation note event. Null means
   status **Unfound Event**: the payload is parked in `automatic_examination_event_log` with
   `event_id = 0`, keyed on `unique_code`, and the loop continues.
3. `UniqueCodes::examinationEventCheckFromUniqueCode($code)` counts prior non-failed log
   rows for that code and returns the latest.
4. Optometrist contact saving, **if** `disable_auto_import_optoms_from_portal === 'off'`.
   The sense is inverted: `off` means the disabling is off, so the contact **is** saved. It
   matches on `national_code` (the GOC number) plus address line 1, creates a `Contact` with
   the `Optometrist` label if there is no match, adds a Correspondence `Address`, and adds a
   `PatientContactAssignment` only when the patient has no optometrist already.
5. If the count is 0, create the event inside a transaction via `ExaminationCreator::save()`
   -> status **Success Event**. Any exception rolls back and writes status **Import
   Failure** with the payload.
6. If the count is not 0 and the payload differs from the stored JSON, write a log row with
   status **Duplicate Event** and create nothing. Byte-identical payloads are silently
   dropped, which is how the inclusive `start_date` is absorbed.

Statuses live in `import_status`. This path uses `Success Event`, `Import Failure`,
`Duplicate Event`, `Unfound Event` and `Dismissed Event`.

The command also needs a separate OE user: `User::portalUser()` looks up the username from
`SettingMetadata::getSetting('portal_user')` (default `portal_user`) and the command throws
`No User found for import` if it is missing.

### 6.5 What the Examination event ends up containing

`OEModule\OphCiExamination\components\ExaminationCreator::save()` builds an `Event` in the
`automatic` scenario with `is_automated = 1` and `automated_source = json_encode(op_tom)`,
owned by the portal user, dated `examination_date`, on the episode of the operation note and
with the op note's `institution_id` / `site_id` (it throws if there is no op note to copy
them from). Elements created:

| Element | From |
|---|---|
| `Element_OphCiExamination_Refraction` | sphere / cylinder / axis per eye, type `Optometrist` |
| `Element_OphCiExamination_VisualAcuity` | `reading[0].visual_acuity` |
| `Element_OphCiExamination_NearVisualAcuity` | `reading[0].near_visual_acuity` |
| `Element_OphCiExamination_IntraocularPressure` | `reading[0].iop`, matched to an instrument |
| `Element_OphCiExamination_PostOpComplications` | `complications`, tied back to the op note |
| `Element_OphCiExamination_OptomComments` | `comments` and `ready_for_second_eye` |

Unit names are translated on the way in, because the portal's vocabulary is not OpenEyes':

| Portal | OpenEyes |
|---|---|
| `logMAR` | `logMAR 1dp` |
| `logMAR single-letter` | `logMAR 2dp` |
| `N Scale` | `N-Scale @40cm` |

`addComplication()` matches lowercased, HTML-decoded names. In this source an unmatched
named complication is logged and skipped; it need not fail the whole import. Successful
import therefore does not prove every submitted complication was represented. Older
versions had failures around purified labels; inspect both DTO and creator behavior.

### 6.6 How the message is created in OpenEyes

`ExaminationCreator::save()` calls `createMessage()` after creating the comments and before
finishing the measurement imports. The portal itself does not write to the OE messaging
API. Message creation is a local consequence of importing the examination.

1. `OphCoMessaging` must be enabled in the application module configuration. The creator
   resolves `Element_OphTrOperationnote_Surgeon` for the supplied operation-note event ID
   and uses its `surgeon` relation as recipient. There is no active fallback to the
   episode consultant, no generic team-inbox destination and no automatic second-eye team
   rule in this method. Missing module, supplied operation-note ID or surgeon skips the
   message and email branch.
2. The sender is the OpenEyes import user selected by `portal_user`. The message type is
   the configured **General** row. `MessageCreator` receives the episode plus the
   operation note's institution and site.
3. `OphCoMessaging/components/MessageCreator.php::save()` creates a separate automated
   `Event` of type `OphCoMessaging`, on that episode, dated today (the import date).
   Audit user is the sender; `automated_source` links `event` to the NEW Examination ID.
4. It creates `Element_OphCoMessaging_Message`, assigns the sender's personal mailbox
   when present, and creates an `OphCoMessaging_Message_Recipient` for the surgeon's
   personal mailbox with `primary_recipient = true`. Check the recipient mailbox as
   well as the surgeon user when the message save fails.
5. `views/templates/optom.php` renders the patient identifier appropriate to the event's
   institution/site, optometrist name and GOC code, practice address, readiness answer
   and comments. Empty comments become **No Comments**. Strict boolean `true`/`false`
   become **Yes**/**No**; other values become **Not Applicable**. A blank comment or
   **No** answer does not suppress creation.
6. If `setting_installation.optom_comment_alert` contains a comma-separated list,
   `emailAlert()` also sends the rendered text with subject **New Optom Comment** using
   OpenEyes `Mailer` and its configured sender. This does not redirect the in-app message.
   `emailAlert()` catches exceptions and returns false; its caller does not inspect the
   return, so a successful import/message does not establish successful email delivery.

The normal command wraps creator work and its success log in a database transaction.
Message-save failures can therefore make the entire examination an **Import Failure**.
Email is sent within creator execution before the final transaction commit, so it is not
an after-commit delivery guarantee; later element failures can still roll back the DB work.

### 6.7 The admin screen and invoice workflow

`/oeadmin/eventLog/list` (`protected/controllers/oeadmin/EventLogController.php`) lists
`automatic_examination_event_log`, searchable by event id, unique code or examination date
and filterable by status. Editing a row:

| Status | What the buttons do |
|---|---|
| `Duplicate Event` | accept the new one: re-runs `ExaminationCreator`, soft-deletes the old event and repoints the log row; or dismiss it, setting `Dismissed Event` |
| `Unfound Event` | takes a `patient_id`, resolves that patient's cataract episode and creates the examination there; HTTP 400 if the patient has no cataract episode |
| everything else | read-only |

One inconsistency worth knowing: the cron path records refraction type `Optometrist`, both
admin re-import paths record `Ophthalmologist`. Same payload, different provenance, depending
on which route created it.

The Unfound assignment path passes no operation-note ID. `ExaminationCreator` falls back
to the patient's latest operation note to copy institution/site, but does not pass that
fallback's ID into `createMessage()`. Consequently manual assignment can succeed without
creating a surgeon message. It can still fail if no operation note exists. Accepting a
duplicate passes the resolved operation-note ID and can create a fresh message; this
controller does not remove a previously created message just because it deletes the old
Examination. Assigning an unfound row also does not repair `unique_codes_mapping`.

Use the admin screen only after establishing the intended patient and operation. A code
ambiguity should not be resolved by guessing a patient. The source lookup is on bare code
and this screen is not a second check of the portal DOB.

The separate **Optom Invoice Manager**, route `/OphCiExamination/optomFeedback/list`,
requires the **Optom co-ordinator** role. Its heading is **Optometrist Feedback Manager**.
It shows successful imports with non-deleted examinations and allows per-row invoice
status/comments and version history. It is not a failed-import queue, and changing an
invoice status does not resend data or edit the clinical examination. Status definitions
are managed in Admin > Examination > Optom Invoice Statuses. The Optometrist Comments
element is read-only in the event UI; imported values are not corrected by typing there.

## 7. Signatures: wired up, not connected

The portal has a complete signature feature. `POST /signatures` takes
`{unique_identifier, image}` (base64, validated by the `Base64Image` rule registered in
`SignatureValidationProvider`) unauthenticated, resolves the trust from the identifier prefix
and stores the row. The authenticated side serves `POST /signatures/searches` and
`GET /signatures/{uid}`. OpenEyes has the matching client:
`OptomPortalConnection::signatureSearch()`, which hits `searches` for a date range or swaps
`searches` for an id to fetch one.

**Nothing in OpenEyes calls it.** `signatureSearch()` has no callers. The one place that
would read a portal signature is `OphCoCvi_Manager::populateCviCertificate()`, which calls
`$signature_element->loadSignatureFromPortal()` - a method that does not exist in the tree,
on an element returned by `getConsentSignatureElementForEvent()`, which also does not exist.
The only caller of `populateCviCertificate()` passes `$ignore_portal = true` and takes the
other branch. The whole path is dead.

Do not confuse it with the live signature inbound path:
`protected/modules/Api/controllers/v1/SignController.php` (`actionAdd`) accepts a scanned
CVI/consent signature, resolves the event with `UniqueCodes::eventFromUniqueCode()` and logs
to `signature_import_log`. That takes the **bare six-character code**, not a PUC, is a
different client, and has nothing to do with the portal.

## 8. Troubleshooting by the point where the flow stops

1. **Blank identifier in the letter.** The patient's latest operation note never got a pool
   code, so `getPatientUniqueCode()` returned `''`. Check `unique_codes_mapping` for the
   event, then the pool.
2. **"The Identifier or Date of Birth is invalid".** Check the complete printed PUC,
   formatting and entered DOB, then the environment pair and the trust/client-ID coupling
   in 4.2. Check identifier API status/response and the deployed validator version before
   assuming the person entered the date incorrectly. A server error can present the same
   blocked form as a checksum mismatch.
3. **Unfound Event in the log.** The identifier validated (so salt and prefix are right) but
   no source event resolves. Check mappings, deletion and environment routing. A duplicated
   code can instead resolve to a WRONG event without producing this status. Establish the
   source event before considering the admin assignment workflow.
4. **Nothing imports at all.** In order: `OE_PORTAL_ENABLED` is not `TRUE`; the cron is not
   installed; the token call fails and `CURLOPT_FAILONERROR` has hidden why; the portal
   `users` row's `trust` does not match `institution_code`, so the trust's examinations were
   filed under a different `user_id` and this OpenEyes cannot see them.
5. **An older submission is never retried.** `latestSuccessfulEvent()` orders local logs
   by `created_date DESC, id DESC`, excluding only **Import Failure** and **Dismissed
   Event**. Its name is misleading: Duplicate and Unfound rows can advance the cursor.
   `start_date` then uses the portal `updated_at` from that row's stored payload. A failed
   item followed by a later eligible row can be left behind. A normal rerun will not
   necessarily replay it; inspect the failed payload and date window before repair.
6. **Optometrist lookup returns nothing.** The GOC register changed its markup, or a bad
   result is stuck in the forever-cache.
7. **Comments arrive but nobody is told.** Check the exact source op note's surgeon,
   enabled messaging module, import route and recipient mailbox, then the local Message
   event/recipient rows. Missing email alone needs the installation alert setting and
   mail delivery checked. Also check whether site-specific jobs subsequently hide messages.

Additional diagnostic checks:

| Symptom | Evidence to inspect |
|---|---|
| Portal says success but no OE event | Success means the portal HTTP submission completed. Check OE polling, OAuth resource owner, cursor, automatic event log and creator exception separately. |
| All imports fail after an upgrade | Actual manager config and crontab, `portal_user`, import log/command output, lookup data and deployed creator/DTO versions. An upgrade date alone does not identify the cause. |
| Import fails on VA or IOP | The portal vocabulary and OE unit/method/instrument rows must match the creator lookups, including `logMAR 1dp`, `logMAR 2dp` and `N-Scale @40cm`. Check reading values too. |
| Import fails only on a complication | Compare the exact submitted complication text with OE post-op complication configuration. The DTO preserves `patient.eyes.*.complications` to avoid HTML purification changing names such as `raised IOP (>21 mmHg)`. |
| Changed submission becomes Duplicate Event | Reusing a PUC can update the portal row, while OE refuses to overwrite an existing imported event automatically. Inspect/accept or dismiss via the event log. |
| Browser contacts the wrong API after a config change | API URL is compiled into frontend JavaScript from `environments.json`; Laravel `APP_ENV` alone cannot switch it. Inspect the served bundle and browser request URL. |
| Token works but searches are empty | Filter is `examinations.user_id = OAuth resource owner`. Check the actual portal user, trust routing and requested time window, not only the OAuth client name. |
| Certificate warning or HTTP error | Inspect TLS/reverse proxy, frontend port 80 versus API port 9000, response status and portal logs. Do not infer API availability from the form rendering. |

Read-only database checks below return counts/status rather than clinical payloads. Run
inside the approved database client container against the intended OpenEyes database.
Large pool/grouping scans may be expensive; scope investigations appropriately.

```sql
SELECT COUNT(*) AS free_codes FROM unique_codes uc LEFT JOIN unique_codes_mapping m ON m.unique_code_id=uc.id WHERE uc.active=1 AND m.id IS NULL;
SELECT code, COUNT(*) AS copies FROM unique_codes GROUP BY code HAVING COUNT(*)>1;
SELECT s.status_value, COUNT(*) AS rows_held FROM automatic_examination_event_log l JOIN import_status s ON s.id=l.import_success GROUP BY s.status_value;
SELECT id, username FROM user WHERE username='portal_user';
```

For one case, trace source operation-note ID -> mapping/code -> import log -> Examination
event -> Message event and recipient. Inspect full identifiers, payloads, DOBs and command
logs only within the protected investigation location; they can contain clinical data.
Never re-point an issued mapping to another event as a shortcut.

## 9. File map

OpenEyes:

| Path | Role |
|---|---|
| `protected/config/core/common.php`, `protected/config/OEConfig.php` | portal config and merge/cache rules |
| `protected/components/OptomPortalConnection.php` | the whole HTTP client |
| `protected/components/CheckDigitGenerator.php` | check digits |
| `protected/modules/OphTrOperationnote/components/OphTrOperationnote_API.php` | `getPatientUniqueCode`, behind `[puc]` |
| `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php` | `getPortalUrl`, behind `[pul]` |
| `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_Substitution.php` | shortcode expansion |
| `protected/controllers/BaseEventTypeController.php` | which elements trigger code allocation |
| `protected/modules/OphCiExamination/commands/PortalExamsCommand.php` | the import command |
| `protected/modules/OphCiExamination/components/ExaminationCreator.php` | payload to Examination event |
| `protected/modules/OphCoMessaging/components/MessageCreator.php`, `protected/modules/OphCoMessaging/views/templates/optom.php` | local message, mailbox recipient and email |
| `protected/modules/OphCiExamination/dtos/AutomatedExaminationDTO.php` | purification of the response |
| `protected/modules/OphCiExamination/models/AutomaticExaminationEventLog.php` | the log and `latestSuccessfulEvent()` |
| `protected/controllers/oeadmin/EventLogController.php` | `/oeadmin/eventLog/list` |
| `protected/models/UniqueCodes.php` | `eventFromUniqueCode`, `examinationEventCheckFromUniqueCode` |
| `protected/models/User.php` | `portalUser()` |
| `protected/scripts/.cron/portalexams`, `protected/scripts/portalexams.sh` | scheduling |

Portal (`oe-community-portal`):

| Path | Role |
|---|---|
| `api/app/Http/routes.php` | every endpoint, split by the `api.auth` middleware |
| `api/app/Http/Controllers/IdentifierController.php` | PUC validation endpoint |
| `api/app/DataAccess/Validators/IdentifierValidator.php` | the portal's check-digit implementation |
| `api/app/Http/Requests/CreateExaminationRequest.php` | clinical bounds and the `PatientIdentifier` rule |
| `api/app/Http/Controllers/ExaminationController.php` | create, list, search |
| `api/app/DataAccess/Transformers/` | both directions of the payload shape |
| `api/app/DataAccess/Scrapers/Goc.php` | the GOC register scrape |
| `api/app/PasswordGrantVerifier.php`, `api/config/oauth2.php` | OAuth2 password grant |
| `api/config/api.php` | the `vnd.OpenEyesPortal.v1+json` media type and `dateFormat` |
| `app/scripts/controllers/form.js` | the submission |
| `app/scripts/directives/checkIdentifier.js` | live identifier validation |
| `app/scripts/directives/goclookup.js` | optometrist lookup |
| `environments.json` | frontend to API base URL, per environment |

## 10. Repository guide

### Frontend and image layout

| Path in `oe-community-portal` | Responsibility |
|---|---|
| `app/scripts/app.js` | Angular modules, form/success routes and Restangular API base |
| `app/scripts/controllers/form.js` | Form defaults, enabled eyes, readiness coercion and examination submission |
| `app/views/form.html`, `app/templates/` | Form and reusable fields, including GOC lookup and identifier validation |
| `app/scripts/directives/` | Identifier/DOB check, GOC lookup, refraction and visual-acuity widgets |
| `environments.json` | Frontend API URL for `local`, `uat`, `prod` builds |
| `gulpfile.js` | Generates `app/scripts/environments.js`, compiles styles, bundles assets into `dist/` |
| `bower.json`, `package.json` | Browser dependencies and Node/Gulp build dependencies |
| `Dockerfile.local`, `Dockerfile.uat`, `Dockerfile.prod` | Node 20 build stage, PHP 7.3/Apache API runtime by default |
| `000-default.conf` | Frontend on port 80; API document root `api/public` on port 9000 |
| `docker-compose.yml` | Example portal container with externally supplied database and secrets; not a complete database-backed deployment |
| `Vagrantfile`, `puppet/` | Historical development provisioning; distinct from the Docker deployment path |
| `test/spec/`, `karma.conf.js` | Frontend controller/directive tests and Karma browser setup |

The root README still describes Grunt. The current scripts are Gulp:
`npm run build-local`, `npm run build-uat` and `npm run build-prod`, inside a build container.
The build selects `NODE_ENV`; API runtime `APP_ENV` controls Laravel separately. Switching
the latter does not rebuild browser assets. Browser dependencies also require the Bower
step used in the Dockerfiles. These are legacy dependencies; a current Node version in
the builder does not make the AngularJS/PHP/Laravel runtime current.

The Dockerfiles copy the API and install Composer production dependencies, prepare
storage permissions and run Apache. They do not invoke `artisan migrate` or seed the
database at startup. Schema provisioning is a separate deployment action. The supplied
Compose example references an existing image rather than building from the checkout.
For a running system, verify the image tag/digest and source provenance before choosing
either repository as its implementation.

### API structure and contract

Both repositories have `api/` as the Laravel application root. Paths below are relative
to that directory; the embedded API is the newer comparison baseline.

| Path | Responsibility |
|---|---|
| `bootstrap/app.php`, `app/Http/Kernel.php` | Laravel application and HTTP middleware |
| `app/Http/routes.php` | Actual route/authentication split; prefer this over generated API prose |
| `app/Http/Requests/` | JSON validation for examinations and signatures |
| `app/Providers/ExaminationValidationProvider.php` | Registers server-side `PatientIdentifier` validation |
| `app/DataAccess/Validators/IdentifierValidator.php` | Trust/client lookup and checksum validation |
| `app/DataAccess/Models/` | Eloquent relations and trust/account lookup |
| `app/DataAccess/Transformers/` | Fractal response structure and reverse transformation into database models |
| `app/NoDataArraySerializer.php` | Unwrapped response arrays consumed by OpenEyes |
| `app/DataAccess/Scrapers/Goc.php` | External GOC register lookup and cache |
| `app/Http/Controllers/OAuthController.php`, `app/PasswordGrantVerifier.php` | Token grant and email/password authentication |
| `app/helpers.php` | Combined repo's `read_secret()` helper |
| `config/api.php`, `config/oauth2.php`, `config/cors.php` | Vendor/version format, one-hour password grants and browser CORS |
| `config/database.php`, `database/migrations/`, `database/seeds/` | Connections, schema and lookup seed data |
| `public/docs.md` | Generated API documentation; annotations can be stale |
| `tests/`, `phpunit.xml` | API tests; test bootstrap migrates its configured testing database |

Public routes include `GET /complications`, `GET /identifiers/{id}`,
`POST /gocs/searches`, `POST /examinations`, `POST /signatures` and the OAuth grant endpoint.
The token endpoint still requires valid credentials to issue a token. Authenticated routes
are `GET /examinations`, `POST /examinations/searches`, `POST /signatures/searches` and
`GET /signatures/{id}`. Generic `Route::auth()` scaffolding also exists, but the community
submission form has no login step. CORS permits all origins/headers and GET/POST methods
in source config. Do not confuse CORS with authentication or identifier validation.

`config/api.php` uses vendor `OpenEyesPortal`, version `v1`, dates `Y-m-d\TH:i:sP` and the
custom serializer. OpenEyes expects a top-level array, not a conventional `data` envelope.
The search API supports optional `start_date` AND `end_date`, inclusive; the OpenEyes
command only supplies `start_date` and does not paginate. There is no consumed flag or
acknowledgement that removes records when OpenEyes imports them.

### Database navigation, starting with a unique code

The migration sequence defines 29 portal tables after applying `up()` changes, plus
Laravel's `migrations` tracking table. Much of that is OAuth scaffolding. A support case
normally starts with `patients`, `examinations`, `users` and `oauth_clients`, then follows
the small measurement graph. This is the source-defined schema; confirm deployed changes
with `SHOW TABLES`, `SHOW CREATE TABLE patients` and the migration ledger when necessary.

There is NO portal `unique_codes` or `unique_codes_mapping` table. Those belong to the
OpenEyes database. The portal stores the entire printed reference in the UNIQUE
`patients.unique_identifier` column, including prefix and check digits. A portal patient
row means a submission subject identified by that PUC, not an imported OpenEyes patient
record. Two operation-note PUCs for one person can create two portal patient rows.

```mermaid
flowchart LR
    U[users] -->|examinations.user_id| X[examinations]
    P[patients: full PUC] -->|examinations.patient_id| X
    O[op_toms: GOC number] -->|examinations.op_tom_id| X
    U -. users.trust = oauth_clients.name .-> C[oauth_clients: ID is salt]
    P -->|eye_patient.patient_id| EP[eye_patient]
    EP -->|eye_id| E[eyes]
    E -->|reading_id| R[readings]
    R -->|refraction_id| F[refractions]
    R -->|iop_id| I[iops]
    R -->|reading_visual_acuity| V[visual_acuities]
    E -->|complication_eye| K[complications]
```

The dotted trust/client link is an application lookup, not a foreign key. `users.email`
is unique, but `users.trust` and `oauth_clients.name` have no unique constraint in these
migrations. Both routing helpers select their first match. Unexpected duplicates can
therefore affect routing or salt selection even when OAuth authentication succeeds.

| Table | Keys and useful fields | How to follow it |
|---|---|---|
| `patients` | PK `id`; unique `unique_identifier`; `dob`, nullable `ready_for_second_eye`, `comments`, timestamps | Find full PUC, then use its ID in `examinations.patient_id` and `eye_patient.patient_id` |
| `examinations` | PK `id`; FKs `patient_id`, `op_tom_id`, `user_id`; `examination_date`, timestamps | `user_id` determines which authenticated portal user can retrieve it; `updated_at` determines polling eligibility |
| `users` | PK `id`; unique `email`; three-character `trust`, name, password hash | Compare owner ID to the OAuth resource owner; trust comes from the PUC's first three characters |
| `oauth_clients` | String PK `id`; `name`, `secret`, timestamps | Find `name = users.trust`; its ID must match the OE salt/client ID. Do not export `secret` |
| `op_toms` | PK `id`; unique `goc_number`; name/address, timestamps | Join from `examinations.op_tom_id`; not the OpenEyes contact ID |
| `eye_patient` | `patient_id`, `eye_id`, both FKs; no separate ID | Join the PUC's patient row to its currently attached eye rows |
| `eyes` | PK `id`; `label` Left/Right; FK `reading_id` | Follow `reading_id`, not an assumed `readings.eye_id` |
| `readings` | PK `id`; FKs `refraction_id`, `iop_id` | Follow each measurement ID; VA entries use the pivot below |
| `refractions` | PK `id`; `sphere`, `cylinder`, `axis` | Sphere/cylinder become decimal(11,2) in the later migration |
| `iops` | PK `id`; `mm_hg`, `instrument` | Instrument is a string to match during OE import, not an OE instrument FK |
| `reading_visual_acuity` | `reading_id`, `visual_acuity_id`, both FKs | Can contain several distance/near entries for a reading |
| `visual_acuities` | PK `id`; `measure`, `reading`, `method`, `is_near` | `is_near = 0` is distance, `1` is near. `reading` is a string, including non-numeric VA values |
| `complication_eye` | `eye_id`, `complication_id`, both FKs | Current eye-complication join; the earlier `complication_examination` table is dropped by migration |
| `complications` | PK `id`; `complication` label | Portal-local IDs; OpenEyes matches the returned label to its own lookup |
| `signatures` | PK `id`; FK `user_id`; unique `unique_identifier`; `image` | Separate feature. The same reference text is not a FK to `patients`; avoid selecting image blobs during an examination investigation |

The remaining OAuth tables hold grants/scopes, clients' permitted associations, sessions,
auth codes, access tokens and refresh tokens; `password_resets` is account scaffolding.
For the configured password grant, `oauth_sessions.client_id` joins the client and
`owner_type = 'user'` / `owner_id` identifies the resource owner. There is no need to dump
token values to establish which `examinations.user_id` should be visible.

`PatientTransformer::reverse()` matches the full PUC, while `OpTomTransformer::reverse()`
matches GOC number. Repeated submissions can update shared patient/optometrist records;
they are not immutable snapshots. The controller detaches prior eyes and creates the new
eye/reading graph, then reuses or creates the patient/optometrist pair's examination.
Detaching a relation does not itself delete the old eye/reading rows. Submission saving
has no enclosing transaction, so an error can leave partially updated data.

There is no unique database key on the examination's `(patient_id, op_tom_id)` pair;
`firstOrNew()` is application-level reuse. Do not assume it excludes all concurrent
duplicates. Since patient and optometrist rows are shared, an older examination can
serialize their newer content without its own `updated_at` changing. Use the examination
timestamp actually used by the API rather than a patient/optometrist timestamp when
investigating polling.

#### Read-only lookup sequence

Replace angle-bracket placeholders within the protected investigation environment.
These are SQL statements for the approved database-client container, not commands to run
on the host. Start in the PORTAL database, using the exact full PUC from the relevant letter:

```sql
SELECT id, unique_identifier, updated_at FROM patients WHERE unique_identifier='<FULL-PUC>';
SELECT id, user_id, op_tom_id, examination_date, updated_at FROM examinations WHERE patient_id=<PORTAL_PATIENT_ID> ORDER BY updated_at,id;
SELECT id, trust FROM users WHERE id=<PORTAL_USER_ID>;
SELECT id, name FROM oauth_clients WHERE name='<TRUST>';
```

If the full reference is unavailable and only the bare code is known, this fallback finds
candidate references, not a definitive patient match. It uses a leading wildcard and can
scan the table; constrain it further when possible. Different trusts/check digits can
share the same middle code even though the complete portal identifier is unique.

```sql
SELECT id, unique_identifier FROM patients WHERE unique_identifier LIKE '%-<CODE>-%';
```

Follow the returned portal patient ID through the clinical graph. Select only the data
needed for the investigation; names, DOBs, comments and values are clinical data.

```sql
SELECT e.id, e.label, e.reading_id FROM eye_patient p JOIN eyes e ON e.id=p.eye_id WHERE p.patient_id=<PORTAL_PATIENT_ID>;
SELECT id, refraction_id, iop_id FROM readings WHERE id=<READING_ID>;
SELECT id, sphere, cylinder, axis FROM refractions WHERE id=<REFRACTION_ID>;
SELECT id, mm_hg, instrument FROM iops WHERE id=<IOP_ID>;
SELECT v.* FROM reading_visual_acuity p JOIN visual_acuities v ON v.id=p.visual_acuity_id WHERE p.reading_id=<READING_ID>;
SELECT c.id, c.complication FROM complication_eye p JOIN complications c ON c.id=p.complication_id WHERE p.eye_id=<EYE_ID>;
```

Then switch to the corresponding OPENEYES database and use the PUC's middle segment.
Portal IDs and OE IDs are unrelated. Do not join them numerically across databases.

```sql
SELECT u.id AS code_id, m.event_id FROM unique_codes u LEFT JOIN unique_codes_mapping m ON m.unique_code_id=u.id WHERE u.code='<CODE>';
SELECT id, episode_id, event_type_id, institution_id, site_id, deleted FROM event WHERE id=<SOURCE_EVENT_ID>;
SELECT id, event_id, import_success, examination_date, created_date FROM automatic_examination_event_log WHERE unique_code='<CODE>' ORDER BY id;
SELECT id, status_value FROM import_status;
```

`unique_codes_mapping.event_id` is the SOURCE operation-note event. By contrast,
`automatic_examination_event_log.event_id` is the CREATED Examination, an existing
Examination for a duplicate, or zero for unresolved/failed imports. The returned portal
examination ID is stored inside the log's payload, not used as the OE event primary key.
Check all matching code rows; multiple mappings for the same text are an ambiguity,
not a reason to take the first row.

To investigate notifications, follow the Examination's linked automated Message event
through `event.automated_source`, then `et_ophcomessaging_message.event_id` and
`ophcomessaging_message_recipient.element_id`. The recipient references a mailbox, not
the portal user or GOC number. See section 6.6 for how that mailbox is selected.

### Portal hosting through oe-deploy

`templates/portal.yml` hosts `optom-portal` and maps the container's two Apache ports
through separate frontend/API reverse-proxy routes. This is different from
`templates/modules/optom.yml`, which configures OpenEyes as a CONSUMER of that portal.

| Portal deployment input | Runtime value or secret |
|---|---|
| `PORTAL_TAG` | Portal image tag |
| `PORTAL_API_DEBUG`, `PORTAL_APP_DEBUG`, `PORTAL_APP_ENV`, `PORTAL_APP_LOG` | `API_DEBUG`, `APP_DEBUG`, `APP_ENV`, `APP_LOG` |
| `PORTAL_DB_NAME`, `PORTAL_DB_USER`, `DATABASE_HOST`, `DATABASE_PORT` | `DB_DATABASE`, `DB_USERNAME`, `DB_HOST`, `DB_PORT` |
| `PORTAL_CACHE_DRIVER`, `PORTAL_REDIS_HOST`, `PORTAL_REDIS_PORT` | Cache/Redis backend settings |
| `PORTAL_MAIL_*` | Laravel SMTP settings |
| `secrets/PORTAL_APP_KEY`, `secrets/PORTAL_DB_PASSWORD` | `/run/secrets/APP_KEY`, `/run/secrets/DB_PASSWORD` |
| `secrets/PORTAL_MAIL_PASSWORD`, `secrets/PORTAL_REDIS_PASSWORD` | `/run/secrets/MAIL_PASSWORD`, `/run/secrets/REDIS_PASSWORD` |

`db-setup.sh --portal-only` provisions the database and database login; that is distinct
from migrating Laravel's tables and from creating the trust's portal user/OAuth client.
Preserve the deployed database, application key, storage and issued account values through
upgrades. For logs, distinguish Apache access/error output, Laravel `api/storage/logs/`,
and the OpenEyes manager's cron/import output. Do not publish those logs without reviewing
them for credentials or clinical payloads.

### Test boundaries

API tests cover identifier validation, controllers, transformers, signatures, GOC scraping
and password grants. They use Laravel's test bootstrap and a `testing` DB connection;
verify that connection before running them in an isolated test container. The production
Dockerfiles install Composer with `--no-dev`, so they do not supply PHPUnit by default.

`npm test` invokes `gulp test`, but the Gulp task calls `$.karma` while root dependencies
do not declare `gulp-karma`; browser/runner setup also needs checking. The root README's
Grunt commands are not evidence of a working current test runner. No cross-repository
contract test in these trees establishes that a deployed OpenEyes/portal pair agrees.
Useful verification for a code change includes checksum compatibility, altered submission
handling, trust scoping, clinical lookup names and local message/recipient creation.

## 11. Support history and reusable lessons

Ticket identifiers below are source references for historical observations, not claims
that every deployment still has the same issue. Ticket closure alone is not fix verification.

| Ticket and period | Recorded result | Troubleshooting lesson |
|---|---|---|
| TKLS-3532, March-July 2024 | Missing PUCs were repaired and weekly supply changed to daily; later confirmation reported a full set of codes. Existing letters still lacked the old blank substitution. | Check free-code capacity and mapping separately. A historical ticket's 1000-code default differs from the 1500 target in this source. Regenerate correspondence after repair. Do not reuse the ticket's bulk SQL as a general backfill. |
| TKLS-3963, May 2024 | UAT submissions sent through the production portal appeared on production patient records. The workflow was moved to a separate UAT portal and confirmed tested. | Test-patient demographics do not isolate bare-code lookup. Align environment URLs, trust credentials and letter macros; hardcoded URLs need separate correction. |
| TKLS-2844, November 2023 | Imports failed because configured VA unit names differed from the creator's translated names. Unit data was corrected and a manual import was reported successful. | Inspect lookup values and their expected labels before assuming a transport fault. Treat historical data changes as examples, not universal SQL repairs. |
| TKLS-7923 / OE-16447, September-October 2025 | Regression guidance covers complication labels containing special characters, and clarifies that Patient Reference is the correspondence PUC. The thread does not establish final successful retest. | Check DTO preservation of complication names and the exact OE lookup. The skip list is present in the source described here. |
| TKLS-6748, April 2025 | A valid-DOB report was attributed to a server-side problem; one submitter confirmed recovery, but later reports requested reopening. No precise root cause is recorded. | The form's identifier error does not establish operator error or a proven salt defect. Inspect the API response and server implementation. |
| TKLS-6297, February 2025 | An upgrade-related outage was reported fixed and stored submissions reprocessed; the thread does not specify the technical fix. | Portal storage and OE import are separate stages. Determine the backlog and cursor before replay; a normal poll is not a guaranteed backfill. |
| TKLS-9767, June 2026 | A deployment-specific 15-minute job marked existing portal messages read/deleted and the requester confirmed the visible result. | Messages can be created correctly and hidden later. Inspect local scheduled cleanup before changing the importer. This is not default application behavior. |

## 12. Related

- [Unique codes](../Database/oe-unique-codes.md) - pool, allocation locking, duplicate codes and version-dependent backfill.
- [Unique-code concurrency](../Database/oe-18464-unique-code-concurrency-and-solutions.md) - concurrency analysis and alternative allocation designs.
