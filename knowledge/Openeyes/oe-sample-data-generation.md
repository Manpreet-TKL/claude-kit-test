# Reproducible OpenEyes sample scenarios

Verified lessons from a September 2026 sample-data rehearsal. Recheck release-specific behaviour before reusing an import against another build.

## Verification boundary

The inspected OpenEyes base was `release/26.1.x` at `ab35454c623e6c565a8d03005a02ffb4d2bbbbb2`; the sample base was `060436f250f699eb05bde32fedbf04798e028b1d`. The scenario scripts were developed as uncommitted changes under `sample/sql/demo/scenarios/`. They are not assumed to be present upstream.

This note records verified mechanics. It does not claim every clinical or external billing scenario is complete. Capture final verification evidence and any application changes separately from these base revisions.

## Start with the existing deployment and sample patterns

1. Use the [oe-deploy skill](../../skills/c-oe-deploy/SKILL.md). Clone a fresh template, rename it, assign unused ports and new storage, and check capacity before starting it. Never reuse another deployment without authorisation.
2. Pin the application, sample and supporting modules. Web and manager must contain the same application revision and any local changes being tested. Record image IDs and source-file hashes; a base commit alone does not describe an edited runtime.
3. Use the deployment's sample setup script. Manager startup runs migrations but does not itself load the sample database.
4. Inspect the sample repository before choosing tooling. The inspected sample uses numbered shell scripts, SQL files and existing application commands. It has no sample-owned PHP command precedent. Add yiic PHP only for a demonstrated gap in those patterns, or when an existing maintained command pattern already fits.
5. The sample archive has a `.zip` name but contains gzip data. Detect its format instead of assuming ZIP.
6. Check the installed runner. The inspected directory runner does not forward scenario arguments, and `oe-reset.sh --post-path` does not change the demo directory actually selected. Call parameterised scenario scripts explicitly.

## Establish a frontend reference before importing a graph

Record the starting role, institution, site, service/context, patient identity, exact clicks and entered values. Record the resulting internal IDs privately; resolve imported patients through their stable external identifiers rather than hardcoded database IDs.

Use a reserved reference ordinal and different generated ordinals. Verify an imported example through View, Edit without saving, and the application's native PDF before expanding its count. A successful SQL insert alone does not prove the application can read or edit the graph.

The current diagnosis model has event records, cumulative state, caches and materialised projections. Inserting only a legacy secondary-diagnosis row is insufficient. Follow a freshly saved reference and the maintained DTO/mapper representation. For a schema-compatible Sample recipe, validate the required layout and configured lookups rather than pinning application source-file fingerprints. Recheck the native frontend after a release update.

## Identity, counts and ownership

1. Treat count as the desired total. Identical inputs reuse the same patients; a higher count adds missing ordinals; a lower count retains and reports extras.
2. Resolve institution, site, service, medication and other lookups through existing codes or names. Reject ambiguity. Check institution assignments and allowed dispensing-location/condition pairs, not only display names.
3. Check ownership before writes: stable identifier, duplicate identifiers including alternate sources, demographic values, creator/provenance, event type, clinical links and the exact owned content. A matching identifier alone is insufficient.
4. Use a transaction and a cohort lock. Test a collision at a later ordinal to prove earlier inserts or date changes roll back.
5. Keep the synthetic identity and clinical history coherent. Do not silently overwrite a person's changed demographics or subsequent clinical work during a rerun.

### Automation metadata is not a durable ownership key in the inspected release

`Event::afterFind()` decodes `automated_source`. The save path does not encode a string again. A JSON scalar can therefore become a plain string after one native save, and later become null. An object-shaped value also conflicts with the current shared DTO's string expectation.

The scenario import initially writes truthful automation information, but discovers its records using an exact visible trailing marker in existing History or prescription comments. It then checks the full expected content and links. This avoids depending on lossy metadata or adding a new registry table. Changing the owned marker/text requires reconciliation; the script must fail rather than adopt a different record.

## Dates, prescriptions and signatures

