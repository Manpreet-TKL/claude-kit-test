# Pennine

Channels: 6.  BridgeLink 4.4.2.  PASAPI **V1 only**.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number **`PID-3.5 = DN`** - unique to
Pennine. No merge.

## Deltas from the general rules

- **V1 for everything** - `PASAPI/V1/Patient/{hospitalNumber}/identifier-type/LOCAL-1-0` and
  `PASAPI/V1/PatientAppointment/{visitId}/identifier-type/LOCAL-1-0`. Only Pennine and Wales
  are still fully on V1.
- **`DN` is the local assigning-authority code.** No other site uses it, so a Pennine feed
  replayed against another site's channel loses its hospital number entirely.
- **No merge handling** - three destinations only.
- The **only** rule-builder filter on site is `MSH-9.2 != M05`. Everything else is the common
  Appointment Filter.
- **The primary PAS feed is on :6662**, not :6661.
- **Port collision:** `DICOM_11118` and `OpenEyes DICOM IOLMaster Channel` both configure
  :11118; `DICOM_11119` and `OpenEyes DICOM Channel` both configure :11119. Two listeners
  cannot bind the same port, so one of each pair is disabled in the running instance. The
  `DICOM_1111x` channels are the current AET-aware side; the `OpenEyes DICOM *` pair (shared
  by id with Kingston) is legacy. **Confirm enabled state before redeploying here.**
- All six of the estate's `inferred`-confidence corpus records are Pennine channels - the
  export was less complete than elsewhere, so treat Pennine detail as the least certain.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `OpenEyes PAS` | PAS Inbound | MLLP :6662. Three destinations, V1. Shares its id with Kingston. |
| `OpenEyes PAS Query` | PAS Outbound | HTTP :6663. The `06f0b8b8` family. |
| `DICOM_11118` | DICOM Ingestion | Current. Shares its id with EK, ENHT, Kingston, Portsmouth and Wales. |
| `DICOM_11119` | DICOM Ingestion | Current, second AET. |
| `OpenEyes DICOM Channel` | DICOM Ingestion | :11119, legacy. Shares its id with Kingston. |
| `OpenEyes DICOM IOLMaster Channel` | DICOM Ingestion | :11118, legacy. Shares its id with Kingston. |
