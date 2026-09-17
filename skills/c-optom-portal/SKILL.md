---
name: c-optom-portal
description: Optom portal repos, unique codes, OpenEyes imports and messages
disable-model-invocation: false
---

# Optom portal

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

Use for community/optom portal repos, PUCs, post-op imports, messages and deployment.
It covers cataract feedback; the separate OpenEyes signature API has another path.

## Repositories and reference

`~/oe-community-portal` contains AngularJS `app/` AND a Laravel 5.2 API in `api/`.
`~/oe-community-portal-api` is the older standalone API. Both need context, but they
are overlapping implementations, not two services required by the workflow.
The combined repo adds a PHP-compatible checksum fix, Docker-secret reading and
Docker/Node build files. Verify the deployed image before choosing the source.
Some API comments incorrectly say Lumen; the root README's Grunt commands are stale.

Read the relevant sections of
[the portal reference](../../knowledge/Openeyes/oe-community-portal.md):
sections 3-4 for configuration/codes, 5-6 for submission/import/messages, 8 and 11
for troubleshooting/support history, and 9-10 for source paths/build/schema/API.
Read both repositories' differing files before changing their shared contract.
Keep deployment credentials, real hostnames and patient data outside the kit.

## Round trip and unique codes

1. OpenEyes pre-generates six-character `A-Z2-9` codes in `unique_codes`.
   Saving an event with the cataract operation-note or CVI element allocates a
   `unique_codes_mapping` row. The portal examination flow uses the operation note.
   Pool generation, event allocation and missing-mapping repair are different jobs.
2. Correspondence `[puc]` invokes `OphTrOperationnote_API::getPatientUniqueCode()`:
   `<trust><cd1>-<CODE>-<cd2>`. The salt is the portal OAuth **client ID**.
   Digit 1 incorporates trust + code; digit 2 incorporates code + DOB (`Y-m-d`).
   `[pul]` supplies the browser URL. The code travels in a letter without portal
   pre-registration. Existing letters stay unchanged after mapping/config repairs.
3. Portal `IdentifierValidator` validates the complete PUC against entered DOB,
   `users.trust` from its first three characters and `oauth_clients.id` where
   `name = trust`. `CreateExaminationRequest` repeats this validation server-side.
   The portal does not ask OpenEyes whether the code exists. Checksums are not
   cryptographic identity proof.
4. Anonymous `POST /examinations` stores PUC-keyed patient data and routes ownership
   to the trust's portal user. Re-submission can update existing records.
5. OpenEyes `portalexams` obtains an OAuth password-grant token and polls
   `POST /examinations/searches`. It strips the PUC to the middle six characters
   and resolves the source event. It does NOT revalidate DOB or either check digit.
   Never describe check digits as unused everywhere; the portal validates them.
6. `ExaminationCreator` creates an automated Examination in the operation-note
   episode, copies its institution/site, imports readings/complications/comments,
   then creates a local message when eligible. OpenEyes pulls; the portal does not
   push into an OpenEyes webhook.

For pool exhaustion, lock contention or duplicate repair, read
[unique codes](../../knowledge/Database/oe-unique-codes.md) and verify the deployed
branch. Older source allows duplicate code text and returns one matching event;
proposed fixes in knowledge do not prove they are installed. Do not re-point an
issued mapping. UAT and production must have aligned but separate endpoint/account
configuration; test demographics do not prevent bare-code collisions.

For DB navigation, reference section 10 has the 29-table schema, relationships
and read-only queries. Start with portal `patients.unique_identifier` (full PUC),
then `examinations.patient_id`, owner `user_id`, optometrist and `eye_patient`.
The portal has no code pool. In OE, the middle code reaches `unique_codes_mapping`
and the source op note; the import log's `event_id` instead identifies the new
Examination. Never join portal IDs to OE IDs directly.

## Configuration and accounts

