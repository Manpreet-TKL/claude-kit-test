---
name: c-oe-interop
description: OpenEyes third-party integration capabilities
disable-model-invocation: true
---

# OpenEyes interoperability

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

OpenEyes integrates with hospital systems (PAS, medical/imaging devices, document management, BI) primarily through a per-server **NextGen Healthcare Connect** integration engine (the rebranded Mirth Connect — ToukanLabs ships BridgeLink, see `c-mirth`). Connect remaps inbound feeds onto OpenEyes' native interfaces, so the same engine can accept HL7 v2, REST, file-drop, etc. without touching OE core. This skill distils the v1.1.1 Interoperability Guide into per-capability config notes; the heavy detail is in `subs/`. Key constraint: **HL7 is always remapped to the native PAS API, so the PAS API is the limiting factor** for what demographic/appointment data can move. Demographics are **inbound-only** — OE cannot push demographic updates back to a PAS, and in-OE demographic editing is disabled to prevent drift.

## Integration methods at a glance

| Capability | Mechanism |
|---|---|
| Patient demographics / ADT | HL7 v2 (→ remapped) **or** native PAS API (REST), inbound only |
| PAS demographic lookup (no record found) | HL7 Q21/K21 exchange **or** PAS API |
| Appointments / clinic lists / check-in | HL7 v2 (A01 = arrived) **or** PAS API |
| GP / practice data | GP/practice codes + NHS Digital import (PASAPI v1); full details direct or embedded (PASAPI v2) |
| Correspondence / discharge / referrals | PDF + metadata file-drop to a network folder (filename encoding and/or sidecar XML) |
| Document upload (into OE) | PASAPI v2: file-drop (SFTP/SMB) by filename or sidecar XML, **or** HL7 MDM^T02 |
| BI / data warehouse | Direct MySQL connection (REPORTS / SUPPORT DB copy) |
| User authentication | LDAP / Active Directory |
| User data (staff details) | Outbound SOAP/REST pull keyed on AD username (CSD API) |
| Devices | Zeiss FORUM, Topcon ImageNET 6 (desktop launcher); Cerner HIE, CIVICA CITO (contextual web link) |
| Event-driven notifications | xAPI webhook subscribers (Created/Modified/Deleted) |

## Where config lives

- **Admin screens** carry most per-institution config: `Admin->System->Settings` (device on/off toggles, ImageNET identifier type, FORUM enable), `Admin->System->Webhook Subscribers`, `Admin->System->Settings->Worklists` (check-in match), `Admin->Correspondence->Recipient Output Types` and `->Delivery Configurations`, `Admin->Core->LDAP Configurations` + `Admin->Institutions->...->Authentication Methods`, `Admin->Core->Users` (HIE roles), `Admin->Core->Patient Identifier Types`.
- **Env vars / Docker secrets** drive back-end integrations and **override** the matching Admin setting: `HIE_*`, `CITO_*`, `OE_CSD_API_*`. Secrets-only values (passwords) must be Docker secrets in production.
- **Connect/BridgeLink channels** do the wire-protocol work; channel settings (e.g. the arrival-status match text) must agree with the OE Admin settings.

## Subs

- `subs/patient-adt.md` — demographics/ADT (HL7 + PAS API), supported vs unsupported fields, GP data, Ophthalmology filtering, Q21/K21 lookup, appointments/clinic lists, A01 check-in settings.
- `subs/correspondence.md` — letters/discharge PDF+metadata output, recipient output types, delivery configs, internal referrals, PASAPI-v2 document **upload** (file-drop naming, sidecar XML, HL7 MDM^T02).
- `subs/devices.md` — Zeiss FORUM, Topcon ImageNET 6, Cerner HIE, CIVICA CITO: settings, env vars, usage.
- `subs/auth-users.md` — LDAP/AD authentication config fields, and the outbound User Data (CSD) API.
- `subs/webhooks-bi.md` — xAPI webhook subscribers (events, payload shape, version coverage) and the BI / data-warehouse DB connection.
- `subs/appendices.md` — appendix/reference index, the HL7 MDM^T02 worked example, and known gaps in the source guide.

## Key anchors

- Source guide: `/home/toukan/oe_interop_guide.doc` (Confluence MHTML export, v1.1.1, 8 Jun 2026).
- Siblings: `c-mirth` (BridgeLink/Mirth engine + REST), `c-mcchannels` (the actual OE PAS/interop channels), `c-pasapi` (PASAPI v2 + OpenMRS→BridgeLink→OE flow), `c-oe-iolmaster-import` and `c-oe-payload-processor` (DICOM/device-result importers feeding device events).
