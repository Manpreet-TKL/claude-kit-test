# PASAPI - field contract and routing detail

## PASAPI V2 endpoints

Base on monkey: `http://web/PASAPI/V2`. All **PUT**, Basic auth, body = patient XML, `Content-Type: text/plain`.

| Endpoint | Key | Purpose |
|---|---|---|
| `PUT .../Patient/{HospitalNumber}` | hosp no | create/update patient (`${PatientXML}`) |
| `PUT .../PatientAppointment/{VisitID}` | visit id | create/update appointment |
| `PUT .../PatientMerge/{HospitalNumber}` | hosp no | merge |
| `PUT .../Patient/{SecondaryHospitalNumber}` | 2nd hosp no | secondary identifier |

Response: `<Success><Id>..</Id><Message>Patient updated</Message></Success>` or `<Failure><Errors><Error>..</Error></Errors></Failure>`.

## PAS_POLL source queries

- Patients: FHIR2 `GET /ws/fhir2/R4/Patient?_lastUpdated=gt{watermark}&_sort=_lastUpdated`
- Appointments: Bahmni `POST /ws/rest/v1/appointment/search`
- Builds HL7 ADT: A04 = patient-only (PID), A05 = appointment (PID + PV1/PV2); MLLP to `127.0.0.1:6661` (same mc container), `pollOnStart`, ~10 s interval.

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

A04 (patient-only) reaches the Patient destination and is filtered out of the appointment destination.
