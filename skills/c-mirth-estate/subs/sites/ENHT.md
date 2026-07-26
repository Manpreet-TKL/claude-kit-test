# ENHT

Channels: 4.  BridgeLink 4.4.2.  PASAPI V2 throughout, **including merge**.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number `PID-3.5 = FACIL`;
merge `MRG-1.5 = FACIL`.

## Deltas from the general rules

Very few - ENHT is close to the estate baseline, which is itself a useful answer.

- One of only three sites (with Optegra and Portsmouth) on **`PASAPI/V2/PatientMerge`**.
  Bedford, Bolton, MEH and Sussex still call V1 for merge.
- The standard five-destination quintet, no site extras, no absorber.
- Appointment Filter is the common form, unmodified.
- On `PAS Out`, both `Convert K21 to XML` and `Create response` require
  `$('d1').getStatus() == Status.SENT`, so nothing is parsed unless `Send Q21` reached the
  PAS. There is no not-SENT fallback, so a failed query returns nothing at all.
- No document ingestion, no PayloadProcessor channel, no second inbound feed. Smallest
  footprint alongside Bolton.
- Trigger events handled span the full common set - A01, A02, A03, A04, A05, A08, A11, A12,
  A13, A38, A40.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS In` | PAS Inbound | MLLP :6661. Shares its channel id with Bolton and Wales PAS inbound. |
| `PAS Out` | PAS Outbound | HTTP :6663. `Send Q21` / `Convert K21 to XML` / `Create response` / `Respond`. |
| `DICOM` | DICOM Ingestion | :11112. Shares its id with EK, Kingston, Pennine, Portsmouth and Wales. No `getDicomHeaders` destination. |
| `Docman` | Document Outbound | File Reader to a share. Shares its id with MEH, Optegra and Portsmouth `DOCUMENT-OUT-Minestrone`. |
