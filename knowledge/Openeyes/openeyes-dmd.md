# OpenEyes dm+d findings

## Purpose and evidence boundary

This note records what the NHS dictionary of medicines and devices (dm+d) is,
how OpenEyes uses it, when the current integration was introduced, which Change
Requests (CRs) concern it, and what related improvements are worth considering.

The OpenEyes source findings were checked on 2026-08-31 against commit
`ad2324084788608246a8250e817198c2f26a4fd6` (`master`, version 26.0.9). The
documentation finding was checked against OeDocumentation commit
`9d6f524ac2`. The CR findings came from the read-only local export at
`/home/toukan/jira-corpus/cr-change-requests`.

This is a code and document review, not an audit of a particular deployment.
OpenEyes does not record the source dm+d release in its medication tables, so a
deployment's actual catalogue age cannot be established from the repository or
database schema alone. It must be compared with a named NHS release.

## What dm+d is

The dictionary of medicines and devices is the NHS standard dictionary for
identifying medicines and medical devices used in UK health care. It provides
stable identifiers, descriptions, relationships and selected attributes so that
systems can exchange medication information without depending on free text or a
supplier-specific product list.

The current NHS service describes seven concept classes:

| Class | Meaning | Example role |
| --- | --- | --- |
| VTM | Virtual Therapeutic Moiety | The abstract active substance or substance combination |
| VMP | Virtual Medicinal Product | A generic medicine with strength and form |
| VMPP | Virtual Medicinal Product Pack | A generic pack presentation |
| AMP | Actual Medicinal Product | A supplier-specific medicinal product |
| AMPP | Actual Medicinal Product Pack | A supplier-specific pack presentation |
| TF | Trade Family | A group of related branded products |
| TFG | Trade Family Group | A broader grouping of trade families |

The NHS recommends its Terminology Server for consumers that need a terminology
service. The complete raw release remains available as XML through the
Terminology Reference-data Update Distribution service (TRUD). The dm+d TRUD
item is currently released weekly on Monday. NHS guidance says general clinical
systems should update at least every six months, while Electronic Prescription
Service systems must use data no more than two months old. Those are external
minimums, not a recommendation to wait that long.

As a dated observation, the item 24 release page showed version 8.3.0 dated
2026-08-24 and a next scheduled release date of 2026-08-31 when checked on
2026-08-31. These values are deliberately not described as the permanent latest
release; the live item 24 page is the authority at update time.

### The supplied NHSBSA link

The link supplied with this task is valid and is on the authoritative NHS
Business Services Authority site:

<https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/nhs-dictionary-medicines-and-devices-dmd/dmd-pharmaceutical-suppliers-and-manufacturers>

Its purpose is guidance for pharmaceutical suppliers and manufacturers that
need to maintain their product portfolios in dm+d. It is useful background for
how national product records are maintained, but it is not the download feed an
OpenEyes updater should consume. OpenEyes should use the NHS Terminology Server
or the official dm+d release distributed through TRUD.

## How OpenEyes uses dm+d

OpenEyes stores national and locally maintained medicines in one `medication`
table. `source_type` distinguishes `DM+D` from `LOCAL`. The unique key on
`preferred_code` and `source_type` makes the dm+d concept code the natural
national identity within that table.

The current OpenEyes importer covers only VTM, VMP and AMP. It does not import
VMPP, AMPP, Trade Family or Trade Family Group, so OpenEyes is not a complete
mirror of the national dictionary.

| dm+d class | Imported by current OpenEyes process | Current use |
| --- | --- | --- |
| VTM | Yes | Abstract ingredient or moiety level medication |
| VMP | Yes | Generic medicinal product level medication |
| AMP | Yes | Actual supplier product level medication |
| VMPP | No | Not represented by the importer |
| AMPP | No | Not represented by the importer |
| TF | No | Not represented by the importer |
| TFG | No | Not represented by the importer |

All three imported levels may be prescribed. Medication sets and their rules
control the choices made available in clinical workflows. Administrators can
also set aliases, short terms and default attributes such as route, form and dose
unit.

The medication identifier is used by clinical and configuration data, including
prescriptions, medication use, medication sets, allergy assignments and PGD/PSD
configuration. The PGD/PSD report labels `preferred_code` as the `DM+D Code`.
This means stable `medication.id` values and stable national codes are important:
an update must change a current record in place rather than delete it and insert
a replacement.

The main current implementation is:

- `protected/scripts/dmd-import.sh`
- `protected/commands/ImportDrugsCommand.php`
- `protected/migrations/data/dmd_import/*.sql`
- `protected/data/dmd_data/Drug-Type-Mappings.xlsx`

