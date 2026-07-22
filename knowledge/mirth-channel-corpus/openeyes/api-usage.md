# OpenEyes API usage (Phase 5)

Every OpenEyes call the corpus makes, extracted from HTTP Sender connectors and the
transformer bodies that build each request. Source records: `deepdive/_slices/*.json`;
each call carries an `evidence[]` pointer. PASAPI-version to OE-release mapping (approved):
**V1 = OE <= 8, V2 = OE 9-10, V3 = OE 11+**. Exact per-instance release is still
user-supplied (`unresolved/questions.md`); the PASAPI version sets the floor.

## Two distinct API families

OpenEyes exposes two separate surfaces and the corpus uses both:

| Family | Base | Purpose | Versioning seen |
|---|---|---|---|
| PASAPI | `PASAPI/V{1,2,3}/...` | patient + appointment + merge + DNA + AIS sync | V1, V2, V3 |
| Core REST | `/api/v1/...`, `/api/v2/...` | Document create/search/update, Patient/Search, PayloadProcessor queue | api/v1, api/v2 |

Note `api/v2` (Optegra Document API) is **not** the same as PASAPI V2 - they version
independently. This resolves the Phase 2 caveat: Optegra's `api/v2/Document` is a real,
directly-read endpoint, not a typo of PASAPI V2 (see reconciliation below).

## PASAPI resource + verb matrix

| Resource | Verb | Path shape | V1 sites | V2 sites | V3 sites |
|---|---|---|---|---|---|
| Patient | PUT | `PASAPI/V{n}/Patient/${HospitalNumber}` (V1 adds `/identifier`) | Pennine, Wales, Newmedica | Bedford, Bolton, EK, ENHT, Kingston, MEH, Optegra, Portsmouth, Sussex | Newmedica |
| Patient (secondary id) | PUT/POST | `.../Patient/${SecondaryHospitalNumber}` | Newmedica, Wales | Bedford, Bolton, ENHT, Optegra, Portsmouth, Sussex, MEH (POST) | Newmedica |
| PatientAppointment | PUT | `.../PatientAppointment/${VisitID}` (V1 adds `/identifier`) | Newmedica, Pennine, Wales | Bedford, Bolton, EK, ENHT, Kingston, MEH, Optegra, Portsmouth, Sussex | Newmedica |
| PatientAppointment | DELETE | `.../PatientAppointment/${VisitID}` | Newmedica, Pennine, Wales | (same V2 set) | Newmedica |
| PatientMerge | PUT | `.../PatientMerge/${HospitalNumber}` | Bedford, Bolton, MEH, Sussex, Wales, Newmedica | ENHT, Optegra, Portsmouth | Newmedica |
| DidNotAttend | PUT | `.../DidNotAttend` | Newmedica | Bolton | Newmedica |
| AISFlags | GET/PUT | `PASAPI/V2/AISFlags/${PatientId}` | - | MEH only | - |

Reading the matrix: a single instance commonly spans PASAPI generations because
different resources were migrated at different times (e.g. MEH does Patient/Appointment
on V2 but PatientMerge on V1). The instance's minimum OE release is set by the *highest*
version it calls.

## Core REST (non-PASAPI) endpoints

| Endpoint | Verb | Used by | Role |
|---|---|---|---|
| `/api/v1/request/queue/add` | POST | all 12 instances | PayloadProcessor submission (DICOM + document jobs, `request_type=dicom_request`) |
| `/api/v1/Patient/Search`, `/api/v1/patient/search` | POST/GET | Portsmouth | resolve patient before a document submission |
| `/api/v2/Document/create` | POST | Optegra | create an OpenEyes document |
| `/api/v2/Document/search` | GET | Optegra | find existing document |
| `/api/v2/Document/update` | PATCH | Optegra | amend an existing document |

`request/queue/add` is the single universal OpenEyes call in the estate - every site
submits imaging/documents through the PayloadProcessor queue. It is the strongest
template-target endpoint.

## Per-instance API-version matrix (reconciled with Phase 2 taxonomy)

| Instance | PASAPI | Core REST | Inferred OE floor |
|---|---|---|---|
| Bedford | V2 | api/v1 | OE 9-10 |
| Bolton | V2 | api/v1 | OE 9-10 |
| EK | V2 | api/v1 | OE 9-10 |
| ENHT | V2 | api/v1 | OE 9-10 |
| Kingston | V2 | api/v1 | OE 9-10 |
| MEH | V2 (+AISFlags V2) | api/v1 | OE 9-10 |
| Newmedica | V1 and V3 | api/v1 | OE 11+ (migration in progress) |
| Optegra | V2 | api/v1 + api/v2 (Document) | OE 9-10 (api/v2 Document available) |
| Pennine | V1 | api/v1 | OE <= 8 |
| Portsmouth | V2 | api/v1 (+ Patient/Search) | OE 9-10 |
| Sussex | V2 | api/v1 | OE 9-10 |
| Wales | V1 | api/v1 | OE <= 8 |

## Payload shapes (confirmed)

- **Patient (PUT)** - XML body built by XSLT from the PID/PD1 segments (demographics,
  identifiers, address, GP/practice, death). `updateOnly=1` attribute set on A31 (Pennine).
  `X-OE-Partial-Record` header on A08.
- **PatientAppointment (PUT)** - visit id in the path; date/time/clinic/doctor/status in
  the body; status derived from the ADT trigger + PV1/PV2 fields.
- **PatientAppointment (DELETE)** - visit id in the path; used on cancel/void triggers.
- **PatientMerge (PUT)** - primary HospitalNumber in path, secondary from MRG-1.1 (A40).
- **DidNotAttend (PUT)** - hospital number + date + comments; separate call, not a status.
- **PayloadProcessor (POST `request/queue/add`)** - multipart/form job with
  `request_type=dicom_request` and the file/document payload.
- **Document (Optegra api/v2)** - create then optional search/update(PATCH) against a
  document resource.

## Reconciliation items closed by the deep-read

1. **Optegra `api/v2/Document` - CONFIRMED.** `Document Migration` (and the wider Optegra
   document channels) POST `/api/v2/Document/create`, GET `/api/v2/Document/search`,
   PATCH `/api/v2/Document/update`, read directly from the connector URLs. This is a real
   second REST version, independent of PASAPI V2 (Phase 2 caveat 2 resolved).
2. **Newmedica V1 + V3 coexistence - CONFIRMED migration mechanism.** The per-practice
   `PAS In LOCAL-*` channels POST PASAPI **V3**, with a **disabled** V1 connector retained
   alongside (the migration toggle); `OpenEyes Document In` still calls **V1**. So
   Newmedica is genuinely mid-migration, not mixed by accident (Phase 2 caveat resolved).
3. **Portsmouth Patient/Search** is `api/v1` (both cased spellings appear); its document
   channels resolve the patient first, then submit to PayloadProcessor.

## Gaps / open

- Exact OE release within each PASAPI band (user-supplied).
- OE API session lifetime is not expressed in the channels (auth is per-message Basic; see
  `auth/persisted-login.md`) - a server-side concern, not a channel concern.
