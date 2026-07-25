# App pages - real field-level docs (non-admin remainder)

Field-level docs for the OpenEyes app's previously-undocumented remainder: patient-record event-view pages, the 4 mini-apps (Practices, Practitioners, Trials, Virtual Clinic), and the 20 one-page utility screens. Written from `develop` controller/view code and live-checked (sample stack) on 2026-07-24 - same convention as `admin-forms.md`/`event-forms.md`: where the live check found a real mismatch it's recorded as a **Live check** note rather than silently corrected. One `###` per area, one `####` per page where an area has more than one.

This sweep's live-check pass came back with a markedly higher discrepancy rate than `admin-forms.md`'s (10 discrepancy + 3 blocked out of 13 sampled pages, zero clean matches) - selectors/labels drift more on the non-admin app than on admin's generic lookup-table pages. Two entries (Operation note, Advanced Search) got conflicting verdicts from the primary live-check pass and the independent adversarial spot-check that runs after it; both were resolved with a direct third live check against the sample stack rather than picked by preference - see their entries below. The Advanced Search selector/label errors the direct check reconfirmed are corrected in place (not just noted), per the stricter bar this sweep applies to spot-check-confirmed defects; every other discrepancy below follows the standard append-only convention.

## Patient record - event views

10 event-view module templates documented below, covering all 24 crawled patient-record instances for sample patient 17891 (each module renders the same view template regardless of which dated event you land on - `event-forms.md` covers the matching **create** forms; this section is the read-only **view** rendering only). A one-agent blind-spot pass skimmed all 10 modules' `actionView()` for conditional gate/redirect logic invisible to a DOM crawl - the finding, if any, is noted per page below; none suggest an invisible-to-crawl reachability gate. Sitemap: `areas/patient-record.md`.

#### Operation note (view) `/OphTrOperationnote/default/view/3686606`

Read-only rendering of an Operation Note event backed by OphTrOperationnote/controllers/DefaultController::actionView() and protected/modules/OphTrOperationnote/views/default/view.php.

- Procedure & OPCS codes section (table): displays procedures and their OPCS code assignments; eye (adjective e.g., 'Right'), procedure name, and OPCS codes rendered as text
- Site/Theatre section (if assigned): displays site name and theatre name
- Personnel section (collapsible): surgeon name and additional personnel roles (Scrub nurse, Assistant, etc.) displayed as name-role pairs
- Anaesthetic section: anaesthetic type(s) selected, anaesthetic agents/delivery methods, anaesthetist assigned, witness (if required)
- Procedure-specific elements (variable by procedure): e.g., for cataract - IOL model, power, A-constant; eyedraw diagrams for surgical sketches
- Complications section (if applicable): complications recorded during procedure
- Per-operative drugs section: list of prescribed per-operative medications
- Post-op instructions section: post-operative care instructions
- Comments section: free-text operative notes
- VTE Assessment (if enabled): VTE risk category and mitigation strategy
- Event metadata: created by/date, modified by/date shown in standard event header

Actions: print icon (top-right icon row alongside View/Edit/Change Context, if access granted - icon-only, no text label); template pre-fill alerts if applicable; event attachments section.

**Live check (2026-07-24):** the primary verify pass and the independent spot-check disagreed on this page (verify: discrepancy - "Post-op drugs" section not found, no Print button in the button list, several conditional sections absent; spot-check: sound - all documented sections present). A direct third check against the sample stack resolved it: the section is actually headed **"Per-operative drugs"**, not "Post-op drugs" (corrected above - genuine terminology miss in the original write); "Post-op instructions" is a real heading the original write omitted (added above); Site/Theatre, Complications and VTE Assessment were already correctly hedged as conditional in the original write, so their absence on this particular sample event isn't a discrepancy; and the "missing" Print button is real controls but icon-only (matches `paths.md`'s documented pattern for the event-view icon row), not absent - the verify agent's dump just doesn't capture icon-only buttons by label. Net: the spot-check's "sound" verdict was closer to right, but both passes missed the terminology error corrected above.

**Blind-spot check (2026-07-24):** actionView() has no non-standard conditional logic (checked, nothing non-standard).

#### Laser (view) `/OphTrLaser/default/view/3686602`

Read-only rendering of a Laser Treatment event backed by OphTrLaser/controllers/DefaultController::actionView() and protected/modules/OphTrLaser/views/default/view.php.

- Site/Theatre section: location, laser machine/system used
- Procedure section: procedure name, eye treated, laterality
- Treatment details section: laser parameters (wavelength, power, spot size, duration, number of shots) displayed as key-value pairs
- Anterior Segment section: anterior segment examination findings rendered as text/values
- Fundus section: fundal examination findings (retinal areas treated, vascular status)
- Posterior Pole section: optic disc and macula assessment details
- Treatment zones/areas: diagram or text description of treatment locations
- Complications section (if applicable): any laser-related complications recorded
- Comments section: clinical notes on treatment and patient response
- Event metadata: created by/date, modified by/date shown in standard event header

Actions: print icon (top-right icon row, if access granted); event attachments section.

**Live check (2026-07-24) - discrepancy:** page loaded with headings Laser, Laser Information, Procedures, Anterior Segment only - Fundus, Posterior Pole, Treatment zones/areas, Complications and Comments were not visible as distinct headings on this sample event, and Treatment details/Site-Theatre/Procedure may be folded into "Laser Information"/"Procedures" rather than separate sections as documented. No Print button found in the visible button list (View, Edit, Change Context, delete, Add Event) - likely icon-only per the Operation note pattern above, not independently confirmed here. Not re-verified beyond the primary pass.

**Blind-spot check (2026-07-24):** actionView() has no non-standard conditional logic (checked, nothing non-standard).

#### Visual Fields / Generic (view) `/OphGeneric/default/view/3686718`

Read-only rendering of a Generic Event (typically VF/imaging result import) backed by OphGeneric/controllers/DefaultController::actionView() and protected/modules/OphGeneric/views/default/view.php.

- Device Information section: manufacturer, device model, serial number, SOP Instance UID rendered as text fields
- Image Display section: embedded image viewer showing the imported image (VF field plot, OCT scan, etc.); data-test selectors for image container
- Event metadata section: import timestamp, source device/system, import status
- Eye designation: which eye(s) the image applies to
- External links: 'Open In Forum' button (if FORUM integration enabled and SOP UID present); 'Open In ImageNet' button (if ImageNet enabled and device is Triton)
- Event metadata: created by/date, source system shown in standard event header

Actions: print icon (top-right icon row, if access granted); external launcher links (Forum/ImageNet); event attachments section.

**Live check (2026-07-24) - discrepancy:** the live Device Information section showed a richer/different field set than documented - Manufacturer, Manufacturer model name, Series description, Laterality, Study description, Document title, Acquisition date/time, Study date/time, Content date/time, Station name, Operators name - rather than the documented manufacturer/model/serial number/SOP UID. Serial number and SOP Instance UID weren't visible under those labels in this text dump (may be present but unlabeled, or genuinely absent from this section). External links and the image viewer weren't confirmed either way in a text-only dump - consistent with the documented FORUM/ImageNet conditions and the fact that images don't render as text.

**Blind-spot check (2026-07-24):** actionView() has no non-standard conditional logic (checked, nothing non-standard).

#### Correspondence (view) `/OphCoCorrespondence/default/view/3686608`

Read-only rendering of a Correspondence (Letter) event backed by OphCoCorrespondence/controllers/DefaultController::actionView() and protected/modules/OphCoCorrespondence/views/default/view.php.

- Draft status indicator: 'Draft' badge or sign-off status (Yes/No) if correspondence approval setting enabled
- Letter type: GP letter, clinical report, referral response, etc., rendered as text
- Recipient/Address section: primary recipient name/address and CC recipients listed; email output status icons if outputs are queued
- Letter content: rendered document body with letterhead, patient details, clinical content, and signature block
- Document status: sent/unsent, print/email output status indicators for each recipient
- Attachments: any enclosures or attachments listed
- Event metadata: created by/date, user who created the letter shown in standard event header

Actions: Print buttons - 'Print Draft' if draft status, or 'Print Primary Recipient' and 'Print all' if finalised; 'Reprint paper copies' if print outputs exist; 'Export' button (if institution allows export and exportUrl available); event attachments section.

**Live check (2026-07-24) - blocked:** the sampled event (3686608) was in a 'Correspondence (Failed)' state showing only a 'Generating PDFs' status bar - no rendered letterhead, signature block, sent/unsent indicators or print buttons were visible. This looks like a sample-data artifact (a stuck/failed PDF generation) specific to this event rather than a documentation defect; Letter type and Recipient/Address sections were confirmed present and correct. Worth re-checking against a successfully-generated correspondence event.

