# Optegra

Channels: 6.  BridgeLink 4.5.2.  PASAPI V2 throughout, **including merge**.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number `PID-3.5 = MR`;
merge `MRG-1.5 = MR`.

## Deltas from the general rules

- One of only three sites (with ENHT and Portsmouth) on **`PASAPI/V2/PatientMerge`**.
- **The create-vs-update jam.** `Document Migration` searches for an existing document, then
  branches on `JSON.parse(responseMap.get('Search').getMessage()).length` - `0` creates, `1`
  updates. **Two or more matches fire neither branch**: nothing happens and no error is
  raised. A duplicate therefore permanently blocks updates for that document.
- **Name is not function, twice.** `IOL` on :11112 is the biometry channel; `HFA2` on :11113
  is a visual-field feed. Neither name matches the estate's `DICOM` convention, and `IOL`
  holds the `getDicomHeaders` destination while `HFA2` does not.
- `Docman` has a `Nothing to do` absorber destination and a `File Format` JavaScript rule.
- **No HTTP listener at all** - no PAS-outbound channel. Optegra receives but does not query.
- `DOCUMENTS IN` is a TCP listener on :6662 posting straight to the document API.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN V2` | PAS Inbound | MLLP :6661. The standard quintet, V2 merge. Shares its id with Bedford, Portsmouth and Sussex. |
| `IOL` | IOLMaster | DICOM :11112, with `getDicomHeaders`. Shares its id with Bedford, Bolton and Sussex `DICOM`. |
| `HFA2` | DICOM Ingestion | :11113. Visual fields. |
| `DOCUMENTS IN` | PayloadProcessor | TCP :6662 -> `Send Document`. |
| `Document Migration` | Document Ingestion | The search / create / update branch above. |
| `Docman` | Document Outbound | File Reader to a share, plus an absorber. |
