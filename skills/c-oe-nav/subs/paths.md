# OE frontend paths — the hardcoded atlas

Pre-recorded navigation for the stock OpenEyes UI. Captured from a full crawl on `develop` (2026-06) and spot-verified on v11.0.18 (2026-07). The app's navigation is stable across versions — trust these paths, but source *in-form field labels* from the fix branch's view code or a probe (`subs/probe.md`), and never put sample ids/creds from this file into PR text.

## Reaching the app and logging in

- Find the web container: `docker ps` → `<stack>-web-1` (image `toukanlabsdocker/oe-web-live:<version>` — the tag is the running OE version). Its network is `<stack>_backend`; on that network the container answers as **`http://web`**.
- Login page `/site/login`: fields 'Username' (`#LoginForm_username`), 'Password' (`#LoginForm_password`), then Institution and Site pickers. The pickers are custom JS — the real `<select>`s are `display:none`, so automation must set the hidden `#LoginForm_institution_id` / `#LoginForm_site_id` and click `#login_button` (humans just use the pickers). Success lands on `/` (the patient search screen); still on `/site/login` = failed.
- Sample boxes: `admin`/`admin`, institution 1, site 1; the crawl admin holds all 66 roles. Patient search home; ~2284 sample patients; **patient 17891** has 129 events (the richest record).
- Running version: hover/read `#js-openeyes-info` in the header *after* login. Never trust `protected/version.txt`.

## Global chrome (every page)

- Main-menu (shortcuts) icon `#js-nav-shortcuts-btn` opens the panel `#js-nav-shortcuts-subnav`, heading "Main menu".
- Worklist toolbar button `#js-nav-worklist-btn` (a toggle — see Worklist), hotlist toolbar button (opens the hotlist side panel), theme toggles `#js-set-theme-light|dark|auto`.
- A hidden re-auth login form `#js-login` sits in every page's DOM — harmless; ignore it in dumps.
- Never wait for network-idle anywhere: OE long-polls (worklist sync, notifications).

## Main menu — 26 items

Top toolbar ▸ shortcuts icon. Each item is `#js-nav-shortcuts-subnav a[href="<url>"]`:

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

Notable destination details: Add Patient — 'Create new patient' `[data-test="save-patient"]`. Reports — lands on "Diagnoses report"; 'Display report' `[data-test="display-report-button"]`, 'Download report' `[data-test="download-report-button"]`. Partial bookings — 'Print all' `#btn_print_all`, 'Print selected' `#btn_print`. Theatre Diaries — heading "Search schedules"; 'Print' `#btn_print_diary`, 'Print list' `#btn_print_diary_list`. Patient Merge — heading "Merge Requests"; Filter / Add / Delete `#rq_delete`. Practices — "Practices: viewing 1 - 20 of 271", 'Create Practice'; rows → `/practice/view/:id`. Practitioners — 'Add'; rows → `/gp/view/:id`. Genetics — heading "Patients", Search `[data-test="search_bnt"]`. Virtual Clinic / Internal referrals (PatientTicketing) — per-ticket 'Review Patient' / 'Open record' `[data-test="ticket-action"]`. List pages paginate with `[data-test="pagination-previous|next"]`.

## Patient search → patient summary

- `/` is the search screen; the top toolbar also carries a patient-search field on every page. Accepts surname ("SMITH" / "SMITH, John"), hospital number, NHS number. Result rows have **no href** — they open via a JS row-click (true of most OE list rows). Sample patient 17891 is "BLACKWELL, Elizabeth (Mrs)".
- Patient summary `/patient/summary/:id`, heading "Patient Overview": episodes sidebar (left), event timeline (per-episode, dated entries like "8Dec2017 GL"), summary panels (medications, procedures, management summaries), 'Previous <subspecialty> Summaries' `[data-test="get-past-summaries-btn"]`.
- **Add Event** button `#add-event` / `[data-test="add-new-event-button"]` lives on the patient summary.
- **Lightning viewer** (event preview browser, verified v11.0.18): lightning-bolt icon in the patient sidebar (`a.lightning-viewer-icon`) → `/patient/lightningViewer?id=<pid>`; per-event timeline icons `span.js-lightning-view-icon` select an event. Selecting one whose preview is missing/stale fires `GET /eventImage/getImageInfo?event_id=` and generates the preview server-side; the episode-sidebar quick-look and an event's print view drive the same generation, and previews rebuild after the event is modified.

## Add Event dialog → create pages

Dialog has three columns: **Subspecialties** (episode list + 'Add New Subspecialty'), **Context** (service/firm within the subspecialty), **'Select New Event'** — one flat alphabetical list of event types (filtered by subspecialty at runtime; there are no event groups). Quirks:

