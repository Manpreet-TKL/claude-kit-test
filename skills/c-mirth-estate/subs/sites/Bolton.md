# Bolton

Channels: 4.  BridgeLink **4.6.1** - the only site on 4.6.  PASAPI V2, merge V1.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number `PID-3.5 = FACIL`;
merge `MRG-1.5 = FACIL`.

## Deltas from the general rules

- **The Appointment Filter is materially narrower than anywhere else.** It opens with
  `if ($('d1').getStatus() != Status.SENT) return false`, then accepts only
  `A01 / A05 / A08 / A11`, then drops clinic `ECAS` outright, then drops clinic `H2` unless
  the event is A05. A02, A03, A12 and A13 never reach the clinic list at Bolton. This is the
  first thing to check for "the appointment did not update here".
- Only site besides Newmedica with a **`Clinic List - DNA`** destination:
  `MSH-9.2 == A05 && PV1-14.1 == "DNA"` posts to `PASAPI/V2/DidNotAttend`.
- Carries the `OBX-3.1` / `ReportFile` content split and the
  `channelMap BookingType contains "Cataract"` route (both otherwise Newmedica-only).
- Six destinations on PAS IN - the quintet plus DNA. No absorber destination.
- Smallest estate footprint alongside ENHT: no document ingestion, no PayloadProcessor
  channel, no second inbound feed.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN` | PAS Inbound | MLLP :6661. Shares its channel id with ENHT and Wales PAS inbound. |
| `PAS OUT` | PAS Outbound | HTTP :6663. The `06f0b8b8` family. |
| `DICOM` | DICOM Ingestion | :11112, with `getDicomHeaders`. |
| `CORRESPONDENCE OUT` | Document Outbound | File Reader to a file share. Shares its id with EK `Filedrop Correspondence`. |