| Date or state | Rule |
| --- | --- |
| Synthetic birth date | Fixed independently of the clinical anchor. |
| Clinical event dates | Absolute offsets from one explicit anchor; rerunning the same anchor must not shift them again. Native episode creation records the actual creation day and may differ for late-entered history. |
| Diagnosis observation date | Rebase with the intended clinical observation. Editing the event date alone can leave this unchanged. |
| Creation, modification and audit dates | Preserve their actual provenance. Inspect derived-state exceptions separately; do not backdate actual entry or signature evidence. |
| Prescription item start date | Native signing stamps the actual signing day in the inspected release. Generate current-clinic prescriptions so the episode, assessment, prescription and treatment dates remain coherent. |
| Reporting day | Define the reporting timezone, then convert its boundaries to the stored timestamp convention. A date label alone is insufficient. |

Generate prescription drafts, then sign them through the native frontend. Do not copy signature rows or files, or set a finalised flag to simulate signing. Reveal the current PIN through the user's authorised profile workflow when needed; a PIN printed in an old sample README can differ after migration.

Capture an unsigned database and protected-files checkpoint before signing. Identical reruns must recognise a genuine finalised transition while preserving its signature, audit and content. A new anchor must stop before changing any part of a pack that contains signed fixtures. Restore the unsigned checkpoint into a separate rehearsal instance, rebase and sign again instead. Check this across every kind and retained ordinal, not just the requested glaucoma count.

A historical clinical event date does not prove historical treatment. The initial boundary fixtures exposed an incoherent combination of an old prescription event, a current episode and a current signature/item start date. Keep date-boundary controls outside active clinical charts. Correct an existing signed clinical record through native amendment and re-signing, preserving its audit history; never repair signed content with SQL. Medication History can record prior use through its current frontend element, but it does not establish an earlier prescription or signature. Supplied legacy finalized prescriptions can lack electronic signatures and must retain that provenance.

Native clinical date validation also rejects a time later on the current day. Use the documented native date-only representation where the scenario knows the clinical day rather than a precise event time. Midnight then means unknown within-day time; keep explicit IOP reading clocks separate. Do not bypass the validator or alter the system clock. Compare actual stored dates, not only the displayed date label. During the inspected prescription amendment workflow, a rejected future-date save removed the current signature before the old clinical values changed. Verify persisted signature state after an unsuccessful amendment and complete any authorized correction through genuine signing; do not assume failed validation guarantees no writes.

## Checkpoints and replay evidence

1. Keep a clean migrated sample checkpoint, an unsigned prepared checkpoint and a final prepared checkpoint.
2. Pause all scenario writers and background consumers that can alter the relevant data. Browser reads and PDF rendering can also write audit/cache files; finish them before capturing a database/files pair.
3. Archive the actual protected storage. The application's `protected/files` and `protected/event_images` can be symlinks; archiving only the links omits the content.
4. Retain hashes and image/source manifests with each checkpoint. If a checkpoint predates a custom migration, record the normal migration step required after restoration.
5. Restore into an isolated disposable database or deployment and run the scripts again. A repeat against an already prepared database does not prove clean regeneration.
6. Test identical reruns, increasing and decreasing counts, leap-day rebasing and restoration, late collisions and deliberate manual drift. Compare owned rows, timestamps, versions and audit history. Check unrelated baseline data separately.
7. Do not run the sample audit-clearing script during scenario reruns.

With the inspected images, files copied to the container's `/tmp` can be hidden by its runtime tmpfs. Use an explicitly mounted workspace or another known visible directory. Reuse the installed `.source_config.sh` and `.db_connection.sh` helpers, but remove their exported password-bearing connection string and pass credentials through protected client defaults. Do not print credentials or store them in repository files.

The manager image's MySQL dump client requires `--column-statistics=0` when reading MariaDB. Use the database container's matching MariaDB tools when practical. The installed shell helpers are not safe under an inherited `set -u` without preparing their expected optional variables.

Record the server dialect separately from the client executable. MariaDB anonymous `BEGIN NOT ATOMIC` blocks can be sent through a MySQL client but do not establish Oracle MySQL server compatibility. Keep a concrete server requirement and verify against the target deployment before presenting a SQL fixture as reusable.

## Native workflow details worth checking again