- The dialog body is a Mustache template (`<script type="text/html" id="add-new-event-template">`) — not in the live DOM until opened. Items are `li.oe-event-type[data-eventtype-id]`, **no href**; the create URL is built in JS. Item hooks by version: v11.0.18 has `#<Module>-link` (e.g. `#OphCoDocument-link`); develop/26.x adds `[data-test="add-new-event-<Module>"]`. 'Add New Subspecialty' is `#js-add-subspecialty-btn`.
- Create URL shape: `/patientEvent/create?patient_id=<pid>&event_type_id=<id>&context_id=<ctx>&episode_id=<ep>` — needs **both** `context_id` and a matching `episode_id`, else HTTP 400 "Episode/Context mismatch".
- **Probing: skip the dialog, `goto` the create URL directly.** A `#<Module>-link` only becomes clickable once a subspecialty *and* a context are chosen; clicking one cold **silently no-ops** — the probe just sees the dialog unchanged (a real dead-end, not a bad selector). **DB is the fallback, not the first stop:** on a sample box try the recorded 17891 pairs below first — a wrong/stale pair fails fast and loud (the 400 above), so guessing costs one `goto`; `event_type_id`s are already in the table above. Query the DB (via `c-dblogin`) only after a 400 or when the repro needs a data-shaped patient ("a patient with …"): `SELECT id, firm_id FROM episode WHERE patient_id=<pid> AND deleted=0` — `firm_id` is the `context_id`, `id` the `episode_id`; `event_type_id` is `SELECT id FROM event_type WHERE class_name='<Module>'`.
- Sample patient 17891 pairs (captured on develop; stock sample seeds usually match): General Ophthalmology ctx 13 / ep 601038 · Glaucoma ctx 8 / ep 601039 · Eye Casualty ctx 2 / ep 601040.

All 23 event types on develop/26.x ('Select New Event' label → `event_type_id`, module). On v11.0.18 the dialog showed 20 — DNA sample, Genetic Results and Medical Device Usage Record were absent (later additions and/or subspecialty-filtered; confirm on the target version before citing them):

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

Create-form field labels are **not** in this atlas — read them from `protected/modules/<Module>/views/default/form_*.php` on the fix branch, or probe. One exception, recorded because repros keep landing on it:

### Document create form (OphCoDocument, event_type_id 40) — verified live v11.0.18 (2026-07)

The trigger path for the PDF/render temp-file bug family (`oe_pdf` stubs, `magick-*` pixel cache): upload a PDF, then build its page previews.

- 'Event Sub Type' dropdown `#Element_OphCoDocument_Document_event_sub_type` (empty option '-- Select --'; options from `ophcodocument_sub_types` — sample id 1 = "General").
- 'Upload' row radios: 'Single file' `#upload_single` (checked by default) · 'Right/Left sides'.
- File input `#Document_single_document_row_id` (`.js-document-file-input`) is `display:none` — the probe's upload action works on it anyway. Drop-zone label: "Click to select file, DROP here or press Ctrl + V to paste".
- In-container test PDF (web-live ships ghostscript; one `showpage` per page): `gs -q -o /tmp/twopage.pdf -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=300 -dDEVICEHEIGHTPOINTS=300 -c "showpage showpage"`.
- 'Save' `#et_save` → lands on `/OphCoDocument/default/view/<event_id>` — take the id from the URL for endpoint work.
- Page previews build server-side (`createPdfPreviewImages()`): fire logged-in `GET /eventImage/getImageInfo?event_id=<id>` (the same path the lightning-viewer icon fires) and re-fire after a few seconds until the JSON shows `page_count`. Temp-leak pairing: `docker exec <stack>-web-1 sh -c 'ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l'` before/after.

## Event view / edit / delete

