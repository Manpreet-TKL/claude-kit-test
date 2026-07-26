# Portsmouth

Channels: 9.  BridgeLink 4.4.2.  PASAPI V2 throughout, **including merge**.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number **`PID-3.5 = PT`**;
merge `MRG-1.5 = PT`.

## Deltas from the general rules

- One of only three sites (with ENHT and Optegra) on **`PASAPI/V2/PatientMerge`**.
- **`PT` is the local assigning-authority code**, used nowhere else in the estate.
- **The document-ingestion site.** Four inbound document channels, three of which prepend a
  `Patient Search` (`/api/v1/patient/search`) destination before the queue-add call to
  resolve the patient. No other site does this, and it is the pattern worth lifting into a
  template as an optional first destination.
- One of two sites (with Sussex) carrying **all three `$('d1').getStatus()` forms**, all on
  `PAS OUT` where `d1` is `Send Q21`: `Convert K21 to XML` needs it SENT, `Create response`
  fires when it is blank (the query never ran), `Respond` when it is anything but SENT.
- Three `File Format` JavaScript rules across the document channels.
- Appointment Filter is the common form; the standard five-destination quintet on PAS IN.
- Two inbound MLLP ports: :6661 for PAS, :6662 for HL7-carried documents.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN V2` | PAS Inbound | MLLP :6661. Shares its id with Bedford, Optegra and Sussex. |
| `PAS OUT` | PAS Outbound | HTTP :6663. The `06f0b8b8` family. |
| `DICOM` | DICOM Ingestion | :11112. Shares its id with EK, ENHT, Kingston, Pennine and Wales. |
| `DOCUMENTS IN HL7` | Document Ingestion | MLLP :6662 -> `Send Document`. |
| `General Documents IN` | Document Ingestion | File Reader, `Patient Search` then queue-add. Shares its id with Bedford `Document Upload PP`. |
| `IOL Documents IN` | Document Ingestion | Same shape, biometry documents. |
| `Migration Documents IN` | Document Ingestion | Same shape, migration load. |
| `DOCUMENT-OUT-Drop` | Document Outbound | File Reader to a share. |
| `DOCUMENT-OUT-Minestrone` | Document Outbound | File Reader to a share. Shares its id with ENHT, MEH and Optegra `Docman`. |
