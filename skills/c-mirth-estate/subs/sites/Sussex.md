# Sussex

Channels: 5.  BridgeLink 4.4.2.  PASAPI V2, merge V1.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number `PID-3.5 = FACIL`;
merge `MRG-1.5 = FACIL`.

## Deltas from the general rules

- **Two PAS inbound channels running the same logic on different ports** - `PAS IN` on :6661
  and `PAS IN - Migration` on :6662. This is why Sussex shows double counts for
  `MSH-9.2 == A40` (4) and `MSH-9.2 != M05` (2) in estate-wide rule tallies; it is one
  behaviour, deployed twice. A message can legitimately be absent from one and present in the
  other.
- Extra destination `Nothing` (d6) on `PAS IN`, with **no filter** - it runs on every
  message. `PAS IN - Migration` has the plain five-destination quintet without it.
- One of two sites (with Portsmouth) carrying **all three `$('d1').getStatus()` forms**, all
  on `PAS OUT` where `d1` is `Send Q21`: `Convert K21 to XML` needs it SENT, `Create response`
  fires when it is blank, `Respond` when it is anything but SENT.
- Appointment Filter is the common form at both channels.
- Merge still goes to `PASAPI/V1/PatientMerge/{hospitalNumber}/identifier-type/LOCAL-1-0`
  while Patient and PatientAppointment are V2.
- No document ingestion and no PayloadProcessor channel.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN` | PAS Inbound | MLLP :6661. Six destinations - the quintet plus `Nothing`. Shares its id with Bedford, Optegra and Portsmouth. |
| `PAS IN - Migration` | PAS Inbound | MLLP :6662. Same logic, five destinations. |
| `PAS OUT` | PAS Outbound | HTTP :6663. The `06f0b8b8` family. |
| `DICOM` | DICOM Ingestion | :11112, with `getDicomHeaders`. Shares its id with Bedford, Bolton and Optegra `IOL`. |
| `Document Delivery` | Document Outbound | File Reader to **SFTP**. Shares its id with Bedford `Document OUT`. |
