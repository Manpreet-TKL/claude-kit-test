# Admin pages - real field-level docs

Field-level docs (label, selector, type, required-ness, default/pre-fill) for the admin pages with genuinely non-generic fields, written from `develop` controller/view code and live-checked (v11.0.18) on 2026-07-24 - same convention as `event-forms.md`: where the live check found a real mismatch it's recorded as a **Live check** note rather than silently corrected. One `###` per admin section (33 total, same order as `paths.md`'s pointer table), one `####` per documented page. Sections with no non-generic pages get a one-line entry pointing at the generic pattern(s) in `paths.md` and the crawl file - see there for the full page list.

### Allergies

All 5 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__allergies.md`.

### Biometry (2 pages total, 2 documented below)

**Blind-spot check (2026-07-24):** Lens types page has conditional display of Add/Deactivate/institution-mapping buttons based on $this->checkAccess('admin') check, but list view itself is universally accessible.

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__biometry.md`.

#### IOL Master Import Log Viewer

Displays DICOM biometry file import log with search and filtering via DicomLogViewerController; results render asynchronously into mustache templates from API response.

- 'Station ID' <text> `#station_id` (optional)
- 'Location' <text> `#location` (optional, like search)
- 'Patient Number' <text> `#hos_num` (optional)
- 'Status' <select> `#status` (optional: All, success, failed)
- 'Type' <select> `#type` (optional: All types, biometry)
- 'Study Instance ID' <text> `#study_id` (optional, autocomplete widget, like search)
- 'File name' <text> `#file_name` (optional, autocomplete widget, like search)
- 'Date type' <radio> `input[name="date_type"]` (default: 2 for Study date; options: 1=Import date, 2=Study date)
- 'From' <date> `#date_from` (optional)
- 'To' <date> `#date_to` (optional)

Save: Submits via AJAX POST to /DicomLogViewer/search with serialized form data; API returns JSON with data array; renders each row via mustache.render() into #dicom-file-list tbody; no server-side validation error messages in response.

#### Lens types

Administers IOL lens types for biometry calculations with optional assignment to current institution via OphInBiometry_LensType_Lens model; search filters by name, display name, description, ACON, or ID.

- 'Name' <text> `#OphInBiometry_LensType_Lens_name` (required)
- 'Display Name' <text> `#OphInBiometry_LensType_Lens_display_name` (required)
- 'Description' <text> `#OphInBiometry_LensType_Lens_description` (required)
- 'Position' <select> `#OphInBiometry_LensType_Lens_position_id` (required, empty: "- Select Grade -", populated from OphInBiometry_Lens_Position order by display_order)
- 'Comments' <text> `#OphInBiometry_LensType_Lens_comments` (optional)
- 'A constant' <text> `#OphInBiometry_LensType_Lens_acon` (required, ACON value for calculations)
- 'SF' <text> `#OphInBiometry_LensType_Lens_sf` (optional, Surgeon Factor)
- 'pACD' <text> `#OphInBiometry_LensType_Lens_pACD` (optional, predicted Anterior Chamber Depth, alternative to SF)
- 'a0' <text> `#OphInBiometry_LensType_Lens_a0` (optional, regression coefficient)
- 'a1' <text> `#OphInBiometry_LensType_Lens_a1` (optional, regression coefficient)
- 'a2' <text> `#OphInBiometry_LensType_Lens_a2` (optional, regression coefficient)
- 'Active' <checkbox> `#OphInBiometry_LensType_Lens_active` (optional, default: unchecked)

Save: POST to /OphInBiometry/lensTypeAdmin/edit; saves OphInBiometry_LensType_Lens attributes; validation errors display on form; redirects to /OphInBiometry/lensTypeAdmin/list on success.

**Live check (2026-07-24) - discrepancy:** original write pass gave no selectors and marked Position optional. Model `rules()` lists `position_id` in the same required group as name/display_name/description/acon (`OphInBiometry_LensType_Lens.php:97`), so Position is required, not optional - the view shows no visual asterisk, so this is silent server-side-only validation. Selectors above are standard Yii `activeTextField`/`activeDropDownList`/`activeCheckBox` ids from `views/admin/edit.php`, confirmed against source (not independently re-probed live).

### Checklists (2 pages total, 2 documented below)

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__checklists.md`.

#### Categories

Manages checklist categories via ChecklistCategory model; categories provide organizational grouping for checklist types and are referenced during checklist configuration.

- 'Category Name' <text> `#ChecklistCategory_name` (optional per model rules, no explicit server validation)

Save: POST to /OphCoChecklist/Admin/EditCategory; creates or updates ChecklistCategory record; flashes success message 'ChecklistCategory Edited' or 'ChecklistCategory Created'; redirects to /OphCoChecklist/Admin/viewCategories on success.

#### Checklists

Manages checklist types with multi-level contextual assignment (institutions, sites, subspecialties, firms) via ChecklistType model; each checklist associates multiple categories and defines section structure.

- 'Checklist Full Name' <text> `#ChecklistType_checklist_long_title` (required)
- 'Checklist Short Name' <text> `#ChecklistType_checklist_short_title` (required, max 50 chars)
- 'Display Layout Flow' <select> `#ChecklistType_display_tile_columns` (required: 0=Columns (auto), 1=Stack vertically, 2=Two column layout)
- 'Is Active' <checkbox> `#ChecklistType_is_active` (optional)
- 'Categories' <multi-select> (optional, searches ChecklistCategory list)
- 'Institutions' <multi-select> (optional, searches Institution list)
- 'Sites' <multi-select> (optional, searches Site list filtered by selected institution)
- 'Subspecialties' <multi-select> (optional, searches Subspecialty list)
- 'Firm' <multi-select> (optional, searches Firm list filtered by selected institution)

Save: POST to /OphCoChecklist/Admin/EditChecklist; creates or updates ChecklistType and all relationship associations; flashes 'Checklist Edited' or 'Checklist Created' on success; redirects to /OphCoChecklist/Admin/viewChecklists.

**Live check (2026-07-24) - discrepancy:** the multi-select dropdowns (Categories/Institutions/Sites/Subspecialties/Firm) have no usable id/name selector - confirmed both live (`#categories`/`#institutions` match zero elements) and in source. `views/admin/update_checklist.php` passes `'id' => 'categories'` etc. into the `MultiSelectDropDownList` widget, but `MultiSelectDropDownList::renderDropDown()` (`protected/widgets/MultiSelectDropDownList.php:59-74`) ignores the `id` option entirely and renders via `CHtml::dropDownList((string) $name, ...)` with `$name` hardcoded `null` - so the option key each view passes is silently dropped. A driver has to fall back to structural selectors (e.g. row order within `.js-multiselect-dropdown-wrapper`), not the ids implied by the widget config.

### Consent Form (8 pages total, 3 documented below)

The other 5 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__consent-form.md`.

#### Extra Procedures

Searchable listing and deletion interface for extra procedures (surgical procedures used in consent forms) backed by OphTrConsent/oeadmin/ExtraProceduresController::actionList() displaying OphTrConsent_Extra_Procedure models.

- 'Search' text input `input[name="search[query]"]` (optional, searches Term/Snomed Code/OPCS Code/Default Duration/Aliases across all procedures, placeholder text describes searchable fields)
- 'Active' dropdown filter `select[name="search[active]"]` (optional, values: '' for all, '1' for only active, '0' for exclude active)
- 'Search' button `button#et_search` (submits POST to /OphTrConsent/oeadmin/ExtraProcedures/list)
- 'Add' button (blue, navigates to /OphTrConsent/oeadmin/ExtraProcedures/edit for new procedure creation, only when no rows selected)
- 'Delete' button `button#et_delete` (red, disabled by default until checkbox rows selected, submits POST to /OphTrConsent/oeadmin/ExtraProcedures/delete)

Procedures table shows columns: checkbox select, Term, Snomed Code, Aliases, Has Benefits (comma-separated benefit names), Has Complications (comma-separated complication names). Each row is clickable to edit. Pagination controls shown in footer if results exceed items per page (30).

Save: Search filters results via POST to same URL. Delete removes selected procedures if not referenced elsewhere; deletion fails if procedure is used in procedure-subspecialty assignments or additional consent assignments (error message: 'Procedure cannot be deleted. Other tables depend on it.').

#### Supplementary Consent

Searchable listing and nested display interface for supplementary consent questions and their institutional/site assignments backed by OphTrConsent/oeadmin/SupplementaryConsentController::actionList() displaying Ophtrconsent_SupplementaryConsentQuestion models with nested Ophtrconsent_SupplementaryConsentQuestionAssignment details.

- 'Search' text input `input[name="search[query]"]` (optional, searches question name/description/text, answer name/description/text, and institution/site/subspecialty/form names across all questions and assignments; case-insensitive)
- 'Active' dropdown filter `select[name="search[active]"]` (optional, values: '' for all, '1' for only active assignment contexts, '0' for exclude active)
- 'Search' button `button#et_search` (submits POST to /OphTrConsent/oeadmin/SupplementaryConsent/list)
- 'Add' button (blue, navigates to /OphTrConsent/oeadmin/supplementaryConsent/edit for new question creation)

Questions table shows columns: Name (required, up to 255 chars), Description (optional, text), Question Type (read-only, link to question type), and expanded Question Assignments nested table per question showing: Question Text (wording used in forms), Required (yes/no flag), Override Level (institution/site/subspecialty/firm), Applies Only to Form (form type or blank). If no assignments exist for a question, displays: 'No current wording assigned - Question cannot be used.' Each question row is clickable to edit.

Save: Search filters results via POST to same URL. Filter by active status applies to question assignments only (if 'Active' is set, only shows questions with active assignments matching the filter value).

#### Template

Searchable listing and deletion interface for consent form templates backed by OphTrConsent/oeadmin/TemplateController::actionList() displaying OphTrConsent_Template models.

- 'Search Name' text input `input[name="searchQuery"]` (optional, searches template ID or name via numeric or text match)
- 'Institution' dropdown filter `select[name="institution"]` (optional, empty=all institutions, 'None'=null institution, otherwise specific institution ID)
- 'Site' dropdown filter `select[name="site"]` (optional, empty=all sites, 'None'=null site, otherwise specific site ID)
- 'Subspecialty' dropdown filter `select[name="subspecialty"]` (optional, empty=all subspecialties, 'None'=null subspecialty, otherwise specific subspecialty ID)
- 'Search' button `button#search-button` (submits GET to /OphTrConsent/oeadmin/Template/list)
- 'Add' button (blue, navigates to /OphTrConsent/oeadmin/Template/add for new template creation)
- 'Delete' button `button#et_delete_template` (red, deletes checkbox-selected templates via AJAX POST to /OphTrConsent/oeadmin/Template/delete)

Templates table shows columns: checkbox select, Id, Name, Institution (institution name or blank), Site (site name or blank), Subspecialty (subspecialty name or blank), Type (consent type name or blank). Each row is clickable to edit template. Pagination controls shown in footer if results exceed items per page (30).

Save: Search filters results via GET to same URL, filters applied server-side in actionList(). Delete removes selected templates via AJAX; all referenced template procedures are deleted first. On deletion failure, error message displayed in alert box (.js-admin-errors shows errors). On success, page reloads.

### Core (25 pages total, 9 documented below)

**Blind-spot check (2026-07-24):** TeamController depends on OphDrPGDPSD module API retrieval (beforeAction); Teams page will load but may lack user-selection features if module unavailable. No detected feature flags or conditional redirects gating Core listing pages; actionIndex redirects to first accessible page category if Users page not accessible.

The other 16 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__core.md`.

#### Element Type Custom Text

Manages custom hint text displayed alongside element types in clinical events. Backed by AdminController::actionEditElementTypeCustomText() + view admin/custom_text.php.

- 'Custom text block' <textarea> `.custom-text-field` (optional, default: empty; present in raw HTML, renders with TinyMCE editor - see Live check below)

Save: POST to same URL; updates each element type's custom_hint_text field; displays validation errors via _form_errors partial if model save fails.

**Live check (2026-07-24) - discrepancy:** `.custom-text-field` is present in `views/admin/custom_text.php`'s `CHtml::activeTextArea` output, but TinyMCE (`tinymce.init({selector: '.custom-text-field', ...})`) hides/replaces the original textarea on init, so `.custom-text-field` no longer resolves via a driver `waitForSelector`/`read` once the page has loaded - confirmed live (`Waiting for selector .custom-text-field failed` after a 2s wait, ~200 elements on this page). A prior automated verify pass on this same page wrongly reported "matched"; a follow-up spot-check with an actual selector probe (not just presence-in-dump) caught the discrepancy. There is no per-row `<label>` either - each row is one element type, distinguished only by its position in `table.standard tbody tr`, so a driver needs a row index, not a bare class selector.

#### Event Type Custom Text

Manages custom hint text and display position for event types. Backed by AdminController::actionEditEventTypeCustomText() + view admin/custom_text.php.

- 'Custom text block' <textarea> `.custom-text-field` (optional, default: empty; present in raw HTML, renders with TinyMCE editor - see Live check below)
- 'Display Position' <radio> `EventType_<id>_hint_position_0` (Top) / `EventType_<id>_hint_position_1` (Bottom), required

Save: POST to same URL; updates each event type's custom_hint_text and hint_position fields; displays validation errors via _form_errors partial if model save fails.

**Live check (2026-07-24) - discrepancy:** Display Position radios confirmed live with the ids given. `.custom-text-field` is present in `views/admin/custom_text.php`'s `CHtml::activeTextArea` output (this view is shared verbatim with Element Type Custom Text above), but TinyMCE hides/replaces the original textarea on init, so `.custom-text-field` no longer resolves via a driver `waitForSelector`/`read` once the page has loaded - same root cause and same fix as the Element Type Custom Text entry above; the original automated verify pass wrongly reported "matched" here too (confirmed only page-load and toolbar presence, not that the class selector itself still resolved).

#### Event deletion requests

Lists events pending deletion with approval/rejection controls; filters by institution. Backed by AdminController::actionEventDeletionRequests() + view event_deletion_requests.php.

- 'Institution' <select> `#select-institution` (optional, defaults to session selected_institution_id)

