# OE frontend paths - the hardcoded atlas

Pre-recorded navigation for the stock OpenEyes UI. Captured from a full crawl on `develop` (2026-06) and spot-verified on v11.0.18 (2026-07). The app's navigation is stable across versions - trust these paths, but source *in-form field labels* from the fix branch's view code or a probe (`subs/probe.md`), and never put sample ids/creds from this file into PR text.

## Reaching the app and logging in

- Find the web container: `docker ps` -> `<stack>-web-1` (image `toukanlabsdocker/oe-web-live:<version>` - the tag is the running OE version). Its network is `<stack>_backend`; on that network the container answers as **`http://web`**.
- Login page `/site/login`: fields 'Username' (`#LoginForm_username`), 'Password' (`#LoginForm_password`), then Institution and Site pickers. The pickers are custom JS - the real `<select>`s are `display:none`, so automation must set the hidden `#LoginForm_institution_id` / `#LoginForm_site_id` and click `#login_button` (humans just use the pickers). Success lands on `/` (the patient search screen); still on `/site/login` = failed.
- Sample boxes: `admin`/`admin`, institution 1, site 1; the crawl admin holds all 66 roles. Patient search home; ~2284 sample patients; **patient 17891** has 129 events (the richest record).
- Running version: hover/read `#js-openeyes-info` in the header *after* login. Never trust `protected/version.txt`.

## Global chrome (every page)

- Main-menu (shortcuts) icon `#js-nav-shortcuts-btn` opens the panel `#js-nav-shortcuts-subnav`, heading "Main menu".
- Worklist toolbar button `#js-nav-worklist-btn` (a toggle - see Worklist), hotlist toolbar button (opens the hotlist side panel), theme toggles `#js-set-theme-light|dark|auto`.
- A hidden re-auth login form `#js-login` sits in every page's DOM - harmless; ignore it in dumps.
- Never wait for network-idle anywhere: OE long-polls (worklist sync, notifications).
- **Adder dialogs** - the one picker behind most 'Add ...' buttons (extra procedures, decision contacts, medications, worklist filters), `protected/assets/js/OpenEyes.UI.AdderDialog.js`. The popup is `.oe-add-select-search.auto-width` / `[data-test="adder-dialog"]`; option lists are `ul[data-id="<list name>"] > li` with the on-screen label as the item text; free-text search is `input[data-test="adder-search-input"]` with hits in `ul.js-search-results li`; the confirm control (labelled 'Click to add') is `i.oe-i.plus` inside the dialog. It is `position: fixed`, so `offsetParent` is null and any visibility check resting on that reports it hidden - test the bounding box instead. Several screens keep more than one adder in the DOM at once, so scope every selector to the dialog you just opened rather than to `document`.

## Main menu - 26 items

Top toolbar > shortcuts icon. Each item is `#js-nav-shortcuts-subnav a[href="<url>"]`:

| Menu label | URL |
|---|---|
| Add Patient | `/patient/create` |
| Admin | `/admin` |
| Advanced Search | `/OECaseSearch/caseSearch/index` |
| Analytics | `/Analytics/analyticsReports` |
| Audit | `/audit` |
| CVI | `/OphCoCvi/Default/list` |
| CXL Dataset | `/CxlDataset` |
| Failsafe Management | `/OphCiExamination/ResponsibleForCareManagement/index` |
| Genetics | `/Genetics/default/index` |
| Internal referrals | `/PatientTicketing/default/?cat_id=2` |
| IVT booking | `/OphCiExamination/bookingpages/intravitrealinjection/index` |
| Link a mobile device | `javascript:eSignDevicePopup();` (popup, not a page) |
| NOD Export | `/NodExport` |
| Optom Invoice Manager | `/OphCiExamination/OptomFeedback/list` |
| Partial bookings waiting list | `/OphTrOperationbooking/waitingList/index` |
| Patient Merge | `/patientMergeRequest/index` |
| Pharmacy worklist | `/OphDrPrescription/OphDrPrescriptionPharmacyWorklist/default/index/` |
| Practices | `/practice/index` |
| Practitioners | `/gp/index` |
| Reports | `/report` |
| Request Form worklist | `/OphCoRequestForm/worklist/index` |
| Safeguarding | `/Safeguarding/index/` |
| Theatre Diaries | `/OphTrOperationbooking/theatreDiary/index` |
| Therapy Application worklist | `/OphCoTherapyapplication/worklist/index` |
| Trials | `/OETrial` |
| Virtual Clinic | `/PatientTicketing/default/?cat_id=1` |