In oe-deploy, retain existing `MODS` entries and include `optom`.
`templates/modules/optom.yml` passes URLs, enable flag, username and client ID to
web/manager and mounts `OE_PORTAL_PASSWORD`/`OE_PORTAL_CLIENT_SECRET` secrets.
`templates/portal.yml` instead HOSTS the portal. `build.sh` renders the selected
templates; editing `.env` alone does not update containers.

OpenEyes `protected/config/core/common.php` builds `params['portal']`; all four
credential fields accept secret-file-before-env precedence. `OEConfig.php` merges
local config last: `local/common.php` affects web/console, and `local/main.php` or
`local/console.php` can override one side. APCu may retain web configuration.

`OE_INSTITUTION_CODE = users.trust = oauth_clients.name`; OE's client ID must be
the selected OAuth row's ID. Rotating that ID changes the salt for printed letters.
`OE_PORTAL_EXTERNAL_URI` is the browser URL; `OE_PORTAL_URI` is the API URL.
The frontend API URL is compiled from `environments.json` with `NODE_ENV`;
changing Laravel `APP_ENV` alone does not change the browser bundle.

`OE_PORTAL_ENABLED` gates the cron, not a manual command. Application polling
defaults hourly; confirm manager `ENABLE_CRON` and installed crontab.
`CRON_PORTALEXAMS_SCH` exists in application source but is not passed by the
inspected stock optom module. Pool supply uses `CRON_GENERTAEUNIQUECODES_SCH`
(keep the typo); oe-deploy's template overrides the application's weekly default
to daily. Check actual deployed values and free-code demand.

`scripts/optom_portal_new_client.sh` creates portal `users` and `oauth_clients`
rows and a sensitive password-manager CSV. It does not configure OpenEyes or
create its internal `portal_user`. The existing script uses host DB/curl/OpenSSL
tools, relative `.env` reads and non-transactional inserts; inspect before use and
adapt to container-only execution where required. Do not run it just to load context.

The internal OE `portal_user` owns imports and sends messages. The GOC
optometrist is a separate contact. Admin's disable-auto-import toggle
defaults On; Off permits contacts. The command reads that flag directly from
`params` and requires literal `'off'`, so verify effective console config rather
than assuming the database toggle is consulted.

## Message creation and failure tracing

`ExaminationCreator::createMessage()` requires enabled `OphCoMessaging`, a supplied
operation-note ID and that note's surgeon. `MessageCreator` creates a separate
automated Message event on the same episode, links its source to the new Examination,
and creates a primary recipient in the surgeon's personal mailbox. Sender is the
OE import user; type is General. `views/templates/optom.php` includes patient
identifier, optometrist/GOC/address, second-eye readiness and comments. Empty
comments and a No answer do not suppress messages. There is no team-inbox fallback.

Email is additional: direct `setting_installation` key `optom_comment_alert`,
comma-separated recipients, subject `New Optom Comment`, OpenEyes Mailer.
It does not redirect the in-app message; failure returns false without being
checked. Mail can be sent before the import transaction commits.

Trace `automatic_examination_event_log` and `/oeadmin/eventLog/list` first.
Identical re-fetches are skipped; changed existing data becomes Duplicate Event.
Accepting a duplicate creates another examination/message and deletes the old
examination. Manual Unfound assignment passes no operation-note ID and can create
an examination without a message; it does not repair the code mapping.
The invoice manager shows successful imports, not failures.

`latestSuccessfulEvent()` excludes only Import Failure and Dismissed Event;
Duplicate/Unfound rows can advance its `updated_at` cursor. A normal rerun may
miss older failed submissions. Check lookup names (VA/IOP/complications), recipient
mailboxes, DTO complication preservation and the raw failure before replay.
GOC lookup depends on external markup plus server/browser caches.

Section 11 covers historical pool, environment-mixing, lookup, validation and
backlog incidents, plus TKLS-9767's local message-hiding job. They are diagnostic
lessons, not universal fixes or permission to repeat ticket SQL.
