# Bedford

Channels: 5.  BridgeLink 4.5.2.  PASAPI V2, merge V1.  HL7 2.4.
Identifiers: NHS number `PID-3.5 = NHS`; hospital number **`PID-2.1`**; merge `MRG-1.5 = MR`.

## Deltas from the general rules

- Hospital number comes from **PID-2**, not PID-3 - only Bedford, MEH and Newmedica do this.
- Carries the **location gate** (with MEH): `PV1-3.2 != "checkin"` and `PV1-3.2 != ""`. An
  appointment with a blank PV1-3 second component is dropped.
- Extra destination **`Send to MEH`** - forwards the message on to another site's engine.
  Nowhere else in the estate does a PAS inbound channel fan out to a second organisation.
- Extra destination `Do Nothing` (d6) on `PAS IN`, with **no filter** - it runs on every
  message. On `PAS OUT`, `Respond` carries the `$('d1').getStatus()` **not** SENT form, so it
  answers only when `Send Q21` failed.
- `PAS OUT` carries the `QPD-3 != ""` empty-query guard (with MEH and Newmedica).
- Appointment Filter is the common form, unmodified.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN` | PAS Inbound | MLLP :6661. Seven destinations - the quintet plus `Do Nothing` and `Send to MEH`. Shares its channel id with Optegra, Portsmouth and Sussex PAS inbound. |
| `PAS OUT` | PAS Outbound | HTTP :6663. Shares the `06f0b8b8` id with five other sites - and with Kingston, where the same id is a completely different channel. |
| `DICOM` | DICOM Ingestion | :11112. Has the `getDicomHeaders` destination. Shares its id with Bolton, Optegra and Sussex. |
| `Document OUT` | Document Outbound | File Reader to **SFTP**. Shares its id with Sussex `Document Delivery`. |
| `Document Upload PP` | PayloadProcessor | File Reader straight to the queue-add API. Shares its id with Portsmouth `General Documents IN`. |