The script reads an extracted NHS release from `DMD_EXTRACT_FOLDER`, or from
`protected/data/dmd_data` by default. The command reads XML and XSD files into
temporary `f_*` tables. SQL scripts then rebuild the OpenEyes medication data,
bind imported medications and repopulate automatic sets. The script also takes
prescription snapshots before and after the operation.

The repository contains the mapping workbook but not a national dm+d XML
release. It also contains no manifest, release number, release date or checksum
for the catalogue last loaded into a deployment.

### Current admin behaviour

The OpenEyes documentation describes an Add action that creates a `DM+D` record
with subtype `UNMAPPED` and a generated `UNMAPPED<n>` code. It does not validate
that record against NHS dm+d. Delete is permanent in the current admin workflow.
These records are therefore a local stopgap and should not be presented as
verified national concepts.

The stock documentation snapshot contains 127,441 `DM+D` rows:

| Subtype | Rows in the documented stock snapshot |
| --- | ---: |
| VTM | 2,867 |
| VMP | 21,164 |
| AMP | 103,410 |
| Total | 127,441 |

These counts describe that stock database snapshot. They do not establish that
the catalogue matches the current national release.

### Limitations and update risks in the existing importer

The current command reads each complete XML file into memory, converts the full
tree, constructs SQL values manually, and inserts batches of 100 rows. It sets
the PHP memory limit to unlimited. That approach is more memory-intensive and
slower than a streaming parser followed by a database bulk load.

The existing SQL has several behaviours that are unsafe for a routine live
refresh:

- `delete.sql` removes dm+d medication rows and associated set memberships,
  automatic rules, event medication-use records, medication attributes,
  assignments, forms and routes.
- The copy process deletes and rebuilds medication attributes globally.
- AMP copy logic strips the supplier name, groups by preferred term and uses
  `INSERT IGNORE`. Different AMP codes can therefore be collapsed when their
  text matches.
- Imported VMP data can overwrite AMP default route, form and dose-unit choices.
- The process has no source release ledger, checksum, prepared change report,
  approval gate, staleness alert or deterministic cache invalidation.
- It does not import the national historical-code file, so it has no explicit
  model for retired or replaced codes.

OpenEyes already has `deleted_date` and `is_prescribable` behaviour, and normal
pickers exclude deleted records. A safe updater can use soft retirement instead
of hard deletion while retaining historical references.

Medication display data is cached by medication ID, type, firm and site for
1,000 seconds in `protected/widgets/MedicationInfoBox.php`. An update needs a
defined cache-invalidation step rather than relying on expiry.

## When dm+d was introduced in OpenEyes

There are two different dates because the original support and the present
importer are separate generations.

| Date | Commit | Finding |
| --- | --- | --- |
| 2014-08-05 | `bc2bd18a90fd2ab56c33a99f0ffd1a9ecf8c55b6` | Introduced legacy dm+d support |
| 2018-06-19 | `241c91951c67ab06a8b03c3116732ef293045c63` | Introduced the current medication importer files |
| 2018-09-14 | `a8e0c656796b6efcbcb3655b56a2f48fd3754975` | Added the import scripts used by the current pipeline |
| 2019 to 2020 | Several commits | Most functional development of the current importer |
| 2020-07-09 | `d32f0c7296bdb69f78d4b8915603b9ec75f659ae` | Added `DMD_EXTRACT_FOLDER` support |
| 2021-01-14 | `84af26c0548f3ae9a98ebd855381f03fef2fb24a` | Version 4.0 tag; current importer is present |
| 2021-06-03 | `0a1fba1927a1c950d31ae7416e5d07a291dd3cd7` | Last content change found for the mapping workbook |
| 2024 | Compatibility-only changes | PHP 8.1 and static-analysis changes, not a redesign of the import process |

The current import files are absent from version 3.6.2 and present in version
4.0. It is therefore fair to say that the current mechanism dates from the
version 4 generation and has not been meaningfully updated since then. More
precisely, its core behaviour was written in 2018 to 2020, which is more than six
years old at the time of this review. The literal version 4.0 tag is less than
six years old on 2026-08-31.

## Change Request findings

The local CR export was searched for direct references to dm+d, medications,
drug dictionaries, terminology, HSCIC, NHS reference data and adjacent import
work. Statuses below are the statuses present in that export on 2026-08-31.

### Primary and directly related CRs

