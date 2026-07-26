# EK

Channels: 7.  BridgeLink 4.5.2.  PASAPI V2.  HL7 **2.3** - the only site not on 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number `PID-3.5 = MR`. No merge.

## Deltas from the general rules

- **The only site that filters at the source.** Both PAS inbound channels carry two
  rule-builder rules on the source connector: `MSH-9.2 == A01 or A05 or A08` and
  `MSH-9.2 == A11 or A38`. Everything else is discarded before any destination runs, so a
  dropped message leaves nothing to inspect per destination.
- Consequently **no `Appointment Filter` script anywhere** - EK is the one site without it -
  and no `MSH-9.2 != M05` rule either.
- **No merge handling at all**: three destinations only (`PASAPI - Patient`,
  `Clinic List - PUT`, `Clinic List - DELETE`). An A40 is inert here, and it would be
  discarded at the source in any case.
- **Two trusts, two inbound feeds** - `PAS IN` on :6661 and `PAS IN Maidstone` on :6671, with
  identical logic and different upstreams. :6671 exists nowhere else.
- `PAS OUT` has a fourth destination, `Send Q21 test empi`, pointing at a second MPI. Only
  site with two query targets.
- Three separate correspondence-out channels rather than one.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN` | PAS Inbound | MLLP :6661. Source-filtered, three destinations. |
| `PAS IN Maidstone` | PAS Inbound | MLLP :6671. Identical logic, second trust. |
| `PAS OUT` | PAS Outbound | HTTP :6663. The `06f0b8b8` family, plus the test-MPI destination. |
| `DICOM` | DICOM Ingestion | :11112. Shares its id with ENHT, Kingston, Pennine, Portsmouth and Wales. |
| `Filedrop Correspondence` | Document Outbound | File Reader to a share. Shares its id with Bolton. |
| `MTW Correspondence` | Document Outbound | Second trust's correspondence. |
| `Synertec Correspondence` | Document Outbound | Third correspondence route. |