1. Select institution/site/service/context explicitly in browser work. The verified independent sessions kept their active contexts separately, while a later login inherited the shared account's most recently remembered default. Concurrent login does not prove simultaneous editing is supported.
2. A hidden local identifier field can need its existing display preference changed to Optional. Preserve its type and validation.
3. Manual biometry entry is controlled by an existing administrator setting. Manual entry is useful for a clinical demonstration but does not establish a device import. Preserve that distinction in the runbook.
4. Surgery scheduling needs the existing theatre/session configuration. A one-off session can support a dated rehearsal without regenerating every theatre session.
5. Wait for native PDF responses before judging printing. The print iframe can remain blank while its request is still rendering.
6. A controller can override the base validation path. When adding a shared clinical field, test real save requests for every affected module, the shared DTO mapping, View and Print. A base-model test alone can miss a module that never invokes the new validation.
7. Existing xAPI routing/authentication is preferable to another custom front controller. An internal Docker DNS request can still require an allowed Host header. Verify the installed Swagger/OpenAPI routes separately from JSON API calls.

## Keep interim PAS work portable

Before building an interim billing integration, compare actual message and correction contracts. Reusable patient, visit and clinical-service fields do not prove that prices, invoices, payments, refunds or provider allocation transfer between products. Keep the source clinical envelope and delivery checks stable, but record each financial system's identifiers and authoritative transaction rules separately. If the intended destination's financial-write contract is unavailable, do not describe a successful local review receiver as verified billing compatibility.

Record the source trigger, transformation, destination API, authentication role, application acknowledgement, persisted verification, duplicate handling, correction behavior and error-review procedure for every channel. Engine acceptance alone is not application success. State whether retries are automatic or explicit, and whether a flow is deployed, simulated or only proposed.

## Realistic variation comes after the base acceptance gate

First confirm every base scenario and its reproduction recipe. External-system scenarios remain pending until the real system is available; simulated messages do not establish compatibility.

Only then assess a small useful variation set. Keep fictional names, age, eye, dates, diagnoses, measurements, medicines and procedures internally consistent. Use deterministic existing SQL/shell selection patterns and stable identity keys. A reused patient should have one coherent longitudinal record; a new patient must receive a new stable identity. Do not rename prepared patients or randomise their history on rerun.

Keep actual generated records, screenshots, exports, signatures, connection details and credentials outside this repository, including synthetic patient-shaped payloads. This knowledge file holds the method and pitfalls; the sample repository holds reusable generation code and generic run instructions.


## Reproducing a completed historical cataract journey

Use a separate historical cohort when the minimal assessment importer owns a narrower diagnosis graph. The existing sample pattern supports explicit linked SQL; copying the entire prepared database cannot provide independent patient counts and dates. Inventory the native clinical graph before writing its SQL counterpart. Exclude session, worklist, cache and audit artifacts that are not part of the declared imported workflow.

Some relationships have misleading names. In the inspected medication-history model, `copied_from_med_use_id` references the source event, not the medication-use row. Resolve the current implementation and verify a native copy before reproducing it. Automatic diagnosis-resolution records also derive their creation/modification fields from the clinical event date in the maintained diagnosis service; the actual entry, audit and cache timestamps remain distinct. Preserve that observed derived representation without rewriting actual provenance.

Retrospective surgery can expose current-day scheduling assumptions. The native earliest-offer calculator considers the current clock as well as the clinical decision date. Do not manufacture a historical offer or use that result to claim historical waiting times. If omission is supported, record it as unknown and verify both native rendering and model behavior. A completed historical booking also has an actual completion-action date separate from its clinical surgery date.

Respect theatre duration as well as configured case capacity. Give a generated cohort a clearly owned session, reject unrelated bookings before moving it, and verify that every retained case moves coherently when its shared session is rebased. Keep zero-count runs as no-ops. A frontend clinical Save can rebuild derived rows; an importer should refuse changed graphs rather than overwrite later clinical work.


Opening Examination Edit can autosave a draft before a Save click. Capture the database baseline after browser inspection when testing subsequent exact reruns. Keep those genuine UI side effects separate from finalized clinical events. A fixed-reference SQL import must resolve every configured lookup, including undeclared foreign keys such as biometry lens selection; a source-ID literal can accidentally work in one sample but select another value after migration. Check clinical enums against their current definitions instead of treating every integer as either a lookup ID or a free value.