Save: No direct form submission. Approve button (id=et_approve) and Reject button (id=et_reject) trigger AJAX POST to actionApproveEventDeletionRequest and actionRejectEventDeletionRequest endpoints respectively; update event delete_pending flag and audit log. Errors result in HTTP exception responses.

#### Examination Event Logs

Lists automatic examination event logs with import status and search/filter controls. Backed by EventLogController::actionList() + view oeadmin/event_log/index.php.

- 'Search query' <text> `search[query]` (optional, searches event_id, unique_code, examination_date)
- 'Status' <select dropdown> `search[status_value]` (optional, filters by ImportStatus.status_value, empty = all)

Save: POST form search via search button (id=et_search); resubmits form to same action with filtered results. Delete button (id=et_delete) posts selected checkboxes to actionDelete endpoint.

#### Institutions

Lists institutions with search and filter controls; displays configured logos. Backed by AdminController::actionInstitutions() + view admin/institutions/index.php.

- 'Name/ID/Pas Code' <text> `search[name][value]` (optional, searches institution name, remote_id, short_name)
- 'Status' <select> `search[active]` (optional, filters: All, Only Active, Exclude Active)

Save: GET form submission to same action; reloads page with filter applied. Table rows are clickable (data-uri=admin/editinstitution); Add button (id=et_add) navigates to addInstitution.

#### Patient Identifier Types

Lists and manages patient identifier types configured per institution and site. Backed by PatientIdentifierTypeController::actionIndex() (protected/modules/Admin/controllers/PatientIdentifierTypeController.php, view: protected/modules/Admin/views/patientIdentifierType/index.php).

- 'Institution' <select> `#institution` (optional, default: empty/All)
- 'Site' <select> `#site` (optional, default: empty/All, populated from selected Institution)
- Search button <button> `#search-button` (submits form)

Save: Displays filtered list of patient identifier types; no form submission on this page (search/filter only).

