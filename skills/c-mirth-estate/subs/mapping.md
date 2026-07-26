# HL7 to PASAPI - the field map

What the PAS inbound transformers actually do to a message. The map below is the estate's
common core, taken from the fullest implementation; the per-site column of
`SKILL.md` and the site files carry the departures.

## Identifier selection - do this first

Every transformer starts by picking identifier repetitions out of PID by assigning authority.
Nothing downstream works if this misses, and it misses quietly. The per-site codes are in
`SKILL.md`; the mechanics are:

| Target | Source | Notes |
|---|---|---|
| `Patient.NHSNumber` | the PID-3 repetition whose authority matches the site's NHS code | selection is done in XSLT, not JavaScript |
| `Patient.HospitalNumber` | the PID-3 (or PID-2) repetition whose authority matches the site's local code | **also builds the PASAPI URL path** - a miss sends the call to a malformed endpoint rather than failing a validation |
| `PatientMerge.SecondaryPatientNumber` | `MRG-1.1` under the same local authority code | the primary comes from the PID of the same message |
| `PatientAppointment` VisitID | `PV1-19.1`, or `PV1-19.1` concatenated with `PV1-19.4` where the site qualifies it | Newmedica requires PV1-19.1 non-empty |

Two sites break the pattern: **Kingston** matches on `PID-3.4` (the namespace id) rather than
`PID-3.5`, and **Newmedica** takes the hospital number from `PID-2.1` under authority `PAS`
with the NHS number under `NH`, not `NHS`.

## Demographics

| HL7 | PASAPI | Transform |
|---|---|---|
| `PID-5.5` | `Patient.Title` | first character upper-cased, remainder lower-cased, spaces removed |
| `PID-5.2` + `PID-5.3` | `Patient.FirstName` | given name plus optional middle name, space-separated |
| `PID-5.1` | `Patient.Surname` | direct |
| `PID-7.1` | `Patient.DateOfBirth` | `YYYYMMDD` to `YYYY-MM-DD` |
| `PID-8.1` | `Patient.Gender` | `F` and `M` retained; **everything else becomes `U`** |
| `PID-15.4`, `PID-15.5` | `Patient.LanguageCode`, `InterpreterRequired` | direct |
| `PID-22.1` | `Patient.EthnicGroup` | `NKN` and `NSP` both map to `ZX` |
| `PID-29.1`, `PID-30.1` | `Patient.DateOfDeath`, `IsDeceased` | `PID-30.1 = Y` sets IsDeceased 1 and formats the date; otherwise 0 |
| `PID-35.1` repetitions | `Patient.Risks` | concatenated |

## Address

| HL7 | PASAPI |
|---|---|
| `PID-11.1` / `.2` / `.3` | `Address.Line1` / `Line2` / `City` |
| `PID-11.4`, `PID-11.5` | `Address.County`, `Address.Postcode` |
| `PID-11.7` | `Address.Type` - `H` becomes `HOME`, **everything else becomes `CORR`** |

**Known defect worth remembering:** the county/postcode mapping uses `.4` as County and `.5`
as Postcode only when `.5` is populated. When `.5` is absent the output logic reverses the
intended values as coded - the postcode lands in County. A site whose PAS omits PID-11.5
therefore produces addresses that look transposed, and it is a transformer bug, not a feed
problem.

## Contact

| HL7 | PASAPI |
|---|---|
| `PID-13.1` | `Patient.TelephoneNumber` |
| `PID-14.1` | `Patient.MobilePhoneNumber` |
| `PID-13` repetition coded `Internet` | `Patient.Email` |
| `NK1-2`, `NK1-4`, `NK1-5` | `Patient.ContactList.PatientContact` - name, address, telephone, mobile, `NET`-coded email |

Next-of-kin contacts are created for every NK1 **except** `NK1-2.1 = NS`.

## Practice and GP

| HL7 | PASAPI | Transform |
|---|---|---|
| `PD1-3.3` | `Patient.Practice.Code` | direct |
| `PD1-4.1` | `Patient.GP.Code` | first eight characters; defaults to the national unknown-GP code `G9999981` when PD1-4.1 is absent |

## Appointment