## Refresh derived summaries after direct SQL changes

Native clinical saves invalidate patient-summary sections, while direct SQL bypasses those hooks. The inspected application can retain a cached summary for a day when its per-patient buster is unchanged. A direct event page can therefore show correct imported data while the patient overview remains empty or stale.

Follow the maintained SQL in `BuildsPatientSummaryBusterSql`, including its monotonic timestamp rule, and update only the relevant sections for patients actually inserted or rebased. Do not copy reference cache rows or reset a buster to an older clinical date. An identical rerun must not advance these values. Verify the actual summary after first caching it, then importing or moving the clinical date.

A date rebase followed by restoration should restore clinical values and preserve signatures/audit history, while its intentional cache invalidations remain newer. Compare those scopes separately. Resetting the derived timestamps just to match an earlier whole-database hash would reintroduce the stale-summary defect.

## Keep database replay checks independent of browser activity

HTTP health checks can create user-session rows even when no person is browsing. Inspect both web and manager: the manager can also serve the same health endpoint on its own localhost. For an exact full-database SQL replay check, pause those HTTP writers while retaining the database and shell generator, and record that boundary. Restore normal services for native rendering and cached-summary checks. A disposable one-shot manager can behave differently from the full daemon service. Preserve failures caused by background activity as evidence rather than deleting the new session or silently omitting its table from a claimed whole-database comparison.

Schema discovery must distinguish base tables from views. A view whose name resembles an event-element table can expose rows already represented elsewhere; counting it as another owned element can produce a false collision. Use the current information-schema table type when inventorying stored relationships. Keep actual clinical child-table absence guards, since unexpected optional elements must still cause a safe refusal.

Opening a demographics-only patient can also initialize a neutral Unknown visual-impairment status row. Importing after that view must not blindly insert a second unique row or overwrite its genuine metadata. Reuse only the exact neutral state that the recipe permits, and refuse a recorded clinical value. Include a viewed-before-import case in the native comparison; an untouched database alone does not expose this behavior.

## Verify document import against the installed API

The legacy Document API and current PASAPI can use different authentication paths. A working browser administrator or PAS request does not establish Document API access. Check the installed controller's identifier parameter and account selection, then verify a read-only search before preparing an upload. After a sample database reload, confirm that the provisioned service-account secret was actually applied; a mounted secret alone is not proof that the database credential matches.

Use a stable external document reference with search-before-create, content comparison and refusal on drift. A native frontend upload can lack that integration reference, so compare human and API creation on separate clean instances rather than create two referrals on one patient. Preserve the original clinical chronology in the attachment. In particular, a referral must not describe findings from a later consultation as already known.

Creation and subsequent verification can have different permissions. If a create succeeds but a protected-file download is denied, retain the committed event identity and investigate the read permission. Do not automatically repeat the create. Avoid delete-and-recreate for idempotence: the inspected legacy hard-delete helper also removes event-linked audit rows. Absence of delete controls on the audit screen does not establish immutable application audit storage.

The native Document editor's Download button can build a new PDF from its displayed page images. Its bytes and size then differ from the retained uploaded PDF. Compare the original protected-file mapping and stored bytes when verifying exact ingestion, and label a rendered download separately. A visibly correct page and a different rendered-download hash can both be valid observations.

## Use traceable demonstration images

Prefer a reusable phantom image with a published source and clear attribution when exercising OCT image upload. Preserve its original bytes, caption and source hash. A phantom scan tests file ingestion and viewing; it cannot substantiate a fictional patient's CST, fluid findings or laterality. Keep manually constructed clinical values separate and label the image visibly as external demonstration material.

Modern native event attachments use a group/item/data/protected-file graph. The event type's attachment setting is distinct from the older Generic attachment flag, and the enabled category picker must be checked in the actual form. A database dump alone cannot restore the image: retain the corresponding protected-file bytes. Saving an existing attachment ID differs from uploading the same file again; verify repeat behavior through the maintained route before claiming idempotence.

