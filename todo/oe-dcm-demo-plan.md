# OpenEyes + DCM: demo scenario responses and setup plan

Saved: 2026-09-17. Original plan presented: 2026-09-15.

Status: clinical reproduction is the active priority on 2026-09-17. The retained preview, 14 patient links and same-input script replay are verified. DCM and billing are parked. The separately requested TKLS-10347 preview now runs the latest inspected release with both packs present. Native and generated shared identities passed all four local imaging launches. Guarded trust/shared-identity replay, DNA export, native virtual review, prescribing, IVT planning and reporting controls are verified within their documented limits. A paired checkpoint was restored and checked; independent SQL replay for the new clinical references remains pending. The current operator entry point is `/home/toukan/tkls-10347-demo-guide.md`.

This is a client-neutral copy for the public task repository. The project-specific plan, including this amendment, is stored outside the repository at [the private plan](/home/toukan/oe-dcm-demo-plan-private.md). Organisation labels, the deployment directory and the research API prefix below are neutral placeholders; use the private plan to recover the agreed project-specific values before implementation. Keep credentials, issued access URLs, patient-shaped fixtures and client-specific exports outside this repository.

The original workflow assessment and capacity readings are the 2026-09-15 planning snapshot. Section 4 adds release and sample-source checks performed on 2026-09-17. Recheck capacity, versions and local paths before setup. Current public demo-access findings and a prepared supplier request are in section 6.

## Current priority and preview

The active priority is reproducible clinical scenarios. DCM acquisition, billing and OpenMRS work are parked and no longer gate clinical acceptance or clinically reviewed variation. Earlier financial sections remain historical planning material.

The [clinical operator guide](/home/toukan/oe-clinical-demo-guide.md) is the current entry point for the retained preview, all 14 verified patient links, human workflows, exact script commands, count/date limits and checkpoint recovery. The extra rehearsal and task support runtimes were archived and retired; preserve their evidence without reviving them as another preview.

The later TKLS-10347 request explicitly authorizes a separate requirements instance. Keep that new instance isolated from this clinical preview while making its optional data pack compatible with these scenarios. Patient details and deployment-specific evidence stay outside this repository.

## 1. Recommended approach and evidence

**Use OpenEyes for the clinical record and DCM for patient administration, quotations, billing and financial reporting.** Build a new oe-deploy instance with sample data, then add the synthetic records needed to demonstrate the organisation's scenarios.