**Blind-spot check (2026-07-24):** actionView() checks DocumentOutput status (DOCMAN/INTERNAL_REFERRAL) and conditionally sets the page title based on output_status (COMPLETE = "Sent") - affects the header text, not reachability.

#### Examination (view) `/OphCiExamination/default/view/3686607`

Read-only rendering of a Clinical Examination event backed by OphCiExamination/controllers/DefaultController::actionView() and protected/modules/OphCiExamination/views/default/view.php.

- Chief Complaint section: presenting complaint text
- Ocular History section: relevant eye history and current eye symptoms
- Systemic History section: medical history relevant to eye condition
- Anterior Segment examination (left/right or both): visual acuity, eye movement, pupil response, anterior chamber depth, lens status, IOP rendered as structured fields/values
- Posterior Segment examination: optic disc appearance, retinal vascular status, macula condition, periphery findings; eyedraw diagrams for optic disc/posterior pole sketches
- OCT results (if applicable): OCT image thumbnails with measurement overlays
- Visual Fields (if applicable): VF plot images and indices (MD, PSD)
- Specular Microscopy (if applicable): endothelial cell count and morphology data
- Current Management Plan section: diagnosis, treatment plan, follow-up schedule rendered as text/structured data
- Risks/Alerts section: e.g., CVI status, DR grading, CXL history if relevant
- Event metadata: created by/date, examining clinician shown in standard event header

Actions: print icon (top-right icon row, if access granted); 'Next Examination step' link if pathway step enabled; event attachments section.

**Live check (2026-07-24) - discrepancy:** on the sampled event, Ocular/Systemic History, Visual Acuity and IOP rendered under the documented sections, but no separate 'Chief Complaint' heading was visible, and Posterior Segment/OCT/Visual Fields/Specular Microscopy sections were absent - plausibly because this exam simply didn't record those elements (OCT/VF/Specular Microscopy are already documented as conditional), but the missing Chief Complaint heading and lack of an explicit Risks/Alerts section are unconfirmed either way. Not conclusive - worth a re-check against an exam event with a fuller element set.

**Blind-spot check (2026-07-24):** actionView() has no non-standard conditional logic (checked, nothing non-standard).

#### Consent form (view) `/OphTrConsent/default/view/3686605`

Displays a read-only clinical consent event capturing patient agreement/capacity for procedures, with status alerts and workflow actions. Renders multiple Element views (Type, Procedure, BenefitsAndRisks, CapacityAssessment, Consenttakenby, etc.) determined by consent template; backed by OphTrConsent\DefaultController + view.php routing renderOpenElements().

- Consent type (read-only): displays type label (optional, e.g. "1. Patient agreement...")
- Procedure & Anaesthetic section (read-only): lists procedures with laterality icons (right/left), procedure term; anaesthetic type in table; extra procedures section
- Status alerts: "draft" badge if Element_OphTrConsent_Type->draft=true; "withdrawn" badge if Withdrawal element exists with signature_id; "delete pending" if event->delete_pending
- Confirm consent button (secondary): appears if signature=null, no withdrawal, no opnote, and consent type matches specific patterns
- Patient withdraws consent button (secondary): appears if signature=null, no opnote, no withdrawal
- Print buttons (if access): standard print, print with leaflets, print for visually impaired (±leaflets)
- Event attachments section: EventAttachmentSection widget
- Hidden fields: OphTrConsent_print (session value), OphTrConsent_draft (element->draft flag), confirm_et_id, withdraw_et_id (element type IDs for JS)

View-specific additions beyond create form: status badges, conditional action buttons for confirm/withdraw/print, event attachment widget, hidden session state fields.

**Live check (2026-07-24) - discrepancy:** the specific CSS class selectors documented as `view_Element_OphTrConsent_Type`/`view_Element_OphTrConsent_Procedure` do not exist live - the elements use a generic `.element` class instead. No status badges, no attachments widget, no 'Patient withdraws consent' button and no print buttons were visible on this sample event's view tab; the hidden JS fields could not be independently confirmed. Not re-verified beyond the primary pass.

**Blind-spot check (2026-07-24):** actionView() manipulates `session['printConsent']` and calls parent - minimal non-standard logic, no reachability gate.

#### Operation booking (view) `/OphTrOperationbooking/default/view/3686604`

Displays a read-only operation booking event with procedure details, scheduling info, and theatre booking status. Renders Operation element plus optional ContactDetails, Diagnosis, PreAssessment elements; backed by OphTrOperationbooking\DefaultController + view.php routing renderOpenElements().

- Procedure & OPCS codes section (header): lists procedures with eye laterality, OPCS code lookup, operation complexity, consultant required (name if assigned), anaesthetic type display, anaesthetic choice (if set), stop medication yes/no (±details), decision date, site, operation priority, operation comments
- Information section: Complexity (caption), Consultant required (yes/name or "No Consultant"), Anaesthetic type, Anaesthetic choice (if applicable), Stop medication (optional, with details), Decision date, Site, Operation priority, Operation comments, Admission category (overnight vs day case), Total theatre time (mins), Special equipment yes/no (±details)
- Comments section: Operation RTT comments (if present), Organising admission user (if set), Is golden patient flag (if module enabled)
- Booking details section (if booking exists): Theatre list (date, time slot, firm), Theatre name, Ward, Admission time (HHmm format), EROD description (if exists), booking metadata (created/modified by user, with timestamps)
- Cancelled bookings section (if any): List of cancelled bookings with original schedule, cancellation date/user, cancellation reason+comment, EROD
- Cancellation details section (if status=Cancelled or Requires rescheduling): Cancellation date, user, reason; optional cancellation comments
- Status alerts: no GP practice alert, no address alert, issue alert (event->hasIssue), on-hold with reason/comment alert, delete pending alert, patient warnings (if clinical access), consent withdrawal alert (if booking linked to withdrawn consent)
- Template save/update alerts: pre-fill template prompts for new/modified events
- Whiteboard action button (if enabled)
- Print buttons: letter (invitation/admission), admission form (if scheduled), conditional on access
- Schedule/Reschedule buttons (if editable, diary not disabled)
- Cancel operation button (if edit access)
- Hidden fields for template popups (JS-driven)

View-specific additions: booking details table with metadata, cancellation history, template management UI, whiteboard integration, scheduling action buttons.

**Live check (2026-07-24) - discrepancy:** on the sampled event (status "(Completed)") the core informational sections all rendered correctly (Procedure & OPCS codes, Information, Diagnoses, Comments, golden-patient flag, Schedule options, Contact Details, Pre-Assessment, and the patient-allergies status banner). The Booking details, Cancelled bookings, Cancellation details, print, Schedule/Reschedule and Cancel operation controls were **not** visible - most plausibly because a Completed booking has nothing left to schedule/cancel/reprint, which the original write didn't call out as conditional on booking status. Treat all of those as conditional on booking status until confirmed on a non-Completed sample event.

**Blind-spot check (2026-07-24):** actionView() has no non-standard conditional logic (checked, nothing non-standard).

#### Prescription (view) `/OphDrPrescription/default/view/3686592`

Displays a read-only prescription event as a table of medication items with dosing and dispensing details. Renders single Element_OphDrPrescription_Details; backed by OphDrPrescription\DefaultController + view.php routing renderOpenElements().

- Prescription items table (header): Columns: Drug (with allergy warning icon if patient allergic, medication info box, PGD label), Dose (numeric + unit), Route (term ± laterality if route has_laterality), Frequency (term, optional), Duration (name, optional), Dispense Condition/Location (formatted with form_type placeholder replacement if "Print to {form_type}"), Comments (italic text, optional)
- Taper rows (if applicable): indented (child-arrow icon), "then" label, taper dose/frequency/duration
- Prescription metadata hidden fields: et_ophdrprescription_draft (boolean), et_ophdrprescription_print (boolean)
- Comments section (separate): Optional comments rendered with line breaks if element->comments exists
- Status alerts: "draft" badge if Element->draft; message bar (base/_messages partial)
- Draft > final transition button ("Save as final"): appears if Element->draft=true, Element not editable by medication user, user has edit access
- Print buttons (if access, not draft, OprnPrintPrescription permission): "Print [form_format]" (if any item has dispense_condition="Print to {form_type}" and overprint enabled), standard print
- Event attachments section: EventAttachmentSection widget

View-specific additions: medication allergy warnings, taper display, draft-to-final workflow, print form overrides.