Check storage limits as well as form limits. The inspected upload dialog accepted a 128-character description while `protected_file.description` stored only 64. A longer description produced a partial Save: attachment links existed with no protected-file row, while the original bytes remained on disk. Subsequent View attempted an unsuitable blob recovery because no blob had been stored. Keep descriptions within the actual storage limit. After a failed Save, inspect both the persisted graph and files before retrying; record any bounded recovery explicitly in the persisted audit, not only an application log message.

Inspect the complete generator ownership boundary before adding files to generated events. An extra-element check over `et_*` tables does not also guard attachment tables. The current completed-journey script does not own optional attachments. Attach them after final clinical generation and date adjustment, then verify them separately and capture a paired database/files checkpoint. Do not claim that the clinical SQL regenerates or validates these files.

The native Generic Save can change stored representations while leaving the clinical controls and display unchanged: NULL event info becomes an empty string, legacy assessment flags become -9, JSON null and SQL NULL differ, and comment line endings can change. The revised replay guards accept these observed empty/unset equivalents while still checking the complete modern assessment JSON, numeric measurements, ownership and clinical dates. Same-anchor replay after native attachment passed. Native edits still fix the anchor; restore the pre-attachment imported checkpoint before moving clinical dates, then apply and verify the separate idempotent image helper.

The current binary AttachmentData API requires an existing processing request. Creating one through the queue endpoint can schedule a routine. Do not invent inert queue records solely to upload a demonstration file. Reuse a maintained native upload path and existing browser runtime when that is the smaller supported route; keep its target manifest and session material outside the shared kit.

## One operator guide and composable scenario packs

Retain one named preview per explicitly requested demonstration. Before retiring a rehearsal, preserve SQL, protected files, source changes and verification evidence; archives are recovery material, not an additional live preview. Provide a single operator entry point with stable patient identifiers, current numeric links, clinical contexts, exact count/date commands and explicit native-signing/image boundaries. Recheck every landing link after selecting the retained environment.

When a separately requested requirements pack must coexist with an earlier pack, keep identifier ranges, institution codes, lookup ownership and optional script entry points distinct. Preserve the earlier sample institution and fixtures. Verify the combined run in one authorized instance without treating a successful standalone run as proof of compatibility. Financial work that has been parked must not remain a clinical acceptance gate.


## Check fixture demographics through native Edit

A synthetic name can render on View while failing the application's contact validator on Edit. Avoid numeric ordinals in surnames; keep uniqueness in the patient identifier and use realistic alphabetic names. Verify one generated patient through native Edit before scaling. A normal Save can normalize NULL title/email to empty strings and create an empty address row. Accept only the observed equivalent values in replay guards; preserve user-entered addresses and clinical changes.

A correspondence address can be required for admission output. Use an unmistakably synthetic non-delivery address and no invented real postcode. Generate it only with a new patient, or add it through native Edit for an existing reference. A completed booking can hide print buttons even though its maintained authenticated PDF route still works; describe which path was actually tested.

## Institution-specific identifiers and local viewers

Selecting an institution on the identifier-type form can automatically select its sole site. Explicitly choose the institution-wide option when that is intended. Identifier display preferences default to hidden and need their separate display/search configuration. A shared global identifier and several trust-specific local identifiers belong to one patient, not several copies of the patient.

For LOCAL authentication, the header's Institution selector can be disabled even though its DOM contains authorized options. Verify the supported logout/login route for each institution. Menu visibility and context-sensitive identifiers do not establish clinical tenant isolation. Test the receiving viewer too: reject missing, duplicate, unknown and mismatched identifiers, and scope its manifest to the selected trust. A direct browser context link does not involve Mirth; do not describe it as a tested ADT or DICOM interface.

## DNA correspondence completion has multiple states

A letter's finalized flag is not sufficient to prove output completion. The native example required editing/saving after genuine signing, then moving the local Print output from pending to printed. Record draft, finalized, output-complete and externally delivered as distinct states. Never create signatures or delivery evidence through fixture SQL.

A report covering absent letters cannot start only from existing letter rows. Start from the missed-attendance records and left-join the associated letter. The demo uses an explicit event reference in the same-episode letter subject; this is a bounded demo convention, not a generic production relationship. Export the association method and distinguish a missing letter from an incomplete one.

