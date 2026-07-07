# IOLMasterImport - formats, patient resolution, OpenEyes writes

## DICOM dispatch

`DICOMParser.parseDicomFile()` (lines 191-227) reads the SOP Class UID
(`00080016`), maps it via `DICOMTools.getDICOMType()` (map at
`DICOMTools.java:26-29`), then **overrides to IOLMaster 500** if device-model tag
`00081090` == `"IOLMaster 500"`. Laterality (L/R) is read generically from any
element whose tag ends in `08` (`DICOMCommonFunctions.getSideFromAttributes`).

| Device | Dispatch key | Parser | Status |
|---|---|---|---|
| **Zeiss IOLMaster 500** | SOP `1.2.840.10008.5.1.4.1.1.7.4` *or* model tag == `IOLMaster 500` | `DICOMIOLMaster500.java` | Full. Reads private group `771Bxxxx` SQ tags: measured K1/K2, axes, AL, ACD, SNR, and standard-formula IOL calculation sequences. |
| **Zeiss IOLMaster 700** | SOP `1.2.840.10008.5.1.4.1.1.104.1` (Encapsulated PDF) | `DICOMIOLMaster700.java` | Full. Uses private tags if present, else extracts from the **encapsulated PDF** (tag `00420011`) via PDFBox + regex (`PDFFunctions.java`); validates IOL/REF against in-house formula recompute. |
| **HFA visual fields** | same SOP as IOLM700 - **commented out** in `DICOMTools.java:28` | `DICOMHFAVF.java` | **Dead.** Hard-coded Windows paths; its UID collides with IOLM700 so it can never be selected. |
| **Kowa** | SOP `1.2.840.10008.5.1.4.1.1.77.1.5.1` | `DICOMKOWA.java` | Stub: prints "currently it is not supported". |

DICOM conformance statements for the IOLMaster 500 (7.1, 7.5) are committed under
`doc/` as a tag reference.

## Patient resolution

`DatabaseFunctions.searchPatient()` (lines 418-473):

- **With `HOSNUM_REGEX`** (and not `EXACT`): apply the regex to the DICOM hospital
  number; use capture group 2 if present else group 1; then
  `String.format(HOSNUM_PAD or "%07d", n)`.
- **`-r EXACT`**: exact match, padding off.
- **Default** (no regex): left-pad to 7 digits with zeros.
- Match is on `patient.gender` (only if M/F), `patient.dob`, and
  `patient_identifier.value` (lower-cased) where the identifier's
  `patient_identifier_type.unique_row_str == PATIENT_IDENTIFIER_TYPE` and the
  identifier is not deleted. 0 or >1 matches -> error, patient stays null -> exit 4
  (or FHIR fallback). The matched identifier's type supplies the new event's
  `institution_id`.

### Directory-name -> identifier-type

A watched sub-folder named `local-N-M` / `global-N-M` (case-insensitive) is mapped
by the watcher to a `patient_identifier_type.unique_row_string`; the queue
processor substitutes that string into the importer's `-t` argument by
regex-replacing the literal `local|global-\d+-\d+` token
(`queueProcessorClass.php:39`). This lets one watched folder route files to
different identifier types by subdirectory.

## OpenEyes tables

**Owned by PHP (queue infra):** `dicom_file_queue`, `dicom_process_status` (CREATE
in `cli_commands/file_watcher.sql`, though that file is stale - see gotchas), plus
`dicom_files`/`dicom_file_log` (CREATEd by the OpenEyes module migrations).

**Written by Java (Hibernate, annotation-mapped entities under `src/.../models/`):**

- `event` - new Biometry event (`event_type.name='Biometry'`); episode is
  intentionally left null (manual linking).
- `ophinbiometry_imported_events` - one per import, with dedup/merge keyed on
  device serial + acquisition datetime (700) or study/series/surgeon (500).
- `et_ophinbiometry_measurement` - bilateral K1/K2 + axes, axial length, SNR +
  SNR-min, ΔK, ACD, refraction, eye-status FK, modified flags.
- `et_ophinbiometry_selection` / `et_ophinbiometry_calculation` - zeroed
  selection + formula/target refractions.
- `et_ophinbiometry_iol_ref_values` - per lensxformula JSON of IOL/REF arrays,
  with merge of new values into existing rows.
- **Auto-created reference data if missing:** `ophinbiometry_lenstype_lens`
  (+ `_institution` mappings scoped by `-i`), `ophinbiometry_calculation_formula`,
  `ophinbiometry_surgeon`, `dicom_eye_status` (new ids from 1000), and a fallback
  `user`/`user_authentication` "Unknown IOLMaster" / "IOLMAutoUser".
- `dicom_import_log` - full audit row incl. `raw_importer_output` (the entire
  debug log), study/series/SOP, station, make/model/sw, status.
- **`_version` shadow tables** - every clinical save also raw-`INSERT`s into the
  `<table>_version` audit table (`DatabaseFunctions.addVersionTableData`),
  matching the OpenEyes audit pattern.