- View: `/<Module>/default/view/:id`; edit: `/<Module>/default/update?id=<id>` (verified v11.0.18; also seen path-style `/update/:id`). Event header tabs (verified v11.0.18): 'View' `[data-test="button-event-header-tab-view"]`, 'Edit' `[data-test="button-event-header-tab-edit"]`, 'Change Context' `[data-test="button-event-header-tab-change-context"]`, delete `#js-delete-event-btn`. The **print icon** sits in the same top-right icon row (icon-only — describe by position in PR steps; probe for the selector when needed).
- Delete flow: confirm with 'Yes - DELETE Event' `[data-test="delete-event"]`, cancel `#et_canceldelete`. Operation booking views add 'Put on Hold' `#et_put_on_hold` / `#et_cancel_put_on_hold`. Save on create/edit forms is `#et_save`.
- Episode sidebar subspecialty letters (GL, CA, …) link to OEscape charts `/patient/oescape?subspecialty_id=<id>&patient_id=<pid>`.
- Rich sample event views on 17891 (all Glaucoma episode): Examination `/OphCiExamination/default/view/3686607`, Correspondence `.../3686608`, Operation note `/OphTrOperationnote/default/view/3686606`, Consent `/OphTrConsent/default/view/3686605`, Operation booking `.../3686604`, Laser `/OphTrLaser/default/view/3686602`, Prescription `/OphDrPrescription/default/view/3686592`, Message `/OphCoMessaging/default/view/3686590`, Biometry `/OphInBiometry/default/view/3686331`, Generic/Visual Fields `/OphGeneric/default/view/3686718`.

## Worklist (clinic manager)

Single-URL app at `/worklist/view` — every sub-view is an in-page panel/tab/dialog state:

- **Filter panel is open by default.** The toolbar button `#js-nav-worklist-btn` *toggles* it — clicking once **closes** it. Drive the tabs directly: `[data-subpanel="lists"|"recent"|"starred"]` (Lists / Recent / Favourites); on v11.0.18 the tabs dump as 'Lists', 'Recent' `[data-test="worklist-mode-recent-tab"]`, starred `[data-test="worklist-mode-starred"]`.
- Filter controls (verified v11.0.18): site/context selects `[data-test="worklist-filter-panel-select-site|context"]`, 'from'/'to' date inputs, 'All', `[data-test="combine-lists-option"]` checkbox, 'Name filter' search box, 'Reset to defaults', 'Show patient pathways' `[data-test="show-patient-pathways"]`, print `#et_print`.
- Add-filter adder `[data-test="add-filter"]`, close `[data-test="close-worklist-adder-btn"]`; adder categories: Lists, Sort by, Categories, Assigned To, Steps, To-do, Age range, Red flags, Priority, Status, Wait time. Save favourite `[data-test="save-favourite-filter"]`; filter popup close `[data-test="worklist-filter-popup-close-icon-btn"]`.
- Hotlist panel (toolbar): Find Patient, Drafts toggle, row-click opens the patient.
- Auto-sync popup `[data-test="sync-btn"]`: 'Sync: 30 Seconds' / '1 Minute' / '5 Minutes' / '10 Minutes' `[data-test="sync-30|60|300|600"]`, 'Stop Auto Sync' `[data-test="sync-off"]`.
- The menu's Pharmacy / Request Form / Therapy Application worklists are separate module pages (see menu table), not states of this one.

## Admin

- Menu ▸ Admin → `/admin` redirects to `/admin/users`. Sidebar `.oe-full-side-panel.admin-panels`, sections **alphabetical**, the current section expanded to show its pages (~267 pages total on develop).
- Sections (30, verified v11.0.18; develop's crawl had 33): Biometry · CVI · Checklists · Consent form · Core · Correspondence · Disorders · Document · Drugs · Event Export · Examination · Generic event · Genetics · Intravitreal injection · Investigation management · Lab results · Laser · Leaflets · Message · Operation booking · Operation note · PASAPI · PatientTicketing · Payload processor API · Procedure management · Request forms · SSO settings · System · Therapy application · Worklist.
- Core's pages (the most-touched admin area, verified v11.0.18): Users · Institutions · Sites · Teams · Subspecialty (+ Subsections) · Contexts and Services · Patient Identifier Types · Patient Shortcodes · Contacts · Contact labels · Commissioning bodies (+ services, service types, body types) · Data sources · Element/Event Type Custom Text · Event deletion requests · Ethnic Groups · Examination Event Logs · LDAP Configurations · PAS Configuration · SSO Configurations.
- Module sections use **module-prefixed** routes, not `/admin/…`: e.g. Examination `/OphCiExamination/admin/<Thing>`, plus `/oeadmin/...`, `/Admin/...`, `/sso/...`.
- Biggest sections: examination (77 pages), core (25), drugs (18), operation-booking (16), intravitreal-injection (15), correspondence and cvi (10 each).
- Lookup-table admin pages follow one pattern: heading "Edit <Thing>s", rows with 'Add' `[data-test="add-row"]`, 'Save' `[data-test="save-rows"]` (some settings pages use `#et_admin-save`), delete per row `[data-test="delete-row"]`.
- When `~/oe-frontend-tests/docs/sitemap/` exists, `areas/admin__<section>.md` lists every page in a section with its exact URL and heading — use it as an accelerator; otherwise probe.