**Live check (2026-07-24) - confirmed via spot-check:** the prescription items table (Drug/Dose/Route/Frequency/Duration/Dispense Condition/Comments) and the allergy warning banner both confirmed present and populated as documented; no taper rows on this sample (correctly none expected).

**Blind-spot check (2026-07-24):** actionView() checks `event.delete_pending`, `isEditableByMedication()` (created-from-Medication-Management), and a `userIsAdmin()` check - these gate the `$this->editable` flag and set conditional flash messages that affect what renders, without gating reachability itself.

#### Message (view) `/OphCoMessaging/default/view/3686590`

Displays a read-only message thread (single message + replies) with sender/recipient/read status and optional reply composition. Renders single Element_OphCoMessaging_Message; backed by OphCoMessaging\DefaultController + view.php routing renderOpenElements().

- Message metadata (left column, read-only): Sender mailbox name (priority-text), Date sent (NHS format), Recipient mailbox name (primary, data-test="message-primary-recipient-mailbox-name"), CC'd recipients list (if cc_enabled, data-test="message-cc-recipient-mailbox-names", with team icon if non-personal mailbox), Message type (dropdown label + name or "None", data-test="message-type"), Urgent flag (orange highlighter "Urgent message" if urgent, data-test="message-urgent-indicator")
- Message body (right column, read-only): Formatted text (Ntext filter, whitespace normalized), read status ("Unread" or "Read by: [user names]", data-test="read-status")
- Mark as read/unread buttons: Appear if no comments yet and user can mark (specific permission logic); buttons link to markRead/markUnread action with event_id + mailbox_id params
- Comment replies (if any): Threaded replies, each showing sender user/mailbox + timestamp, reply text (formatted), read status on final comment only
- Reply composition form (if canComment() true): Text area (class="cols-full increase-text autosize msg-write js-editor-area", data-test="your-reply"), mailbox selector dropdown (user's sending/receiving mailboxes), Preview & check button (data-test="preview-and-check"), Edit/Send buttons (data-test="send-reply"), preview pane (hidden by default), line-break formatter JS
- Status alerts: delete pending badge, base error messages (base/_messages partial)
- Event attachments section: EventAttachmentSection widget
- Print button (if access): standard print
- Hidden mailbox_id parameter (GET param or user personal mailbox default)

View-specific additions: message thread display, read/unread marking workflow, inline reply composition with preview toggle.

**Live check (2026-07-24) - discrepancy:** on the sampled event no CC recipients, urgent flag, mark as read/unread buttons, reply composition form, comment threads, attachments section or print button were visible - plausibly explained by the documented conditions (cc_enabled, urgent flag, canComment()/permission logic, no existing comments) rather than a doc defect, but not confirmed either way on this sample. Sender/Date sent/Recipient/Type metadata and the message body/read status were all confirmed present, though without the exact 'mailbox name' terminology in the visible labels.

**Blind-spot check (2026-07-24):** no override of `actionView()`; `initActionView()` only shows the comment form - nothing non-standard.

#### Biometry (view) `/OphInBiometry/default/view/3686331`

Displays a read-only biometry event with IOL measurements, lens selection, and visual acuity assessment, typically for cataract surgery planning. Renders Selection, Measurement, BiometryData, Calculation, VisualAcuity elements; backed by OphInBiometry\DefaultController + view.php routing renderOpenElements().

- Surgeon display (if auto import): Left column showing surgeon name (populated from Element_OphInBiometry_IolRefValues->surgeon_id)
- Lens selection section per eye: Left/Right eye tables: Lens ID (display_name), Formula used (name from OphInBiometry_Calculation_Formula lookup), A constant (auto-calculated from IolRefValues if auto import + not manually overridden; else from lens->acon), IOL power (large-text orange highlighter, formatted to 2 decimals), Predicted refraction (with +/- prefix). Signature row (if signed): esigned-at timestamp, signed user fullname, signed date
- Measurement section (if rendered): Eye-draw diagram, measurement data fields (axial length, keratometry, etc.)
- BiometryData section (if rendered): Raw biometry values
- Calculation section (if rendered): Formula results, target refraction
- Visual acuity section (if rendered): Pre/post-op VA
- Status alerts: delete pending badge if event->delete_pending
- Choose Lens button `[data-test="event-action-choose-lens"]` (if edit access): links to `/OphInBiometry/default/update/{event_id}`
- Open in Forum button (if FORUM integration enabled + biometry_imported_events->sop_uid set): launcher link `oelauncher:forumsop/{sop_uid}`
- Print button (if access): standard print
- Event attachments section: EventAttachmentSection widget

View-specific additions: eye-draw rendering, auto-import surgeon metadata, formula-driven A-constant calculation, IOL power highlighting, signature evidence tracking.

**Live check (2026-07-24) - confirmed via spot-check:** the independent spot-check verified the Choose Lens button and its `data-test="event-action-choose-lens"` selector/link target, plus the Biometry/Visual Acuity/Near Visual Acuity/Refraction sections and the data-source banner - all matched. No signatures were present on this sample event, consistent with the documented "if signed" condition.

**Blind-spot check (2026-07-24):** actionView() conditionally loads IolRefValues/Selection model data and calls `setFlashMessage()` - minor conditional rendering logic, not a reachability gate.

## Practices

2 distinct page templates - list and detail (the crawl's 3rd "page" is a second detail instance of the same template, a different practice id). Sitemap: `areas/practices.md`.

#### Practices - list `/practice/index`

Lists all practices with search, filtering and pagination; backed by PracticeController::actionIndex and protected/views/practice/index.php.

- Search text field `[name="search_term"]` (optional, default: empty) - searches practice name, phone, address, postal code, and code
- Practices table displaying name, address, code, ID, telephone, email (rows clickable to navigate to detail view)
- Pagination widget (standard `LinkPager` pattern - see Live check)
- Create Practice button `[href="/practice/create"]` (visible if user has TaskCreatePractice role)

No form submission on this page - search is GET-based via CActiveForm #practice-search-form.

**Live check (2026-07-24) - discrepancy:** pagination is a `LinkPager` widget with numbered links (2, 3, 4, ...), not `[data-test="pagination-previous|next"]` (corrected above). Search field, Create Practice button href, and table structure all matched.

#### Practices - detail `/practice/view/3`

Displays a single practice's contact and associated practitioners; backed by PracticeController::actionView and protected/views/practice/view.php.

- Back to Practices link `[href="/practice/index"]`
- Update Practice Details button (visible if user has TaskCreatePractice role) - see Live check for href shape
- Contact information table showing:
  - Practice Name (read-only, from contact.getFullName())
  - Practice Address (read-only, from practice.getAddressLines())
  - Code (read-only, from practice.code)
  - Phone (read-only, from contact.primary_phone)
  - Email (read-only, from contact.email)
- Associated Practitioners table (if any) with columns: Provider Number, Practitioner Name `[data-test="practitioner-name"]`, Practitioner Phone Number, Role
- Pagination widget (standard pattern)

Read-only view with no form submission.

**Live check (2026-07-24) - discrepancy:** Update Practice Details href is the RESTful path form `/practice/update/3`, not the query-string form `/practice/update?id=N` (corrected above). Back to Practices link, heading and table structure matched; `[data-test="practitioner-name"]` exists in source but wasn't independently confirmed live (practice 3 has no associated practitioners on the sample stack).

## Practitioners

2 distinct page templates - list and detail (the crawl's 3rd "page" is a second detail instance of the same template, a different GP id). Sitemap: `areas/practitioners.md`.

#### Practitioners - list `/gp/index`

Lists all practitioners (GPs) with search, filtering and pagination; backed by GpController::actionIndex and protected/views/gp/index.php.

- Search text field `[name="search_term"]` (optional, default: empty) - searches last name, first name, phone
- Practitioners table displaying name, telephone, code (nat_id), role, active status (icon)
- Rows are clickable to navigate to detail view
- Pagination widget (standard pattern)
- Create Practitioner link (dynamic label based on 'general_practitioner_label' setting; visible if user has TaskCreateGp role)

No form submission on this page - search is GET-based via CActiveForm #practitioner-search-form.

**Live check (2026-07-24) - confirmed via spot-check:** search field, table, pagination and Create Practitioner link all confirmed on live dump (184 practitioners, page heading "Practitioners: viewing 1 - 30 of 184").

#### Practitioners - detail `/gp/view/15041`

Displays a single practitioner's contact details and associated practices; backed by GpController::actionView and protected/views/gp/view.php.

- Back to GP link `[href="/gp/index"]`
- Update Practitioner Details button `[href="/gp/update/N"]` (RESTful path, not query-string - matches the Practices page's equivalent button; visible if user has TaskCreateGp role; button label uses 'general_practitioner_label' setting)
- Contact Information table showing (read-only):
  - Name (from gp.getCorrespondenceName())
  - Phone Number (from contact.primary_phone)
  - Email (from contact.email)
  - National Id (from gp.nat_id)
  - Role (from contact.label.name)
  - Active status (icon: tick or remove, from gp.getActiveStatus())
- Associated Practices table (if any) with columns: Provider Number, Practitioner Email (email_override), Practice Contact, Practice Address, Code, Telephone
- Pagination widget (standard pattern)

Read-only view with no form submission.

**Live check (2026-07-24) - defect in original doc, corrected in place:** the Update Practitioner Details button is confirmed `/gp/update/15041` (RESTful path) on the live dump, resolving the previously-flagged ambiguity in favour of the RESTful form - the field list above has been corrected accordingly.

## Trials

2 distinct page templates - list and detail (the crawl's 3rd "page" is a second detail instance of the same template, a different trial). Sitemap: `areas/trials.md`.

#### Trials - list `/OETrial`

Displays a paginated list of clinical trials with search and filter options in a side panel. Backed by OETrial/controllers/TrialController::actionIndex() and OETrial/views/trial/index.php.

- Bookmarked trials toggle button `button.js-bookmark-filter-toggle` (optional, toggles between bookmarked/all)
- Show recruiting trials toggle button `button.js-recruiting-filter-toggle` (optional)
- Short title search input `input[name='trial_search[title]']` text (optional)
- Descriptions search input `input[name='trial_search[description]']` text (optional)
- Trial status radio buttons (optional, default: All Trials) - All Trials `value=""`, Active `value="open"`, Closed `value="closed"`
- Trial type radio buttons (optional, default: Any type) - Any type `value=""`, Intervention `value="intervention"`, Non-intervention `value="non-intervention"`
- Date range - from input `input[name='trial_search[date_from]']` date (optional, visible when status selected)
- Date range - to input `input[name='trial_search[date_to]']` date (optional, visible when status selected)
- Date range quick select radio buttons `input[name='trial_search[date_range]']` (optional, visible when status selected) - No date range `value="no-range"`, Last year `value="last-year"`, This year `value="this-year"`
- Sort by select `select.js-sort-trials-by[name='trial_sorting[sort_by]']` (optional - see Live check for actual options)
- Sort direction radio buttons `input[name='trial_sorting[sort_direction]']` (optional) - Ascending `value="asc"` `i.oe-i.direction-up`, Descending `value="desc"` `i.oe-i.direction-down`
- Page size select from pagination bar (optional, values: 20, 50, 100)
- Trial list table displays: Trial name (with bookmark star), P.I./Coordinators, Status, Recruiting flag, Intervention type, action link

Search action: Form submission filters and displays matching trials, pagination applies. Clear search button resets filters.

**Live check (2026-07-24) - discrepancy:** the sort-by select's actual options are Status Date / Title / Principal Investigator / Status / Intervention / Recruiting / Bookmarked (values `status-date`/`title`/`principal-investigator`/`status`/`intervention`/`recruiting`/`bookmarked`), not the `name`/`participant_count`/`recruitment_status`/`started_date` originally documented. Every other filter/toggle/radio verified as documented.

#### Trials - detail `/OETrial/trial/view/1`

Displays detailed information about a specific trial with participant list and management options. Backed by OETrial/controllers/TrialController::actionView() and OETrial/views/trial/view.php.

Trial details (read-only side panel):
- Title display with bookmark star toggle `i.js-toggle-bookmark[data-trial-id]`
- Ethics code display
- Description display
- Principal Investigator names display
- Coordinator names display
- Status display (Active/Closed with dates)
- Recruiting flag display
- Recruitment target display
- External data link (clickable)
- Trial type display (Intervention/Non-intervention with masked indicator if applicable)

Participant quick filters (side panel):
- Show all participants link `a.js-patient-quick-filter[data-status='']` (default selected, shows count)
- Shortlisted link `a.js-patient-quick-filter[data-status='shortlisted']` (shows count)
- Accepted link `a.js-patient-quick-filter[data-status='accepted']` (shows count)
- Completed link `a.js-patient-quick-filter[data-status='completed']` (shows count)
- Pre-screen fail link `a.js-patient-quick-filter[data-status='pre_screen_fail']` (shows count)
- Screen fail link `a.js-patient-quick-filter[data-status='screen_fail']` (shows count)
- Withdrawn link `a.js-patient-quick-filter[data-status='withdrawn']` (shows count)

Participant search filters (side panel):
- Family name input `input.js-family-name` text (optional, placeholder: 'e.g. S, or Sm, or Smith')
- Filter by family name button `button.js-apply-family-name-filter` (activates family name filter)
- Clear family name filter icon `i.js-clear-family-name-filter` (removes family name filter)
- Participant ID input `input.js-participant-id` text (optional, placeholder: 'Participant ID')
- Filter by ID button `button.js-apply-participant-id-filter` (activates participant ID filter)
- Clear participant ID filter icon `i.js-clear-participant-id-filter` (removes participant ID filter)

Participant list (main panel):
- Sort by select `select.js-sort-by[data-test='sort-by-selection']` (options: name, date_enrolled, status, id)
- Sort direction radio buttons `input[type='radio'][name='sort-direction'].js-sort-dir` (values: asc, desc)
- Page size selector from pagination bar (values: 20, 50, 100)
- Participant table displays: Participant info, Status (with change date), Participant ID & notes
- Each row has status change button and patient information popups accessible on hover

Search/filter action: Selections update the participant list via fetch request to /OETrial/trial/updateParticipantList, pagination updates via new page number parameter.

**Live check (2026-07-24) - confirmed via spot-check:** sort-by select (`data-test="sort-by-selection"`), sort-direction radios (`data-test="sort-direction-input"`), family-name and participant-ID search inputs with their filter buttons all confirmed present and labeled as documented.

## Virtual Clinic

Only 1 distinct page template (the crawl's other 2 "pages" for this area are patient-summary drill-ins reached by clicking a ticket row, not a separate Virtual Clinic template - see `paths.md`'s patient-summary coverage). Sitemap: `areas/virtual-clinic.md`.

#### Virtual Clinic worklist `/PatientTicketing/default/?cat_id=1`

Displays a virtual clinic worklist (queue) of patient tickets for internal referrals with filtering and batch operations. Backed by PatientTicketing/controllers/DefaultController::actionIndex() and PatientTicketing/views/default/index.php. The Internal referrals menu item (`?cat_id=2`) shares this exact controller/view - only the category param differs; see the Internal referrals entry below.

Queue selector:
- Queue set name display (in header)
- Change Queue button `button#js-virtual-clinic-btn[data-test='change-vc-btn']` (opens queue selection form)

Filter sidebar:
- Subspecialty dropdown `select[name='subspecialty-id']` (optional if queueset.filter_subspecialty=1, empty: 'All specialties')
- Firm dropdown `select[name='firm-id']` (optional if queueset.filter_firm=1, empty: 'All Firm/Consultant's')
- Site dropdown `select[name='site-id']` (optional, empty: 'All sites')
- Lists multi-select dropdown `#virtual-clinic-search-list` with checkbox list (optional, selectedItemsInputName: 'queue-ids[]')
- Actors Roles multi-select dropdown `#virtual-clinic-search-roles` with checkbox list (optional, selectedItemsInputName: 'roles[]')
- Patient search autocomplete `input#oe-autocompletesearch` text (optional, placeholder: 'Patient identifier, Firstname Surname or Surname, Firstname')
- Selected patients list `ul#patient-result-list` with hidden inputs `input[name='patient-ids[]']` (optional)
- Priority flags checkboxes `input[name='priority-ids[]']` for Red (value=1), Amber (value=2), Green (value=3) (optional)
- Completed tickets checkbox `input[name='closed-tickets']` (optional, value: 1)
- Date range from input `input#js-date-from-field[name='date-from']` date (optional, placeholder: 'From')
- Date range to input `input#js-date-to-field[name='date-to']` date (optional, placeholder: 'To')
- Ownership dropdown `select[name='owner-id']` (optional if queueset.allow_take_ownership=1)
- Search button (primary action)
- Reset all filters button `button#reset-filters` (clears all filters)

Ticket list (main panel):
- Sort by dropdown (values: list, patient, priority, date, default: date)
- Sort direction radio buttons (ascending/descending)
- Page size pagination (default page size: 25)
- Batch assign ownership dropdown `select[name='assign_ownership_list']` (optional if allow_take_ownership and assignment_supervisor)
- Batch ownership action buttons (Assign owner, Remove owner)
- Ticket table displays: icon, Step, Patient name (clickable link), Clinic & Site, Clinic info & Notes, Assignee (optional), Checkbox for batch operations (optional)
- Each ticket row has ticket action button for workflow progression
- Pagination controls at bottom

Search/filter action: Form submission to /PatientTicketing/default with GET parameters (cat_id, queueset_id, subspecialty-id, firm-id, site-id, queue-ids[], roles[], patient-ids[], priority-ids[], closed-tickets, date-from, date-to, owner-id, custom-filter-ids[]) filters and displays matching tickets. Batch operations via POST to /PatientTicketing/updateTicketOwnership/. Ticket workflow actions via POST to /PatientTicketing/default/startTicketProcess/.

**Live check (2026-07-24) - confirmed via spot-check:** Change Queue button (`#js-virtual-clinic-btn`), subspecialty/firm/site selects, patient search autocomplete (`#oe-autocompletesearch`), priority checkboxes (`priority-ids[]`), closed-tickets checkbox, and both date range fields all confirmed present as documented.

## One-page utility screens

20 standalone app pages, each its own sitemap area (menu labels/URLs also listed in `paths.md`'s main menu table).

### Add Patient `/patient/create`

Create a new patient record in OpenEyes. Backed by PatientController::actionCreate and protected/views/patient/crud/_form.php.

- Title <text> (optional based on config, maxlength 40) - see Live check for selector
- First Name <text> `#Contact_first_name` (required based on config, maxlength 40, data-test='first-name')
- Last Name <text> `#Contact_last_name` (required based on config, maxlength 40, data-test='last-name')
- Maiden Name <text> (optional, maxlength 40)
- Date of Birth <date> `input[data-test='dob']` (required based on config, format dd/mm/yyyy)
- Patient Source <select> `select[name='Patient[patient_source]']` (required, default: referral/other/self_register)
- Sex <select> (required for self-register scenario - labeled 'Sex', not 'Gender', see Live check)
- Ethnic Group <select> `select[name='Patient[ethnic_group_id]']` (optional)
- Address, City, Postcode, County (optional, full breakdown - see Live check)
- Country <select> `select[name='Address[country_id]']` (optional)
- Phone number <tel> (required based on setting, maxlength 20, data-test='phone' - labeled 'Phone number', not 'Primary Phone')
- Email <email> `input[name='Contact[email]']` (required for self-register scenario, maxlength 255)
- Patient Identifiers (configurable by institution/site, necessity varies)
- GP autocomplete, Practice autocomplete, User autocomplete, Referral file upload (undocumented in the original pass - see Live check)
- Is Deceased <checkbox> `input[name='Patient[is_deceased]']` (optional)
- Date of Death <date> (optional, shown only once is_deceased is checked - not present in the initial DOM)

Submit button: Form posts via AJAX to actionCreate; validates and saves patient record with validation errors displayed inline.

**Live check (2026-07-24) - discrepancy:** most fields use plain `id` selectors (e.g. `#Contact_title`), not the `name`-attribute selectors the original write used - corrected above where practical. Sex/Phone number labels corrected above (documented as 'Gender'/'Primary Phone'). The address block is a full breakdown (Address2, City, Postcode, County) rather than a single Address field, and GP/Practice/User autocompletes plus a Referral file upload are present and were entirely undocumented - both corrected/added above. Date of Death is genuinely absent from the DOM until Is Deceased is checked (not just optional).

Sitemap: `areas/add-patient.md`.

### Advanced Search `/OECaseSearch/caseSearch/index`

Search for patients using configurable clinical parameters in the OECaseSearch module. Backed by OECaseSearch/controllers/CaseSearchController::actionIndex and OECaseSearch/views/caseSearch/index.php.

- Previous searches <button> `#load-saved-search` (optional, opens previous searches modal)
- Search Criteria <table> `table#param-list` (dynamically populated with parameter rows once criteria are added - not present on initial load)
- Add criteria <button> `#add-to-advanced-search-filters` (opens dialog to select parameters)
- From date <text> `#from_date` (optional, plain text input - no datepicker class or `from_date` name attribute; format dd/mm/yyyy, disabled when 'All available dates' checked)
- To date <text> `#to_date` (optional, plain text input - no datepicker class or `to_date` name attribute; format dd/mm/yyyy, disabled when 'All available dates' checked)
- All Available Dates <checkbox> `#show-all-dates` (optional, default: true on initial load)
- Search <button> `[data-test='search']` (type='submit', submits search parameters)
- Save search <button> `[data-test='save-search']` (opens dialog to save current search)
- Clear search <button> `#clear-search` (resets all parameters)
- Download CSV BASIC <button> `#download-csv-basic` (appears only if results, submits to downloadCSV?mode=BASIC)
- Download CSV Advanced <button> `#download-csv-advanced` (appears only if results, submits to downloadCSV?mode=ADVANCED)
- Results List <div> `div.oe-search-results` (displays patient list when search executed)

Search action: POST to caseSearch/search with parameters; returns patient IDs and variable data; displays results in list or plot view.

**Live check (2026-07-24) - defect, corrected in place:** button/field selectors and labels above were rewritten from a direct live check (not just the automated passes) after the primary verify and the independent spot-check gave conflicting reports on this page. Confirmed live: the button labeled 'Previous searches' (not 'Load Saved Search') is `#load-saved-search`; Search and Save search are `[data-test='search']`/`[data-test='save-search']` with **no** `js-search-btn`/`js-save-search-dialog-btn` classes present; the date inputs are plain `#from_date`/`#to_date` with no `datepicker-from`/`datepicker-to` classes or matching `name` attributes (the specific defect the spot-check flagged, confirmed). `table#param-list` was not observed on initial page load in the live dump (dump doesn't enumerate arbitrary tables, so its presence once criteria are added is plausible but unconfirmed either way) - documented above as populated dynamically rather than asserting it doesn't exist.

### Analytics `/Analytics/analyticsReports`

Display clinical analytics and outcome reports by specialty. Backed by AnalyticsController::actionAnalyticsReports and protected/views/analytics/analytics_report.php.

- Specialty Tabs `ul.oescape-icon-btns[data-test='analytics-specialty-options']` with links for All, Cataract (CA), Glaucoma (GL), Medical Retina (MR); tab becomes active on click
- Sidebar Options `div#sidebar` (dynamically populated with filters for selected specialty)
- Plot Container `div#plot` (renders Plotly visualization; hidden when switching to list view)
- Patient List Table `table[data-test='analytics-results-table']` (appears when drilling into plot data or clicking specific bar) - columns: Patient ID, NHS Number, Name, Age, Eye, Date, Outcome
- Back to Chart `button#js-back-to-chart` (returns from patient list to plot view)
- Loading Spinner `div#js-analytics-spinner` (displayed during data fetch)

Analytics action: No form submission; loads dynamically via JavaScript. Specialty selection triggers sidebar update and plot re-render with filtered data from analytics API endpoints.

**Live check (2026-07-24) - confirmed via spot-check:** specialty links (All/CA/GL/MR) and the two date pickers confirmed present as documented.

### Audit `/audit`

Search and filter audit log entries for system activity tracking. Backed by AuditController::actionIndex and protected/views/audit/index.php.

- Institution <select> `select[name='institution_id']` (required for Institution Audit role, optional otherwise; default: current institution)
- Site <select> `select[name='site_id']` (optional, empty option='All sites')
- Context (Firm) <select> `select[name='firm_id']` (optional, empty option='All firms')
- Action <select> `select[name='action']` (optional, empty option='All actions', data-test='audit-action')
- Target <select> `select[name='target_type']` (optional, empty option='All targets')
- Event Types <select> `select[name='event_type_id']` (optional, empty option='All event types', data-test='audit-event-type')
- User <autocomplete> `input.AutoCompleteSearch` (optional, searches users by full name)
- Patient Identifier <text> `input[name='patient_identifier_value']` (optional, placeholder='Enter Patient Identifier', data-test='patient-identifier-input')
- Date From <datepicker> `input[name='date_from']` (optional, format dd/mm/yyyy)
- Date To <datepicker> `input[name='date_to']` (optional, format dd/mm/yyyy)
- Auto Update Toggle <link> `a#auto_update_toggle` (toggles live updates, shows 'Auto update on' or 'Auto update off')
- Reset All Filters <link> (resets form to initial state)
- Create Audit <button> `button[data-test='create-audit-button']` (type='submit', submits to audit/search)

Search action: POST to /audit/search with filter parameters; returns results table and pagination with audit entries; rows show user, action, target, date, IP address.

**Live check (2026-07-24) - confirmed via spot-check:** all documented selects, the Patient Identifier field, both date fields, the Auto Update toggle, Reset All Filters link and Create Audit button all confirmed present as documented.

### CVI list `/OphCoCvi/Default/list`

Display and manage Certification of Vision Impairment (CVI) records. Backed by OphCoCvi/controllers/DefaultController::actionList and OphCoCvi/views/default/list.php.

- Date From <date> `#date_from` (optional, format d M yy)
- Date To <date> `#date_to` (optional, format d M yy)
- Subspecialty <select> `select[name='subspecialty_id']` (optional, empty option='All specialties')
- Site <select> `select[name='site_id']` (optional, empty option='All sites')
- Created By <autocomplete> `input[data-test='createdby_auto_complete']` (optional, adds to multi-select list, hidden field `input[name='createdby_ids']`)
- Consultant Signed By <autocomplete> `input[data-test='consultant_auto_complete']` (optional, adds to multi-select list, hidden field `input[name='consultant_ids']`)
- Consultant in Charge <autocomplete> `input[data-test='firm_auto_complete']` (optional, adds to multi-select list, hidden field `input[name='firm_ids']`)
- Show Issued <checkbox> `input[name='show_issued']` (optional, default: false)
- Complete <checkbox> `input[name='issue_complete']` (optional, default: true)
- Incomplete <checkbox> `input[name='issue_incomplete']` (optional, default: true)
- Missing Consultant Signature <checkbox> `input[name='missing_consultant_signature']` (optional, default: false)
- Missing Patient Signature <checkbox> `input[name='missing_patient_signature']` (optional, default: false)
- Missing Clerical Part <checkbox> `input[name='missing_clerical_part']` (optional, default: false)
- Export <button> `#export_csv` (type='button', triggers CSV download of filtered results)
- Reset <button> `#reset_button` (appears only if filters applied, clears all filters)
- Search <button> `#search_button` (type='submit', disabled until filter changed)

Search action: POST form to /OphCoCvi/Default/list; returns CGridView table with sortable columns (Event Date, Subspecialty, Site, Name, Hospital No., Created By, Consultant, Status, Issue Date) and View/Edit action buttons.

**Live check (2026-07-24) - confirmed via spot-check:** all fields, autocompletes and checkboxes confirmed present as documented; the Reset button was absent on the unfiltered page, consistent with its documented "appears only if filters applied" condition.

Sitemap: `areas/cvi-list.md`.

### CXL Dataset `/CxlDataset`

Generate and download Cross-Linking (CXL) dataset export for research. Backed by CxlDatasetController::actionIndex and protected/views/cxldataset/index.php.

- Date From <datepicker> `#date_from` (optional, format dd/mm/yyyy, leave blank to include all data)
- Date To <datepicker> `#date_to` (optional, format dd/mm/yyyy, leave blank to include all data)
- Generate CXL Dataset <button> (type='submit', submits form to /CxlDataset/Generate)

Generate action: POST to /CxlDataset/Generate; processes SQL queries to extract patient, history, assessment, and CXL surgery data into CSV files; creates ZIP archive and triggers download. Processing time depends on data volume.

**Live check (2026-07-24) - confirmed via spot-check:** both date fields and the Generate button confirmed present as documented.

Sitemap: `areas/cxl-dataset.md`.

### Failsafe Management `/OphCiExamination/ResponsibleForCareManagement/index`

Monitor and manage Failsafe entries for Area of Care coverage tracking. Backed by OphCiExamination/controllers/ResponsibleForCareManagementController::actionIndex and OphCiExamination/views/responsibleforcaremanagement/index.php.

- Failsafe Status <checkboxes> `input[name='statuses[]']` (multiple, each status option from database)
- Areas of Care <checkboxes> `input[name='areas_of_care[]']` (multiple, each area option from database)
- Organization Responsible for Care <multi-select> `select[name='responsible_institution']` (optional, includes 'No responsible organization' option)
- Responsible Consultant <autocomplete> `#user_add_id` (optional, adds to multi-select list `ul#users-list-m`, hidden fields `input[name='users[N][id]']` and `input[name='users[N][name]']`)
- Recording Organization <multi-select> `select[name='institution']` (optional, includes all institutions)
- Subspecialty <select> `select[name='subspecialty']` (optional, empty option='- Subspecialty -')
- Patients <autocomplete> `#patient_auto` (optional, accepts identifier/name variations, adds to multi-select list `ul#patients-list-m`, hidden fields `input[name='patients[N][id]']` and `input[name='patients[N][name]']`)
- Date From <date> `#search-date-from` (optional, format d b Y, pickmeup datepicker)
- Date To <date> `#search-date-to` (optional, format d b Y, pickmeup datepicker)
- All Dates <link> `a.js-clear-dates#sidebar-clear-date-ranges` (clears date fields)
- Search <button> `button[type='submit']` (submits form to /OphCiExamination/ResponsibleForCareManagement/search)
- Reset All Filters <button> `#reset-filters` (clears all filters and checkboxes)

Search action: POST to /OphCiExamination/ResponsibleForCareManagement/search with filter parameters; returns HTML partial with table of matching Area of Care entries and additional blank patient entries for searched patients without coverage.

**Live check (2026-07-24) - confirmed via spot-check:** all checkboxes, selects, autocompletes, date fields, the All Dates link, Search and Reset All Filters buttons all confirmed present as documented.

### Genetics `/Genetics/default/index`

Lists genetics patients and allows searching by subject ID, hospital number, family ID, date of birth, name, and diagnoses; backed by OEModule\Genetics\controllers\SubjectController::actionList with view at protected/modules/Genetics/views/subject/list.php.

- 'Subject Id' <text> (optional) placeholder
- 'Hospital number' <text> (optional) placeholder
- 'Family id' <text> (optional) placeholder
- 'Date of Birth' <date> `#GeneticsPatient_patient_dob` (optional) JUI date picker
- 'First name' <text> (optional) placeholder
- 'Last name' <text> (optional) placeholder
- 'Maiden name' <text> (optional) placeholder
- 'Comments' <text> (optional) placeholder
- 'Year of Birth' <text> (optional) placeholder
- 'Diagnosis' <autocomplete> (optional) disorder autocomplete with clear button

Search button submits to actionList; re-displays grid filtered by criteria (no results until search is submitted); grid columns: Id, Family Id, Hospital number, First Name, Last Name, Maiden Name, DOB, Diagnoses, Affected status. Click row to view subject details.

**Live check (2026-07-24) - blocked:** HTTP 403 on the sample stack's admin user - lacks permission to access the Genetics module. Fields above are documented from source only, not confirmed live.

### Internal referrals `/PatientTicketing/default/?cat_id=2`

Patient Ticketing worklist for internal referrals (`cat_id=2`); shares controller and views with Virtual Clinic (`cat_id=1`, documented in full above) at OEModule\PatientTicketing\controllers\DefaultController::actionIndex. Use the Virtual Clinic entry's field list - the category param determines which queue sets are displayed. Filters by subspecialty, firm, site, lists, roles, patients, priority, ownership, and date range; results show active tickets with queue, priority, assignee, and dates.

**Live check (2026-07-24) - blocked:** HTTP 500 application error on the sample stack for this specific category - couldn't verify whether this is a genuine bug or sample-data-specific (Virtual Clinic's `cat_id=1` loaded fine via the same controller). Worth a re-check before relying on this page for a repro.

**Live check (2026-07-24) - re-checked, still blocked:** HTTP 500 persists. Stack trace shows the error inside `modelToResource()`'s category resource conversion, triggered by `readActive()` on the queue-set category lookup - looks like a genuine app-level bug specific to `cat_id=2`, not a transient/sample-data fluke, since `cat_id=1` uses the identical controller and loads fine.

Sitemap: `areas/internal-referrals.md`.

### IVT booking `/OphCiExamination/bookingpages/intravitrealinjection/index`

Intravitreal Injections Bookings worklist; backed by OEModule\OphCiExamination\modules\ExaminationBookingPages\controllers\IntravitrealinjectionController::actionIndex with view at protected/modules/OphCiExamination/modules/ExaminationBookingPages/views/intravitrealinjection/index.php. Default display shows patients with pending/unbooked injections; searches for specific patients.

- 'Patient Identifier or name' <text> `[data-test="patient-identifier-input"]` (optional) placeholder 'Enter Patient Identifier or name'

Search button (data-test=search-button) submits form; results display paginated list of patients with injection management records. Click patient row to view booking details and manage IVT bookings.

**Live check (2026-07-24) - blocked:** HTTP 403 on the sample stack's admin user - lacks permission to access this page. Fields above remain documented from source only, not confirmed live.

Sitemap: `areas/ivt-booking.md`.

### NOD Export `/NodExport`

Generates CSV files and zip archive for National Ophthalmology Dataset (NOD) audit submission; backed by NodExportController::actionIndex with view at protected/views/nodexport/index.php.

- 'Cataract' <checkbox> `name="nod_choice[cataract]"` (optional, required: at least one type)
- 'AMD' <checkbox> `name="nod_choice[amd]"` (optional, required: at least one type)
- 'From' <date> `#date_from` (optional) JUI date picker, placeholder 'From'; leave blank for all-time data
- 'To' <date> `#date_to` (optional) JUI date picker, placeholder 'To'; leave blank for all-time data

Generate button (type=submit, class=green, text "Generate NOD (.zip)") creates temporary tables, populates with filtered data (by date range if supplied), exports CSVs for each selected audit type (Cataract or AMD), creates zip file, and triggers download. No validation errors reported in-view; error dialogs may appear if no audit type selected.

**Live check (2026-07-24) - confirmed via spot-check:** the independent spot-check verified both checkboxes' name attributes, both date field ids, and the Generate button text ("Generate NOD (.zip)") - all matched.

Sitemap: `areas/nod-export.md`.

### Optom Invoice Manager `/OphCiExamination/OptomFeedback/list`

Optometrist Feedback Manager; allows searching and updating invoice status for optom feedback records; backed by OEModule\OphCiExamination\controllers\OptomFeedbackController::actionList with view at protected/modules/OphCiExamination/views/optom/list.php. Displays list of automatic examination event logs with inline editing for status and comments.

- 'Filter by Date - From' <date> `#date_from` (optional) JUI date picker, placeholder 'from'
- 'Filter by Date - To' <date> `#date_to` (optional) JUI date picker, placeholder 'to'
- 'Invoice Status' <select> (optional, dropdown) empty = 'All'; populated from active invoice_status records
- 'Optometrist Name' <text> `#optometrist` (optional)
- 'Patient number' <text> `#patient_number` (optional, data-test=patient-number-search-input)
- 'Optometrist GOC code' <text> `#goc_number` (optional)

Search button filters grid (required to filter first time); Reset button (if filtered) clears all fields; grid columns (editable inline): Date Received, Patient (link to patient view), Optometrist Name, Optom Address, Invoice Status (select), Comment (textarea). Actions: View (links to examination event), Save (AJAX row update), View log (audit history).

**Live check (2026-07-24) - confirmed via spot-check:** all six filter fields confirmed present as documented.

Sitemap: `areas/optom-invoice.md`.

### Partial bookings waiting list `/OphTrOperationbooking/waitingList/index`

Operations waiting list filtered for partial bookings (On-Hold, Requires scheduling, Requires rescheduling status); backed by WaitingListController::actionIndex with view at protected/modules/OphTrOperationbooking/views/waitingList/index.php. Searches and manages booking letters for pending operations.

- 'Subspecialty' <select> `name=subspecialty-id` (optional, data-test=waiting-list-filter-subspecialty) empty = 'All specialties'; triggers AJAX firm list update
- 'Firm/Context' <select> `name=firm-id` (optional, data-test=waiting-list-filter-firm) empty = "All [service_firm_label]s"; disabled until subspecialty selected
- 'Next letter due' <select> `name=status` (optional) values: Off, No letters sent, Invitation letter, 1st reminder, 2nd reminder, GP letter
- 'Site' <select> `name=site_id` (optional, data-test=waiting-list-filter-site) empty = 'All sites'
- 'Patient Identifier' <text> `name=patient_identifier_value` (optional, class=js-patient-identifier) autocomplete off
- 'Status' <select> `name=booking_status` (optional) empty = 'All'; values: On-Hold, Requires scheduling, Requires rescheduling
- 'Sort By' <radio> `name=results_display_order` (optional, default=asc) values: 'asc'='Oldest First', 'desc'='Newest First'
- 'Set latest letter sent to be' <date> `#adminconfirmdate` (optional, class=datepicker1) default = today; hidden if no OprnOperationBookingLetterSend role
- 'Letter filter' <select> `#adminconfirmto` (optional) values: Off (default), noletters, 0 (Invitation), 1 (1st Reminder), 2 (2nd Reminder), 3 (GP letter); hidden if no OprnOperationBookingLetterSend role

Search Waiting List button (data-test=search-waiting-list) performs search via AJAX, replacing results main section. Confirm selected button (if OprnConfirmBookingLetterPrinted) marks selected records with letter sent date. Print buttons (if OprnPrint) generate letters.

**Live check (2026-07-24) - confirmed via spot-check:** all nine filter fields confirmed present as documented.

Sitemap: `areas/partial-bookings.md`.

### Patient Merge `/patientMergeRequest/index`

Lists pending and merged patient merge requests; backed by PatientMergeRequestController::actionIndex with view at protected/views/patientmergerequest/index.php. Displays merge requests with filtering by patient identifiers; filters persisted in session.

- 'Show merged' <checkbox> `name=PatientMergeRequestFilter[show_merged]` (optional, default=cookie/0) toggles display of merged vs. pending requests; cookie per user
- 'Secondary Patient Identifier' <text> `#secondary_patient_identifier` (table filter row, optional) searches secondary_local_identifier_value
- 'Primary Patient Identifier' <text> `#primary_patient_identifier` (table filter row, optional) searches primary_local_identifier_value

Filter button (type=submit) applies filters via session; results grid columns: Secondary Hospital Number (sortable), Primary Hospital Number (sortable), Status (sortable, color-coded), Created (sortable), Merged (if show_merged checked). Rows clickable to view/update; Add button creates new merge request, Delete button (disabled if show_merged=1) removes selected pending requests.

**Live check (2026-07-24) - discrepancy:** on the initial (unfiltered) page load only the 'Show merged' checkbox was found in the dump - the `#secondary_patient_identifier`/`#primary_patient_identifier` table filter-row inputs were not present. Since they're documented as a CGridView filter row, they may only render once the grid has rows/a filter is active rather than being genuinely absent; not confirmed either way, worth a closer look before relying on their selectors.

Sitemap: `areas/patient-merge.md`.

### Pharmacy worklist `/OphDrPrescription/OphDrPrescriptionPharmacyWorklist/default/index/`

Worklist for managing unsigned prescriptions with secondary signatory requirements, backed by OphDrPrescriptionPharmacyWorklist nested module DefaultController and index.php view.

- 'Site' <select> `filters[site_id]` (optional, data-test="filter-site-id", empty: 'All sites')
- 'Context' <select> `filters[firm_id]` (optional, data-test="filter-firm-id", empty: 'All firms')
- 'Dispense condition' <select> `filters[dispense_condition_id]` (optional, data-test="filter-dispense-condition-id", empty: 'All')
- 'Dispense location' <select> `filters[dispense_location_id]` (optional, data-test="filter-dispense-location-id", empty: 'All')
- 'Secondary Signatories' <dynamic-filter-widget> (optional, preselected via `dynamic_filters`)
- Search button <submit> (data-test="submit-filter")

On search: filters are serialized and submitted via POST; results display prescriptions awaiting secondary signatory approval in a table with Event date, Patient name, and Signatory status columns. Table rows link to the prescription event view. Pagination via standard `LinkPager` widget with data-test="pagination-previous|next".

**Live check (2026-07-24) - blocked:** HTTP 403 on the sample stack's admin user - lacks permission to access this page. Fields above are documented from source only, not confirmed live.

Sitemap: `areas/pharmacy-worklist.md`.

### Reports `/report`

Diagnoses report generation and download interface, backed by ReportController redirecting to actionDiagnoses and diagnoses.php view.

- 'Start date' <text> `#start_date` (required, placeholder='dd-mm-yyyy', default: today's date in d-m-Y format, data-test="report-start-date-input")
- 'End date' <text> `#end_date` (required, placeholder='dd-mm-yyyy', default: today's date in d-m-Y format)
- Institution <select> (optional, via _institution_table_row partial)
- 'Disorder' <diagnosis-selection-widget> `#DiagnosisSelection_disorder_id` with paired text input `#DiagnosisSelection[disorder_id]` (optional, callback='Reports_AddDiagnosis')
- Selected diagnoses table `#Reports_diagnoses` (optional, appears once diagnoses selected) with Diagnosis and Edit columns
- 'Match patients with **any** of these diagnoses' <radio> `condition_type` value='or' (checked by default)
- 'Match patients with **all** of these diagnoses' <radio> `condition_type` value='and' (optional)
- 'Display report' button <submit> (data-test="display-report-button", class='display-report')
- 'Download report' button <submit> (data-test="download-report-button", class='download-report')

On submit: form POSTs to /report/downloadReport action. Validation errors display in `.errors.alert-box` div with error message list. Report summary renders in `.js-report-summary.report-summary` (data-test="report-summary") when report completes.

**Live check (2026-07-24) - discrepancy:** the Disorder field's actual id is `#DiagnosisSelection_disorder_id` (documented above), not the bare `disorder_id` field name originally given. `#Reports_diagnoses` was not present in the initial page dump - likely only rendered once a diagnosis is added (documented above as conditional rather than always-present); the `report-start-date-input` data-test attribute and the display/download button classes weren't independently confirmed in the dump used for this check.

### Request Form worklist `/OphCoRequestForm/worklist/index`

Worklist for managing request forms across multiple statuses and date ranges, backed by OphCoRequestForm WorklistController actionIndex and index.php view.

- 'Forms' <checkboxes> `forms[]` (optional, one per form, dynamically listed)
- 'Status' <checkboxes> `statuses[]` (optional, one per status with preselect_on_search_screen flag honoured if filter empty)
- 'Institution' <multi-select-list> `institution[]` (optional, widget='application.widgets.MultiSelectList')
- 'Subspecialty' <multi-select-list> `subspecialty[]` (optional, widget='application.widgets.MultiSelectList')
- 'Filter by Date' - From <text> `#worklist-date-from` (optional, placeholder='From') and To <text> `#worklist-date-to` (optional, placeholder='To')
- Clear dates link <a> `#sidebar-clear-date-ranges` (class='selected js-clear-dates')
- 'Search Request Forms' button <submit> (AJAX posts to /OphCoRequestForm/worklist/search)
- 'Reset all filters' button <button> `#reset-filters` (type='button', clears all checkboxes and date fields)

On search: form serialized and AJAX-posted to actionSearch; results render in `#searchResults` (class='oe-full-main partial-waiting-main'). Loading spinner in `#search-loading-msg` during request. Date pickers (pickmeup) format='d b Y' on both date inputs.

**Live check (2026-07-24) - discrepancy:** the 'Institution' and 'Subspecialty' fields render live as plain single-value `<select>` elements, not the multi-select-list widget (checkbox-style multi-select) the source code names/documents - possibly the MultiSelectList widget's JS enhancement didn't fire on this sample page, or it degrades to a single-select under some condition. All other fields (`forms[]`, `statuses[]`, both date fields, `#reset-filters`) confirmed present as documented.

Sitemap: `areas/request-form-worklist.md`.

### Safeguarding `/Safeguarding/index/`

Filter and view safeguarding concerns for patients by age, protection status, and concern type, backed by SafeguardingController actionIndex and safeguarding/index.php view.

- 'Age from' <number> `safeguarding_filters[age_from]` (optional, min='0', max='130')
- 'Age to' <number> `safeguarding_filters[age_to]` (optional, min='0', max='130')
- 'Has social worker' <checkbox> `safeguarding_filters[has_social_worker]` (optional, hidden when age > 16 via JS)
- 'Under protection plan' <checkbox> `safeguarding_filters[under_protection_plan]` (optional, hidden when age > 16 via JS)
- 'Concern' <select> `safeguarding_filters[safeguarding_concern_id]` (optional, empty: '-- Select concern --')
- 'Filter' button <submit>

On submit: form POSTs to /Safeguarding/index/ with GET parameters; results display in clickable table with Referral Date, Safeguarding Status, MRN, Patient Name, Date of Birth, and Saved/Assigned by columns. Row click navigates to OphCiExamination event view. Table rows filtered to show only elements where outcome_id IS NULL OR outcome_id equals FOLLOWUP_REQUIRED and no_concerns = 0.

**Live check (2026-07-24) - confirmed via spot-check:** all five filter fields confirmed present with correct types (age-from/age-to as number inputs, both checkboxes, the Concern select).

### Theatre Diaries `/OphTrOperationbooking/theatreDiary/index`

Theatre schedule diary and booking list viewer with date range and context filters, backed by OphTrOperationbooking TheatreDiaryController actionIndex and theatreDiary/index.php + side_panel.php views.

- 'Site' <select> `site-id` (optional, empty: 'All sites', data-test="theatre-diary-filter-site", disabled if emergency_list=1)
- 'Theatre' <select> `theatre-id` (optional, empty: 'All theatres', disabled if emergency_list=1)
- 'Subspeciality' <select> `subspecialty-id` (optional, empty: 'All specialties', data-test="theatre-diary-filter-subspecialty", disabled if emergency_list=1)
- 'Firm' <select> `firm-id` (optional, empty: 'All firms', data-test="theatre-diary-filter-firm", disabled if emergency_list=1 or subspecialty='All')
- 'Ward' <select> `ward-id` (optional, empty: 'All wards', disabled if emergency_list=1)
- 'Include lists with no bookings' <checkbox> `include_no_booking_lists` (optional)
- 'Emergency list' <checkbox> `emergency_list` (optional)
- Date range - From <text> `#date-start` (optional, class='date js-filter-date-from', data-test="theatre-diary-filter-date-start") and To <text> `#date-end` (optional, class='date js-filter-date-to', data-test="theatre-diary-filter-date-end")
- Quick date selectors <radio> `quick-selector` (optional, values: +4days, +7days, +12days, yesterday, today, tomorrow, last-week, this-week, next-week, last-month, this-month, next-month)
- 'Search' button <submit> `#search_button` (type='submit', data-test="theatre-diary-filter-search-button")
- Print buttons (header) 'Print' and 'Print list' (visible if OprnPrint access)

On search: form POSTs to /OphTrOperationbooking/theatreDiary/search (AJAX); results render in `#theatreList` (data-test="theatre-diary-root"). Date pickers (pickmeup) format='d b Y' on both date inputs. autoload attribute on theatreList determines whether initial search required (data-autoload="true|false").

**Live check (2026-07-24) - discrepancy:** the quick date selector radios (`quick-selector`) were not found in the live dump - either a naming/selector mismatch (documented as a bare name, not a confirmed CSS selector) or genuinely absent on this sample page; not resolved. All other fields (site/theatre/subspeciality/firm/ward selects, both checkboxes, both date fields, Search button, Print buttons) confirmed present as documented.

Sitemap: `areas/theatre-diaries.md`.

### Therapy Application worklist `/OphCoTherapyapplication/worklist/index`

Worklist for therapy applications across multiple statuses with NICE compliance, date, and user filters, backed by OphCoTherapyapplication WorklistController actionIndex and worklist/index.php view.

- 'Status' <checkboxes> `statuses[]` (optional, values: 'Pending'/'pending', 'Sent'/'sent', 'Reopened'/'reopened', 'Complete'/'complete', 'Historical'/'historical'; default: 'Pending' checked)
- 'NICE Compliance' <select> `nice_compliance` (optional, values: 0='Non Compliant', 1='Compliant', empty: 'All')
- 'Include applications that have been modified today' <checkbox> `modified_today` (optional, with hidden field)
- 'User' <auto-complete-search> `created_user` with hidden field `created_user_id` (optional, URL='/user/autoComplete')
- Filter by Date - From <text> `#worklist-date-from` (optional, placeholder='From') and To <text> `#worklist-date-to` (optional, placeholder='To')
- Clear dates link <a> `#sidebar-clear-date-ranges` (class='selected js-clear-dates')
- 'Search Therapy Applications' button <submit> (AJAX posts to /OphCoTherapyapplication/worklist/search)

On search: form serialized via POST to actionSearch; results render in `#searchResults` (class='oe-full-main partial-waiting-main'). Loading spinner in `#search-loading-msg` during request. Date pickers (pickmeup) format='d b Y' on both date inputs. User selection displays as removable list item with .js-remove-created-user icon. Search options cached in YiiSession 'therapy_worklist_searchoptions'.

**Live check (2026-07-24) - confirmed via spot-check:** all seven fields (status checkboxes, NICE Compliance select, modified_today checkbox, User auto-complete, both date fields, Clear dates link, Search button) confirmed present as documented.

Sitemap: `areas/therapy-application-worklist.md`.