Notable destination details: Add Patient - 'Create new patient' `[data-test="save-patient"]`. Reports - lands on "Diagnoses report"; 'Display report' `[data-test="display-report-button"]`, 'Download report' `[data-test="download-report-button"]`. Partial bookings - 'Print all' `#btn_print_all`, 'Print selected' `#btn_print`. Theatre Diaries - heading "Search schedules"; 'Print' `#btn_print_diary`, 'Print list' `#btn_print_diary_list`. Patient Merge - heading "Merge Requests"; Filter / Add / Delete `#rq_delete`. Practices - "Practices: viewing 1 - 20 of 271", 'Create Practice'; rows -> `/practice/view/:id`. Practitioners - 'Add'; rows -> `/gp/view/:id`. Genetics - heading "Patients", Search `[data-test="search_bnt"]`. Virtual Clinic / Internal referrals (PatientTicketing) - per-ticket 'Review Patient' / 'Open record' `[data-test="ticket-action"]`. List pages paginate with `[data-test="pagination-previous|next"]`.

Real field-level docs (filter fields, buttons, selectors) for all 20 one-page utility screens above plus Practices/Practitioners/Trials/Virtual Clinic are in `subs/app-forms.md` - check there before reading the module's controller/view PHP or probing by hand.

## Patient search -> patient summary

- `/` is the search screen; the top toolbar also carries a patient-search field on every page. Accepts surname ("SMITH" / "SMITH, John"), hospital number, NHS number. Result rows have **no href** - they open via a JS row-click (true of most OE list rows). Sample patient 17891 is "BLACKWELL, Elizabeth (Mrs)".
- Patient summary `/patient/summary/:id`, heading "Patient Overview": episodes sidebar (left), event timeline (per-episode, dated entries like "8Dec2017 GL"), summary panels (medications, procedures, management summaries), 'Previous <subspecialty> Summaries' `[data-test="get-past-summaries-btn"]`.
- **Add Event** button `#add-event` / `[data-test="add-new-event-button"]` lives on the patient summary.
- **`/patient/summary/:id` is the only patient-record route.** Two plausible-looking neighbours are dead and both 404 - `/patient/episode/<episode_id>` and `/patient/episodes/<patient_id>` (no `actionEpisode`/`actionEpisodes` exists; the `episodes.php` view they would render is dead code). Never route a repro step through them.
- **Change of context** is a screen, not just a header tab: `protected/views/patient/change_event_context.php` reuses the Add Event dialog class in a `ChangeContext` mode and lists workflow steps fetched from `/ChangeEvent/findWorkflowSteps`. It is reached from an event's 'Change Context' header tab (below) and appears in neither `subs/page-index.md` nor the section above - probe it rather than assuming a URL.
- **Lightning viewer** (event preview browser, verified v11.0.18): lightning-bolt icon in the patient sidebar (`a.lightning-viewer-icon`) -> `/patient/lightningViewer?id=<pid>`; per-event timeline icons `span.js-lightning-view-icon` select an event. Selecting one whose preview is missing/stale fires `GET /eventImage/getImageInfo?event_id=` and generates the preview server-side; the episode-sidebar quick-look and an event's print view drive the same generation, and previews rebuild after the event is modified.

## Add Event dialog -> create pages