| CR | Status | Relevance |
| --- | --- | --- |
| CR-379, Backend Update Mechanism for DM+D from NHS source | Expired | The closest direct requirement. It asks for a backend command or script that obtains the NHS source, validates and de-duplicates it, records timestamps and logs, and can be triggered during upgrades or by a service request. A comment suggests a weekly job like the HSCIC process, notes that a terminology service might supersede the design, and estimated five days for technical analysis. |
| CR-361, Allow new DM+D drugs via admin | In Development | Documents that a planned monthly synchronisation was never built. It provides the manual Add/Delete stopgap. Later discussion recommends secondary validation for future national or local medication changes as a clinical-safety control. Implementation commit `655f7397acb8a007bee26dd6143bf6c3b9c1596f`, dated 2026-08-07, is on `develop`, not the reviewed `master`. |
| CR-443, Fix broken HSCIC/ODS import, NHS switched to CSV API | Development Estimation | A useful operational precedent: a scheduled national reference-data import silently stopped working after the upstream format changed. It supports explicit source-schema checks, run summaries, failure alerts and staleness monitoring for dm+d. |
| CR-459, Merge local drugs / link to DM+D | Development Estimation | Covers reconciliation between local records and national concepts. Matching can be suggested by an updater, but changing an existing local record's identity should remain a separately reviewed, manual operation. |

CR-379 should be reopened or replaced and used as the main implementation CR.
CR-361, CR-443 and CR-459 should be linked because they define the stopgap,
operational failure mode and local-record boundary respectively.

### Other direct keyword matches

| CR | Status | Relationship |
| --- | --- | --- |
| CR-279, Add admin screens for managing drug units and frequencies | Expired | Medication reference-data administration |
| CR-295, Widgetised Drug Administration | In Development | Consumer of medication catalogue data |
| CR-303, Medication Management v2 | Expired | Wider medication-management design |
| CR-308, Administerable Drug Set | Expired | Medication-set configuration |
| CR-349, Include BNF links to drugs in tooltips | Expired | External drug reference and display |
| CR-376, Mandatory prescribing in injection workflow | In Development | Prescribing workflow dependency |
| CR-59, automatic national Health board/Trust/site update | Expired | Precedent for scheduled national reference-data maintenance |
| CR-63, Welsh GP/practice source via DHCW | Expired | Precedent for a separate national source and deployment variation |

### Adjacent CRs reviewed

| CR | Status | Relationship |
| --- | --- | --- |
| CR-227, search heuristics | Needs Analysis | Medications were excluded from its initial work, but its search and alias concerns apply to renamed and newly imported medicines. |
| CR-353, SNOMED allergy codes | Not Approved | A TRUD terminology-import precedent and a reminder to separate medication and allergy coding scope. |
| CR-354, SNOMED risks/alerts | Completed | Chose a small maintained list rather than a terminology service; useful contrast because dm+d is too large and changes too often for that approach. |

No reviewed CR provides a complete, current implementation specification. The
required behaviour has to be assembled from CR-379 plus the clinical-safety
concern in CR-361 and the operational lessons in CR-443 and CR-459.

## CSV and efficient loading

The canonical TRUD dm+d release is XML. The NHS also publishes a Windows and
Excel based XML transformation tool that can convert a downloaded dm+d release
to Excel and CSV. That confirms a CSV representation is valid, but the tool is
not a suitable production dependency for a containerised OpenEyes update path:
it requires Windows, a `C:` drive, Excel and a macro-enabled workbook.
The release page showed transformation tool version 2.0.3 dated 2024-12-17 when
checked on 2026-08-31.

A better server-side design is to stream the official XML and write a controlled
UTF-8 tab-separated staging file. MariaDB can load that file with `LOAD DATA
LOCAL INFILE`, which is intended for high-volume ingestion and avoids issuing an
insert for every record. Tab-separated output avoids much of the quoting
ambiguity found in general CSV files. A standards-compliant CSV report can still
be emitted for people to review.

One representative containerised OpenEyes database stack checked during this
review had `local_infile` enabled and no `secure_file_priv` restriction. This
only proves that bulk loading is feasible in that stack; every deployment must
check its own database and client configuration. PHP PDO's
`PDO::MYSQL_ATTR_LOCAL_INFILE` setting must be supplied when the dedicated
connection is constructed. Because MariaDB relaxes strict SQL modes for `LOCAL`,
the importer must validate row counts, rejected data, warnings, lengths and
types before it accepts a staging table. A bound multi-row insert fallback is
needed where local file loading is disabled.

Accepting an arbitrary third-party CSV should not be the first implementation
contract. It adds dialect, encoding, escaping, column-version and provenance
risks. The official signed or checksummed NHS XML should remain the source of
truth, with importer-generated TSV used only as an efficient internal transport.

## Additional improvements worth adding to OpenEyes

### Core update requirements

1. Record catalogue provenance: TRUD item, release version and date, archive
   checksum, preparation time, application time and result.
2. Publish a machine-readable health and staleness status. Alert on failed,
   unknown or overdue updates rather than allowing silent drift.
3. Distinguish verified NHS concepts from manual and legacy-unverified records.
   A generated `UNMAPPED` record must not claim national provenance.