**Live check (2026-07-24) - discrepancy:** Documentation correctly identifies Institution (#institution) and Site (#site) selects with proper defaults and Search button (#search-button). However, documentation claims 'no form submission on this page (search/filter only)' but the actual page contains Add Patient Identifier (#et_add) and Delete (#et_delete) buttons, plus checkboxes for selecting patient identifier types. These mutation controls are entirely undocumented and contradict the 'search/filter only' description.

#### Sites

Lists and manages healthcare sites with contact and address information. Backed by AdminController::actionSites() (protected/controllers/AdminController.php, view: protected/views/admin/sites/index.php).

- 'Search' <text input> `#search` (optional, searches by name, short_name, remote_id, postcode, address fields, city, county)

Save: Form submission searches/filters site list by entered criteria; clicking rows navigates to edit page (data-uri: admin/editsite?site_id=ID).

#### Teams

Lists and manages teams with members and inter-team relationships. Backed by TeamController::actionList() (protected/controllers/oeadmin/TeamController.php, view: protected/views/oeadmin/team/list.php); requires OphDrPGDPSD module API.

- 'Search Teams...' <text input> `#js-team-search` (optional, searches by team name, email, or ID)

Save: Form submission filters team list by search criteria; clicking rows navigates to edit page (data-uri: oeadmin/team/edit/ID); checkbox-selected teams can be deactivated via Deactivate Teams button.

#### Users

Lists and manages system users with roles, authentication methods, and access status. Backed by AdminController::actionUsers() (protected/controllers/AdminController.php, view: protected/views/admin/users.php).

- 'Search Users...' <text input> `#search` (optional, searches by first_name, last_name, user ID, or username)

Save: Form submission filters user list by search criteria; clicking rows navigates to edit page (data-uri: admin/editUser/ID); non-admin users see only institution-scoped users.

### Correspondence (10 pages total, 6 documented below)

**Blind-spot check (2026-07-24):** AdminController.php trait includes delivery config actions but not checked for conditional logic; email templates, sender addresses, and letter macros actions all render standard forms with no observed redirects or feature gates beyond institution tenancy checks.

The other 4 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__correspondence.md`.

#### Delivery Configurations

Displays and manages correspondence delivery configurations for electronic document output (PDF/XML); backed by the CorrespondenceDeliveryConfiguration model in the AdminForCorrespondenceDeliveryConfigurations trait.

- 'Institution' <select dropdown> `.js-state` (optional, filtered by current tenant or admin-selected institution; defaults to current institution)
- 'Name' <text input> `CorrespondenceDeliveryConfiguration_name` (required, max 255 chars)
- 'Content Type' <select dropdown> `CorrespondenceDeliveryConfiguration_content_type` (required, values: PDF, XML)
- 'Output Type' <select dropdown> `CorrespondenceDeliveryConfiguration_output_type` (required, values: DOCMAN, INTERNAL_REFERRAL, ELECTRONIC)
- 'Filename Mask' <text input> `CorrespondenceDeliveryConfiguration_filename_mask` (required, max 200 chars; supports placeholders like {patient.hos_num}, {date}, {document_output.id}, {event.id}, {event.last_modified_date}, {gp.nat_id}, {prefix}, {random}, {recipient.output_type}, {recipient.to_or_cc})
- 'Path' <text input> `CorrespondenceDeliveryConfiguration_path` (optional; sets child folder under Docman Export Directory; leave blank for root)
- 'Comment' <text input> `CorrespondenceDeliveryConfiguration_comment` (optional)
- 'Test Path' <button> `.test` (per-row button; tests directory existence and file count)
- 'Test ALL' <button> `.test-all` (bulk test all configurations)

Save: Form submission updates configuration; on add, back button returns to list; on error, validation messages shown inline; test buttons trigger AJAX to /OphCoCorrespondence/admin/TestCorrespondenceDeliveryConfigurations and update status/date/message fields.

**Live check (2026-07-24) - discrepancy:** Institution field is documented as a form field with .js-state selector and description '(optional, filtered by current tenant or admin-selected institution; defaults to current institution)' but is missing from the actual add/edit form (/OphCoCorrespondence/admin/editCorrespondenceDeliveryConfiguration). The list view has an institution_id selector for filtering, but the form itself lacks the Institution field. All other documented form fields are present and have correct IDs: Name (CorrespondenceDeliveryConfiguration_name), Content Type (CorrespondenceDeliveryConfiguration_content_type), Output Type (CorrespondenceDeliveryConfiguration_output_type), Filename Mask (CorrespondenceDeliveryConfiguration_filename_mask), Path (CorrespondenceDeliveryConfiguration_path), Comment (CorrespondenceDeliveryConfiguration_comment). Test buttons exist on the list page but the .test and .test-all class selectors could not be verified.

#### Email Templates

Manages email templates per recipient type (Optometrist, Patient, GP, DRSS, Internal Referral, Other); backed by EmailTemplate model and rendered via _email_template.php partial.

- 'Recipient Type' <select dropdown> `EmailTemplate_recipient_type` (required; uniqueness enforced with site_id and institution_id combination)
- 'Institution' <read-only display> (auto-filled from current institution)
- 'Site' <select dropdown> `EmailTemplate_site_id` (optional; defaults to None; lists sites of current institution)
- 'Title' <text input> `EmailTemplate_title` (optional, max 255 chars)
- 'Subject' <text input> `EmailTemplate_subject` (optional, max 255 chars)
- 'Body' <textarea/TinyMCE editor> `EmailTemplate_body` (optional, max 1MB bytes)
- 'Add shortcode' <select dropdown> `.cols-full` (convenience dropdown; populates from PatientShortcode records)

Save: Form submitted to actionAddEmailTemplate or actionEditEmailTemplate; validation checks recipient_type uniqueness; errors displayed at top of form; success redirects to emailTemplates list.

**Live check (2026-07-24):** matched the live page. All documented fields verified on add form (/OphCoCorrespondence/admin/addEmailTemplate): Recipient Type (EmailTemplate_recipient_type), Institution (displayed as read-only text showing 'The Monachs Trust'), Site (EmailTemplate_site_id select dropdown), Title (EmailTemplate_title), Subject (EmailTemplate_subject), Body (TinyMCE rich text editor present with toolbar visible), Add shortcode (shortcode select dropdown with full PatientShortcode list available). Field selectors and types match documentation.

#### Internal Referral site mapping

Maps firms to sites for internal referrals; backed by InternalReferralSettingsController::actionSiteFirmMapping.

- 'Institution' <select dropdown> `institution_id` (required for admin; read-only display for non-admin; defaultto current institution)
- 'Site / Location' <select dropdown> `site_id` (required; populated from selected institution's sites; triggers form submission on change)
- 'Service / Subspecialty' <select dropdown> `subspecialty_id` (optional, defaults to 'All'; filters firms list by subspecialty on POST)
- 'Firms' <multi-select list> `InternalReferralSiteFirmMapping_firm_id[index]` (hidden input fields in list; uses Mustache template for dynamic row creation; firm display includes subspecialty in parentheses)

Save: POST request to actionSiteFirmMapping; deletes previous mappings for site and rebuilds from submitted firm IDs; creates InternalReferralSiteFirmMapping records; no server-side validation error text exposed to UI (internal transaction rollback on failure).

#### Letter Snippets

Lists and manages letter snippets (LetterString records) scoped by institution/site; backed by SnippetController using Admin widget pattern.

- 'Institution' <select dropdown> `institution_relations.institution_id` (search filter; restricted to current user's institutions unless admin; required to populate site dropdown)
- 'Sites' <select dropdown> `sites.id` (search filter; depends on institution selection; defaults to 'All sites')
- 'Name' <text input> `name` (search filter; text match)
- 'Display Order' <hidden/managed> `display_order` (auto-managed via actionSort)
- 'Letter String Group' <select dropdown> `LetterString_letter_string_group_id` (required on edit; populated from LetterStringGroup records for selected institution)
- 'Name (edit)' <text input> `LetterString_name` (required; max 255)
- 'Body (edit)' <textarea/shortcode editor> `LetterString_body` (required; supports patient shortcodes)
- 'Element Type' <select dropdown> `LetterString_element_type` (optional; linked to ElementType.class_name)
- 'Event Type' <select dropdown> `LetterString_event_type` (optional; linked to EventType.class_name)

Save: actionEdit validates required fields (letter_string_group_id, name, body); on POST, saves and rebuilds LetterString_Institution/Site mappings; redirect to list on success or re-renders edit form with errors.

#### Letter macros

Lists and manages letter macros for correspondence; backed by AdminController::actionLetterMacros and actionAddMacro/actionEditMacro.

- 'Type' <select dropdown> `type` (filter; values: site, subspecialty, firm; no selection = 'Type')
- 'Institution' <select dropdown> `institution_id` (filter; restricted by tenant for non-admin; defaults to current institution)
- 'Site' <select dropdown> `site_id` (filter; empty option = '- Site -')
- 'Subspecialty' <select dropdown> `subspecialty_id` (filter; empty = '- Subspecialty -')
- 'Firm' <select dropdown> `firm_id` (filter; empty = '- ' + Firm::contextLabel() + ' -')
- 'Name' <select dropdown> `name` (filter; empty = '- Name -'; populated from unique macro names)
- 'Episode Status' <select dropdown> `episode_status_id` (filter; empty = '- Episode status -')
- 'Institution (edit)' <read-only display> (fixed to selected institution; hidden field with value)
- 'Site (edit)' <multi-select list> `LetterMacro[levels][sites][]` (optional)
- 'Subspecialty (edit)' <multi-select list> `LetterMacro[levels][subspecialties][]` (optional)
- 'Firm (edit)' <multi-select list> `LetterMacro[levels][firms][]` (optional; label uses Firm::contextLabel())
- 'Letter Type' <select dropdown> `LetterMacro_letter_type_id` (optional; empty = '- Letter type -')
- 'Name (edit)' <text input> `LetterMacro_name` (required, max 255)
- 'Default Recipient' <radio buttons> `LetterMacro[recipient_id]` (optional; values from LetterRecipient records; 'None' option always present)
- 'CC Patient' <checkbox> `LetterMacro_cc_patient` (required - must be checked or error)
- 'CC Doctor' <checkbox> `LetterMacro_cc_doctor` (required - must be checked or error)
- 'CC DRSS' <checkbox> `LetterMacro_cc_drss` (optional; hidden if recipient is DRSS)
- 'CC Optometrist' <checkbox> `LetterMacro_cc_optometrist` (optional)
- 'Use Nickname' <checkbox> `LetterMacro_use_nickname` (required - must be checked or error)
- 'Episode Status (edit)' <select dropdown> `LetterMacro_episode_status_id` (optional; empty = '- None -')
- 'Body' <textarea/TinyMCE editor> `LetterMacro_body` (required, max 1MB)
- 'Add Shortcode' <select dropdown> `shortcode` (convenience dropdown; empty = '- Select -')

Save: Form posted to actionAddMacro or actionEditMacro; validates name, body, cc_patient, cc_doctor, use_nickname as required; must have at least one level (institution/site/subspecialty/firm); on success redirects to letterMacros list; on error re-renders edit form with validation errors.

#### Sender Email Addresses

Manages SMTP server credentials for sending correspondence emails; backed by AdminController::actionSenderEmailAddresses and actionAddEmailAddress/actionEditEmailAddress.

- 'Host' <text input> `SenderEmailAddresses_host` (required; SMTP server hostname)
- 'Username' <text input> `SenderEmailAddresses_username` (required)
- 'Password' <password input> `SenderEmailAddresses[password]` (required on insert, optional on edit if not changed; encrypted on save via EncryptionDecryptionHelper)
- 'Reply-To Address' <text input> `SenderEmailAddresses_reply_to_address` (optional; email address)
- 'Port' <text input> `SenderEmailAddresses_port` (required; numeric, typically 25/465/587)
- 'Security' <select dropdown> `SenderEmailAddresses_security` (optional; values: ssl, tls, empty=None)
- 'Institution' <read-only display> (auto-filled from current institution)
- 'Site' <select dropdown> `SenderEmailAddresses_site_id` (optional; defaults to None; lists sites of current institution)
- 'Domain' <text input> `SenderEmailAddresses_domain` (required; pattern: must be * or @domain.com format; uniqueness enforced with (institution_id, site_id) combination)

Save: Form posted to actionAddEmailAddress or actionEditEmailAddress; password encrypted on save if provided/changed; validation checks domain format and (institution_id, site_id, domain) uniqueness; errors displayed at top of form; success redirects to senderEmailAddresses list.

### CVI (10 pages total, 2 documented below)

**Blind-spot check (2026-07-24):** No unusual patterns; Clinical Disorder and Clinical Disorder Section both use standard patient-type filtering; other admin pages in section (Contact Urgency, Employment Status, Field of Vision, Low Vision Status, Patient Factor, Preferred Info Format) use genericAdmin() helper with add-row/save-rows pattern.

The other 8 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__cvi.md`.

#### Clinical Disorder

Manages clinical disorder entries for the CVI module, listing disorders by patient type (adult/child), backed by OphCoCvi_ClinicalInfo_Disorder model and AdminController::actionClinicalDisorders().

- 'Patient type' <select> `search[patient_type]` (optional, filters results to adult/child patients, empty = show all)
- 'Search' <button> `[data-test="patient-type-filter-submit"]` (optional, applies filter)

Save: Filter applied via GET request; individual disorder edit navigates to separate form page; clickable table rows open edit at `/OphCoCvi/admin/editClinicalDisorder/{id}`

**Live check (2026-07-24) - discrepancy:** Select field 'Patient type' is labeled 'search[patient_type]' (field name) rather than with a proper label. Selector search[patient_type] and id #search_patient_type are correct. Search button [data-test='patient-type-filter-submit'] with text 'Search' exists and matches documentation.

#### Clinical Disorder Section

Manages sections that group clinical disorders, backed by OphCoCvi_ClinicalInfo_Disorder_Section model and AdminController::actionClinicalDisorderSection().

- 'Patient type' <select> `search[patient_type]` (optional, filters sections by patient type)
- 'Search' <button> (type: submit) (optional, applies filter)

Save: Filter applied via GET request; individual section edit navigates to separate form page via clickable table rows to `/OphCoCvi/admin/editClinicalDisorderSection/{id}`

**Live check (2026-07-24) - discrepancy:** Same as page 1: select field labeled 'search[patient_type]' instead of 'Patient type'. Additionally, the Search button lacks the data-test='patient-type-filter-submit' attribute found on the Clinical Disorder page - it has no id/data-test/name attributes in the dump. Documentation specifies (type: submit) but selector/attributes are not clearly identified.

### Disorders (5 pages total, 5 documented below)

**Blind-spot check (2026-07-24):** All pages render list/edit views without feature-flag gates; no deferred redirects detected. Save operations validate group assignments against institution scope.

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__disorders.md`.

#### Common Ophthalmic Disorder Groups

Manages reorderable list of ophthalmic disorder groups at installation or institution level, backed by AdminController::actionEditCommonOphthalmicDisorderGroups and the editcommonophthalmicdisordergroup view.

- 'Institution' <select> `#institution_id` (optional, filter; 'All Institutions' empty option for admins)
- 'Subspeciality' <select> `#subspecialty_id` (optional, filter; 'All subspecialties' empty option)
- Table columns:
  - Order (drag handle with up/down arrows)
  - 'Group Name' <text> `#CommonOphthalmicDisorderGroup_ROW_id_name` (required, max 400px width; pattern `name` in JSON)
  - 'Institution' <select or text> (admin sees dropdown; non-admin sees text display; read-only if group has active disorders)
  - 'Subspecialty' <text, display-only> (derived from subspecialty_id query param, e.g. 'Cataract')
  - Actions: delete button (disabled if group has active disorders, tooltip explains)

Save: POSTs to same URL; converts row table to JSON via OpenEyes.GenericFormJSONConverter; validates group name required; server rolls back and flashes errors if save fails ('There has been an error in saving, please contact support'); no validation errors returned per field for admin pages (generic error message used)

**Live check (2026-07-24):** matched the live page. All documented elements present and correct: Institution/Subspecialty filters with proper empty options, table columns (Order with arrows, Group Name input pattern CommonOphthalmicDisorderGroup_[row]_name, Institution dropdown/text display, Subspecialty read-only text, Actions delete with disable logic). Delete button correctly disabled for groups with active disorders.

#### Common Ophthalmic Disorders

Manages reorderable list of ophthalmic disorders (diagnoses) linked to ophthalmic disorder groups, backed by AdminController::actionEditCommonOphthalmicDisorder and the editcommonophthalmicdisorder view.

- 'Institution' <select> `#institution_id` (optional, filter; 'All Institutions' empty option for admins)
- 'Subspeciality' <select> `#subspecialty_id` (required filter, defaults to first subspecialty; no empty option)
- Table columns:
  - Order (drag handle)
  - 'Disorder' <text autocomplete> `.diagnoses-search-autocomplete` (required; autocomplete searches `/disorder/autocomplete?code=OPHTHALMIC`; displays selected diagnosis term; hides on select)
  - 'Group' <select> `.group-id` (optional; dropdown of groups filtered by institution/subspecialty; '-- select --' empty option)
  - 'Alternate Disorder' <text autocomplete with toggle> `.alternate-disorder-search-autocomplete` or `.alternate-disorder-display` (optional; autocomplete searches diagnoses; toggle shows/hides input and display span on select)
  - 'Alternate Disorder Label' <text> (optional; plain text field, no visible header label)
  - 'Institution' <select or text> (admin sees dropdown; non-admin sees text display)
  - Actions: delete button (always enabled, no disable logic)

Save: POSTs to same URL; validates disorder_id and finding_id required via JS before POST (alert('Please select a valid finding from the list') if finding input has value but not selected from list); server validates group assignment to institution; JSON error flashes per-field errors ('Group is not available for the selected institution'); success message 'List updated'

**Live check (2026-07-24) - discrepancy:** Group field is documented as having selector .group-id, but actual implementation only provides ID #CommonOphthalmicDisorder_[row]_group_id with no .group-id class. All other elements match: Disorder field has .diagnoses-search-autocomplete class, Alternate Disorder has .alternate-disorder-search-autocomplete and .alternate-disorder-display classes, Alternate Disorder Label is present as plain text field, Institution dropdown/text display correct, delete buttons always enabled as documented.

#### Common Systemic Disorders

Manages reorderable list of systemic disorders (diagnoses) linked to systemic disorder groups, backed by CommonSystemicDisorderController::actionList and the editcommonsystemicdisorder view.

- 'Institution' <select> `#institution_id` (optional, filter; data-test=common-systemic-disorders-institution-select; 'All Institutions' empty option for admins)
- Table columns:
  - Order (drag handle)
  - 'Disorder' <text autocomplete> `.diagnoses-search-autocomplete` (required; autocomplete searches diagnoses; displays selected disorder term; hides on select)
  - 'Group' <select> (optional; dropdown of groups filtered by institution; '-- select --' empty option)
  - 'Institution' <select or text> (admin sees dropdown; non-admin sees text display)
  - Actions: delete button (always enabled)

Save: POSTs to `/oeadmin/CommonSystemicDisorder/save?institution_id=X`; validates group assignment to institution; JSON error flashes per-field errors; success message 'List updated'; redirect to referrer on success or error

#### Common Systemic Disorders Groups

Manages reorderable list of systemic disorder groups at installation or institution level, backed by CommonSystemicDisorderGroupController::actionList and the listcommonsystemicdisordergroup view.

- 'Institution' <select> `#institution_id` (optional, filter; 'All institutions' empty option for admins)
- Table columns:
  - Order (drag handle)
  - 'Group Name' <text> `#CommonSystemicDisorderGroup_ROW_id_name` (required; pattern `name` in JSON)
  - 'Institution' <select or text> (admin sees dropdown; non-admin sees text display; read-only if group has active disorders)
  - Actions: delete button (disabled if group has active disorders, tooltip explains)

Save: POSTs to `/oeadmin/CommonSystemicDisorderGroup/save?institution_id=X`; converts row table to JSON; validates group name required; flashes errors if save fails; success message 'List updated'; redirect to referrer

#### Disorders

Displays paginated searchable grid of all disorders (reference data) with create/update/delete actions, backed by DisorderController::actionIndex (gated on TaskCreateDisorder or admin role) and the disorder/admin view.

- Search filter row (submit via 'Search' button on page):
  - 'ID' <text> `#Disorder_id` (optional filter)
  - 'Fully Specified Name' <text> `#Disorder_fully_specified_name` (optional filter)
  - 'Term' <text> `#Disorder_term` (optional filter; main diagnosis label)
  - 'Specialty' <text> `#Disorder_specialty_id` (optional filter; dropdown in filter row)
- Grid columns (sortable by header click):
  - id (numeric)
  - fully_specified_name (text, snomed-like)
  - term (text, user-facing label)
  - specialty (derived via getSpecialtyNameFromId)
  - Actions: pencil (update), info (view), trash (delete)
- Pagination: LinkPager with prev/next and page numbers

Save: Handled per-record via create/update/delete actions (not bulk edit like other disorder pages); 'Add New Disorder' button links to `/disorder/create`; delete via grid action column triggers confirm + server-side delete

### Document

All 1 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__document.md`. **Blind-spot check (2026-07-24):** DocumentSubTypesSettingsController::actionIndex() line 47: checkAccess('admin') gate throws 403 if not system admin

### Drugs (18 pages total, 6 documented below)

The other 12 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__drugs.md`.

#### Anaesthetic Agent Mapping Facial Injection

Manages anaesthetic agent assignment for facial injection procedures by subspecialty and firm context, backed by FacialInjectionAnaestheticAgentAssignmentController and views in protected/modules/OphCiExamination/modules/ExaminationAdmin/views/facialInjectionanaestheticagentassignment/.

- 'Subspecialty' <select> `select[name=subspecialty_id]` (optional, default: empty, triggers Context list)
- 'Context' <select> `select[name=firm_id]` (optional, default: 'All contexts', disabled until Subspecialty selected)
- 'Anaesthetic Agent Name' <text> (read-only, one row per currently assigned agent)
- 'Is Default' <checkbox> `input[name$="[is_default]"]` (optional per agent, default: unchecked)
- Add button <button> `button[data-test=add-new-anaesthetic-agent]` to add agents via modal

Save: Save button (`#et_save`) POSTs to `/OphCiExamination/admin/FacialInjectionAnaestheticAgentAssignment/update`, validates form fields, updates ExaminationFacialInjection_AnaestheticAgents assignments, displays inline success/error alert.

**Live check (2026-07-24):** matched the live page. All documented selectors verified: subspecialty_id select, firm_id select (ID=filter-firm-id), button[data-test=add-new-anaesthetic-agent] present. Is Default checkboxes and Anaesthetic Agent Name rows not visible on this sample as no agents are currently assigned to any subspecialty/context - this is expected behavior (they appear conditionally per agent). All required elements are accessible and functional.

#### DM+D Drugs

Lists DM+D medications with search/filter and sort capabilities, backed by DmdDrugsAdminController (extends RefMedicationAdminController) and generic Admin list view in protected/views/admin/generic/list.php.

- 'Source Subtype' <text search> (optional, searches medication source_subtype)
- 'Preferred Code' <text search> (optional, searches medication preferred_code)
- 'Preferred Term' <text search> (optional, searches medication preferred_term)
- List columns: id, source_type, source_subtype, preferred_code, preferred_term, alternativeTerms, vtm_term, vmp_term, amp_term (all sortable except alternativeTerms)
- Checkbox per row `input[name="Medication[id][]"]` (optional, for bulk delete)

Save: Add/Edit buttons navigate to edit page; Delete button removes selected medications via POST to `/OphDrPrescription/OphDrPrescriptionAdmin/dmdDrugsAdmin/delete`, confirms via JSON response.

**Live check (2026-07-24) - discrepancy:** Search fields correct (Source Subtype, Preferred Code, Preferred Term). Checkboxes correct (Medication[id][]). Column headers present: id, source_type, source_subtype, preferred_code, preferred_term, alternativeTerms, vtm_term, vmp_term, amp_term. DISCREPANCY: Documentation states 'all sortable except alternativeTerms' but alternativeTerms IS sortable (has sort link ?c=alternativeTerms&d=1). All 9 columns are actually sortable.

#### Drug Sets

Indexes automatic medication sets filtered by usage code, subspecialty, site, and name, backed by AutoSetRuleController.actionIndex() and views in protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/views/AutoSetRule/.

- Usage Code buttons (multi-select toggle) `button[data-usage_code_id]` (optional, default: 'ALL', green highlight when selected)
- 'Name' <text> `input[name="search[query]"]` (optional, filters by medication set name)
- 'Subspecialty' <select> `select[name="search[subspecialty_id]"]` (optional, default: empty)
- 'Site' <select> `select[name="search[site_id]"]` (optional, default: empty)
- Search button `button#et_search` triggers AJAX pagination
- List table columns: checkbox, id, name, rules, item count, hidden status, actions
- Checkbox per row `input[name="delete-ids[]"]` (optional, for bulk delete)

Save: Add button navigates to edit form; Delete button POSTs selected set ids to `/OphDrPrescription/admin/autoSetRule/delete`, confirms via JSON response; 'Rebuild all sets now' button triggers background migration command.

#### Local Drugs

Lists LOCAL-source medications with search/filter and sort, backed by LocalDrugsAdminController (extends RefMedicationAdminController) and generic Admin list view in protected/views/admin/generic/list.php.

- 'Source Subtype' <text search> (optional, searches medication source_subtype)
- 'Preferred Code' <text search> (optional, searches medication preferred_code)
- 'Preferred Term' <text search> (optional, searches medication preferred_term)
- List columns: id, source_type, source_subtype, preferred_code, preferred_term, alternativeTerms, vtm_term, vmp_term, amp_term (all sortable except alternativeTerms)
- Checkbox per row `input[name="Medication[id][]"]` (optional, for bulk delete)

Save: Add/Edit buttons navigate to edit page (no preferred_code on Local drugs edit); Delete button removes selected medications via POST to `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/delete`, confirms via JSON response.

#### PGD/PSD Settings

Lists PGD/PSD records with search, type/name/description display, and institution mapping, backed by AdminController.actionPGDPSDSettings() in protected/modules/OphDrPGDPSD/controllers/ and list view in protected/modules/OphDrPGDPSD/views/admin/pgdpsdsettings/list.php.

- 'Search' <text> `input#js-pgd-search[name=search]` (optional, matches name or description)
- Checkbox per row `input[name="PGDPSDs[]"]` (optional, for bulk deactivate)
- List table columns: checkbox, type (PGD/PSD), name, description, institution, active status

Save: Add PGD/PSD button navigates to edit form; Deactivate PGDPSDs button POSTs selected ids to `/OphDrPGDPSD/admin/deletePGDPSDs`, sets active=0 and returns JSON success (1) or failure (0).

#### Prescription Signatures

Manages secondary signatory names and active status per institution, backed by SignaturesController.actionEdit() in protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/controllers/ and edit view in protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/views/signatures/edit.php.

- 'Institution' <select> `select[name=institution_id]` (optional, filters signatories by institution; GET submit on change)
- In table body (sortable):
  - 'Order' (read-only, reorder arrows with hidden display_order field) `input[name="display_order[row]"]`
  - 'Name' <text> `input[name="SecondarySignatory[row][name]"]` (required, inline edit)
  - 'Active' <checkbox> `input[name="SecondarySignatory[row][active]"]` (optional, default: checked for new)
  - Delete button (per row) `button.js-delete-signatory` removes row on click
- Add button `button#add_new` adds blank row via Mustache template

Save: Save button (`button[data-test=save-signatory-form]`) POSTs form, calls updateSignaturesFromPost(), saves all signatories with display_order, deletes removed records, returns to same page.

### Event Export (1 pages total, 1 documented below)

**Blind-spot check (2026-07-24):** File drops with is_locked=true cannot be edited or deleted; actionEdit() redirects locked drops to actionView(); actionDelete() throws RuntimeException for locked items

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__event-export.md`.

#### File drop settings

Manages file drop configurations for event export destinations. Controller: EventExport/modules/EventExportAdmin/controllers/FileDropController::actionList(). View: fileDrop/index.php.

This page displays existing file drop configurations in a read-only table. No input fields present on this page.

Save: N/A - page uses Add File Drop link and Delete File Drops button (#delete-file-drops) for checkbox-selected rows; deletion via AJAX POST to /EventExport/admin/FileDrop/delete with CSRF token

### Examination (77 pages total, 10 documented below)

**Blind-spot check (2026-07-24):** All five pages are list views with identical interaction patterns (sortable rows, Add button, Show Deleted toggle); the controller has no visible feature-flag gates or conditional redirects that would hide these pages from the crawl - they should all be reliably reachable.

**Blind-spot check (2026-07-24):** All Workflow pages respect institution-level tenancy and access control; DrivingSafety and Element Attributes pages lack conditional redirect logic found in other module admin areas; no feature-flag gates detected on these five pages.

The other 67 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__examination.md`.

#### DR Grading - Clinical Maculopathy

Displays a sortable list of clinical maculopathy grades managed by DRGradingController::actionViewClinicalMaculopathy, backed by list_OphCiExamination_Clinical_Pathy.php view and OphCiExamination_Maculopathy_Clinical_Grade model.

- 'Show Deleted' checkbox `#show-deleted` (optional; when checked, reveals deleted-marked rows and the "Deleted" column)
- 'Order' reorder control per row (drag handle with up/down arrow; sortable rows submit to /OphCiExamination/admin/DRGrading/UpdateClinicalMaculopathyOrder via AJAX on drop)
- 'Maculopathy clinical grade' text display per row (value field from model, read-only in list view)
- 'National Grade Default' text display per row (related national grade value or empty if not set)
- 'Disorder Change Policy' link per row (`/oeadmin/DisorderChangePolicy/edit/{id}?class=OEModule\\OphCiExamination\\models\\OphCiExamination_Maculopathy_Clinical_Grade...` - link opens related disorder policy edit page)
- 'Help Text' text display per row (help_text field, multiline, displayed with nl2br)
- 'Help Colour' color swatch display per row (6 background color options: blue/green/amber/red/gray/undefined; renders as 20px box with border)
- 'Deleted' status column (displays check icon if deleted=1, hidden by default; toggle via "Show Deleted" checkbox)

Table rows are clickable (`class="clickable"`): click leads to /OphCiExamination/admin/DRGrading/EditClinicalMaculopathy/{id} to edit that grade.

Save: Reordering rows sends AJAX POST to UpdateClinicalMaculopathyOrder action with display_order values; success re-sorts table in-place. Add button `#et_add` leads to Add page (/OphCiExamination/admin/DRGrading/AddClinicalMaculopathy), where a new grade form is submitted; on success redirects to this View page with flash message 'Clinical Maculopathy Created'. Edit action saves via model->save() and redirects with 'Clinical Maculopathy Edited' message. No delete control on list page itself (deletion via edit page by marking Deleted checkbox).

**Live check (2026-07-24):** matched the live page. All documented controls present and functional: #show-deleted checkbox, table headers (Order, Maculopathy clinical grade, National Grade Default, Disorder Change Policy, Help Text, Help Colour), #et_add button, clickable rows with class, hidden Deleted column. AJAX sort URL correct. All 6 color options (blue/green/amber/red/gray/undefined) implemented. Controller flash messages match documentation. Table is empty (sample data has no clinical maculopathy grades).

#### DR Grading - Clinical Retinopathy

Displays a sortable list of clinical retinopathy grades managed by DRGradingController::actionViewClinicalRetinopathy, backed by list_OphCiExamination_Clinical_Pathy.php view and OphCiExamination_Retinopathy_Clinical_Grade model (same view template as Clinical Maculopathy with 'Retinopathy' substituted for 'Maculopathy').

- 'Show Deleted' checkbox `#show-deleted` (optional; when checked, reveals deleted-marked rows and the "Deleted" column)
- 'Order' reorder control per row (drag handle with up/down arrow; sortable rows submit to /OphCiExamination/admin/DRGrading/UpdateClinicalRetinopathyOrder via AJAX on drop)
- 'Retinopathy clinical grade' text display per row (value field from model, read-only in list view)
- 'National Grade Default' text display per row (related national grade value or empty if not set)
- 'Disorder Change Policy' link per row (`/oeadmin/DisorderChangePolicy/edit/{id}?class=OEModule\\OphCiExamination\\models\\OphCiExamination_Retinopathy_Clinical_Grade...` - link opens related disorder policy edit page)
- 'Help Text' text display per row (help_text field, multiline, displayed with nl2br)
- 'Help Colour' color swatch display per row (6 background color options: blue/green/amber/red/gray/undefined; renders as 20px box with border)
- 'Deleted' status column (displays check icon if deleted=1, hidden by default; toggle via "Show Deleted" checkbox)

Table rows are clickable (`class="clickable"`): click leads to /OphCiExamination/admin/DRGrading/EditClinicalRetinopathy/{id} to edit that grade.

Save: Reordering rows sends AJAX POST to UpdateClinicalRetinopathyOrder action with display_order values; success re-sorts table in-place. Add button `#et_add` leads to Add page (/OphCiExamination/admin/DRGrading/AddClinicalRetinopathy), where a new grade form is submitted; on success redirects to this View page with flash message 'Clinical Retinopathy Created'. Edit action saves via model->save() and redirects with 'Clinical Retinopathy Edited' message. No delete control on list page itself (deletion via edit page by marking Deleted checkbox).

**Live check (2026-07-24):** matched the live page. All documented controls present and functional: #show-deleted checkbox, table headers (Order, Retinopathy clinical grade, National Grade Default, Disorder Change Policy, Help Text, Help Colour), #et_add button, clickable rows with class, hidden Deleted column. AJAX sort URL correct. All 6 color options (blue/green/amber/red/gray/undefined) implemented. Controller flash messages match documentation. Table is empty (sample data has no clinical retinopathy grades).

#### DR Grading - National Maculopathy

Displays a sortable list of national maculopathy grades managed by DRGradingController::actionViewNationalMaculopathy, backed by list_OphCiExamination_National_Pathy.php view and OphCiExamination_Maculopathy_National_Grade model.

- 'Show Deleted' checkbox `#show-deleted` (optional; when checked, reveals deleted-marked rows and the "Deleted" column)
- 'Order' reorder control per row (drag handle with up/down arrow; sortable rows submit to /OphCiExamination/admin/DRGrading/UpdateNationalMaculopathyOrder via AJAX on drop)
- 'Value' text display per row (grade value from model, required field, must be unique, read-only in list view)
- 'Help Text' text display per row (optional help_text field, read-only in list view)
- 'Help Colour' color swatch display per row (6 background color options: blue/green/amber/red/gray/undefined; renders as 20px box with border)
- 'is_m1_grading' checkbox status display per row (displays check icon if is_m1_grading=1; read-only indicator, not editable on list page)
- 'Deleted' status column (displays check icon if deleted=1, hidden by default; toggle via "Show Deleted" checkbox)

Table rows are clickable (`class="clickable"`): click leads to /OphCiExamination/admin/DRGrading/EditNationalMaculopathy/{id} to edit that grade.

Save: Reordering rows sends AJAX POST to UpdateNationalMaculopathyOrder action with display_order values; success re-sorts table in-place. Add button `#et_add` leads to Add page (/OphCiExamination/admin/DRGrading/AddNationalMaculopathy), where a new grade form is submitted; on success redirects to this View page with flash message 'National Maculopathy Created'. Edit action saves via model->save() and redirects with 'National Maculopathy Edited' message. Server-side validation: 'value' required, must be unique across all national maculopathy grades (rules: ['value', 'required'], ['value', 'unique']). No delete control on list page itself (deletion via edit page by marking Deleted checkbox).

#### DR Grading - National Retinopathy

Displays a sortable list of national retinopathy grades managed by DRGradingController::actionViewNationalRetinopathy, backed by list_OphCiExamination_National_Pathy.php view and OphCiExamination_Retinopathy_National_Grade model (same view template as National Maculopathy with 'Retinopathy' substituted for 'Maculopathy').

- 'Show Deleted' checkbox `#show-deleted` (optional; when checked, reveals deleted-marked rows and the "Deleted" column)
- 'Order' reorder control per row (drag handle with up/down arrow; sortable rows submit to /OphCiExamination/admin/DRGrading/UpdateNationalRetinopathyOrder via AJAX on drop)
- 'Value' text display per row (grade value from model, required field, must be unique, read-only in list view)
- 'Help Text' text display per row (optional help_text field, read-only in list view)
- 'Help Colour' color swatch display per row (6 background color options: blue/green/amber/red/gray/undefined; renders as 20px box with border)
- 'is_r0_grading' checkbox status display per row (displays check icon if is_r0_grading=1; read-only indicator, not editable on list page)
- 'Deleted' status column (displays check icon if deleted=1, hidden by default; toggle via "Show Deleted" checkbox)

Table rows are clickable (`class="clickable"`): click leads to /OphCiExamination/admin/DRGrading/EditNationalRetinopathy/{id} to edit that grade.

Save: Reordering rows sends AJAX POST to UpdateNationalRetinopathyOrder action with display_order values; success re-sorts table in-place. Add button `#et_add` leads to Add page (/OphCiExamination/admin/DRGrading/AddNationalRetinopathy), where a new grade form is submitted; on success redirects to this View page with flash message 'National Retinopathy Created'. Edit action saves via model->save() and redirects with 'National Retinopathy Edited' message. Server-side validation: 'value' required, must be unique across all national retinopathy grades (rules: ['value', 'required'], ['value', 'unique']). No delete control on list page itself (deletion via edit page by marking Deleted checkbox).

#### DR Grading - Photocoagulation Scarring

Displays a sortable list of photocoagulation scarring grades managed by DRGradingController::actionViewPhotocoagulationScarring, backed by list_OphCiExamination_Photocoagulation_Scarring.php view and OphCiExamination_Photocoagulation_Scaring model (simpler structure than Clinical/National grades, no help_text or disorder_policy fields).

- 'Show Deleted' checkbox `#show-deleted` (optional; when checked, reveals deleted-marked rows and the "Deleted" column)
- 'Order' reorder control per row (drag handle with up/down arrow; sortable rows submit to /OphCiExamination/admin/DRGrading/UpdatePhotocoagulationScarringOrder via AJAX on drop)
- 'Value' text display per row (scarring grade value from model, read-only in list view)
- 'Deleted' status column (displays check icon if deleted=1, hidden by default; toggle via "Show Deleted" checkbox)

Table rows are clickable (`class="clickable"`): click leads to /OphCiExamination/admin/DRGrading/EditPhotocoagulationScarring/{id} to edit that grade.

Save: Reordering rows sends AJAX POST to UpdatePhotocoagulationScarringOrder action with display_order values; success re-sorts table in-place. Add button `#et_add` leads to Add page (/OphCiExamination/admin/DRGrading/AddPhotocoagulationScarring), where a new grade form is submitted; on success redirects to this View page with flash message 'Photocoagulation Scarring Created'. Edit action saves via model->save() and redirects with 'Photocoagulation Scarring Edited' message. No delete control on list page itself (deletion via edit page by marking Deleted checkbox).

#### Driving Advice - Standards

Lists existing driving safety standards backed by DrivingSafetyController::actionViewDrivingSafetyStandard. Clicking 'Add Driving Standard' button opens actionEditDrivingSafetyStandard form.

- 'Vehicle Class' text `activeTextField` (required)
- 'Better eye min BC <= LogMAR' text `activeTextField` (optional, numeric)
- 'Poorer eye min BC <= LogMAR' text `activeTextField` (optional, numeric)
- 'Binoculars' text `activeTextField` (optional, numeric)
- 'Alert min age' text `activeTextField` (optional, numeric)
- 'Alert max age' text `activeTextField` (optional, numeric)
- 'Regulatory Authority Guidance Title' textarea `activeTextArea` (optional)
- 'Regulatory Authority Guidance' textarea `activeTextArea` (optional)
- 'Active' checkbox `activeCheckbox` (optional, default: unchecked)

Save: Validates vehicle_class required; on success redirects to viewDrivingSafetyStandard with success flash; on failure displays error flash with model errors

**Live check (2026-07-24):** matched the live page. Form structure matches documentation. All 9 fields present with correct types: vehicle_class, better_eye_min_logmar, poorer_eye_min_logmar, binocular, min_age, max_age as text inputs, authority_guidance_title and authority_guidance as textareas, and active as checkbox.

#### Element Attributes

Lists examination element attributes with pagination and institution filtering, backed by ExaminationElementAttributesController::actionList and actionEdit. Table shows: display_order, name, label, attribute_elements.id, attribute_element_types.name, is_multiselect. Clicking a row or using sort/pagination controls operates via the generic Admin class.

- 'Name' text `text` (required)
- 'Label' text `text` (required)
- 'Element Type' select `DropDownList` (required, populated from ElementType::model())
- 'Institution' select `DropDownList` (optional, empty option for None)
- 'Multi-select' checkbox `checkbox` (optional, default: unchecked)

Save: Creates or updates OphCiExamination_Attribute and OphCiExamination_AttributeElement records; on success redirects to list; on failure displays error messages

**Live check (2026-07-24) - discrepancy:** Form fields match (Name, Label, Element Type select, Institution select, Multi-select checkbox). However, the list table has a discrepancy: documentation mentions 'attribute_elements.id' as a displayed column, but actual table shows 'Action' column instead. Table columns are: Display Order, Attribute Name, Attribute Label, Action, Element Mapping, Is Multiselect. The attribute_elements.id data may be accessible through the 'Action' column or 'Manage Options' link rather than displayed as a table column.

#### Strab Mgmt - Treatments

Lists strabismus management treatments via genericAdmin, backed by AdminForStrabismusManagement trait. Each row has an 'Options' action link to manage StrabismusManagement_TreatmentOption records for that treatment.

- 'Name' text (required)
- 'Reason Required' checkbox (optional, boolean)
- 'Column 1 Multi-select' checkbox (optional, boolean)
- 'Column 2 Multi-select' checkbox (optional, boolean)
- 'Display Order' text (optional, for sorting)

Save: Uses genericAdmin's standard save mechanism; validates name required; redirects to list on success; displays validation errors on failure

#### Workflow rules

Lists workflow rules filtered by institution, backed by AdminController::actionViewWorkflowRules. Table shows: Subspecialty, Firm (Context), Episode status, Workflow. Institution dropdown filter appears if admin role. Clicking row opens actionEditWorkflowRule form.

- 'Context (Firm)' select `activeDropDownList` (optional, empty option '- All -', populated from Firm::model())
- 'Episode status' select `activeDropDownList` (optional, empty option '- All -', populated from EpisodeStatus::model())
- 'Subspecialty' select `activeDropDownList` (optional, empty option '- All -', populated from Subspecialty::model())
- 'Workflow' select `activeDropDownList` (required, populated from institution-scoped workflows)
- 'Institution' select `dropDownList` (optional if admin, shows institution selector with AJAX-driven updates to Firm/Workflow dropdowns)

Save: Validates workflow_id required; on success redirects to viewWorkflowRules; displays error summary if validation fails; Firm and Workflow options are dynamically loaded via AJAX when institution changes

#### Workflows

Lists examination workflows filtered by institution, backed by AdminController::actionViewWorkflows. Table shows: Name. Institution dropdown filter appears if admin role. Clicking row opens actionEditWorkflow form; Add button opens actionAddWorkflow form.

- 'Institution' select `dropDownList` (optional if admin, empty option 'All institutions', populated from Institution::model()->getTenanted())
- 'Name' text `textField` (required, autocomplete disabled)

Save: On actionAddWorkflow/actionEditWorkflow POST, validates name required via saveWorkflow method; on success redirects to viewWorkflows with success message; on failure redisplays form with error summary; institution_id can be null (installation-level) or an institution ID; administrators can change workflows between institutions unless workflow_rules exist for that workflow

### Generic Event (6 pages total, 1 documented below)

**Blind-spot check (2026-07-24):** AssessmentSpecialty deletion is restricted - two hardcoded specialties (Medical Retina, Glaucoma) are mandatory and their delete checkboxes are not rendered; no dynamic gating, purely UI-level

The other 5 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__generic-event.md`.

#### Assessment Specialty

Manages assessment specialty records that gate field-level assessment configurations. Controller: OphGeneric/modules/OphGenericAdmin/controllers/AssessmentController::actionViewAssessmentSpecialty(). View: Assessment/list_AssessmentSpecialty.php.

This page displays existing assessment specialties in a read-only table. No input fields present on this page.

Save: N/A - uses standard Add/Delete buttons (#et_add, #et_delete) for checkbox-selected rows; Medical Retina and Glaucoma are MANDATORY_ASSESSMENT_SPECIALTY_LIST and their checkboxes are disabled (no delete option)

### Genetics (3 pages total, 3 documented below)

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__genetics.md`.

#### DNA Extraction Storage

Manages DNA sample storage coordinates (box, letter, number) using DnaExtractionStorageAdminController with Admin utility and generic edit/list templates.

- 'Box' dropdown `input[name="OphInDnaextraction_DnaExtraction_Storage[box_id]"]` (required, empty option: - Box -)
- 'Letter' text `input[name="OphInDnaextraction_DnaExtraction_Storage[letter]"]` (required, validated against box's max letter value)
- 'Number' text `input[name="OphInDnaextraction_DnaExtraction_Storage[number]"]` (required, numeric min 1, validated against box's max number value)

Save: Validates letter and number within box's configured ranges; rejects duplicates with error "These parameters are already in use"; display_order auto-assigned on create.

**Live check (2026-07-24):** matched the live page. All three fields present and correct: Box dropdown (select #OphInDnaextraction_DnaExtraction_Storage_box_id with empty option '- Box -'), Letter text input (#OphInDnaextraction_DnaExtraction_Storage_letter), Number text input (#OphInDnaextraction_DnaExtraction_Storage_number). Field selectors match documented name attributes. Edit form accessible at /OphInDnaextraction/DnaExtractionStorageAdmin/edit.

#### DNA Sample Type

Manages DNA sample type options using DnaSampleAdminController with Admin utility and generic edit/list templates.

- 'Name' text `input[name="OphInDnasample_Sample_Type[name]"]` (required)

Save: Creates or updates sample type record; display_order auto-assigned on creation as max existing order + 1; supports drag-drop reordering via sort action.

**Live check (2026-07-24):** matched the live page. Name field present and correct as text input (#OphInDnasample_Sample_Type_name). Field selector matches documented name attribute. Edit form accessible at /OphInDnasample/DnaSampleAdmin/edit. List view shows 7 existing sample type records with drag-drop reordering capability.

#### DNA Storage Box

Manages DNA storage box definitions (row/column grid ranges) using DnaExtractionBoxAdminController with Admin utility and generic edit/list templates.

- 'Value' text `input[name="OphInDnaextraction_DnaExtraction_Box[value]"]` (required)
- 'Maxletter' text `input[name="OphInDnaextraction_DnaExtraction_Box[maxletter]"]` (required, single letter A-Z only)
- 'Maxnumber' text `input[name="OphInDnaextraction_DnaExtraction_Box[maxnumber]"]` (required, numeric min 1)

Save: Creates or updates box record; maxletter validated to 1-character pattern; maxnumber validated as integer; page supports drag-drop reordering via sort action.

### Intravitreal Injection (15 pages total, 1 documented below)

**Blind-spot check (2026-07-24):** Treatment drug order is used by OEScape MR visualization; manageIOPLoweringDrugs, manageSkinDrugs, and manageAntisepticDrugs use genericAdmin() helper with inline table editing (not shown in crawl as separate pages), while Treatment Drugs uses dedicated update/edit actions

The other 14 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__intravitreal-injection.md`.

#### Treatment Drugs

Manages treatment drugs for intravitreal injection procedures with display ordering. Controller: OphTrIntravitrealinjection/controllers/AdminController::actionViewTreatmentDrugs(). View: admin/list_OphTrIntravitrealinjection_Treatment_Drug.php.

This page displays existing treatment drugs in a sortable table. No input fields present on this page.

Save: N/A - uses standard Add/Delete buttons (#et_add, #et_delete) for checkbox-selected rows; reordering via drag-handle icon updates display_order via AJAX POST to sortTreatmentDrugs action

### Investigation Management (1 pages total, 1 documented below)

**Blind-spot check (2026-07-24):** Investigation deletion checks isInvestigationDeletable() - items with OphCiExamination_Investigation_Entry references cannot be deleted; checkboxes are not rendered for non-deletable items in the view

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__investigation-management.md`.

#### Investigations

Manages medical investigation codes with SNOMED/ECDS cross-reference. Controller: InvestigationController::actionList(). View: oeadmin/investigation/index.php.

- 'Search query' text field `input[name="search[query]"]` (optional, default: empty, searches name / snomed_code / snomed_term / ecds_code / specialty_id)

Save: Clicking Search (#et_search) submits form via POST to same page and filters results table; no validation errors on list page

### Lab Results (1 pages total, 1 documented below)

**Blind-spot check (2026-07-24):** Result type deletion is separate from institution mapping operations; the page shows 'Assigned to current institution' column which indicates mapping status (tick icon) for each type

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__lab-results.md`.

#### Result Types

Manages lab result type definitions and institution-level mappings. Controller: OphInLabResults/controllers/oeadmin/ResultTypeController::actionList(). View: admin/list_OphInLabResults_Type.php.

This page displays existing result types in a sortable table. No input fields present on this page.

Save: N/A - uses standard Add/Delete buttons (#et_add, #et_delete_result_type) for checkbox-selected rows; two additional buttons handle institution mappings: Assign selected to current institution (#js-add-mapping) and Unassign selected from current institution (#js-delete-mapping), both via AJAX POST

### Laser

All 3 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__laser.md`. **Blind-spot check (2026-07-24):** AdminController::actionManageLaserProcedures() line 103: conditional checkAccess('admin') shows all procedures to admins, institution-level only to others

### Leaflets

All 2 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__leaflets.md`. **Blind-spot check (2026-07-24):** LeafletCategoryController/LeafletController: conditional institution filtering via checkAccess('admin') changes visible data set

### Medical Device Usage (2 pages total, 2 documented below)

**Blind-spot check (2026-07-24):** Both controllers use modern form-based approach with DTO services and client-side form validation; no unusual redirects or feature flags detected.

The other 0 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__medical-device-usage.md`.

#### Manage Devices

Manages medical device entries including manufacturer, model, category, and display settings, backed by MedicalDeviceAdminForm and DeviceAdminController.

- 'Manufacturer Name' <text> `MedicalDeviceAdminForm[manufacturer_name]` (required)
- 'Model Name' <text> `MedicalDeviceAdminForm[model_name]` (required)
- 'Alias' <text> `MedicalDeviceAdminForm[alias]` (optional)
- 'Category' <select> `MedicalDeviceAdminForm[category_id]` (required, populated from available categories, default: first category)
- 'Description' <text> `MedicalDeviceAdminForm[description]` (optional)
- 'Unique Device Identifier' <text> `MedicalDeviceAdminForm[unique_device_identifier]` (required)
- 'Show Batch Number' <checkbox> `MedicalDeviceAdminForm[show_batch_number]` (required)
- 'Show Serial Number' <checkbox> `MedicalDeviceAdminForm[show_serial_number]` (required)
- 'Show Expiry Date' <checkbox> `MedicalDeviceAdminForm[show_expiry_date]` (required)

Save: POST to `/TrDeviceUsageRecord/deviceAdmin/store`; form validates on server; redirects to index on success; errors displayed in alert-box above form

#### Medical Device Categories

Manages device categories with GMDN and SNOMED codes, backed by MedicalDeviceCategoryAdminForm and CategoryAdminController.

- 'Name' <text> `MedicalDeviceCategoryAdminForm[name]` (required)
- 'GMDN Code' <text> `MedicalDeviceCategoryAdminForm[gmdn_code]` (required, max length 5)
- 'SNOMED Code' <text> `MedicalDeviceCategoryAdminForm[snomed_code]` (optional, max length 18)

Save: POST to `/TrDeviceUsageRecord/categoryAdmin/store`; form validates on server; redirects to index on success; error summary displayed above form; Delete button only appears if category has zero devices

### Message

All 2 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__message.md`. **Blind-spot check (2026-07-24):** MessageSubTypesSettingsController: checkAccess('admin') gates on actionIndex/Create/Edit throw 403 for non-admins

### Operation Booking (16 pages total, 7 documented below)

**Blind-spot check (2026-07-24):** Ward listing index supports drag-and-drop reordering (sortable) but no delete functionality (no actionDeleteWard exists); theatre listing has delete checkboxes with async verification for active bookings; role-based access for Sequences (TaskAdminManageSequences) and Sessions (OprnInstitutionAdmin or TaskAdminManageSessions); Letter Contact/Warning Rules and Waiting List Contact Rules inherit parent access rules with no additional role restriction.

The other 9 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__operation-booking.md`.

#### Letter contact rules

Lists letter contact rules in a hierarchical tree structure and allows adding/editing/deleting rules that determine which contact should be used for operation booking letters based on site, firm, subspecialty, and theatre.

- 'Parent Rule' <select> `.rule_order` (optional, default: - None -)
- 'Rule Order' <text> `#OphTrOperationbooking_Letter_Contact_Rule_rule_order` (required)
- 'Site' <select> `.site_id` (optional, default: - Not set -)
- 'Firm' <select> `.firm_id` (optional, default: - Not set -)
- 'Subspecialty' <select> `.subspecialty_id` (optional, default: - Not set -)
- 'Theatre' <select> `.theatre_id` (optional, default: - Not set -)
- 'Refuse Telephone' <text> `#OphTrOperationbooking_Letter_Contact_Rule_refuse_telephone` (optional)
- 'Refuse Title' <text> `#OphTrOperationbooking_Letter_Contact_Rule_refuse_title` (optional)
- 'Health Telephone' <text> `#OphTrOperationbooking_Letter_Contact_Rule_health_telephone` (optional)

Save: POST to actionEditLetterContactRule or actionAddLetterContactRule; on success redirects to viewLetterContactRules; validation errors displayed in error summary; model saves to OphTrOperationbooking_Letter_Contact_Rule table.

**Live check (2026-07-24) - discrepancy:** Page loads correctly with hierarchical tree structure and add/edit form. All documented fields present (Parent Rule select, Rule Order text, Site/Firm/Subspecialty/Theatre selects, Refuse Telephone/Title/Health Telephone text fields). However, discrepancies found: (1) Documentation specifies selector notation using class selectors (`.rule_order`, `.site_id`, `.firm_id`, `.subspecialty_id`, `.theatre_id`) but actual form uses full ID selectors (`#OphTrOperationbooking_Letter_Contact_Rule_rule_order`, etc.); (2) Both Parent Rule (select) and Rule Order (text) fields appear to share the same ID `OphTrOperationbooking_Letter_Contact_Rule_rule_order`, which violates HTML specification for unique IDs.

#### Letter warning rules

Lists admission letter warning rules in a hierarchical tree structure and allows adding/editing/deleting rules that display warnings on operation booking letters based on rule type, site, firm, subspecialty, theatre, and whether patient is child/adult.

- 'Rule Type' <select> `#OphTrOperationbooking_Admission_Letter_Warning_Rule_rule_type_id` (required, default: - Rule type -)
- 'Parent Rule' <select> `#OphTrOperationbooking_Admission_Letter_Warning_Rule_parent_rule_id` (optional, default: - None -)
- 'Rule Order' <text> `#OphTrOperationbooking_Admission_Letter_Warning_Rule_rule_order` (required)
- 'Site' <select> `.site_id` (optional, default: - Not set -)
- 'Firm' <select> `.firm_id` (optional, default: - Not set -)
- 'Subspecialty' <select> `.subspecialty_id` (optional, default: - Not set -)
- 'Theatre' <select> `.theatre_id` (optional, default: - Not set -)
- 'Is Child' <select> `.is_child` (optional, default: - Not set -)
- 'Show Warning' <radio> `input[name="OphTrOperationbooking_Admission_Letter_Warning_Rule[show_warning]"]` (optional, default: Yes)
- 'Warning Text' <textarea> `#OphTrOperationbooking_Admission_Letter_Warning_Rule_warning_text` (optional)
- 'Emphasis' <radio> `input[name="OphTrOperationbooking_Admission_Letter_Warning_Rule[emphasis]"]` (optional, default: Yes)
- 'Strong' <radio> `input[name="OphTrOperationbooking_Admission_Letter_Warning_Rule[strong]"]` (optional, default: Yes)

Save: POST to actionEditLetterWarningRule or actionAddLetterWarningRule; on success redirects to viewLetterWarningRules; validation errors displayed in error summary; model saves to OphTrOperationbooking_Admission_Letter_Warning_Rule table.

**Live check (2026-07-24) - discrepancy:** Page loads correctly with hierarchical tree structure and add/edit form. All documented fields present including Rule Type, Parent Rule, Rule Order, Site/Firm/Subspecialty/Theatre/Is Child selects, Show Warning/Emphasis/Strong radio buttons, and Warning Text textarea. Primary discrepancy: Documentation specifies class selectors (`.site_id`, `.firm_id`, `.subspecialty_id`, `.theatre_id`, `.is_child`) for hierarchical fields but actual form uses full ID selectors (`#OphTrOperationbooking_Admission_Letter_Warning_Rule_site_id`, etc.). This affects how users would programmatically select these elements.

#### Sequences

Lists operation sequences (recurring theatre sessions) with filter form and paginated table view; allows inline editing of multiple sequences or navigation to individual edit form.

- 'Firm' <select> `#OphTrOperationbooking_Operation_Sequence_firm_id` (optional, default: - Emergency -)
- 'Theatre' <select> `#OphTrOperationbooking_Operation_Sequence_theatre_id` (optional, default: - None -)
- 'Start Date' <date> `#OphTrOperationbooking_Operation_Sequence_start_date_0` (optional)
- 'End Date' <date> `#OphTrOperationbooking_Operation_Sequence_end_date_0` (optional, allows null)
- 'Weekday' <select> `#OphTrOperationbooking_Operation_Sequence_weekday` (optional, default: - Weekday -)
- 'Start Time' <text> `#OphTrOperationbooking_Operation_Sequence_start_time` (optional, format HH:MM)
- 'End Time' <text> `#OphTrOperationbooking_Operation_Sequence_end_time` (optional, format HH:MM)
- 'Default Admission Time' <text> `#OphTrOperationbooking_Operation_Sequence_default_admission_time` (optional)
- 'Max Procedures' <text> `#OphTrOperationbooking_Operation_Sequence_max_procedures` (optional, numeric)
- 'Max Complex Bookings' <text> `#OphTrOperationbooking_Operation_Sequence_max_complex_bookings` (optional, numeric)
- 'Interval' <select> `#OphTrOperationbooking_Operation_Sequence_interval_id` (optional)
- 'Consultant' <radio> `input[name="OphTrOperationbooking_Operation_Sequence[consultant]"]` (optional, default: No)
- 'Paediatric' <radio> `input[name="OphTrOperationbooking_Operation_Sequence[paediatric]"]` (optional, default: No)
- 'Anaesthetist' <radio> `input[name="OphTrOperationbooking_Operation_Sequence[anaesthetist]"]` (optional, default: No)
- 'General Anaesthetic' <radio> `input[name="OphTrOperationbooking_Operation_Sequence[general_anaesthetic]"]` (optional, default: No)
- 'Week Selection' <checkbox group> `input[name="OphTrOperationbooking_Operation_Sequence[week_selection_weekN]"]` (optional, 5 checkboxes for weeks 1-5)

Save: POST to actionEditSequence or actionAddSequence; on success redirects to viewSequences; week_selection combined from 5 binary fields into single integer; end_date and week_selection can be set to null; validation errors displayed in error summary; model saves to OphTrOperationbooking_Operation_Sequence table.

#### Sessions

Lists operation sessions (individual scheduled theatre dates) with filter form and paginated table view; allows inline editing or navigation to individual edit form; displays current booked procedure count.

- 'Sequence' <text readonly> `#OphTrOperationbooking_Operation_Session_sequence_id` (optional, read-only if preset)
- 'Firm' <select> `#OphTrOperationbooking_Operation_Session_firm_id` (optional, default: - Emergency -)
- 'Theatre' <select> `#OphTrOperationbooking_Operation_Session_theatre_id` (optional, default: - None -)
- 'Date' <date> `#OphTrOperationbooking_Operation_Session_date` (required on create, read-only on edit)
- 'Start Time' <text> `#OphTrOperationbooking_Operation_Session_start_time` (optional, format HH:MM)
- 'End Time' <text> `#OphTrOperationbooking_Operation_Session_end_time` (optional, format HH:MM)
- 'Default Admission Time' <text> `#OphTrOperationbooking_Operation_Session_default_admission_time` (optional)
- 'Max Procedures' <text> `#OphTrOperationbooking_Operation_Session_max_procedures` (optional, numeric)
- 'Max Complex Bookings' <text> `#OphTrOperationbooking_Operation_Session_max_complex_bookings` (optional, numeric)
- 'Consultant' <radio> `input[name="OphTrOperationbooking_Operation_Session[consultant]"]` (optional, default: No)
- 'Paediatric' <radio> `input[name="OphTrOperationbooking_Operation_Session[paediatric]"]` (optional, default: No)
- 'Anaesthetist' <radio> `input[name="OphTrOperationbooking_Operation_Session[anaesthetist]"]` (optional, default: No)
- 'General Anaesthetic' <radio> `input[name="OphTrOperationbooking_Operation_Session[general_anaesthetic]"]` (optional, default: No)
- 'Available' <radio> `input[name="OphTrOperationbooking_Operation_Session[available]"]` (optional, default: Yes; shows/hides unavailable reason field)
- 'Unavailable Reason' <select> `#OphTrOperationbooking_Operation_Session_unavailablereason_id` (optional, only shown when available=No)

Save: POST to actionEditSession or actionAddSession; on success redirects to viewSessions; validation errors displayed in error summary; model saves to OphTrOperationbooking_Operation_Session table; cannot delete sessions with active bookings.

#### Theatres

Lists theatres and allows adding/editing/deleting theatres associated with sites; deletion prevented if theatre has active future bookings.

- 'Site' <select> `#OphTrOperationbooking_Operation_Theatre_site_id` (required, default: - Site -)
- 'Name' <text> `#OphTrOperationbooking_Operation_Theatre_name` (required)
- 'Code' <text> `#OphTrOperationbooking_Operation_Theatre_code` (optional)
- 'Ward' <select> `#OphTrOperationbooking_Operation_Theatre_ward_id` (optional, default: - None -; populated via AJAX based on selected site)

Save: POST to actionEditTheatre or actionAddTheatre; on success redirects to viewTheatres; validation errors displayed in error summary; model saves to OphTrOperationbooking_Operation_Theatre table; deletion via POST to actionDeleteTheatres checks for active bookings first via actionVerifyDeleteTheatres.

#### Waiting list contact rules

Lists waiting list contact rules in a hierarchical tree structure and allows adding/editing/deleting rules that determine which contact should be used for waiting list communications based on site, service, and firm.

- 'Parent Rule' <select> `.parent_rule_id` (optional, default: - None -)
- 'Rule Order' <text> `#OphTrOperationbooking_Waiting_List_Contact_Rule_rule_order` (required)
- 'Institution' <text display> (read-only, displays current institution name)
- 'Site' <select> `.site_id` (optional, default: - Not set -)
- 'Firm' <select> `.firm_id` (optional, default: - Not set -)
- 'Service' <select> `.service_id` (optional, default: - Not set -)
- 'Name' <text> `#OphTrOperationbooking_Waiting_List_Contact_Rule_name` (optional)
- 'Telephone' <text> `#OphTrOperationbooking_Waiting_List_Contact_Rule_telephone` (optional)

Save: POST to actionEditWaitingListContactRule or actionAddWaitingListContactRule; on success creates institution-level mapping and redirects to viewWaitingListContactRules; validation errors displayed in error summary; model saves to OphTrOperationbooking_Waiting_List_Contact_Rule table; mapping managed via createMapping() and hasMapping() methods.

#### Wards

Lists wards and allows adding/editing wards associated with sites; wards are reorderable via drag-and-drop on the listing page.

- 'Site' <select> `#OphTrOperationbooking_Operation_Ward_site_id` (required, default: - Site -)
- 'Name' <text> `#OphTrOperationbooking_Operation_Ward_name` (required)
- 'Long Name' <text> `#OphTrOperationbooking_Operation_Ward_long_name` (optional)
- 'Code' <text> `#OphTrOperationbooking_Operation_Ward_code` (optional)
- 'Directions' <textarea> `#OphTrOperationbooking_Operation_Ward_directions` (optional)
- 'Restriction Male' <radio> `input[name="OphTrOperationbooking_Operation_Ward[restriction_male]"]` (optional, default: No; adds 1 to restriction field if Yes)
- 'Restriction Female' <radio> `input[name="OphTrOperationbooking_Operation_Ward[restriction_female]"]` (optional, default: No; adds 2 to restriction field if Yes)
- 'Restriction Child' <radio> `input[name="OphTrOperationbooking_Operation_Ward[restriction_child]"]` (optional, default: No; adds 4 to restriction field if Yes)
- 'Restriction Adult' <radio> `input[name="OphTrOperationbooking_Operation_Ward[restriction_adult]"]` (optional, default: No; adds 8 to restriction field if Yes)
- 'Restriction Observation' <radio> `input[name="OphTrOperationbooking_Operation_Ward[restriction_observation]"]` (optional, default: No; adds 16 to restriction field if Yes)
- 'Active' <radio> `input[name="OphTrOperationbooking_Operation_Ward[active]"]` (required, default: 1 for new wards)

Save: POST to actionEditWard or actionAddWard; on success redirects to viewWards; validation errors displayed in error summary; restriction is a single integer field calculated from five binary radio button values using bitwise addition; model saves to OphTrOperationbooking_Operation_Ward table; display_order managed via actionSortWards for reordering.

### Operation Note (8 pages total, 4 documented below)

The other 4 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__operation-note.md`.

#### Generic Operation Default Comments

Manages default text snippets for generic operative procedures, backed by GenericProcedureDataController and form_OphTrOperationNote_Generic_Procedure_Data.php view.

- 'Procedure Term' dropdown `proc_id` (required, defaults to empty when adding; shows procedure name when editing)
- 'Default Text' textarea `OphTrOperationNote_Generic_Procedure_Data[default_text]` (optional)

Save: Form submission triggers redirect to list with 'Generic Operation data saved' flash message on success, or 'Generic Operation data: error saving' on validation failure.

**Live check (2026-07-24) - discrepancy:** Two issues found: (1) The 'Procedure Term' field is documented as a dropdown, but when editing an existing record, it's rendered as read-only text only (proc_id field is not displayed as a form input). The view code shows: if model->procedure is set, display procedure->term as text; otherwise show dropdown. Only the add form displays proc_id as a select dropdown. The edit form completely omits the proc_id field from rendering. (2) The success flash message capitalization doesn't match: code shows 'Generic Operation Data saved' (capital D) but documentation states 'Generic Operation data saved' (lowercase d).

#### Generic Operation Quick Text

Manages operation note quick-text attribute options with searchable, sortable list; backed by AttributesAdminController and BaseAdminController generic list/edit views.

- 'Name' text `OphTrOperationnote_Attribute[name]` (required, max 40 chars)
- 'Label' text `OphTrOperationnote_Attribute[label]` (required, max 255 chars)
- 'Procedure' dropdown `OphTrOperationnote_Attribute[proc_id]` (required, options sorted by procedure term)
- 'Is multiselect' checkbox `OphTrOperationnote_Attribute[is_multiselect]` (optional)

Save: Form submission redirects to list on success; delete via checkbox selection on list page.

#### Operative Devices

Manages operative device inventory with searchable, filterable list; backed by OperativeDeviceController and BaseAdminController generic list/edit views.

- 'Name' text `OperativeDevice[name]` (required)
- 'Active' checkbox `OperativeDevice[active]` (optional, displays as tick/remove icon in list)

Save: Form submission redirects to list on success; delete via checkbox selection on list page.

#### Personnel type default sets

Configures which personnel types are pre-selected by default for operation notes within a given subspecialty, institution, or site; backed by AdminController::actionPersonnelTypeDefaultSets.

- 'Subspeciality' dropdown `subspecialty_id` (required, GET parameter; defaults to first subspecialty on initial load)
- 'Institution' dropdown `institution_id` (optional, GET parameter; only shown to installation admins, includes '- All Institutions -' option)
- 'Site' dropdown `site_id` (optional, GET parameter; shown to both admins, includes '- All Sites -' option)
- 'Set items' multi-select `PersonnelTypeSet[items][personnel_type_id]` (optional, options from PersonnelType model; institution_id and site_id submitted as hidden fields based on which is selected)

Save: Form submission redirects to same URL preserving filter parameters. Delete button labeled 'Delete entire set for this {setting_level}' (subspecialty/institution/site) with id `#mt-delete` removes entire set if not a new record; on error displays validation messages via errorSummary.

### PASAPI

All 1 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__pasapi.md`.

### PatientTicketing (5 pages total, 3 documented below)

**Blind-spot check (2026-07-24):** Clinic Locations and Outcome Options controllers restrict non-admin users to their own institution at save time (checkAccess + institution_id validation), but pages remain reachable. Queue Set Categories page (admin/queueSetCategories) not in documented list but exists in crawl manifest with different row controls (add/delete row buttons instead of table-level add); 5 total pages in section vs 3 documented.

The other 2 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__patientticketing.md`.

#### Clinic locations

Manages clinic location options per institution and queue set using ClinicLocationsController with custom view; institution/queue set filters and sortable add/save row interface.

- 'Institution' dropdown `#filter_institution` (required for admin users; displays current institution name as text for non-admin)
- 'Queue Set' dropdown `#queueset_institution` (optional, empty option -, dynamically loads on institution change)
- 'Name' text `input[name="OEModule_PatientTicketing_models_ClinicLocation[{i}][name]"]` (required in sortable table rows)

Save: POST to actionIndex with table data; validates each model via save(); transaction rolled back if any row fails; display_order set sequentially; unselected rows auto-deleted.

#### Outcome Options

Manages ticket outcome options per institution and queue set using OutcomeOptionsController with custom view; includes name, episode status dropdown, and followup flag per row.

- 'Institution' dropdown `#filter_institution` (required for admin users; displays current institution name as text for non-admin)
- 'Queue Set' dropdown `#queueset_institution` (optional, empty option -, dynamically loads on institution change)
- 'Name' text `input[name="OEModule_PatientTicketing_models_TicketAssignOutcomeOption[{i}][name]"]` (required in sortable table rows)
- 'Episode Status' dropdown `select[name="OEModule_PatientTicketing_models_TicketAssignOutcomeOption[{i}][episode_status_id]"]` (optional, empty option -)
- 'Followup' checkbox `input[type="checkbox"][name="OEModule_PatientTicketing_models_TicketAssignOutcomeOption[{i}][followup]"]` (optional)

Save: POST to actionIndex with table data; validates each model via save(); transaction rolled back if any row fails; display_order set sequentially; unselected rows auto-deleted.

#### Queue Sets

Displays queue sets list with edit/permissions/add actions and institution mapping controls using AdminController actionIndex with custom view; handles add, edit, delete, activate/deactivate, and institution assignment for queue sets.

- Queue Set name (read-only display link, clickable to view queue hierarchy)
- 'Assigned to Current Institution' checkbox column (for selecting queue sets to map/unmap)

Controls: Edit button (actionUpdateQueueSet), Permissions button (actionQueueSetPermissions), Add Queue Set button (actionAddQueueSet), Add selected to current Institution button (maps to /admin/addMapping), Remove selected from current Institution button (maps to /admin/removeMapping). Table supports drag-drop display_order reordering via sortQueueSets action.

Save: Buttons trigger different controller actions; add/update/delete operations create audit log entries; institution mappings handled separately via addMapping/removeMapping endpoints; queue deactivation cascades to child queues.

### Payload Processor API (6 pages total, 2 documented below)

**Blind-spot check (2026-07-24):** Manual upload form has disabled submit button in template to prevent barcode-scanner enter-key emulation triggering premature submission; re-enabled via JavaScript form-submit handler; Requests page supports complex filtering without unusual logic or feature flags.

The other 4 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__payload-processor-api.md`.

#### Request - Manual Upload

Allows manual upload of API requests with custom POST fields and file attachment, backed by DefaultController::actionManualupload() and FormDataHandler.

- 'Request Type' <select> `request_type` (required, populated from RequestType model)
- 'System Message' <text> `system_message` (optional, free-text field for request context)
- 'File' <file> `file` (optional, file upload field)
- 'Key' <text> `.js-field-name` (optional repeating, dynamic extra POST field names)
- 'Value' <text> `.js-field-post` (optional repeating, dynamic extra POST field values)
- 'Add' <button> `#add-new-postfield` (optional, adds new key-value row via Mustache template)

Save: POST with multipart/form-data to same URL; FormDataHandler processes and attaches files; FormDataHandler::save_handler::errorSummary() returns validation errors; on success displays uploaded requests below form in table; disabled submit button in form template prevents premature submission on barcode scanner enter-key (re-enabled via JavaScript form-submit handler)

#### Requests

Lists all API requests with extensive filtering by date range, ID range, status, retry count, routine details, and dynamic extra filters/columns, backed by RequestController::actionIndex() with complex CDbCriteria filtering.

Default filter fields:
- 'From' <date text> `from_date` (optional, format yyyy-mm-dd, filters last_modified_date >=)
- 'To' <date text> `to_date` (optional, format yyyy-mm-dd, filters last_modified_date <=)
- 'From' <time text> `from_time` (optional, format hh:mm:ss or hh, paired with from_date)
- 'To' <time text> `to_time` (optional, format hh:mm:ss, defaults to 23:59:59 if empty)
- 'Set Today' <button> `#set_today_date` (optional, auto-fills date fields)
- 'Id' from <text> `from_id` (optional, filters id >=)
- 'Id' to <text> `to_id` (optional, filters id <=, defaults to from_id if empty)
- 'Complete' <checkbox> `show_complete` (optional, default checked)
- 'Incomplete' <checkbox> `show_incomplete` (optional, default checked)
- 'Failed' <checkbox> `show_failed` (optional, default checked)
- 'Show try count > 1' <checkbox> `show_trycount_higher_than_one` (optional)
- 'Order By' <select> `order_by` (optional, values: latest|earliest)
- 'Request Routine Name' <select> `routine_and_status_filter[routine_name]` (optional, populated from RoutineLibrary)
- 'Request Routine Status' <select> `routine_and_status_filter[routine_status]` (optional, values: COMPLETE|NEW|VOID|RETRY|FAILED)

Column visibility toggles via checkboxes:
- show_id, show_payload_received, show_request_type, show_overall_status, show_system_message, show_steps, show_payload_size, show_attached_size

Dynamic column/filter addition:
- 'Add Column' <button> `#add-column` (optional, AdderDialog for request_details columns)
- 'Add Filter' <button> `#add-extra-filter` (optional, AdderDialog for extra filters)

Save: GET request with all filter/column parameters as query string; results paginated (20 per page); Show attachments/routines/logs toggle via JavaScript; Retry button resets routine status via AJAX GET to `/Api/Request/admin/requestRoutine/resetToNew`

### Procedure Management (9 pages total, 5 documented below)

**Blind-spot check (2026-07-24):** LensRemovalProcedure has non-standard UX: actionList renders the edit view inline with a separate actionSave; ClinicProcedure filters list to only is_clinic_proc=1 procedures, so unrelated procedures are invisible on that page despite the general Procedure list showing all.

The other 4 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__procedure-management.md`.

#### Benefits

Lists and manages procedure benefits used to record the beneficial outcomes of procedures. Backed by BenefitController and /oeadmin/benefit/index and /oeadmin/benefit/edit views.

- 'Name' text `#Benefit_name` (required)
- 'Active' checkbox `#Benefit_active` (optional, default: unchecked)

Save: Form posts to /oeadmin/benefit/edit with Benefit[name] and Benefit[active]; returns to /oeadmin/benefit/list/ on success or redisplays form with validation errors from model rules.

**Live check (2026-07-24):** matched the live page. List page loads correctly with BenefitController. Edit form at /oeadmin/benefit/edit contains all documented fields: #Benefit_name (text input), #Benefit_active (checkbox). Form posts via Benefit[name] and Benefit[active]. All field types and selectors match documentation.

#### Complications

Lists and manages procedure complications used to record possible adverse outcomes. Backed by ComplicationController and /oeadmin/complication/index and /oeadmin/complication/edit views.

- 'Name' text `#Complication_name` (required)
- 'Active' checkbox `#Complication_active` (optional, default: unchecked)

Save: Form posts to /oeadmin/complication/edit with Complication[name] and Complication[active]; returns to /oeadmin/complication/list/ on success or redisplays form with validation errors from model rules.

**Live check (2026-07-24):** matched the live page. List page loads correctly with ComplicationController. Edit form at /oeadmin/complication/edit contains all documented fields: #Complication_name (text input), #Complication_active (checkbox). Form posts via Complication[name] and Complication[active]. All field types and selectors match documentation.

#### OPCS Codes

Lists and manages OPCS (Office of Population Censuses and Surveys) codes that map to procedures for procedural coding and classification. Backed by OpcsCodeController and /oeadmin/opcsCode/index and /oeadmin/opcsCode/edit views.

- 'Name' text `#OPCSCode_name` (required)
- 'Description' text `#OPCSCode_description` (required)
- 'Active' checkbox `#OPCSCode_active` (optional, default: unchecked)

Save: Form posts to /oeadmin/opcsCode/edit with OPCSCode[name], OPCSCode[description], and OPCSCode[active]; returns to /oeadmin/opcsCode/list/ on success or redisplays form with validation errors from model rules.

#### Post-Op Complications

Lists and manages post-operative complications used within the OphCiExamination module to track complications after surgery. Backed by PostOpComplicationController and /oeadmin/postopcomplication/index and /oeadmin/postopcomplication/edit views.

- 'Name' text `[data-test="post-op-complication-admin-name"]` (required)
- 'Active' checkbox `[data-test="post-op-complication-admin-active"]` (optional, default: unchecked)

Save: Form posts to /oeadmin/PostOpComplication/edit with OEModule_OphCiExamination_models_OphCiExamination_PostOpComplications[name] and [active]; returns to /oeadmin/PostOpComplication/list/ on success or redisplays form with validation errors.

#### Procedures

Manages surgical and clinical procedures with comprehensive attributes including terminology, duration, coding, and associated benefits, complications, and risks. Backed by ProcedureController and /oeadmin/procedure/index and /oeadmin/procedure/edit views.

- 'Term' text `#Procedure_term` (required)
- 'Short Format' text `#Procedure_short_format` (required)
- 'Default Duration' numeric `#Procedure_default_duration` (required, max 65535 minutes)
- 'SNOMED Code' text `#Procedure_snomed_code` (required)
- 'SNOMED Term' text `#Procedure_snomed_term` (required, max 255 chars)
- 'ECDS Code' text `#Procedure_ecds_code` (optional)
- 'ECDS Term' text `#Procedure_ecds_term` (optional, max 255 chars)
- 'Aliases' text `#Procedure_aliases` (optional)
- 'Unbooked' checkbox `#Procedure_unbooked` (optional, default: unchecked)
- 'Active' checkbox `#Procedure_active` (optional, default: unchecked)
- 'Clinic / Outpatient procedure?' checkbox `#Procedure_is_clinic_proc` (optional, default: unchecked)
- 'OPCS Code' multi-select `#$opcs_code` (optional, multi-choice dropdown backed by all OPCSCode records)
- 'Benefit' multi-select `#$benefits` (optional, multi-choice dropdown backed by all Benefit records)
- 'Complication' multi-select `#$complications` (optional, multi-choice dropdown backed by all Complication records)
- 'Whiteboard Risk/s' multi-select `#$risks` (optional, multi-choice dropdown backed by OphCiExaminationRisk records)
- 'Operation Note Element' multi-select `[data-test="operation-note-element-dropdown"]` (optional, multi-choice dropdown of non-mandatory operation note element types)
- 'Low Complexity Criteria' rich text `#Procedure_low_complexity_criteria` (optional, HTML editor with TinyMCE)

Save: Form posts to /oeadmin/procedure/edit with Procedure[...], opcs_codes[], benefits[], complications[], risks[], notes[], and calls saveChecklistSets() if procedure exists; returns to /oeadmin/procedure/list/ on success or redisplays form with validation errors.

### Referral (2 pages total, 2 documented below)

**Use the four-segment routes only.** The short `/Referral/admin/<thing>` forms the module config declares are dead (BUG-144); `/Referral/ReferralAdmin/<Controller>/<action>` works. The sidebar group **Referral** sits between "Procedure management" and "Request forms" and renders its entries alphabetically, so Groups appears above Options even though the config declares Options first. Sitemap: `areas/admin__referral.md`.

The underlying tables are `referral_referral`, `referral_referral_rtt_clock_state`, `referral_rtt_clock_state_option`, `referral_rtt_clock_state_option_group` and `referral_rtt_clock_state_valid_next`, each with a `_version` twin - **not** `referral` / `referral_rtt_clock_state`, which is the obvious guess and wrong.

#### RTT Clock State Options

List `/Referral/ReferralAdmin/RTTClockStateOption/index`, edit `.../edit?id=<id>` (also accepts `.../edit/id/<id>`). Form `#rtt-clock-state-option-form`, heading 'Add RTT Clock State Option' / 'Edit RTT Clock State Option' `[data-test="rtt-clock-state-option-heading"]`.

- 'Type' \<select\> `#RTTClockStateOption_type` `[data-test="type-select"]` (empty option '- Select type -')
- 'Code' \<text\> `#RTTClockStateOption_code` `[data-test="code-input"]` (the form's focus field)
- 'Name' \<text\> `#RTTClockStateOption_display_value` `[data-test="name-input"]` - note the attribute is `display_value`, not `name`
- 'Group' \<select\> `#RTTClockStateOption_group_id` `[data-test="group-select"]` (empty option '- No group -')
- 'Guidance' \<textarea\> `#RTTClockStateOption_usage_guidance` `[data-test="guidance-input"]` (4 rows, autosize)
- 'Allowed next options' \<multi-select widget\> `#valid-next-options` `[data-test="valid-next-options-select"]`, posts as `valid_next_option_ids[]`; options render as `<code> - <name>`
- 'Clock running' \<checkbox\> `#RTTClockStateOption_clock_running` `[data-test="clock-running-checkbox"]` (unticked on a new record)
- 'Active' \<checkbox\> `#RTTClockStateOption_active` `[data-test="active-checkbox"]` (ticked on a new record)

Save: standard `OEHtml::submitButton()` plus a 'Cancel' that navigates to the list.

#### RTT Clock State Option Groups

List `/Referral/ReferralAdmin/RTTClockStateOptionGroup/index`, edit `.../edit?id=<id>`. The list is a **drag-to-reorder** table `[data-test="rtt-clock-state-option-groups-table"]` inside `#rtt-clock-state-option-group-sort-form`, columns (reorder handle) / Name / Active; rows are `[data-test="group-<id>"]`, clickable via `data-uri` (no href - the usual OE row-click), and the order posts to `.../sort` as `RTTClockStateOptionGroup[display_order][]`. Active shows as a tick/cross icon `[data-test="group-active-icon"]`, not text.

Edit form `#rtt-clock-state-option-group-form`, heading 'Add/Edit RTT Clock State Option Group' `[data-test="rtt-clock-state-option-group-heading"]`:

- 'Name' \<text\> `#RTTClockStateOptionGroup_name` `[data-test="group-name-input"]` (focus field)
- 'Active' \<checkbox\> `#RTTClockStateOptionGroup_active` `[data-test="group-active-checkbox"]` (ticked on a new record)
- `display_order` is a hidden field on the edit form - reordering is done on the list, not here.

### Request Forms (3 pages total, 2 documented below)

**Blind-spot check (2026-07-24):** Request forms status page (/OphCoRequestForm/Admin/status) exists but uses read-only display; actionStatus() and actionEditStatus() show status management is gated to admin users only per viewList() access checks

The other 1 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__request-forms.md`.

#### Categories

Manages request form categories with a lookup table interface. Controller: OphCoRequestForm/AdminController::actionViewCategories(). View: list_RequestFormCategories.php.

This page displays existing request form categories in a read-only table. No input fields present on this page.

Save: N/A - page uses standard Add/Delete button controls for selected checkbox rows

**Live check (2026-07-24):** matched the live page. Page displays read-only table with request form categories. Contains selectall checkbox and Add/Delete button controls for managing rows. No input/search fields present on page itself. Controller action OphCoRequestForm/AdminController::actionViewCategories confirmed via debug output.

#### Request forms

Manages request forms with filtering by institution and clinical context. Controller: OphCoRequestForm/AdminController::actionFormIndex(). View: request_form_index.php.

- 'Name' text field `input[name="name"]` (optional, default: empty, searches form name)
- 'Category' select dropdown `select[name="category_id"]` (optional, default: All)
- 'Institution' select dropdown `select[name="institution_id"]` (optional, default: All)
- 'Site' select dropdown `select[name="site_id"]` (optional, default: All)
- 'Subspecialty' select dropdown `select[name="subspecialty_id"]` (optional, default: All)
- 'Firm' select dropdown `select[name="firm_id"]` (optional, default: All)

Save: Clicking Search (#search-button) submits filter form and refreshes results table; no server-side validation errors returned on filter page itself

**Live check (2026-07-24):** matched the live page. All 6 documented filter fields present with correct types: 'Name' (text input #name), 'Category' (select #category_id), 'Institution' (select #institution_id), 'Site' (select #site_id), 'Subspecialty' (select #subspecialty_id), 'Firm' (select #firm_id). Search button (#search-button) present. All select dropdowns default to 'All' as documented. Controller action OphCoRequestForm/AdminController::actionFormIndex confirmed. Field names align with documentation selectors (both ID and name-based selectors would work).

### SSO Settings

All 2 pages are the plain lookup-table pattern(s) documented in `paths.md` - no bespoke entries here. Sitemap: `areas/admin__sso-settings.md`. **Blind-spot check (2026-07-24):** SsoController::accessRules() restricts all settings actions to 'admin' role

### System (2 pages total, 1 documented below)

The other 1 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__system.md`.

#### Settings

Displays system settings grouped by category, backed by AdminController::actionSettings() and protected/views/admin/settings.php; individual settings are edited via the edit page accessed by clicking a setting row.

- 'Institution' <select> `#js-institution-setting-filter` (admin users only, optional, default: "All institutions")
- 'Expand All' <span> `.js-expand-all` (optional, expands all setting groups)
- 'Collapse All' <span> `.js-collapse-all` (optional, collapses all setting groups)

Save: No save on this page; click a setting row (data-test="admin-system-setting") to navigate to /admin/editSystemSetting to edit that setting.

**Live check (2026-07-24):** matched the live page. All documented elements verified: Institution select (#js-institution-setting-filter) exists with correct options; Expand All (.js-expand-all) and Collapse All (.js-collapse-all) present and clickable (contain icon elements); setting rows with data-test='admin-system-setting' exist on <tr> elements with class='clickable'; navigation to /admin/editSystemSetting confirmed in PHP view and controller code

### Therapy Application (7 pages total, 3 documented below)

The other 4 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__therapy-application.md`.

#### Diagnoses

Displays therapy disorder hierarchy in a 2-level structure (Level 1 and Level 2), managed through OphCoTherapyapplication_TherapyDisorder model via DiagnosisController in the OphCoTherapyapplicationAdmin submodule.

- 'Disorder' <select> `#disorder_id` (required, searches disorder catalog using DiagnosisSelection widget)

Save: POST to /OphCoTherapyapplication/admin/diagnosis/addDiagnosis; adds disorder to the specified level if not already present; redirects to viewDiagnoses on success.

**Live check (2026-07-24) - discrepancy:** Disorder field selector ID and type incorrect. Documentation says 'Disorder' <select> `#disorder_id`, but actual field is <input:text> with id `#DiagnosisSelection[new_disorder_id]` (autocomplete search). Placeholder text is 'type the first few characters to search'. The DiagnosisSelection widget usage is correct, but the selector ID and field type in documentation need updating.

#### Email Recipients

Configures email recipients for therapy application letters by institution, site, and letter type via OphCoTherapyapplication_Email_Recipient model, with fallback rule logic for matching.

- 'Institution' <select> `#OphCoTherapyapplication_Email_Recipient_institution_id` (required, empty: "- Select Institution -")
- 'Site' <select> `#OphCoTherapyapplication_Email_Recipient_site_id` (optional, empty: "- All sites -")
- 'Letter types' <select> `#OphCoTherapyapplication_Email_Recipient_type_id` (optional, empty: "- Both types -")
- 'Recipient name' <text> `#OphCoTherapyapplication_Email_Recipient_recipient_name` (required)
- 'Recipient email' <text> `#OphCoTherapyapplication_Email_Recipient_recipient_email` (required, email validation applied)

Save: POST to /OphCoTherapyapplication/admin/addEmailRecipient or editEmailRecipient; validates email format; redirects to viewEmailRecipients on success.

**Live check (2026-07-24):** matched the live page. All five form fields match documentation exactly. Add form navigates to /OphCoTherapyapplication/admin/addEmailRecipient. Institution/Site/Letter types selects have correct empty options ('- Select Institution -', '- All sites -', '- Both types -'). Recipient name and email text inputs present with correct selector IDs.

#### File Collections

Manages file collections for therapy applications, grouping multiple uploaded files by institution via OphCoTherapyapplication_FileCollection model; supports file download as zip.

- 'Institution' <select> `#OphCoTherapyapplication_FileCollection_institution_id` (required)
- 'Name' <text> `#OphCoTherapyapplication_FileCollection_name` (required)
- 'Summary' <textarea> `#OphCoTherapyapplication_FileCollection_summary` (required, max 40 chars)
- 'Files' <file> `#OphCoTherapyapplication_FileCollection_files` (multiple input, optional; limited by ini_get(max_file_uploads), ini_get(upload_max_filesize), ini_get(post_max_size))

Save: POST to /OphCoTherapyapplication/admin/addFileCollection or editFileCollection; validates file MIME types via OphCoTherapyapplication_FileCollection::checkMimeType(); creates ProtectedFile entries for each uploaded file; redirects to viewFileCollections on success.

### Worklist (7 pages total, 4 documented below)

The other 3 pages in this section are the plain lookup-table pattern(s) in `paths.md`. Sitemap: `areas/admin__worklist.md`.

#### Automatic Worklists Definitions

Listing and management interface for automatic worklist definitions, backed by Admin/WorklistController::actionDefinitions() and WorklistDefinition model.

- 'Add Definition' button link `a[href*="/definitionUpdate"]` (action, green button)

No editable inline fields on this page. Clicking a row or Edit button navigates to definition_edit view. Worklist definitions are displayed in a sortable table showing Name, Patient Identifier Type, and Default Pathway Type. Each definition shows Instances count and action buttons for Edit (if editable), View, Instances list, Delete Instances (if instances exist) or Generate (if no instances).

Save: Not applicable; list view only. Definitions are created/updated via /Admin/worklist/definitionUpdate/ action.

**Live check (2026-07-24):** matched the live page. All documented features confirmed: 'Add Definition' button with a[href*="/definitionUpdate"] present; table displays Name, Patient Identifier Type, and Default Pathway Type columns; each row shows Instances count and action buttons (Edit, View, Instances list, Generate/Delete Instances); list view only with no inline editable fields.

#### Clinical Pathway Presets

Clinical pathway preset configuration listing backed by Admin/WorklistController::actionPresetPathways() displaying PathwayType models with step composition and activation status.

- 'Add Pathway Preset' button submit `button[formaction*="/addPathwayPreset"]` (action, green)
- 'Toggle Activation Status' button submit `button[data-test="toggle-active-btn"]` (action, red)
- Pathway type selection checkbox `input[type="checkbox"][name="pathway[]"]` (required for bulk actions)

Pathway types are displayed in a table. Each row shows the pathway name (linked to edit view), visual representation of pathway steps, a secondary checkbox for step selection, and an active status indicator. A duplicate icon per row allows duplication. Form posts to togglePathwayPresetsActivationStatus to toggle selected pathways' active state.

Save: Selected pathways' active status is toggled via POST to /Admin/worklist/togglePathwayPresetsActivationStatus. On success, page redirects to presetPathways list.

**Live check (2026-07-24) - discrepancy:** Confirmed features: 'Add Pathway Preset' button with formaction*="/addPathwayPreset" present; 'Toggle Activation Status' button with data-test="toggle-active-btn" present; pathway selection checkboxes with name="pathway[]" present; pathway names linked to /Admin/worklist/editPathwayPreset/{id}. MISSING: The documented 'duplicate icon per row allows duplication' feature does not appear on the actual page. Extensive searches for aria-label, href, or formaction attributes related to clone/duplicate functionality found no such control. This is a significant discrepancy between documentation and implementation.

#### Worklist Wait Times

Generic inline-editable listing and mapping for worklist wait time thresholds backed by Admin/WorklistController::actionWaitTimes() using genericAdmin widget and WorklistWaitTime model.

- 'Label' text input `input[name="label[{i}]"]` (required, text up to DB column length)
- 'Wait Minutes' text input `input[name="wait_minutes[{i}]"]` (required, positive integer)
- 'Active' checkbox `input[name="active[{i}]"]` (optional, default unchecked for new rows)
- 'Add' submit button `button#et_admin-add[data-test="add-row"]` (creates new empty row below, styled blue)
- 'Save' submit button `button#et_admin-save[data-test="save-rows"]` (persists all row changes)
- 'Add selected to current site' submit button `button#et_admin-map-add` (adds checkbox-selected rows to institution/site/subspecialty/firm mapping depending on level dropdown)
- 'Remove selected from current site' submit button `button#et_admin-map-remove` (removes selected from mapping)

Table includes read-only mapping indicator columns (tick/remove icons) showing whether each row is assigned to the current site, subspecialty, and firm. Rows can be drag-reordered via Order column (up/down arrows). Delete link per row removes it without saving (if permitted). Rows display inline errors if validation fails on save.

Save: Submit to /Admin/worklist/waitTimes. On success, page redirects to same URL with success flash message. On error, rows with invalid data display error text inline and transaction rolls back (no partial saves).

#### Worklist custom path steps

Listing and institutional mapping interface for custom pathway step types backed by Admin/WorklistController::actionCustomPathSteps() displaying PathwayStepType models.

- 'Add Custom Path Step' link button (action, navigates to /Admin/worklist/editCustomPathStep for new step creation)
- 'Add Selected to Current Institution' submit button `button#et_add_mapping` (maps checkbox-selected custom steps to current institution)
- 'Remove Selected from Current Institution' submit button `button#et_delete_mapping` (unmaps selected from current institution)

Custom pathway steps are displayed in a table showing Long Name, Short Name, Default State (To Do/Active/Completed/Draft/N/A), Active status (tick/remove icon), and institutional assignment status (tick/remove icon). A select-all checkbox at table top controls row selection. Each row is clickable to edit at /Admin/worklist/editCustomPathStep/{id}.

Save: POST to /Admin/worklist/addStepInstitutionMapping or /Admin/worklist/deleteStepInstitutionMapping. On success, redirects to custom path steps list with updated mapping state.