Dialog has three columns: **Subspecialties** (episode list + 'Add New Subspecialty'), **Context** (service/firm within the subspecialty), **'Select New Event'** - one flat alphabetical list of event types (filtered by subspecialty at runtime; there are no event groups). Quirks:

- The dialog body is a Mustache template (`<script type="text/html" id="add-new-event-template">`) - not in the live DOM until opened. Items are `li.oe-event-type[data-eventtype-id]`, **no href**; the create URL is built in JS. Item hooks by version: v11.0.18 has `#<Module>-link` (e.g. `#OphCoDocument-link`); develop/26.x adds `[data-test="add-new-event-<Module>"]`. 'Add New Subspecialty' is `#js-add-subspecialty-btn`.
- Create URL shape: `/patientEvent/create?patient_id=<pid>&event_type_id=<id>&context_id=<ctx>&episode_id=<ep>` - needs **both** `context_id` and a matching `episode_id`, else HTTP 400 "Episode/Context mismatch". Four more parameters exist and the dialog uses all of them: `service_id` (sent *instead of* `episode_id` when the dialog added a brand-new subspecialty, and *alongside* it when the episode's service dropdown is used), `event_subtype`, and the pair `step_id` + `worklist_patient_id` - the last is how a worklist pathway step opens an event **without the dialog ever appearing**, so a worklist repro does not start at the patient summary. Its other error responses, worth quoting in a repro: 400 on a missing `context_id`/`event_type_id`, 403 "Permission denied for creating event type.", 422 "Firm mismatch for service with existing Episode for patient".
- **Support Services is a dead end in the dialog.** For a patient with a support-services episode the Subspecialties column carries a `Support Services` tile (`data-subspecialty-id="SS"`); selecting it yields an empty Context column and the event list never appears (BUG-128). Users read it as a broken dialog - it is worth naming in any repro that lands near it.
- **Add Event button states** (the button is `#add-event` inside `nav#add-event-sidebar`): disabled reading 'You have View Only rights' in the episode sidebar when the patient is deceased or `OprnCreateEpisode` is absent, and disabled reading 'You have View Only rights and cannot create events' on the no-episodes landing page. **The two disabled labels differ** - assert the right one for the page you are on. Don't call it "the green Add Event button": the markup is `class="button green add-event"` but the computed background is slate grey on every patient tested. Describe controls by label and position, never by a colour taken from a class name.
- **Probing: skip the dialog, `goto` the create URL directly.** A `#<Module>-link` only becomes clickable once a subspecialty *and* a context are chosen; clicking one cold **silently no-ops** - the probe just sees the dialog unchanged (a real dead-end, not a bad selector). **DB is the fallback, not the first stop:** on a sample box try the recorded 17891 pairs below first - a wrong/stale pair fails fast and loud (the 400 above), so guessing costs one `goto`; `event_type_id`s are already in the table above. Query the DB (via `c-dblogin`) only after a 400 or when the repro needs a data-shaped patient ("a patient with ..."): `SELECT id, firm_id FROM episode WHERE patient_id=<pid> AND deleted=0` - `firm_id` is the `context_id`, `id` the `episode_id`; `event_type_id` is `SELECT id FROM event_type WHERE class_name='<Module>'`.
- Sample patient 17891 pairs (captured on develop; stock sample seeds usually match): General Ophthalmology ctx 13 / ep 601038, Glaucoma ctx 8 / ep 601039, Eye Casualty ctx 2 / ep 601040.

All 23 event types on develop/26.x ('Select New Event' label -> `event_type_id`, module). On v11.0.18 the dialog showed 20 - DNA sample, Genetic Results and Medical Device Usage Record were absent (later additions and/or subspecialty-filtered; confirm on the target version before citing them). **Any "N event types" claim needs the qualifier "offerable" or "visible to this role".** 23 is the *offerable* set: `getEventTypeModules()` requires `parent_id IS NULL`, so DNA extraction (`event_type` 46, `parent_id` 45) never reaches the dialog despite being registered and manually creatable. What a given account sees is fewer still: `admin` on the stock role set sees 21, because DNA sample and Genetic Results are gated on `$api->createOprn` (`OprnEditDnaSample`, `OprnEditGeneticResults`) rather than the usual `OprnCreate<rbac_operation_suffix>` pattern, and no sample user holds a Genetics role. Grant the Genetics roles and the same account sees all 23 (live-checked 2026-08-05) - but **not in the session that was already open**: `views/patient/add_new_event.php:113-114` wraps the list in `beginCache('add_event_dialog_event_type_list', duration 3600, varyBySession true)`, so after any role change log out and back in (or start a fresh probe session) before concluding the grant did not work. The `rbac_operation_suffix` column is a red herring here - the three genetics modules all override `createOprn`, and `CreateEventControllerBehavior::getCreateArgsForEventTypeOprn()` prefers the override, so the suffix is never read for the only three rows that have one. The dialog lists only what the signed-in user may create, so a missing type is a permission signal, not a bug:

| Label | id | Module |
|---|---|---|
| Biometry | 37 | OphInBiometry |
| CVI | 23 | OphCoCvi |
| Cat-PROM5 | 42 | OphOuCatprom5 |
| Checklist | 50 | OphCoChecklist |
| Consent form | 32 | OphTrConsent |
| Correspondence | 26 | OphCoCorrespondence |
| DNA sample | 45 | OphInDnasample |
| Did Not Attend | 41 | OphCiDidNotAttend |
| Document | 40 | OphCoDocument |
| Drug Administration | 48 | OphDrPGDPSD |
| Examination | 27 | OphCiExamination |
| Genetic Results | 47 | OphInGeneticresults |
| Intravitreal injection | 33 | OphTrIntravitrealinjection |
| Lab Results | 39 | OphInLabResults |
| Laser | 20 | OphTrLaser |
| Medical Device Usage Record | 51 | TrDeviceUsageRecord |
| Message | 38 | OphCoMessaging |
| Operation booking | 30 | OphTrOperationbooking |
| Operation note | 4 | OphTrOperationnote |
| Phasing | 31 | OphCiPhasing |
| Prescription | 14 | OphDrPrescription |
| Request Form | 49 | OphCoRequestForm |
| Therapy Application | 35 | OphCoTherapyapplication |

Create-form field labels for all 23 event types above are in `subs/event-forms.md` - one section each (label, selector, type, required-ness, default/pre-fill), read from the view PHP on `develop` and live-checked against the running app. Check there before reading `protected/modules/<Module>/views/default/form_*.php` or probing by hand.

## Event view / edit / delete

- View: `/<Module>/default/view/:id`; edit: `/<Module>/default/update?id=<id>` (verified v11.0.18; also seen path-style `/update/:id`). Event header tabs (verified v11.0.18): 'View' `[data-test="button-event-header-tab-view"]`, 'Edit' `[data-test="button-event-header-tab-edit"]`, 'Change Context' `[data-test="button-event-header-tab-change-context"]`, delete `#js-delete-event-btn`. The **print icon** sits in the same top-right icon row (icon-only - describe by position in PR steps; probe for the selector when needed).
- Delete flow: confirm with 'Yes - DELETE Event' `[data-test="delete-event"]`, cancel `#et_canceldelete`. Operation booking views add 'Put on Hold' `#et_put_on_hold` / `#et_cancel_put_on_hold`. Save on create/edit forms is `#et_save`.
- Episode sidebar subspecialty letters (GL, CA, ...) link to OEscape charts `/patient/oescape?subspecialty_id=<id>&patient_id=<pid>`.
- Rich sample event views on 17891 (all Glaucoma episode): Examination `/OphCiExamination/default/view/3686607`, Correspondence `.../3686608`, Operation note `/OphTrOperationnote/default/view/3686606`, Consent `/OphTrConsent/default/view/3686605`, Operation booking `.../3686604`, Laser `/OphTrLaser/default/view/3686602`, Prescription `/OphDrPrescription/default/view/3686592`, Message `/OphCoMessaging/default/view/3686590`, Biometry `/OphInBiometry/default/view/3686331`, Generic/Visual Fields `/OphGeneric/default/view/3686718`.
- Need a sample event id beyond that list? `grep '^| patient-record\|^| patient-summary' subs/page-index.md` already enumerates every event-view URL/heading reachable from 17891's timeline - check there before re-probing one by hand.
- Real field-level docs (section headings, fields, buttons) for the 10 distinct event-view module templates behind those 24 crawled pages are in `subs/app-forms.md`'s "Patient record - event views" section - check there before reading `protected/modules/<Module>/views/default/view.php` or probing by hand.

## Worklist (clinic manager)

Single-URL app at `/worklist/view` - every sub-view is an in-page panel/tab/dialog state:

- **Filter panel is open by default.** The toolbar button `#js-nav-worklist-btn` *toggles* it - clicking once **closes** it. Drive the tabs directly: `[data-subpanel="lists"|"recent"|"starred"]` (Lists / Recent / Favourites); on v11.0.18 the tabs dump as 'Lists', 'Recent' `[data-test="worklist-mode-recent-tab"]`, starred `[data-test="worklist-mode-starred"]`.
- Filter controls (verified v11.0.18): site/context selects `[data-test="worklist-filter-panel-select-site|context"]`, 'from'/'to' date inputs, 'All', `[data-test="combine-lists-option"]` checkbox, 'Name filter' search box, 'Reset to defaults', 'Show patient pathways' `[data-test="show-patient-pathways"]`, print `#et_print`.
- Add-filter adder `[data-test="add-filter"]`, close `[data-test="close-worklist-adder-btn"]`; adder categories: Lists, Sort by, Categories, Assigned To, Steps, To-do, Age range, Red flags, Priority, Status, Wait time. Save favourite `[data-test="save-favourite-filter"]`; filter popup close `[data-test="worklist-filter-popup-close-icon-btn"]`.
- Hotlist panel (toolbar): Find Patient, Drafts toggle, row-click opens the patient.
- Auto-sync popup `[data-test="sync-btn"]`: 'Sync: 30 Seconds' / '1 Minute' / '5 Minutes' / '10 Minutes' `[data-test="sync-30|60|300|600"]`, 'Stop Auto Sync' `[data-test="sync-off"]`.
- The menu's Pharmacy / Request Form / Therapy Application worklists are separate module pages (see menu table), not states of this one.

## Admin

- Menu > Admin -> `/admin` redirects to `/admin/users`. Sidebar `.oe-full-side-panel.admin-panels`, sections **alphabetical**, the current section expanded to show its pages (267 pages total across the 33 sections below - not the 390 figure elsewhere in this file, which is the whole-site crawl across all 62 areas, admin + non-admin).
- Core's pages (the most-touched admin area, verified v11.0.18): Users, Institutions, Sites, Teams, Subspecialty (+ Subsections), Contexts and Services, Patient Identifier Types, Patient Shortcodes, Contacts, Contact labels, Commissioning bodies (+ services, service types, body types), Data sources, Element/Event Type Custom Text, Event deletion requests, Ethnic Groups, Examination Event Logs, LDAP Configurations, PAS Configuration, SSO Configurations.
- Module sections use **module-prefixed** routes, not `/admin/...`: e.g. Examination `/OphCiExamination/admin/<Thing>`, plus `/oeadmin/...`, `/Admin/...`, `/sso/...`.
- Lookup-table admin pages follow one pattern: heading "Edit <Thing>s", rows with 'Add' `[data-test="add-row"]`, 'Save' `[data-test="save-rows"]` (some settings pages use `#et_admin-save`), delete per row `[data-test="delete-row"]`.
- A second generic pattern, seen across Biometry/Drugs/Examination/Operation Booking/PatientTicketing/Worklist lookup pages: multi-select rows + 'Add selected to current institution' / 'Remove selected from current institution' (some pages: 'Enable'/'Disable' instead of 'Add'/'Remove') - an institution-mapping variant of the same lookup-table pattern, not bespoke per-page behaviour.
- A third generic pattern, seen on Core's Commissioning bodies/services/types pages and CVI's Local Authorities: checkbox multi-select + a themed 'Remove <Thing>(s)' bulk button instead of per-row delete - same lookup-table pattern, bulk-delete variant.
- **Editing a system setting**: `/admin/editSystemSetting?key=<key>&class=SettingInstallation` is the working route - `/admin/editSetting` 500s. One trap that silently produces the wrong result: with an institution selected in the site/institution picker, a system admin editing an installation-level setting writes a `SettingInstitution` row instead of the installation value. Pick "All institutions" first, or the setting appears to save and does nothing elsewhere.
- Real field-level docs (label, selector, type, required-ness, default/pre-fill) for the ~88 admin pages with genuinely non-generic fields are in `subs/admin-forms.md`, one `###` per section (matching the table below) with a `####` per documented page. The other ~179 pages are the plain lookup-table pattern(s) above and don't get bespoke entries.
- All 33 sections, from the develop crawl (`UNRELEASED (develop - dev)`, 2026-06-25). Every page's exact URL, route and reach path is vendored in `subs/page-index.md` - `grep '^| admin/<section>' subs/page-index.md` before probing by hand. Regenerate both with `scripts/build-page-index.sh` when the crawl is refreshed.

| Section | Pages | Sitemap file |
|---|---|---|
| Allergies | 5 | `areas/admin__allergies.md` |
| Biometry | 2 | `areas/admin__biometry.md` |
| Checklists | 2 | `areas/admin__checklists.md` |
| Consent Form | 8 | `areas/admin__consent-form.md` |
| Core | 25 | `areas/admin__core.md` |
| Correspondence | 10 | `areas/admin__correspondence.md` |
| CVI | 10 | `areas/admin__cvi.md` |
| Disorders | 5 | `areas/admin__disorders.md` |
| Document | 1 | `areas/admin__document.md` |
| Drugs | 18 | `areas/admin__drugs.md` |
| Event Export | 1 | `areas/admin__event-export.md` |
| Examination | 77 | `areas/admin__examination.md` |
| Generic Event | 6 | `areas/admin__generic-event.md` |
| Genetics | 3 | `areas/admin__genetics.md` |
| Intravitreal Injection | 15 | `areas/admin__intravitreal-injection.md` |
| Investigation Management | 1 | `areas/admin__investigation-management.md` |
| Lab Results | 1 | `areas/admin__lab-results.md` |
| Laser | 3 | `areas/admin__laser.md` |
| Leaflets | 2 | `areas/admin__leaflets.md` |
| Medical Device Usage | 2 | `areas/admin__medical-device-usage.md` |
| Message | 2 | `areas/admin__message.md` |
| Operation Booking | 16 | `areas/admin__operation-booking.md` |
| Operation Note | 8 | `areas/admin__operation-note.md` |
| PASAPI | 1 | `areas/admin__pasapi.md` |
| PatientTicketing | 5 | `areas/admin__patientticketing.md` |
| Payload Processor API | 6 | `areas/admin__payload-processor-api.md` |
| Procedure Management | 9 | `areas/admin__procedure-management.md` |
| Referral | 2 | `areas/admin__referral.md` |
| Request Forms | 3 | `areas/admin__request-forms.md` |
| SSO Settings | 2 | `areas/admin__sso-settings.md` |
| System | 2 | `areas/admin__system.md` |
| Therapy Application | 7 | `areas/admin__therapy-application.md` |
| Worklist | 7 | `areas/admin__worklist.md` |