4. Protect NHS-owned identity fields from routine manual editing.
5. Update in place by dm+d code and preserve `medication.id` references.
6. Soft-retire absent concepts and reactivate them if they return. Do not hard
   delete medication history or configuration.
7. Import the national historical-code mapping so old codes can still be
   resolved without rewriting historical clinical records.
8. Preserve local aliases, short terms, default attributes and medication-set
   choices unless an explicit, reviewed rule says otherwise.
9. Preserve every distinct AMP code and official supplier term. Do not
   de-duplicate different concepts solely because their display text matches.
10. Produce a referential-impact report covering prescriptions, event
    medication use, allergies, medication sets, PGD/PSD configuration, defaults
    and integrations before application.
11. Detect changed schemas, manifests, files and concept classes and fail closed
    until the importer is reviewed.
12. Invalidate affected medication caches after a successful application.
13. State the supported scope explicitly. VTM, VMP and AMP compatibility should
    not be described as full dm+d support.
14. Verify that reports and integrations use national codes for exchange and do
    not rely on deployment-specific internal medication IDs.

### Useful follow-on work

1. Audit whether device concepts or VMPP, AMPP, TF and TFG data are required by
   actual OpenEyes workflows before expanding the model.
2. Generate candidate matches between newly downloaded NHS concepts and local or
   `UNMAPPED` records. Any merge or re-pointing remains a manual CR-459 workflow.
3. Add a read-only administration status card showing the active release, last
   successful preparation and application, staleness and the latest report.
4. Use the NHS Terminology Server for point validation, manual-add searches and
   historical-code lookup where this improves the administrator workflow.
5. Record the second-person review and approval as part of the immutable update
   audit trail.

Unattended application, automatic local-record merging, live terminology-backed
prescribing pickers and a full update administration UI should remain outside
the first implementation unless separately approved.

## References

### NHS and technical references

- [NHS dm+d service overview](https://digital.nhs.uk/services/terminology-and-classifications/dm-d)
- [NHSBSA dm+d guidance for pharmaceutical suppliers and manufacturers](https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/nhs-dictionary-medicines-and-devices-dmd/dmd-pharmaceutical-suppliers-and-manufacturers)
- [TRUD dm+d release item 24](https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6/items/24/releases)
- [TRUD dm+d licence](https://isd.digital.nhs.uk/trud/user/guest/group/0/pack/1/subpack/24/licences)
- [TRUD API catalogue entry](https://digital.nhs.uk/developer/api-catalogue/technology-reference-update-distribution-api)
- [TRUD API guide](https://isd.digital.nhs.uk/trud/user/guest/group/0/api)
- [dm+d and SNOMED CT UK Drug Extension release cycles](https://digital.nhs.uk/services/terminology-and-classifications/uk-medicines-terminology-futures/changes-to-digital-terminologies/survey-dm-d-and-snomed-ct-uk-drug-extension-release-cycles)
- [NHS Terminology Server](https://digital.nhs.uk/services/terminology-server)
- [NHS Terminology Server FHIR API](https://digital.nhs.uk/developer/api-catalogue/terminology-server-fhir)
- [UK medicines terminology future changes](https://digital.nhs.uk/services/terminology-and-classifications/uk-medicines-terminology-futures/changes-to-digital-terminologies)
- [SCCI0052 dm+d standard](https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/scci0052-dictionary-of-medicines-and-devices-dm-d/)
- [DAPB4013 Medicine and Allergy/Intolerance Data Transfer specification](https://digital.nhs.uk/binaries/content/assets/website-assets/isce/dapb4013/401352021specification1.2.pdf)
- [NHS dm+d XML transformation tool releases](https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6/items/239/releases)
- [NHS dm+d XML transformation tool licence](https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6/items/239/licences)
- [MariaDB LOAD DATA INFILE reference](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/inserting-loading-data/load-data-into-tables-or-index/load-data-infile)
- [MariaDB bulk CSV and TSV import guide](https://mariadb.com/docs/server/data-operations/data-import/enterprise-server/load-data-local-infile/)
- [PHP PDO MySQL driver reference](https://www.php.net/manual/en/class.pdo-mysql.php)

### OpenEyes source references

- `protected/scripts/dmd-import.sh`
- `protected/commands/ImportDrugsCommand.php`
- `protected/migrations/data/dmd_import/`
- `protected/migrations/m180504_085420_medication_management_tables.php`
- `protected/widgets/MedicationInfoBox.php`
- `protected/modules/OphDrPGDPSD/models/OphDrPGDPSD_ReportDa.php`
- OeDocumentation: `docs/user-guides/configuring-openeyes/drugs/dmd-drugs.md`