I found an official **DCM online trial offer** on its [Ophthalmic Specialists page](https://www.directcontrol.com.au/ophthalmic-specialists). Access is issued through a request form; I did not find a public sandbox login. That page also lists OpenEyes, which makes an existing supplier-supported connector worth checking before commissioning production integration work.

**For the initial setup, use sample PAS messages and a test receiver for outgoing clinical information.** These will demonstrate the OpenEyes side of the integration. DCM screens, financial processing and compatibility with DCM's actual messages remain pending trial access.

This assessment uses the supplied scenarios, local OpenEyes documentation and source, and DCM's published documentation. The new sample instance has now been created. It is not yet connected to a DCM test system.

| Area | Planned responsibility |
|---|---|
| Patient identity, demographics, appointments and admissions | DCM is authoritative; OpenEyes receives the necessary information. |
| Examination, measurements, prescribing, lens selection, operation notes and outcomes | OpenEyes. |
| Fund contracts, fees, quotations, claims, receipts and reconciliation | DCM. |
| Message delivery, identifier mapping and error handling | BridgeLink integration channels. |
| Exact research extracts and daily research API | A small reporting service reading OpenEyes data. |
| Sub-provider recorded separately for each encounter | An OpenEyes extension shared by the relevant clinical screens. |

## 2. Answers and setup for the demonstration scenarios

### Scenario 1: Cataract journey

The clinical sequence follows OpenEyes' documented [clinic pathway](/home/toukan/Temp10/oedocumentation-test/docs/user-guides/how-it-works/appointment-arrival-to-completed-clinic.md) and [surgery pathway](/home/toukan/Temp10/oedocumentation-test/docs/user-guides/how-it-works/surgery-decision-to-operation-note.md).

| Step | Answer and proposed demonstration |
|---|---|
| **1. Logging in from different rooms** | The inspected OpenEyes code does not show a restriction to one session per user. Demonstrate the same named user in two independent browser sessions. Verify behaviour with the deployed authentication configuration and test simultaneous editing separately. DCM session behaviour needs its trial system. |
| **2. Provider dashboard** | Configure OpenEyes worklists, pathway steps and waiting-time warnings for technician, clinician and outstanding clinical actions. DCM provides administrative referral handling. A single dashboard combining all clinical and administrative queues would need additional integration. |
| **3. First appointment and referral** | Send synthetic patient and appointment messages through BridgeLink into OpenEyes. Import a sample referral document and demonstrate its clinical review. Treat structured referral-management integration as release-dependent; the available API differs between the inspected code and newer documentation. |
| **4. Patient arrives** | Replay an arrival update for the existing appointment. Show the patient appearing in the appropriate worklist with the correct status. Verify that the update does not create another patient or appointment. |
| **5. Technician workup** | Configure an examination pathway with the required elements and role permissions. Demonstrate recording findings and completing the technician step. Saving the examination and completing the pathway step are separate actions. |
| **6. AR, VA, IOP, biometry and OCT** | Use native examination elements for autorefractive measurements, visual acuity and pressure. Replay compatible sample biometry DICOM data and stage OCT measurements/images. Clearly identify staged device input; compatibility with the organisation's actual instruments needs separate testing. |
| **7. Surgeon consultation** | Open the same clinical record, review technician findings and measurements, record diagnosis and surgical decision, and complete the clinician step. |
| **8. Prescribing** | Demonstrate OpenEyes prescription creation, signing and printing using synthetic medication data. Australian electronic prescribing, PBS and dispensing integration require separate confirmation. |
| **9. IOL selection** | Configure lens types and constants, save biometry, then use **Choose Lens** to record lens type, power and predicted refraction. Use clinician-approved sample values. |
| **10. Surgery booking and quotations** | Record the surgical decision and booking details in OpenEyes. DCM owns the administrative booking and quotation in the intended integration. For the first demo, use a simulated booking confirmation and mirror its slot in OpenEyes through the normal scheduling screen. Automatic theatre-booking synchronisation requires additional interface work. |
| **11. Consultation billing** | Prepare a completed-consultation handoff containing patient, encounter, provider and service information. Send it to a billing-review test receiver. Actual invoice creation, claiming and payment occur in DCM once trial access is available. |
| **12. Operation** | Demonstrate the theatre list and operation note, including actual procedure, eye, personnel, implant and complications. The performed procedure must be distinguishable from the original planned procedure. |
| **13. Operation billing** | Send the performed-service summary for billing review. DCM supports separate medical-provider and hospital claiming workflows. Demonstrate those in DCM when available, using separate billing entities and linked encounter references. |
| **14. Postoperative day 1** | Prepare a dated follow-up encounter with examination findings and treatment review. Open it during the demonstration without waiting a real day. |
| **15. Month 1, refraction and outcome** | Prepare a second follow-up encounter with refraction and outcome data. Show the longitudinal clinical record and comparison with the preoperative findings. |

DCM documents quotations through **Informed Financial Consent**, including out-of-pocket amounts, and separate [medical claims](https://support.directcontrol.com.au/hc/en-au/articles/10438321378447-Privately-Insured-in-hospital-Medical-Claim-IMC) and [hospital claims](https://support.directcontrol.com.au/hc/en-au/articles/10443349626767-Privately-Insured-In-Hospital-Claim-IHC). Those are documented DCM capabilities; they have not been tested in an OpenEyes-connected environment.

### Scenario 2: Finance and reporting

**Both requested reports belong in the finance system.** DCM remains the intended system. OpenMRS was assessed as an interim option and is on hold under the limited-rework condition in section 7. OpenEyes supplies the clinical activity that supports billing.

| Requested report | Setup and acceptance criteria |
|---|---|
| **Medicare billings by provider, code and amount** | Start with DCM's **Service Items Extract**. Select the billing provider, relevant Medicare transactions and an explicit reporting period. Include item code, service date, invoice/claim reference and amount. Show billed, claimed and paid values separately. DCM documents the extract, but the exact provider and Medicare filters must be checked in the trial build. |
| **All day-surgery transactions for a week** | Start with DCM's **Transaction** report, using transaction date for the selected week. Include charges, receipts, deposits, credits, refunds and adjustments, with service/admission dates also visible. Group hospital and clinician entities separately and reconcile each transaction class to expected totals. |

Sources: [Service Items Extract](https://support.directcontrol.com.au/hc/en-au/articles/10379578184975-Service-Items-Extract), [Transaction report](https://support.directcontrol.com.au/hc/en-au/articles/10379664763407-Transaction).

Prepare a synthetic financial dataset with full payment, underpayment, overpayment, deposit, refund and corrected-charge examples. Until DCM access is available, its expected reports remain test specifications and sample outputs.

A relevant limitation: DCM's documentation states that **refunds are not exported to the accounting application**. The complete weekly report should therefore be reconciled against DCM, including refunds, rather than relying solely on a downstream accounting export. [Processing a Refund](https://support.directcontrol.com.au/hc/en-au/articles/10475340193295-Processing-a-Refund)

### Scenario 3: Research extract

#### Confirmed glaucoma and Latanoprost over 20 years

**This needs a purpose-built extract.** OpenEyes Advanced Search can assist exploration, but its date range controls measurements and export presentation rather than defining this exact prescription cohort. The prescribed-drugs report also filters by event creation date, which is not necessarily the historical prescribing date. [Advanced Search documentation](/home/toukan/Temp10/oedocumentation-test/docs/user-guides/menu-bar/search-reports-data/oe-case-search-case-search-index.md)

Use these rules:

- Include patients whose relevant glaucoma diagnosis has **Confirmed verification status at extraction**, as selected during planning.
- Require a finalised Latanoprost prescription within the preceding 20 calendar years, using the clinical prescription date.
- Match the ingredient across generic names, brands and historical codes. Include combination products containing Latanoprost, with a separate combination-product flag.
- Exclude drafts, deleted prescriptions and medication-history mentions that do not establish a prescription.
- Treat eligibility as patient-level: either eye may qualify. Include all recorded IOP measurements for both eyes within the period.
- Retain qualifying patients who have no IOP measurements. Preserve missing values and their provenance.
- Do not add an exclusion for deceased patients, since none was requested.

Produce:

1. `patients.csv`
2. `diagnoses.csv`
3. `prescriptions.csv`
4. `iop_measurements.csv`
5. A manifest recording the extraction time, date boundaries, code sets, counts and source version.
6. Equivalent nested JSON when requested.

Separate tables prevent every prescription from being multiplied by every pressure measurement. Preserve patient, encounter and event identifiers, laterality, measurement method, prescription date, dose, units, frequency and route.

For the demo, use a read-only account against the isolated sample database. A production deployment should place this workload on an approved reporting copy.

**Migration limitation:** this can only extract historical data that exists in usable form. Twenty years of scanned letters would not automatically provide twenty years of structured prescriptions and IOP measurements.

#### Bonus: the organisation software pulls yesterday's diabetic-retinopathy cases

Add a **new research endpoint** using the existing xAPI routing, authentication and request patterns:

`GET /xapi/research/v1/diabetic-retinopathy-cases?from=...&to=...&cursor=...`

Execution adjustment: the existing front controller already routes this prefix to Laravel. Reusing it avoids an extra routing mechanism. Deliver a bounded daily snapshot with payload revisions and window reconciliation; this does not imply a complete incremental change feed.

The demo default will mean:

- Clinical encounters on the previous calendar day involving confirmed diabetic retinopathy, including longstanding disease.
- Date boundaries calculated in `Australia/Perth`.
- Stable patient and encounter identifiers, pagination and record revisions.
- Authenticated access, repeatable date-range requests and delivery retry without duplicate processing.

Run a test client that pulls those cases and sends them to a local receiving endpoint. The full bonus acceptance test must use **the organisation's actual software** once supplied.

The current xAPI offers individual patient and event reads; it does not establish a ready-made endpoint for enumerating this research cohort.

### Scenario 4: Restricted sub-provider field

**Implement this as an encounter-linked field on the standard clinical screens.**

The agreed requirement is separate values for each consultation or procedure encounter, including two encounters on the same day. OpenEyes checklists share answers across a patient's day, so they do not satisfy that storage requirement. [Checklist behaviour](/home/toukan/Temp10/oedocumentation-test/docs/user-guides/patients/adding-events/examination/checklist.md)

The extension will:

- Keep **Location/Site** and **Sub-provider** as separate attributes.
- Add a restricted dropdown to Examination and Operation Note capture and display.
- Initially offer Clinic consultation, Mobile van consultation, Surgery and Optometric consultation.
- Store the value against the appointment/admission encounter; create a local encounter identifier for unscheduled care.
- Show the same value across notes linked to that encounter, while keeping separate same-day encounters independent.
- Validate allowed values on the server, audit changes, and include the field in printouts, research exports and clinical handoff messages.
- Preserve retired options in historical records. Existing missing values remain **Not recorded**.

This is development work beyond configuring a checklist.

## 3. Written responses

### Domain 1: Practice management and billing

| Question | Evidence-backed response |
|---|---|
| **How are individual fund contracts updated?** | DCM supports insured location rates, fund-group rules and individual fund overrides. Configure the organisation's negotiated contracts in DCM and validate representative services against the agreed schedules. [Day surgeries and hospitals](https://support.directcontrol.com.au/hc/en-au/articles/7886992910863-Day-Surgeries-and-Hospitals) |
| **How are day-surgery rates and facility fees updated?** | Maintain contracted facility rates in DCM. DCM also documents automatic standard fee-schedule updates, preservation of historical rates and selection by date of service. Bespoke contract changes still need explicit maintenance and validation. [Fee Updates](https://support.directcontrol.com.au/hc/en-au/articles/9150096342159-Fee-Updates) |
| **Can hospital and surgeon claims be distinguished?** | Yes, DCM documents distinct hospital and medical-provider claim workflows. Configure separate billing entities and provider identifiers, linked to the same clinical journey. Verify the separation in claims and financial reports. |
| **Is gap quoting available?** | DCM's IFC workflow supports estimates, eligibility checks, hospital excess/co-payment and medical-provider out-of-pocket amounts. Demonstrate both estimates. Financial consent and clinical consent remain distinct records. [IFC and eligibility workflow](https://support.directcontrol.com.au/hc/en-au/articles/7574036453263-Informed-Financial-Consent-IFC-and-Online-Eligibility-Check-OEC-and-ECF) |
| **How are underpayments handled?** | DCM provides remittance discrepancies for review and correction/resubmission. Its hospital-claim guidance says accepting a lower payment can change the invoice to the paid amount. Demonstrate an authorised review decision, with the difference visible. [Hospital claim processing](https://support.directcontrol.com.au/hc/en-au/articles/10443349626767-Privately-Insured-In-Hospital-Claim-IHC) |
| **How are overpayments handled?** | DCM supports retaining an excess as an overpayment or creating a credit for later allocation/refund. These are different accounting outcomes and should be demonstrated separately. [Credits and Overpayments](https://support.directcontrol.com.au/hc/en-au/articles/7572391271055-Credits-and-Overpayments) |
| **Does surgery admission functionality also answer clinic registration?** | Clinic registration has its own DCM workflow, including demographics and privacy acknowledgement. Surgery adds admission, pre-admission and procedure-specific processes. Provide separate clinic and surgery demonstrations. [Register a Client](https://support.directcontrol.com.au/hc/en-au/articles/15746223719183-Register-a-Client), [Admission through to Discharge](https://support.directcontrol.com.au/hc/en-au/articles/7573936089487-Admission-through-to-Discharge) |
| **Can medication stock shortages be flagged through PBS?** | No verified OpenEyes local-stock feed was found. PBS information does not establish a pharmacy's current stock. A useful implementation needs an authoritative pharmacy stock feed or a maintained availability alert. National shortages can be checked through the [TGA shortage service](https://www.tga.gov.au/safety/shortages-and-supply-disruptions/medicine-shortages), but that is a different source of information. |
| **Are forms free text or constrained?** | OpenEyes supports structured clinical elements and free text. Request Forms provide configurable form components. Standard checklists have validation limitations, so demonstrate the exact dropdowns, required fields and rejection behaviour needed by the organisation rather than promising every form supports every rule. |

### Domain 2: Interfaces, migration and the organisation responsibilities

#### Interfaces that can be documented

| Interface | Available operations and boundary |
|---|---|
| **OpenEyes PASAPI** | XML over HTTP with authenticated patient create/update, appointment create/update/delete and patient merge operations. Examples include `PUT /PASAPI/V2/Patient/{HospitalNumber}` and `PUT /PASAPI/V2/PatientAppointment/{VisitID}`. |
| **OpenEyes xAPI reads** | Individual patient and event reads, external-identifier resolution, code systems, and current allergies, diagnoses, risks and associated contacts. |
| **OpenEyes xAPI writes** | Supported clinical updates for allergies, diagnoses, risks and associated contacts. Some record complete state or create clinical events; they must not be treated as arbitrary database patches. |
| **Referral APIs** | Newer documentation includes referral operations absent from the inspected local route file. Confirm availability against the installed release before including them in the demonstration contract. |
| **OpenEyes Document API** | Document search, create, update and delete operations under `/api/v2/Document/...`. Use stable document references to reconcile delivery and retries. |
| **Webhooks** | Notifications for supported clinical event changes, followed by API reads. They require delivery monitoring and reconciliation; fetching later can return newer state. |
| **Device integration** | DICOM and device-specific processing, subject to instrument and export-profile compatibility. |
| **DCM interfaces** | DCM documents HL7 integration. HealthLink publishes a DCM guide covering results, correspondence and outgoing referrals with PDF payloads. Public evidence does not establish the complete patient, appointment or financial-write contract needed here. |

Provide the installed `/xapi/swagger` and `/xapi/openapi` specifications alongside the [OpenEyes API guidance](/home/toukan/Temp10/oedocumentation-test/docs/devops/apis/xapi-in-practice.md) and [PASAPI guidance](/home/toukan/Temp10/oedocumentation-test/docs/devops/interoperability/pas-and-pasapi.md).

Use dedicated service accounts, explicit institution/site/service context and TLS for external access. **Do not describe these interfaces as a complete FHIR service without an implemented, versioned FHIR contract.**

DCM reference: [HealthLink's DCM integration guide](https://www.healthlink.com.au/wp-content/uploads/2025/04/HLK_DCM_Integration_Guide.pdf).

#### Migration assumptions

the organisation will provide data-owner decisions, access to source exports, identifier reconciliation, clinical and finance reviewers, acceptance testing, training coordination and change-management resources. The implementation team will own mapping, transformation, import tooling, reconciliation reports and defect correction.

A significant qualification is that DCM's detailed migration guide **excludes patient transactions and admissions from standard migration** and says exceptional migration work may attract charges. Those histories need explicit assessment and contractual coverage. [Migrating data from other applications](https://support.directcontrol.com.au/hc/en-au/articles/7765322005519-Migrating-data-from-other-applications)

The sample-data demo will demonstrate migration checks and reporting behaviour; it will not validate the quality or completeness of the organisation's real historical data.

### Domain 6: Commercials

**The eight-flow pricing question cannot be confirmed from the supplied document.** The actual quotation, Annexure A response and definitions of the eight base flows are needed.

Before committing to a price, produce a reconciliation table with one row per requirement:

`Requirement -> system -> interface/feature -> delivery owner -> quoted inclusion -> additional cost -> acceptance test`

| Item requiring explicit confirmation | Commercial detail to obtain |
|---|---|
| DCM specialist and hospital licensing | DCM publicly describes specialist pricing by FTE revenue earner and hospital pricing by theatres or beds/chairs. Confirm the organisation's applicable arrangement and annual support. |
| Base interfaces | Identify each flow, direction, payload, trigger, error handling and supported release. Confirm whether acknowledgements, corrections and reconciliation are included. |
| Research extract and daily research API | Confirm whether development, hosting and ongoing maintenance are included. |
| Encounter sub-provider extension | Confirm configuration/development cost, reporting changes and upgrade support. |
| Device and document interfaces | Confirm each device model, transport, conversion component and third-party licence. |
| SMS, telehealth, electronic claiming and payment services | Obtain each supplier's one-off, recurring, per-user and usage charges, including minimum commitments. |
| Migration and retained history | Explicitly price admissions, transactions, attachments, cleansing exceptions and repeated trial migrations. |

The custom field, research service and any new financial/theatre interfaces are **items to reconcile against the quote**, not automatically proven exclusions.

Published DCM licensing descriptions: [Ophthalmic Specialists](https://www.directcontrol.com.au/ophthalmic-specialists), [Hospitals](https://www.directcontrol.com.au/hospitals).

### Domain 7: Access, audit, integrity and governance

| Question | Current evidence and required setup |
|---|---|
| **Unique users and permissions** | OpenEyes supports named users, role permissions and institution/site/service context. Configure separate reception, technician, surgeon, researcher, auditor, administrator and integration accounts. Test the effective permissions for each role. |
| **Failed logins** | The inspected local-login defaults are ten failures followed by a ten-minute soft lock. Deployment settings and an external identity provider can change this behaviour. Test the actual configuration. |
| **Access and account history** | OpenEyes records successful/failed logins and clinical access activity. A complete account-lifecycle history, including all permission changes, needs a coverage check before making an unqualified claim. |
| **Timestamped and attributable audit** | OpenEyes records user, time, action, target and contextual details, with clinical version history available for supported records. Validate coverage using the demo's create, view, edit, print and delete cases. |
| **Can users or administrators alter audit entries?** | The reviewed audit screen provides no edit/delete controls, but that does not establish immutability. The legacy Document API hard-delete helper deletes all Audit rows linked to the target event before deleting the event. Its soft-delete branch differs. No delete was executed during this assessment. Review access to that API and use independently controlled append-only storage if retained audit must survive privileged or application-level deletion. [Installed Document delete implementation](/home/toukan/openeyes-demo-26.1/protected/modules/Api/controllers/v2/DocumentController.php:79) |
| **Retention** | Retention for at least the associated record's lifetime must be an explicit operational policy, supported by backups and retention tests. It is not established merely by having an audit table. |
| **Search, filter, sort and export** | The audit screen supports filters and newest-first results. Arbitrary sorting and a complete native export were not verified. Include a controlled audit export if required by the organisation. |
| **Complete subject or data-element history** | Combine access audit with event and element version history. Validate a subject export against known changes and deletions. Do not assume a single existing screen provides the complete package. |
| **Protection against alteration/deletion** | Use role permissions, controlled deletion workflows, version history and backups. OpenEyes supports deletion requests and soft deletion in the reviewed workflow; privileged deletion routes also require access control. |
| **Paper copies** | OpenEyes supports clinical/document printing. Demonstrate the required records and signatures. A complete certified-copy process needs an agreed template and validation. |
| **Documentation** | Deliver a versioned configuration record, interface contracts, operating procedures, migration mappings, validation evidence, backup/restore instructions and support responsibilities. |
| **Training** | Provide role-based training, super-user sessions and rehearsals using this sample environment. The organisation coordinates attendance and local procedures. |
| **Change control and releases** | Record versions; assess effects on clinical, billing, research and audit functions; test changes in a separate environment; obtain business acceptance; retain release notes and rollback instructions. Supplier notification and support commitments must be confirmed contractually. |

OpenEyes evidence: [Audit screen documentation](/home/toukan/Temp10/oedocumentation-test/docs/user-guides/menu-bar/search-reports-data/core-audit-index.md). DCM also documents user/security controls, but its public [Security and Audit description](https://support.directcontrol.com.au/hc/en-au/articles/15219454058383-Security-and-Audit) does not establish all of the organisation's retention and immutability requirements.

## 4. New oe-deploy instance and message setup

### Environment

1. **Create a fresh deployment** at `/home/toukan/oe-dcm-demo-20260915`, with the same unique Compose project name. Obtain a fresh oe-deploy template and rename it into place. Give it dedicated ports, volumes and networks.

2. **Use the latest `release/26.1.x` branch.** Refresh the OpenEyes and sample remote branches at implementation start, then pin their exact commits, compatible module/dependency revisions and runtime image digests. Ensure web and manager execute the same pinned application revision. Record the installed API specification. Template defaults must not silently select another release.

3. **Check capacity before startup.** The latest check showed approximately **3.4 GiB available RAM**. Start with the basic OpenEyes/database profile and add BridgeLink and required device services only when capacity permits. Do not stop other environments or prune shared resources.

4. **Load sample data explicitly.** Use the template's sample-environment setup script where available. Otherwise follow its documented first-run sample reset/migration procedure, stopping only this instance's manager while loading. Manager startup alone does not load the sample database.

5. **Configure the demonstration.** Add institution/site/service context, named roles, worklists, pathway presets, lens catalogue, clinical templates and the encounter sub-provider extension. Use Docker secrets and keep all added tools containerised.

6. **Add reproducible scenario-specific synthetic records.** Prepare the cataract journey, research inclusion/exclusion cases, multiple providers, same-day encounters and finance-message fixtures using the frontend runbook and idempotent generator described below. Resolve generated identifiers through a manifest rather than assuming fixed database IDs.

7. **Create rehearsal checkpoints.** Retain a clean sample checkpoint and a prepared demonstration checkpoint. Restore only this instance between rehearsals. Keep the instance available for subsequent iterations.

Keep deployment timezone settings compatible with the host. Use explicit timezone offsets in messages and `Australia/Perth` for the demo's research/reporting calendar boundaries; verify the displayed dates during rehearsal.

### Reproducible demo data and sample-repository PR

This amendment is mandatory for implementation. Deliver both a frontend reproduction runbook and idempotent regeneration scripts using the sample repository's existing SQL, shell and migration patterns. Create a new yiic command only if a specific requirement cannot be met adequately with those patterns, or the sample repository already contains PHP commands that establish a suitable maintained precedent. Avoid new PHP that duplicates OpenEyes logic and can fall behind application changes.

#### Release and repository evidence

Remote branch heads checked on 2026-09-17:

| Repository | Required branch | Observed head |
|---|---|---|
| OpenEyes | `release/26.1.x` | `ab35454c623e6c565a8d03005a02ffb4d2bbbbb2` |
| sample | `release/26.1.x` | `060436f250f699eb05bde32fedbf04798e028b1d` |

Refresh these branches when implementation begins and record the actual commits used. These are observation pins, not an instruction to use an older commit after the branch advances. Pin compatible dependency/module revisions and runtime image digests as well. Verify the code served by the new instance against the recorded commit.

| Inspected pattern | Finding and decision |
|---|---|
| [Sample post-migration yiic hook](/home/toukan/sample/sql/demo/post-migrate/99-yiiccommands.sh:3) | Calls commands implemented and maintained in OpenEyes; it is not a PHP command implementation in sample. Reuse existing commands when their current behavior fits. |
| Sample tracked-file inventory at the recorded commit | Contains no PHP files or commands directory. There is currently no sample-owned PHP command pattern to follow. |
| [Demo settings SQL](/home/toukan/sample/sql/demo/pre-migrate/90-Demo-settings.sql:1) and [role-assignment SQL](/home/toukan/sample/sql/demo/post-migrate/97-all-roles-for-admin.sql:3) | Existing scripts use SQL duplicate guards. Preserve this small-script style; verify that the relevant unique constraints actually prevent duplicates and that errors are not hidden. |
| [Sample worklist generator](/home/toukan/sample/sql/demo/post-migrate/45-GenerateDemoWorklists.sh:18) | Uses relative dates, blind inserts, fixed identifier-type IDs and existing sample patient numbers. Rerunning its inserts can duplicate definitions and worklists. Reuse the idea of dated fixtures, but implement stable keys and explicit date inputs. |
| [Sample database image build](/home/toukan/sample/dockerfile:71) | Copies pre-migration SQL into the database build. Application-dependent generation must run after application migrations in an OpenEyes runtime container. |
| [Sample audit-clearing script](/home/toukan/sample/sql/demo/pre-migrate/05-ClearAudit.sql:1) | Deletes audit rows as part of baseline preparation. It must never be part of the repeatable scenario generator. |
| OpenEyes `protected/config/core/console.php` at the recorded 26.1 commit | Discovers `commands/*Command.php` in module directories. A command under `protected/modules/sample/commands/` can be registered without a core registration change. |
| OpenEyes `protected/scripts/oe-reset.sh` at the recorded 26.1 commit | Demo post-migration hooks run inside the migration branch of reset. A reset with migrations skipped does not run those hooks. Explicitly invoke scenario generation after migrations when using a split setup procedure. |

**Decision:** use the sample repository and its current script layout. The existing worklist script needs duplicate guards and explicit dates for this use, but those shortcomings alone do not justify introducing PHP. First prove a small scenario using existing sample records or frontend-created sample data plus SQL/shell scripts. Reuse commands already maintained in OpenEyes for operations that need application logic.

#### Frontend reproduction record

1. Create a reference instance/checkpoint using the pinned release and sample baseline. Record the exact configuration prerequisites, user role, institution/site/service and browser starting state.
2. Build one reference journey through the frontend for each scenario. Record every numbered click, screen/route, field label, entered value, laterality, date formula, save/sign/complete action and expected visible result. Include worklist/pathway transitions separately from clinical saves.
3. Assign stable step IDs and link each generated patient, encounter, event, element, prescription, booking and attachment to its corresponding runbook step. Keep the actual synthetic values and screenshots with the sample pack or private run artifacts, outside this task repository.
4. Record PAS message replay, device import and other non-frontend prerequisites with their exact input files and invocation steps. For imported or historical data, record the frontend steps that verify it and explicitly identify how it was created. Do not describe imported data as manually entered.
5. Record both a clean-start recipe and a rehearsal recipe from a named checkpoint. Another operator must be able to follow the runbook without relying on undocumented actions or fixed database IDs.
6. Compare generated records against the frontend-created reference in view, edit, print, audit/history and research output. Capture differences and resolve them before calling the generator equivalent. Only claim save/sign behavior actually exercised with the designated demo users.

#### Durable scripts using current patterns

1. Start with the existing sample database and assets, run normal application migrations, then apply the scenario scripts at the appropriate existing pre/post-migration stage. Prefer reusable records already in the sample dataset. Capture additional clinical reference records through the frontend and package them using the repository's existing SQL/data and file conventions.
2. Keep the script changes small and specific to these scenarios. Use the current script runner, database connection helper, numbered SQL/shell files, and existing local-post/selected post-path mechanism where an optional pack is needed. Do not introduce a new command framework, fixture registry table, generic seed engine or configuration format.
3. Accept one explicit anchor date and reporting timezone through the script's documented inputs. Calculate dates with calendar arithmetic from declared original offsets. Do not copy the current worklist script's implicit date variable or repeated 86400-second stepping. Keep a single date-adjustment section so future changes are easy to review.
4. Resolve identifiers through existing stable codes, external references and unambiguous relationships. Use SQL variables for resolved IDs and narrowly scoped insert/update guards. Do not use fixed database IDs or a broad duplicate-ignore statement as proof of idempotency. Validate all lookups before writes, fail on ambiguity, and leave unrelated sample records untouched.
5. Use existing natural keys and the fixture's documented patient/encounter relationships to recognise prior data. Verify expected state before skipping an existing scenario. If a particular object cannot be identified reliably without inventing infrastructure, record that concrete limitation and evaluate the existing application commands or the yiic fallback below.
6. The same script inputs must leave clinical records, links, files and clinical history unchanged on rerun. For changed dates, set absolute values derived from the original scenario offsets and new anchor. Stop on manual drift; use this instance's clean checkpoint for a full rebuild. Keep normal baseline reset separate from the idempotent scenario scripts, and never run the audit-clearing scripts as part of a rerun.
7. Let normal OpenEyes migrations upgrade the bundled sample baseline. Keep any post-migration SQL limited to the schema it actually needs, with explicit columns and a clear failure if required tables, fields, modules or references are missing. SQL can also go stale: record the tested release/schema and rerun the scenario checks whenever the release branch or baseline changes.
8. Reuse existing application commands for actions that require validation or side effects. Do not copy model/controller logic into shell, SQL, or a new PHP command. For SQL-imported sample records, prove their complete relationships and frontend behavior against the reference records; label their provenance as imported sample data. Exercise real save/sign actions through the frontend for workflow and audit evidence.
9. Make file copies and message replays repeatable using the existing import paths, stable names/references and content checks. Use database transactions for related writes where supported; verify interruption recovery for files and messages separately.
10. Retain the run manifest and read-only verification queries already required by this plan. Record source commits, anchor, timezone, resolved IDs, expected counts/cohorts and results as ordinary run artifacts outside source control. No new persistent registry or metadata framework is required.

#### Adjustable patient counts

Accept a count per scenario through the existing shell argument pattern. Assign stable scenario-and-sequence identifiers so that the same counts reuse the same patients and increasing a count adds only the missing patients. Validate non-negative whole numbers and reject ambiguous identifiers before writing. Reducing a requested count must not delete previously generated records; report those records and use the clean checkpoint when a smaller complete rebuild is required. Apply the same anchor-date rules to every patient in a scenario. Verify a multi-patient run, an identical rerun, and an increased-count run, including clinical relationships and expected research cohorts.

#### Realistic variation after the base scenarios pass

User amendment, 2026-09-17: confirm and reproduce every base scenario before considering a larger, more varied dataset. Increasing counts in a repeatability test does not establish clinical variation. Under the latest priority, clinical acceptance is independent of the parked financial demonstration.

1. Finish the base acceptance matrix, frontend recipes, clean restoration, identical reruns and date-adjustment checks first. Record remaining clinical limits explicitly. Parked DCM workflows do not block this clinical gate.
2. After that gate passes, assess a small useful set of varied examples. Use realistic fictional names and internally consistent age, laterality, measurements, diagnoses, treatment, procedure and follow-up dates. Keep synthetic identity clear in the demo.
3. Reuse a patient only where the added scenario forms a coherent longitudinal history. Otherwise create a different named patient with a new stable identity. Never rename a prepared patient or randomise clinical facts during a rerun.
4. Extend the current SQL/shell patterns and deterministic ordinal selection. Retain count adjustment, source checks, collision/drift rejection and checkpoint recovery. Do not introduce a new seed framework or PHP solely to vary names.
5. Verify each added variant through its frontend recipe and expected research/integration results before increasing its volume.
6. Save reusable verified lessons in the existing knowledge structure. Keep patient-shaped fixtures, screenshots, exports, signatures and credentials outside this task repository. The method is recorded in [sample-data generation lessons](/home/toukan/claude-kit/knowledge/Openeyes/oe-sample-data-generation.md).

#### Conditional yiic fallback

1. Before adding PHP, document the exact failed case with the existing scripts or an existing sample-owned command that provides a suitable precedent. A shell hook that invokes a core yiic command does not establish a sample-owned PHP pattern.
2. Prefer invoking or minimally extending a command maintained with the relevant OpenEyes feature. If a new sample command is justified, keep it a thin caller of current application APIs, limited to the demonstrated gap, and follow the existing command conventions. Do not recreate clinical save rules, audit/signature handling or a general fixture framework.
3. Include the reason for the exception, the reused APIs, compatibility checks and maintenance responsibility in the eventual PR. Prove it on the pinned latest `release/26.1.x` before extending its scope. The SQL/shell approach remains the default for the rest of the dataset.

#### Date rules

| Dataset | Required date behavior |
|---|---|
| Cataract journey | Declare the timeline offsets for referral, consultation, operation, day-one and month-one follow-up. Provide checkpoints for the live steps and completed history, preserving chronological order when the anchor moves. |
| Daily diabetic-retinopathy feed | Place positive cases in the calendar day before the anchor in Australia/Perth, with cases just outside both boundaries. Derive query boundaries and expected output from that same calendar. |
| Glaucoma and Latanoprost history | Use current-clinic prescriptions for generated clinical charts. Verify the exact 20-calendar-year boundary and either side in isolated query tests. Identify supplied legacy finalized prescriptions separately from genuinely signed new records. Use calendar arithmetic with an explicit leap-day rule. |
| Appointments, worklists and theatre sessions | Generate dates and availability from the anchor; preserve links when moved. Repeating a shift must not add another offset or another booking. |
| Demographics and provenance | Keep synthetic dates of birth fixed unless a scenario explicitly defines an age-relative case. Do not rewrite audit creation times or fabricate historical signatures to make the dataset appear older. |

#### Proposed sample PR contents and checks

| Proposed artifact | Purpose |
|---|---|
| Numbered SQL/shell scenario scripts in the existing sample layout | Guarded data setup, deterministic date adjustment and verification through current runners. |
| Existing sample data/assets extended only where needed | Frontend-created clinical examples and wholly synthetic inputs packaged by the current repository conventions. |
| Frontend runbook and sample README entry | Exact reproduction steps, prerequisites, one-line commands, checkpoint recovery and limitations. |
| Existing post-migration/local-post integration | Run after the required schema is ready; reuse the current selection mechanism for optional scenarios. |
| Read-only SQL assertions and focused repeat-run checks | Verify duplicates, relationships, dates, expected cohorts, interrupted-run recovery and unchanged unrelated data. |
| A small PHP command only if the conditional rule above is met | Address a documented gap or follow an established sample command pattern; reuse maintained application behavior. |

Target the sample repository's `release/26.1.x` branch, subject to its normal maintainer process. Demonstrate the existing-pattern script approach on that release before preparing the PR. Keep production feature changes separate from sample data.

Implementation order: establish the pinned instance and clean checkpoint; record frontend reference steps; prove one representative scenario with the existing SQL/shell patterns; document any specific limitation before considering yiic; verify repeatability and date shifts; expand the scenarios; rehearse after restore; prepare the local review diff and PR description. The human commits, pushes and creates the PR.

### Message contract and fixture pack

Use a **versioned neutral JSON fixture contract** for the simulated PAS side. This is a proposed demo format, not a claim that DCM emits JSON. BridgeLink converts supported inbound operations into the installed OpenEyes API format.

Each applicable fixture carries a message ID, revision, event time with offset, patient identifier type/value, encounter reference, site and provider. Service messages also carry sub-provider, clinical event references, procedure details and laterality.

| Message group | Demo processing |
|---|---|
| **Patient register/update/merge** | Map into PASAPI patient and merge operations. Test changed demographics, duplicate delivery and identifier reconciliation. |
| **Appointment create/change/cancel** | Map into PatientAppointment operations using a stable external visit reference. Test movement between dates/providers and cancellation. |
| **Arrival and attendance updates** | Update the existing visit and verify worklist behaviour. Keep attendance separate from clinical completion. |
| **Referral and documents** | Import a sample PDF with patient, referral/document reference and date. Demonstrate correct allocation and duplicate prevention. |
| **Surgery request and booking confirmation** | Capture the OpenEyes request, generate a simulated PAS confirmation, and mirror the confirmed slot through the normal OpenEyes scheduler. Mark automatic scheduling reconciliation as additional integration work. |
| **Completed consultation or operation** | Send a performed-service summary to a review queue in the test receiver. Include distinct clinician and facility references. Release for billing requires review; saving a draft clinical event does not create a charge. |
| **Clinical correspondence** | Deliver a sample letter or operation note with stable identifiers and a revision. Record receipt and replacement behaviour. |

Create a separate outbound clinical-service channel. The existing reference PAS OUT channel's scope is patient lookup.

For every fixture, retain the input, transformed request, application response and expected OpenEyes result. A transport acknowledgement alone is insufficient evidence that the patient or appointment was successfully updated.

When DCM trial access becomes available, obtain its supported OpenEyes connector and message specification, replace the simulated DCM boundary, and run the same acceptance cases against real DCM behaviour.

## 5. Delivery responsibilities and acceptance

### Three-minute implementation overview

| Phase | Implementation team | Organisation involvement and decision |
|---|---|---|
| **Agree the workflows** | Map clinical, administrative and financial responsibilities; reconcile requirements against interfaces and quotation. | Nominate clinical, finance, IT and research owners; approve workflow definitions and scope. |
| **Configure and connect** | Build environments, configure OpenEyes/DCM, implement interfaces and prepare sample scenarios. | Supply approved forms, provider/site lists, fund contracts, device details and access arrangements. |
| **Migrate and rehearse** | Run trial imports, produce reconciliation reports and demonstrate end-to-end scenarios. | Resolve source-data issues, review migrated records, validate financial totals and perform acceptance testing. |
| **Train and go live** | Train super-users, complete cutover checks, verify backups and provide the cutover plan. | Coordinate staff and scheduling, approve readiness and authorise go-live. |
| **Support and controlled change** | Monitor interfaces, resolve defects, provide release evidence and support escalation. | Provide first-line triage, report issues and approve material workflow changes. |

### Acceptance tests

The demonstration is ready when:

- All 15 cataract steps have a repeatable script with the correct patient, encounter, provider, eye and dates.
- Every generated fixture has a linked frontend reproduction or verification recipe, with exact prerequisites, values/date formulas and expected results.
- Seeding twice with identical inputs creates no duplicate patients, encounters, events, elements, bookings, attachments or clinical audit/version entries.
- Changing the anchor moves only owned clinical dates and dependent schedules; repeating that anchor is a no-op. Cover leap-day, month-end and local-day boundary cases.
- Fresh checkpoint restoration plus regeneration reproduces the expected clinical state and research cohorts, allowing new surrogate IDs and truthful execution timestamps.
- Generated records render, edit and print correctly in the frontend, retain valid relationships and attributable audit, and leave unrelated sample records unchanged.
- An interrupted seed can be retried without duplicates, including document/message side effects; the scripts stop clearly on missing dependencies or manually changed fixtures.
- Two-room login behaviour and concurrent-edit behaviour have been tested independently.
- Patient, appointment, arrival, cancellation and merge messages produce the expected OpenEyes state without duplicates.
- Failed delivery, malformed identifiers, missing patients, replay and corrections produce visible, recoverable outcomes.
- The glaucoma extract matches a manually checked expected cohort, including boundary dates, brands/combinations, suspect/refuted diagnoses, drafts and missing IOP.
- The daily DR API selects the correct local-calendar day and supports repeat delivery without duplicate processing.
- Two same-day encounters retain different sub-provider values across capture, display, print, audit and export.
- Role and audit tests establish exactly which governance claims can be supported.
- Every demonstration step is labelled **working in OpenEyes**, **demonstrated through sample messages**, or **pending DCM verification**.
- The handover includes the instance location, version manifest, synthetic-data manifest, message fixtures, expected outputs, rehearsal script and outstanding supplier dependencies.

**DCM-dependent acceptance remains separate:** quotations, native financial reports, actual claim workflows and automatic cross-system booking/billing cannot be marked passed until exercised in a DCM test system.

## 6. DCM demo access research - 2026-09-17

### Practical access routes

**Prioritise a downloadable DCM evaluation for local use.** If a complete installer and trial activation cannot be supplied, accept the fastest available hosted trial or guided session. External interfaces and an OpenEyes connector can follow initial access.

| Priority | Route | Evidence and limitation |
|---|---|---|
| 1 | Request a supplier-issued installation package and evaluation licence | The [migration guide](https://support.directcontrol.com.au/hc/en-au/articles/7765322005519-Migrating-data-from-other-applications) explicitly includes installing a trial copy and using it for trials/training. No public installer plus demo licence was found. Ask for a licensed package or supplier-prepared remote machine if hosted access is unavailable. |
| 2 | Request the advertised online trial | Both [Ophthalmic Specialists](https://www.directcontrol.com.au/ophthalmic-specialists) and [Hospitals](https://www.directcontrol.com.au/hospitals) explicitly offer access to an online copy through a form. This is the strongest direct route. Provisioning time, duration, cost and enabled modules are not published there. |
| 3 | Ask for a hosted desktop evaluation over Remote Desktop | The vendor's [Remote Desktop guide](https://support.directcontrol.com.au/hc/en-au/articles/9145459541519-From-a-Remote-Desktop-Connection) documents a DCM-hosted connection. This establishes a real access method, not that an evaluation account is already available. Request full DCM desktop access if the browser offering is only a limited portal. |
| 4 | Book a free product demonstration immediately | The vendor's [product brochure, page 2](https://e17ba581-bf88-4eb1-b055-95c3802e9eef.filesusr.com/ugd/953634_520d8fdd88ba47d08daa54c8ea046f73.pdf) explicitly offers a free demonstration via 1300 557 550. Ask for screen sharing and, if they allow it, supervised control. The free demonstration offer does not establish that a hands-on trial is free. |
| 5 | Seek an introduction through a documented partner | DCM's specialist/hospital pages identify Hills Health Solutions, and HealthLink publishes a [DCM integration guide](https://www.healthlink.com.au/user-guide/direct-control-medical/). These are possible referral routes if direct contact stalls. No partner-issued DCM trial or redistribution right was verified. |

The published contact is **support@directcontrol.com.au**, telephone **1300 557 550**, with support hours of 7am-6pm AEST on weekdays excluding public holidays. Email is a practical initial route from outside Australia; a 1300 number may not be reachable internationally. [Official contact page](https://www.directcontrol.com.au/contact-us)

The ophthalmology form asks for first name, surname, practice, position, phone, email, existing software and a description; first name and email are marked required. Use the actual requester's details when sending.

### What the deeper search established

Reviewed the vendor's product and discipline pages, public page sitemap, resources/support pages, installation/update and migration documentation, public help-centre searches for trial/demo/download/hosted/cloud/training/remote access, vendor brochures, and linked partner material. Searches also covered the legal vendor name, CONNECT DIRECT Pty Ltd.

No immediately usable public sandbox credentials, self-service DCM evaluation download or downloadable DCM sample database were found in those sources. This is a search result, not proof that the vendor cannot supply them. A public login page is not evidence of a demo account.

The [Delivery and Refund page](https://www.directcontrol.com.au/delivery-and-refund-policy) describes delivery through issued account details or downloadable files/links. Together with the trial-copy guidance, this makes requesting a supplier-issued package worthwhile; it does not reveal a public download.

The [Red Oxygen/CompleteSMS partner page](https://redoxygen.com/partners/direct-control/) advertises an SMS trial for integration with DCM. That trial supplies messaging, not the DCM PAS. The PDF linked from the vendor's partners page describes Dox Oculi, another product, and is not a DCM installer.

The Hills link is published by DCM, but the Hills site returned HTTP 403 during this check. Treat it as an unverified referral lead. No existing customer portal was used, no credentials were tried, and no software licence was obtained.

### Existing OpenEyes integration evidence

DCM's [Consultations guide](https://support.directcontrol.com.au/hc/en-au/articles/15782222677775-Consultations) says Clinical > Progress Notes can launch OpenEyes for ophthalmologists when enabled, and describes specialist letters generated in OpenEyes. This supports requesting their existing connector; it does not establish demographic, appointment, theatre or billing message contracts, single sign-on, or automatic invoice creation.

After basic access is secured, request the supported OpenEyes versions, configuration guide, interface contacts and sample messages. Test patient-context launch separately from data synchronisation. Keep OpenEyes on the requested latest `release/26.1.x`; record any DCM compatibility gap explicitly.

The [HealthLink integration guide](https://www.healthlink.com.au/wp-content/uploads/2025/04/HLK_DCM_Integration_Guide.pdf) provides a concrete document/result-messaging integration reference. It does not provide DCM access or establish the PAS appointment/billing contract.

### Download investigation and local execution

The request now prioritises a downloadable evaluation that can run beside the local OpenEyes instance. An EXE or MSI is acceptable; obtain a complete installation package, evaluation activation and demo-database setup together.

| Check performed on 2026-09-17 | Result |
|---|---|
| Technical help articles and public attachments | No installer attachment found in the installation, update, migration and related setup articles checked. The Installation article has an informative screenshot even though its text is empty. |
| Update-server address in the [Installation screenshot](https://support.directcontrol.com.au/hc/en-au/articles/9148635563023-Installation) | The documented HTTP release address returned 404. HTTPS on that hostname failed certificate-name validation. |
| Canonical storage address identified by public DNS | HTTPS was valid, but the release listing and a small set of installer/manifest candidates returned 404. This did not produce a download. These responses do not prove that all vendor packages are unavailable. |
| [Changing Server guide](https://support.directcontrol.com.au/hc/en-au/articles/7765290403343-Changing-Server) | Identifies a legacy setup.exe inside the installed customer's shared server-files directory. That is a local distribution path, not a public demo download. |
| [January 2026 release notes](https://support.directcontrol.com.au/hc/en-au/articles/14506978056335-January-Version-26-0-0-0) | Specify .NET Framework 4.8 and MSI deployment. The general specifications still list 4.7.2; use the requirements for the actual installer supplied. |

The initial checks downloaded documentation screenshots. Subsequent archive research recovered an EXE and identified it by static inspection as a Flash product presentation. No PAS installer, trial licence or DCM sample database has been obtained. Exact checks and results are retained privately in the research records below.

#### Installer filename clues

The confirmed legacy client path is `\\DirectCONTROLServerFiles\DirectCONTROLapp\setup.exe`, published in the [Changing Server guide](https://support.directcontrol.com.au/hc/en-au/articles/7765290403343-Changing-Server). This is an existing installation's server share. The January 2026 notes introduce MSI deployment but do not publish the MSI basename. Search patterns such as `*DirectControl*.msi` and `*DCM*.msi` are clues only.

`DirectCONTROLAddin\setup.exe` is the separate Outlook add-in; `Why Direct CONTROL.exe` is a marketing presentation. Neither supplies the PAS. A final search using the exact client-directory and setup-window names found no authentic package. One archive lookup returned HTTP 503 and remains inconclusive.

A local installer is optional if the vendor issues hosted access with the required billing and integration facilities. Actual DCM access is required to verify DCM workflows and compatibility; the OpenEyes demonstration and simulated PAS messages can proceed independently. A supplied installer may also need companion server files, prerequisites, activation and an empty or synthetic database.

#### Local execution approach after obtaining the package

| Approach | Assessment |
|---|---|
| Windows desktop VM managed through Docker | Preferred compatibility experiment for DCM's desktop, .NET Framework, SQL components and file shares. [Dockur Windows](https://github.com/dockur/windows) provides this model with browser display and persistent storage. This is a full Windows guest managed by a container. |
| Software-emulated Windows VM | [QEMU TCG](https://www.qemu.org/docs/master/system/introduction.html) can emulate a machine without hardware acceleration. Consider a bounded containerised boot/install trial if KVM remains unavailable; performance for this DCM workload is unverified. |
| Wine inside a Linux desktop container | Possible compatibility experiment for a supplied Windows installer, with no host installation. DCM's .NET/SQL/Office dependencies make success uncertain. Limit the initial check to installer, login and a basic database operation; do not assume successful installation proves the demo workflows. |
| Native Windows container | Microsoft documents that applications requiring an interactive desktop are [not supported in Windows containers](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/lift-shift-to-containers). A silent MSI install alone does not solve the desktop requirement. |
| Supplier-hosted desktop | Retain as a fallback if a local package or usable local runtime cannot be provided. It still allows the DCM workflow to be assessed while the OpenEyes instance stays local. |

The current host is Linux x86_64 and has no `/dev/kvm` device. The read-only check found about 12 GiB available memory and 1.4 TiB free disk; these are a new snapshot, not reserved capacity. The vendor's [general workstation specifications](https://www.directcontrol.com.au/specifications) list 16 GB RAM, so the full workload also needs a fresh capacity check. Do not claim the normal KVM-based route is ready on this host or change host/cloud configuration as part of this plan.

1. Download only the supplied/public vendor package and its companion files, retaining the source, version, SHA-256 and publisher-signature check. Store packages, licences and issued URLs outside this task repository.
2. Identify the actual prerequisites, installer type, activation and database-bootstrap procedure before choosing the runtime. Keep DCM's release version distinct from OpenEyes `release/26.1.x`.
3. Use the chosen existing container/VM project's documented configuration with dedicated storage and local-only access. Keep Windows/SQL evaluation terms and DCM activation valid; do not bake licences into images.
4. Prove login, patient/appointment creation, a quotation or invoice and restart persistence using synthetic data. Then test the required OpenEyes interface. Record a compatibility failure as such and use the hosted fallback if local execution cannot support the scenarios.

### Initial access request to use

The user authorised submission on 2026-09-17 and completed the vendor's human verification. The hospital trial form accepted the request with HTTP 200 and displayed "Log on details to explore DCM will be sent shortly." The submission receipt, contact details and exact request are stored privately outside this repository. No DCM licence acceptance or trial login has occurred.

**Recipient:** support@directcontrol.com.au, or the enquiry box on the ophthalmology trial form.

**Subject:** DCM downloadable evaluation package for a local OpenEyes demonstration

> We are preparing an ophthalmology and day-surgery demonstration with OpenEyes release/26.1.x and synthetic sample data. We would like a downloadable DCM evaluation that we can run locally alongside it.
>
> Could you provide the current full EXE/MSI installer with any companion files and prerequisites, an evaluation licence or activation instructions, and either a synthetic sample database or instructions to initialise an empty demonstration database? Please include any required server-files bundle and configuration instructions.
>
> We can provide an isolated Windows desktop environment managed through Docker/virtualisation. Please confirm the supported Windows/SQL versions, current .NET requirement, permitted local evaluation setup, trial duration and any cost. A signed download link would be ideal.
>
> We can start with standard sample data and available modules; OpenEyes interfaces can follow later. If you cannot provide a download, could you issue hosted desktop trial access or arrange the advertised free product demonstration?

**Integration follow-up after access:** request specialist and hospital modules; two named demo users; a resettable synthetic dataset; test-only claiming; OpenEyes version compatibility; patient/merge, appointment/arrival, referral/document, booking and completed-service interface specifications; example messages; message logs; and permitted external connections/automation. Distinguish existing supported functions from additional work.

### Next actions and completion boundary

1. Continue looking for a complete downloadable evaluation package through public vendor, partner and archive routes while awaiting the accepted trial request. Keep interface requirements separate from the initial installer/licence/database request.
2. If the vendor does not reply, follow up through its published telephone contact and request the advertised free demonstration. Use the documented partner routes for an introduction if needed.
3. On receipt, keep credentials, issued access URLs and connection details outside this repository in a machine-local private directory. Record expiry, permitted use, available modules and reset arrangements.
4. Use even a basic UI trial to rehearse DCM workflow and compare it with the supplied scenarios. Keep the sample-message integration fallback until a supported interface connection is available.
5. Obtain and test the existing OpenEyes connector and remaining interfaces separately. Mark unsupported or unavailable functions as pending in the acceptance evidence.

**Status:** the vendor has accepted the trial request. Public research covered 139 help articles and 435 image attachments across 71 relevant articles. Further checks covered archived vendor pages, 37 embedded presentation payloads, Common Crawl, the vendor's public site search and software catalogues. The combined index records 249 source URLs; failed archive requests are recorded separately from successful negative checks. The old Downloads page supplied brochures. Identity-confirmed MYOB and SourceForge listings link to the vendor without supplying a package.

An archived vendor EXE was downloaded and identified by static inspection as a Flash product presentation. No usable PAS installer, demo database or evaluation licence has been obtained. The next concrete dependency is an issued installer with evaluation activation/database setup, or hosted credentials. The user will report further email. Local DCM execution and live integration remain untested.

Detailed private evidence: `/home/toukan/.claude/dcm-evaluation/research/execution-research-20260917.json`, `continuation-research-20260917.json` and `final-catalogue-pass-20260917.json`. Public referral evidence: [MYOB marketplace](https://www.myob.com/nz/apps/direct-control), [SourceForge product listing](https://sourceforge.net/software/product/Direct-CONTROL/).


## 7. Interim OpenMRS billing and documented data flow

User amendment, 2026-09-17: consider the previous OpenMRS implementation while DCM access remains unavailable. Proceed only if switching to DCM would require limited rework and similar messages can be reused. Pause OpenMRS-specific billing work until that portability check passes. Continue the DCM acquisition work in parallel. OpenMRS does not close DCM-specific acceptance checks.

The read-only local assessment found the existing oe-deploy application-registration implementation and the earlier OpenMRS templates. The cached OpenMRS O3 backend already contains its native billing module, and its paired frontend contains invoice, payment and receipt screens. The official Billing 2.4.0 module has also been downloaded and verified. These are inspected capabilities; the new isolated runtime and billing workflows still need verification. See the [private capability assessment](/home/toukan/oe-openmrs-billing-assessment.md).

| Scenario | Interim treatment |
| --- | --- |
| Bill, service lines, partial/full payment and receipt | Rehearse through native OpenMRS billing screens and supported REST resources. |
| Refund and discount | Verify backend permissions and native workflow; the cached frontend lacks the dedicated refund screen, so test a compatible published frontend update if required. |
| Quote and financial consent | No distinct quotation/acceptance lifecycle was established. A pending bill must not be described as a completed quote workflow. |
| Provider and hospital allocation | Preserve clinical provider and service context; verify explicit financial ownership. A cashier or cash point is not a billing practitioner. |
| Weekly financial report | Reconcile bills, payments, refunds and corrections against persisted financial records, with dates and transaction classes explicit. Ready-made requested reports remain unverified. |
| Medicare, ECLIPSE, fund contracts and remittance | Pending the intended Australian finance system and its supported integrations. OpenMRS currency or payment-mode configuration does not demonstrate claiming. |

1. Compare the shared patient, visit and clinical-service message fields against OpenMRS resources and published DCM interfaces. Proceed only with a bounded connector that reuses the clinical workflow and common message contract. Record unverified DCM fields and stop if a separate billing engine, substantial workflow fork or large destination-specific implementation would be required. After this gate passes, use the existing oe-deploy application-registration branch and OpenMRS templates, isolated storage, pinned images and unused local ports.
2. Reuse the distribution's Initializer CSV/XML domains for service, price, cash-point and payment-mode metadata. Verify the installed Initializer version supports each selected domain. Capture the clean billing checkpoint before transactional examples.
3. Prove one patient, one invoice, partial payment, balance settlement and receipt through the frontend. Record each exact manual recipe, its API/script counterpart and resulting identities. Extend only after those controls pass.
4. Recover the prior FHIR2/appointment polling and PAS IN mapping before claiming that OpenMRS patient administration is connected. If the old poller source cannot be recovered, first assess whether a small explicit bridge using the current fixture runner is sufficient; do not build a new polling framework for the interim system. Preserve external patient, visit and OpenEyes encounter references; use the existing BridgeLink secret and channel patterns.
5. Connect explicitly reviewed clinical services to supported OpenMRS billing resources. Define the charge mapping and duplicate-delivery rule before creating bills. Test correction, cancellation and refund separately; an amended clinical note must not silently create another charge or reverse a paid bill.
6. Retain DCM as the intended target. Reuse the same acceptance scenarios once hosted access or a licensed evaluation package arrives. Do not submit claims or connect a live payment service during this rehearsal.

### Portability decision: hold OpenMRS billing

The read-only comparison did not establish that an OpenMRS billing demonstration would transfer to DCM with limited rework. Patient and visit identity fields fit the shared message model, but billing needs OpenMRS-specific cash-point, cashier, billable-service, price and transaction references. Its payment/refund workflow is destination-specific. The HealthLink DCM integration guide shows ADT/DFT controls, including invoice/visit identifiers and item, fee, provider and date mapping. This supports a possible common financial-message direction, but the complete supported profile, duplicate-charge behavior and reversal rules are not established by those controls. The current evidence does not yet demonstrate that the destination change would be small.

OpenMRS billing is therefore on hold under the user's condition. Only a fresh checkout and existing templates were prepared; no OpenMRS runtime, database, volumes, network or secrets were created. The downloaded official module remains available privately. Continue the current neutral clinical-service envelope and BridgeLink review receiver, which preserve reusable source fields and replay/correction tests without committing to an interim financial workflow. Reconsider OpenMRS only when a concrete interface comparison demonstrates a small destination-connector change.

### Data-flow documentation and current verification boundary

The [private data-flow document](/home/toukan/oe-dcm-demo-data-flow.md) records the live channel names and identifiers, system ownership, endpoints, authentication roles, transformations, source triggers, application acknowledgements, replay/correction rules, error review and evidence locations. It includes the proposed OpenMRS branch and distinguishes it from the working fixture flow.

| Direction | Current evidence |
| --- | --- |
| Synthetic PAS -> BridgeLink -> OpenEyes PASAPI | Patient registration/update, appointments, arrival, cancellation and merge exercised. |
| OpenEyes -> explicit export -> BridgeLink -> local review receiver | Saved clinical context, durable encounter/sub-provider references, duplicate delivery and revisions exercised. This creates review items, not invoices. |
| Appointment cancellation after a clinical save | Saved event and encounter survive; removed appointment links become null and the copied PAS visit reference remains. |
| OpenMRS -> BridgeLink -> OpenEyes | Previous implementation identified; fresh deployment held by the portability gate. |
| OpenEyes -> BridgeLink -> OpenMRS billing | Held by the portability gate; no billing connector has been deployed. |
| DCM connection | Pending trial access and supported interface contract. |

The outgoing trigger is currently an explicit export command, not every clinical save. BridgeLink transports and transforms messages; the financial application owns bills, payments and refunds. A message identifier proves engine acceptance only. Application response and persisted state establish success. The demo channels use explicit replays, with automatic destination queueing and retries disabled; production scheduling, retention and retry policy require a separate agreement.

### Clinical-data correction and reproduction contract

The review found that historical-date prescription controls conflicted with current episode and genuine signature/item-start dates. The generated clinical prescriptions now use current-clinic drafts; all three existing signed examples were corrected through native amendment and genuine re-signing. Preserve the old audit trail and mark its prior evidence superseded. Exact 20-year boundary checks belong in isolated query tests. Supplied legacy finalized prescriptions remain labelled legacy data and do not acquire invented electronic signatures.

Document each imported data unit beside its human workflow: demographics, service/episode selection, assessment date, History, IOP values and exact reading times, diagnosis state/observation date, prescription draft, genuine signing and PDF verification. Creation/audit timestamps can differ; clinical values and relationships must match the declared recipe. Full cataract surgery and follow-up now have verified repeatable script coverage beside their native frontend recipes; preserve the documented difference between imported historical records and genuine native signatures.


### Current execution evidence

The corrected initial clinical pack passed clean regeneration, identical full-row reruns, count increase/reduction, unsigned leap-day rebase/restore and chronology refusals. Signed reruns at the same anchor preserve clinical content, signatures and checked audit/version rows. The final research export repeats with identical dataset hashes. The daily research pull reconciles four cases and produces no further changes on the second run.

Both running application images now contain the reviewed encounter and research changes, with matching source-file hashes. Native View, Edit and PDF evidence covers all four encounter Sub-provider options. Authenticated Swagger and OpenAPI are available in the private demo build. Prepared OpenEyes database and actual protected-file snapshots are retained outside this repository.

The completed cataract pack contains consultation, booking, manual biometry, linked manual OCT, surgery assessment, Operation Note, day-one and 30-day review. Its final eight-event SQL/shell version passed isolated full-database reruns, count/capacity tests, late-collision rollback, past leap-day rebase/restoration and lookup-ID remapping. All eight events passed native View, Edit without Save and PDF comparisons, subject to the documented stock OCT assessment-table print omission. The relevant patient-summary caches use maintained application SQL only for actual imports or date changes; visible cache refresh and the post-browser full-pack unchanged rerun passed. The main count-one historical journey import also passed: all pre-existing rows were preserved and an identical rerun left every database row unchanged, including retained health-check sessions. Runtime source hashes match the frozen review package. Preserve actual entry provenance and disclose the unavailable historical offer date. Varied named-patient expansion follows the clinical acceptance gate; parked external financial scenarios no longer block it.

An unmodified FDA retinal phantom OCT image is ingested and byte-verified through native attachments. Its source, reuse terms, hash, human upload steps and repeatable browser helper are documented. Clean creation, unchanged repeat and changed-metadata refusal passed on the separate rehearsal target. The main first Save exposed a stock description limit mismatch and required a recorded recovery of the existing attachment; the corrected description and same-attachment Save then passed. The phantom does not supply the separate manually entered clinical measurements, and PNG upload does not establish device or DICOM ingestion. Optional image attachment follows final clinical generation/date adjustment and has its own replay and checkpoint boundary because native Save normalizes some stored fields.

For a complete cataract PAS rehearsal, import registration, appointment and arrival before creating native clinical events. The inspected PASAPI identifies appointments by their PAS assignment and external visit ID; it cannot adopt an existing walk-in appointment by matching patient and date. Keep the established reference intact and use the recorded clean order rather than creating a duplicate visit.
