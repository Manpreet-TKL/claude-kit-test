# Open questions / user-supplied information

Placeholders that block nothing in the current wave but are needed downstream.

## OpenEyes version per instance (Phase 5)
PASAPI floor is inferred from the PASAPI version each instance's channels call
(V1 = OE <=8, V2 = OE 9-10, V3 = OE 11+). Please confirm the **exact** release.

| Instance | PASAPI versions seen | Inferred OE floor | Exact OE release |
|---|---|---|---|
| Bedford | V1, V2 | mixed (V1+V2) -> straddles OE8/9 | `<TBD>` |
| Bolton | V1, V2 | mixed -> straddles OE8/9 | `<TBD>` |
| EK | V2 | OE 9-10 | `<TBD>` |
| ENHT | V2 | OE 9-10 | `<TBD>` |
| Kingston | V2 | OE 9-10 | `<TBD>` |
| MEH | V1, V2 | mixed -> straddles OE8/9 | `<TBD>` |
| Newmedica | V1, V3 | mixed (V1+V3) -> straddles OE8/11 | `<TBD>` |
| Optegra | V2 | OE 9-10 | `<TBD>` |
| Pennine | V1 | OE <=8 | `<TBD>` |
| Portsmouth | V2 | OE 9-10 | `<TBD>` |
| Sussex | V1, V2 | mixed -> straddles OE8/9 | `<TBD>` |
| Wales | V1 | OE <=8 | `<TBD>` |

Mixed PASAPI versions within one instance suggest either an in-progress migration or
older channels left deployed alongside newer ones - to confirm per instance.

## Resolved by the Phase 4-6 deep-read (kept for the audit trail)
- **globalMap and authentication - resolved.** No channel caches an auth token/session in
  any global map; OE auth is stateless per-message HTTP Basic (`auth/persisted-login.md`).
  Global-map restart-persistence therefore does not affect login. It *does* still matter
  for Newmedica's routing lookup tables (`globalMap:hospitalMapping`,
  `globalMap:channelLookup`) - see the routing item below.
- **OE API session lifetime - not a channel concern.** No channel uses cookie/session;
  all use pure preemptive HTTP Basic. Server-side session lifetime is irrelevant to the
  channels.
- **Optegra api/v2 Document - resolved.** Confirmed real `api/v2/Document/create|search|update`,
  independent of PASAPI V2 (`openeyes/api-usage.md`).

## Security finding (Phase 9) - sample-message payloads in `canonical/` - RESOLVED

Surfaced while building templates. Mirth transformer sample fields
(`<inboundTemplate>` / `<outboundTemplate>`, base64) carry developer sample messages
that are **not used at runtime**, but in this corpus some held **patient-shaped data**
(names, dates of birth, hospital/NHS numbers - e.g. a decoded HTTP query
`familyname=<surname>&givenname=<forename>&dob=<date>`, an ADT^A05 with a named
patient + address, a hospital number). Wave 0 redaction had covered only
`<password>`/`<passPhrase>`/`<username>`, so these fields passed through unredacted.

- **Scope:** 166 non-empty fields across 75 channels (135 inbound + 31 outbound).
- **Fix applied (Wave 0 extension):** `bin/build_canonical.py` now blanks
  `<inboundTemplate>`/`<outboundTemplate>` content across `canonical/` and logs each by
  length (`secret_type = sample_message_inbound|outbound`, `placeholder = (blanked)`).
  Re-baselined the 75 affected `canon_sha256` rows; every `raw_sha256` stayed identical
  (read-only corpus untouched). `bin/build_inventory.py` and `bin/build_templates.py`
  re-run clean; `templates/` also strips these fields defensively. Verified: zero
  sample identifiers and zero non-empty sample blocks anywhere in the output tree.
- **No analytical impact:** the fields carry no channel logic, so no Phase 1-8
  conclusion changes.
- **Real vs synthetic:** cannot be verified from the exports; treated conservatively as
  potentially patient-identifiable and neutralised regardless.

## Reconciliation (Phase 16) - "Docman" document channels are OUTBOUND, not ingest

Surfaced while building the Phase 16 integration surface matrix. The Phase 2
human-readable taxonomy (`taxonomy/channel-types.md`) counts the ENHT/MEH/Optegra
"Docman" channels (shared lineage `04524f4d`) under **document ingestion**. The
connectors say otherwise: source = `File Reader /mnt/docman`, destination =
`File Writer` to a remote host (e.g. ENHT -> `192.168.13.252`); the shared-id sibling
is even named `DOCUMENT-OUT-Minestrone` (Portsmouth). These pick OE-generated
correspondence off the local mount and deliver it to a remote share - **document
outbound delivery, with no OpenEyes ingestion call**.

- **Authoritative record is correct:** `taxonomy/channel-types.json` (and therefore
  `ai-corpus/channels.jsonl` and `dataflows/integration-overview.md`) classify them as
  Document / Correspondence Outbound. Confirmed document *ingestion* is only
  Newmedica / Optegra / Portsmouth.
- **Defect to reconcile:** the `taxonomy/channel-types.md` per-instance matrix's Doc-In
  assignment for those Docman channels is a markdown-summary error. The category totals
  (Doc-In 6 / Doc-Out 13) match the JSON; only the per-instance distribution is wrong.
  Recommend regenerating that matrix from the JSON in a cleanup pass (out of scope for
  this wave - prior-wave gated deliverable, flagged not silently rewritten).

## Other items (needed for later waves, not blocking)
- Whether Newmedica's `globalMap` routing tables (`hospitalMapping`, `channelLookup`) are
  repopulated after a BridgeLink restart - if not, the 28-way PAS-In fan-out breaks
  (operational dependency, `dataflows/dataflows.md`).
- **Deployed/enabled state, esp. Pennine DICOM.** Which channels are actually enabled vs
  dormant. The deep-read indicates Pennine's `DICOM_1111x` channels are current and the
  same-port `OpenEyes DICOM *` channels legacy; confirm against the deployed flag before
  any redeploy (`dataflows/dataflows.md`, `networking/port-map.md`).
- PayloadProcessor version per instance; upstream PAS / MPI system versions.
- Network / firewall ownership; data retention; RTO / RPO.
- MPI (NHS Wales) trust/auth model - the SOAP calls carry no HTTP-Basic layer.
