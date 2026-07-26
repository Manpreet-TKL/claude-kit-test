# Newmedica

Channels: **35** - a third of the estate.  BridgeLink 4.5.2.  PASAPI **V1 migrating to V3**.
HL7 2.4.
Identifiers: NHS number **`PID-3.5 = NH`** (not `NHS`); hospital number `PID-2.1` where
`PID-2.5 = PAS`; merge `MRG-1.5 = PAS`.

## Deltas from the general rules

- **Two-hop routing.** `OpenEyes PAS In` on :8558 is the only MLLP listener; it fans out to
  **28 `PAS In LOCAL-*` clones** with Channel Reader sources, one per practice. A message
  crosses two channels before reaching PASAPI, and a drop can be in either. The 28 clone
  script bodies are byte-identical - the per-practice delta is entirely in connector fields
  (practice code and name, identifier type, destination id, a per-practice
  respond-after-processing toggle, and a cosmetic colour).
- **PASAPI V3** on the clones - `Patient`, `PatientAppointment`, `PatientMerge`,
  `DidNotAttend` - while the front channel still uses V1. The only site on V3.
- The V1 identifier type is a **per-practice value**, not the estate's `LOCAL-1-0`.
- **The NHS assigning-authority code is `NH`, not `NHS`.** An NHS number arriving under `NHS`
  is not picked up here.
- Appointment Filter has **`A08` commented out** and the whole cancel branch commented out:
  appointment *updates* never reach the clinic list, and nothing is ever removed by that
  route. This is the single largest behavioural departure in the estate.
- Carries the `OBX-3.1` / `ReportFile` split (90 + 60 rule instances), the
  `BookingType contains "Cataract"` route, `PV1-19.1 != ''`, and the `QPD-3` query guard.
- Extra destinations on the PAS path: `PASAPI - Patient Referral`, `OBX document`,
  `Clinic List - DNA`, and a `Nothing to do` absorber. Nine destinations in total.
- **The only site reading `SCH` and `OBX` segments**, and the only one handling `S26`.
- Off-convention ports throughout: MLLP :8558 and :8559, DICOM :11114.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `OpenEyes PAS In` | PAS Inbound | MLLP :8558. The fan-out front door. V1 endpoints. |
| `PAS In LOCAL-*` x28 | PAS Inbound | Channel Reader clones, one per practice. V3 endpoints. Template family `pas-inbound-newmedica-local`. |
| `OpenEyes Document In` | Document Ingestion | MLLP :8559. Full PAS destination set plus `OBX document`. |
| `OpenEyes PAS Out` | PAS Outbound | HTTP :6663. Query guard. |
| `DICOM` | DICOM Ingestion | :11114, with `getDicomHeaders`. |
| `Docman` | Document Outbound | File Reader to a share. |
| `Generic Document processor` | PayloadProcessor | Channel Reader to the queue-add API. |
| `Generic Document processor OLD` | PayloadProcessor | Superseded; check enabled state before assuming it is dead. |
