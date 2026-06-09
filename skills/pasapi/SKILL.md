---
name: pasapi
description: How the OpenEyes PAS API (PASAPI V2) works and the end-to-end data flow OpenMRS -> BridgeLink -> OpenEyes on the monkey PAS-surrogate stack. Covers the V2 PUT endpoints, the every-request Basic-auth/stateless-session behaviour, the validation rules that 400/500 you, the HL7 ADT PID/PV1 contract, and how the PAS_POLL/PASIN channels route messages. Invoke by name for PAS integration, HL7->OE field mapping, or debugging patient/appointment ingestion. For generic Mirth/BridgeLink mechanics use the `mcc` skill.
disable-model-invocation: true
---

# OpenEyes PASAPI + the PAS data flow

On the monkey stack **OpenMRS is the patient source-of-truth (a PAS surrogate)** and
feeds OpenEyes through BridgeLink. This mirrors a real client: *client PAS -> HL7 ->
BridgeLink -> OE API*.

## The pipeline

```
OpenMRS  (permanent patient/appointment store)
  │  PAS_POLL  (BridgeLink JS poller, ~10s, pollOnStart)
  │    patients     : FHIR2  GET /ws/fhir2/R4/Patient?_lastUpdated=gt{watermark}&_sort=_lastUpdated
  │    appointments : Bahmni POST /ws/rest/v1/appointment/search
  │    builds HL7 ADT:  A04 = patient-only (PID),  A05 = appointment (PID + PV1/PV2)
  ▼  MLLP to 127.0.0.1:6661 (same mc container)
PASIN  (TCP/MLLP listener) ── routes by ADT event ──▶ HTTP PUT to OE PASAPI V2
```

## PASAPI V2 endpoints

Base on monkey: `http://web/PASAPI/V2`. All are **PUT**, Basic auth, body = patient XML,
`Content-Type: text/plain`.

| Endpoint | Key | Purpose |
|---|---|---|
| `PUT .../Patient/{HospitalNumber}` | hosp no | create/update patient (`${PatientXML}`) |
| `PUT .../PatientAppointment/{VisitID}` | visit id | create/update appointment |
| `PUT .../PatientMerge/{HospitalNumber}` | hosp no | merge |
| `PUT .../Patient/{SecondaryHospitalNumber}` | 2nd hosp no | secondary identifier |

Response: `<Success><Id>..</Id><Message>Patient updated</Message></Success>` or
`<Failure><Errors><Error>..</Error></Errors></Failure>`.

## Auth & session (stateless by design)

- **Basic auth is required on every request.** `V2Controller::beforeAction` 401s if the
  Basic header is absent and calls `Yii::app()->user->login()` **on every call**, so each
  request opens a fresh session. The OE session cookie is `monkey_OESESSID`.
- **Cookie reuse to skip re-auth is impossible** without editing OE core — unlike OpenMRS,
  whose FHIR/REST endpoints issue a `JSESSIONID` you can replay. So PAS_POLL reuses the
  OpenMRS session; PASIN must send Basic to OE every time.

## Validation rules that bite

- HospitalNumber must match `/^([0-9]{7,9})$/` (numeric, 7–9 digits).
- `IdentifierTypeCode` must equal a `patient_identifier_type.unique_row_string`
  (e.g. `LOCAL-1-0`, whose regex is `[0-9]{7,9}`).
- The `NHSNumber` element must be **present even if empty**, or PHP throws a `TypeError`.
- Empty `{VisitID}` -> `Missing request parameter(s). Required parameter(s) are: id`
  (an OE business error, not an auth failure).

## HL7 -> OE field contract (V2)

- NHSNumber = `PID.3.1` where `PID.3.5 == 'NHS'`; HospitalNumber = `PID.3.1` where `PID.3.5 == 'MR'`
- Title `PID.5.5`; FirstName `PID.5.2` (+`PID.5.3` middle); Surname `PID.5.1`
- DOB `PID.7.1` (YYYYMMDD); Gender `PID.8.1`
- Address `PID.11` where `PID.11.7 in {P,H}`; Phone `PID.13`; VisitID `PV1.19.1`

## PASIN destination routing (by ADT event / condition)

| metaId | destination | accepts |
|---|---|---|
| 1 | PASAPI - Patient | `MSH.9.2 != M05` (all but merge) |
| 2 | Clinic List - PUT (appointments) | {A01,A05,A08,A11,A03,A13,A02,A12}, **not A04** |
| 3 | Clinic List - DELETE | A38 |
| 4 | PASAPI - Patient Merge | A40 |
| 5 | PASAPI - Secondary Patient | SecondaryHospitalNumber present |

A04 (patient-only) reaches the Patient destination and is filtered out of the appointment
destination. Appointment ingestion needs OE clinic codes to match the OpenMRS service
names — an open mapping gap on this stack.

## When to invoke this skill

`disable-model-invocation: true` — invoke by name for PAS/HL7/PASAPI work. Generic Mirth
mechanics (REST API, secrets, Rhino) live in the `mcc` skill.
