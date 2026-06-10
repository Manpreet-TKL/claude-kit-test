---
name: pasapi
description: OE PASAPI V2 + the OpenMRS→BridgeLink→OE PAS flow
disable-model-invocation: true
---

# OpenEyes PASAPI + PAS flow

When loaded as context with no task, reply only `Context loaded.`

On monkey, OpenMRS is the patient source-of-truth (a PAS surrogate) feeding OE through BridgeLink — mirroring a real client: *PAS → HL7 → BridgeLink → OE API*. Endpoint detail, HL7 field contract, PASIN routing table: `subs/reference.md`. Generic Mirth mechanics: `mcc` skill.

## Pipeline

```
OpenMRS ── PAS_POLL (BridgeLink JS poller ~10s: FHIR2 patients by _lastUpdated
  │         watermark, Bahmni appointment/search; builds ADT A04=patient-only,
  │         A05=appointment)
  ▼  MLLP 127.0.0.1:6661 (same mc container)
PASIN (TCP listener) ── routes by ADT event ──▶ HTTP PUT to OE PASAPI V2
```

## PASAPI V2

Base `http://web/PASAPI/V2`; all **PUT**, Basic auth, body = patient XML, `Content-Type: text/plain`. Endpoints: `Patient/{HospitalNumber}`, `PatientAppointment/{VisitID}`, `PatientMerge/{HospitalNumber}`, `Patient/{SecondaryHospitalNumber}`. Response is `<Success>` or `<Failure><Errors>` XML.

**Stateless by design:** `V2Controller::beforeAction` 401s without a Basic header and calls `Yii::app()->user->login()` on **every** request — each call opens a fresh session (cookie `monkey_OESESSID`). Cookie replay to skip re-auth is impossible without editing OE core; OpenMRS, by contrast, issues a replayable `JSESSIONID` — PAS_POLL reuses that.

## Validation that bites

- HospitalNumber must match `/^([0-9]{7,9})$/`; `IdentifierTypeCode` must equal a `patient_identifier_type.unique_row_string` (e.g. `LOCAL-1-0`).
- The `NHSNumber` element must be present even if empty, or PHP throws a `TypeError`.
- Empty `{VisitID}` → `Missing request parameter(s). Required parameter(s) are: id` (a business error, not auth).
- Appointment ingestion needs OE clinic codes to match OpenMRS service names — an open mapping gap on this stack.
