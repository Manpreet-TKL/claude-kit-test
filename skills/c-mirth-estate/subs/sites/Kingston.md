# Kingston

Channels: 5.  BridgeLink 4.5.2.  PASAPI V2.  HL7 version not declared in the export.
Identifiers: NHS number **`PID-3.4 = NHSNBR`**; hospital number **`PID-3.4 = RAX MRN`** or
`PID-3.5 = MRN`. No merge.

## Deltas from the general rules

- **Selects identifiers on `PID-3.4`, not `PID-3.5`.** Every other site matches on the
  assigning-authority component 5; Kingston matches on the namespace id in component 4. A
  message whose authority is carried in .5 only will have neither number picked up, silently.
- **No rule-builder filters at all** - every filter at Kingston is JavaScript. No
  `MSH-9.2 != M05`, no `MSH-9.2 == A40`.
- Appointment Filter variant: requires `$('ClinicCode') != ""` **and** the event in
  `A01 / A05 / A08`, and the removal branch tests `PV1-15.1` in `{CHKO, DNA}` rather than
  `PV1-4.1 == "CANCL"`. An appointment with no clinic code never reaches the clinic list.
- **No merge handling** - three destinations only.
- **The primary PAS feed is on :6662**, not :6661. Kingston has no HTTP listener at all.
- `OpenEyes Correspondence` shares the `06f0b8b8` channel id with six sites' PAS-query
  channels but is an entirely different channel - a File Reader fanning to a TCP Sender
  speaking HL7 to the trust EPR and an HTTP destination posting JSON to the document manager.
  **This is the estate's canonical proof that a shared id means nothing.**
- Runs a legacy DICOM pair on :11118 and :11119 alongside the current channel on :11112.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `OpenEyes PAS` | PAS Inbound | MLLP :6662. Three destinations. Shares its id with Pennine `OpenEyes PAS`. |
| `DICOM` | DICOM Ingestion | :11112. The current channel. |
| `OpenEyes DICOM Channel` | PayloadProcessor | :11119, legacy. Generic `Destination 1`. Shares its id with Pennine. |
| `OpenEyes DICOM IOLMaster Channel` | IOLMaster | :11118, legacy. Shares its id with Pennine. |
| `OpenEyes Correspondence` | Document Outbound | The forked `06f0b8b8`. Two destinations, two protocols. |
