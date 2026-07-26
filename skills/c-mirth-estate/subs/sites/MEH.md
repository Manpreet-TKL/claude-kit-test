# MEH

Channels: 6.  BridgeLink 4.5.2.  PASAPI V2, merge V1.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number **`PID-2.1` where `PID-2.5 = PAS`**;
merge `MRG-1.5 = PAS`.

## Deltas from the general rules

- **The only site with AIS integration** - two dedicated channels and a sixth destination on
  the PAS inbound channel. `PASAPI/V2/AISFlags/{patientId}` exists nowhere else.
- The AIS path is gated on `PID-35.1 exists` - no risk segment, no flags call.
- Hospital number comes from **PID-2** (with Bedford and Newmedica), not PID-3.
- Carries the **location gate** (with Bedford): `PV1-3.2 != "checkin"` and `PV1-3.2 != ""`.
- Appointment Filter adds **`A04`** to the common event set - registrations create clinic
  entries here and nowhere else.
- Handles `A60` in addition to the common set, and `AIS OUT` has a `Send A60` destination.
- `OpenEyes PAS Query v2` carries the `QPD-3 != ""` empty-query guard.
- Two HTTP listeners: :6663 for the PAS query, :6664 for AIS.
- On `OpenEyes PAS Query v2` the `Respond` destination carries the `$('d1').getStatus()`
  **not** SENT form, so it answers only when `Send Q21` failed.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `OpenEyes PAS v2` | PAS Inbound | MLLP :6661. Six destinations - the quintet plus `AIS`. |
| `OpenEyes PAS Query v2` | PAS Outbound | HTTP :6663. Query guard. |
| `AIS OUT` | AIS | HTTP :6664. Destinations `Get Flags` and `Send A60`. |
| `AIS Sender` | AIS | Channel Reader, MLLP out to the AIS endpoint. |
| `DICOM` | DICOM Ingestion | :11112. No `getDicomHeaders` destination. |
| `Docman` | Document Outbound | File Reader to a share. Shares its id with ENHT, Optegra and Portsmouth. |