| HL7 | PASAPI |
|---|---|
| `PV1-44.1` | `AppointmentDate` (`YYYY-MM-DD`) and `AppointmentTime` (`HH:MM`) |
| `PV1-3.1` | mapping `Clinic` |
| `PV1-3.2`, falling back to `.1` | mapping `Session` |
| `PV1-9.3` / `.2` / `.1` | mapping `Doctor`, formatted as a display value |
| `PV1-19.1` (+ `PV1-19.4` where used) | endpoint `VisitID` |
| `MSH-9.2`, `EVN-2.1`, `PV1-6.1`, `PV1-14.1`, `PV1-44.1`, `PV2-27.1` | mapping `Status` - resolved to Attended, Did Not Attend, Transferred, Departed, Arrived or Discharged by event **and timing** |
| `PR1-3.2` with `PV1-3.1` and `MSH-9.2` | mapping `Procedure` / `ProcedureInjection` - site-scoped, and only for A05 |

The appointment `Status` is the one field derived from several segments at once. It depends
on the *relative* timing of `PV1-44` and the message, so replaying an old message produces a
different status than it did originally - relevant when re-driving a feed to fix data.

## Did not attend

`PV1-14.1 = DNA` on an A05 produces a `DidNotAttend` call carrying hospital number, date, the
site's identifier type, and comments including the clinic code. Bolton and Newmedica only.

## PASAPI version deltas

| Version | Sites | Shape |
|---|---|---|
| V1 | Pennine, Wales, Newmedica (legacy) | identifier type is a **path segment**: `PASAPI/V1/Patient/{hospitalNumber}/identifier-type/{type}`. Same for `PatientAppointment/{visitId}` and `PatientMerge/{hospitalNumber}`. `DidNotAttend` takes no path parameter. |
| V2 | Bedford, Bolton, EK, ENHT, Kingston, MEH, Optegra, Portsmouth, Sussex | no identifier-type segment: `PASAPI/V2/Patient/{hospitalNumber}`. Adds `AISFlags/{patientId}` (MEH only) and `DidNotAttend`. |
| V3 | Newmedica fleet | same shape as V2 - `PASAPI/V3/Patient/{hospitalNumber}` - across Patient, PatientAppointment, PatientMerge and DidNotAttend. |

Four sites are **mixed - V2 everywhere except merge, which is still V1**: Bedford, Bolton, MEH
and Sussex all post to
`PASAPI/V1/PatientMerge/{hospitalNumber}/identifier-type/LOCAL-1-0` while using V2 for
Patient and PatientAppointment. ENHT, Optegra and Portsmouth are the only sites on
`PASAPI/V2/PatientMerge`. EK and Kingston have no merge call at all.

The V1 identifier type is the literal `LOCAL-1-0` at Bedford, Bolton, MEH, Pennine, Sussex
and Wales; the Newmedica fleet substitutes a per-practice identifier instead, which is what
the 28 clones parameterise.

`Clinic List - PUT` sends header `X-OE-Partial-Record: 0`. `Clinic List - DELETE` is a
`DELETE` against the same appointment path.

## Non-PASAPI destinations

| Path | Used by | Purpose |
|---|---|---|
| `/api/v1/request/queue/add` | every DICOM channel, all PayloadProcessor submissions | queue a binary for processing. Query parameters: institution id, identifier type, file name, content type, a system message carrying the local AET, request type, source platform. |
| `/api/v1/patient/search` | Portsmouth document channels, Optegra document migration | resolve a patient before uploading |
| `/api/v2/Document/create`, `/search`, `/update` | Optegra document migration | the create-vs-update branch in `rules.md` section 7 |

## Outbound query response

The PAS outbound and PDQ archetypes run the reverse map: a `QBP^Q22` is built from the HTTP
query parameters, the `RSP^K21` reply is parsed, and `PID-3`, `PID-5`, `PID-7`, `PID-8`,
`PID-11`, `PID-13`, `PID-22`, `PID-29`, `PID-30`, `PD1-3` and `PD1-4` become a
`PatientList/Patient` XML document returned to the caller. Identifier selection on the way
back uses the same per-site authority codes as the inbound path, so a site whose codes are
wrong fails symmetrically in both directions.