## Rehearse configuration and collision rollback

Replay configuration on a clean database with the same database character set/collation as the deployment, not only on an already configured preview. Check data equality after a second run. Create a deliberate later conflict in the disposable test database and confirm that earlier writes in the same transaction roll back. Identity count tests should cover increase, lower count, zero count and unchanged fixed birth dates under a later anchor. Remove the disposable verification database after retaining evidence; it is not another preview.

## Virtual review needs institution-specific outcome configuration

A queue set and user permission alone do not make a new institution's Clinical Outcome selector offer the required referral. Check the existing Virtual Clinic category mapping and an institution-specific follow-up status as well. A sample outcome status belonging to the original institution may not appear under a newly configured institution. Verify the entire native path: referral, correct trust queue, ownership, consultant review, terminal step, Completed and History. Demonstrating a terminal queue step does not establish a clinical decision or an escalation policy.

## Analytics depends on later events and worklist arrivals

An examination's recorded follow-up interval is not sufficient evidence that it will appear in an overdue report. The inspected implementation excludes an older examination when a later worklist arrival exists, including an automatically created current unbooked arrival during historical data entry. A later discharge can also remove the patient's earlier planned-follow-up aggregate. Capture before/after report counts and the stored dates, and preserve a suppressed control as a documented gap.

New-patient waiting-time analytics uses a Referral Letter Document, whereas the operation partial-booking list uses an unscheduled operation. Create separate dated controls and identify which report each one exercises. Do not infer RTT semantics from an ordinary waiting-list row.

## Separate a pending IVT plan from administration

Verify the configured medication mapping and delivered dose against the native form. A product's concentration or container amount is not automatically its delivered dose. Preserve unsigned prescription snapshots, pending injections and unreserved appointments as those states. Check the actual administration screen for consent, due-date and prescription requirements, then cancel when the synthetic reference has not completed them. Do not convert a future pending plan into a delivered treatment through fixture SQL.

## Test paired checkpoints as well as generators

Pause both application services for a consistent database/files capture. Retain matching encryption keys and deployment secrets privately. Validate the dump by restoring it into an isolated disposable database, compare the relevant graphs/counts, and compare archived protected-file bytes. A successful SQL restore does not prove a complete application restore, and a checkpoint reset does not make native reference journeys independently composable or date-adjustable. State those boundaries in the operator guide.

## Stock schema and regional replay

The later stock-schema rehearsal used OpenEyes revision `7693c6bb82` with the same Sample base. It required no application feature or custom migration. An older supplied database was prepared with ordinary upstream migrations first. Preserve existing patients and configuration; test a separate copy with zero patients and the catalogue/configuration retained. Both regional packs passed together from that state, including whole-database unchanged replay.

1. Region flags select fixture values; deployment country and application/database timezones remain separate configuration. Use distinct deployments for simultaneous regional demonstrations. Give each local viewer its own port range.
2. A shared national identifier must have GLOBAL usage for the native patient header and context placeholders. Preserve an existing LOCAL national type and add a separate suitable GLOBAL type when necessary. Institution-wide local identifiers need their own display preferences.
3. Standard and migrated catalogues can use different labels for the same recorded reaction. Resolve one known compatible existing option, reject ambiguity and do not silently replace catalogue rows.
4. A prescriber needs the Prescribe role as well as ordinary clinical Edit. A user can view an unsigned prescription yet be redirected from its Edit route without that role.
5. A workflow-only virtual ticket needs a source event for the native patient review panel. Keep its History explicit that no clinical assessment or decision is asserted. Preserve native ownership/completion on replay and reject date rebasing after progress.
6. Local printing can depend on the document service account password matching the deployment secret and writable event-image storage. Reconcile the existing account through native administration. The stock reset-user command can fail for an automation authentication row with no institution; do not assume that command works for every account type.
7. Rebuild a local image from the complete upstream base-to-target difference. Copying only the last commit can omit intervening changes while misleadingly labelling the image current. Verify web and manager source together.
8. A clinical-date rebase legitimately advances cache-buster timestamps. Exact no-op replay should preserve all data; rebase-and-restore comparisons should preserve clinical values while allowing those newer cache timestamps.
