# PAS IN message processing

Source: `~/mc_channels/PAS IN.xml` (channel id `7a7288a3-...`).

## Shape

TCP MLLP **Listener** on `0.0.0.0:6661` (`serverMode=true`, MLLP framing
SOM `0B` / EOM `1C0D`, ACK `06` / NACK `15`). Inbound HL7 v2, non-strict parser.
The source connector does no parsing of its own — it fans the raw ADT message
out to **6 destinations**, each with its own filter + transformer. ACKs are
auto-generated before processing.

The 6 destinations (metaDataId / name / endpoint), all Basic-auth to `web`:

| id | name | request |
|---|---|---|
| 1 | PASAPI - Patient | `PUT /PASAPI/V2/Patient/${HospitalNumber}` |
| 5 | PASAPI - Secondary Patient | `PUT /PASAPI/V2/Patient/${SecondaryHospitalNumber}` |
| 2 | Clinic List - PUT | `PUT /PASAPI/V2/PatientAppointment/${VisitID}` |
| 3 | Clinic List - DELETE | `DELETE /PASAPI/V2/PatientAppointment/${VisitID}` |
| 4 | PASAPI - Patient Merge | `PUT /PASAPI/V1/PatientMerge/${HospitalNumber}/identifier-type/LOCAL-1-0` |
| 6 | Clinic List - DNA | `PUT /PASAPI/V2/DidNotAttend` |

Note the merge URL is **V1** (the others are V2) and bakes `LOCAL-1-0` straight
into the path. Each destination has a RuleBuilder/JavaScript filter selecting
which ADT events it acts on (e.g. Secondary Patient fires only on `A40` merges;
Patient skips `M05`; Clinic List - PUT acts on `A01/A05/A08/A11` excluding
clinic `ECAS`, and `H2` except on `A05`). PASAPI endpoint contract and validation
that bites: the `pasapi` skill.

## The parsing logic (duplicated per destination)

Each PASAPI transformer is an XSLT step (`msg` → `PatientXML`/body) followed by a
stack of JavaScript/Mapper steps that pull fields off the parsed HL7 into the
channelMap. The recurring extractions:

- **HospitalNumber** — `PID.2` (or `PID.3`) entry where the assigning-authority
  subcomponent (`PID.2.5` / `PID.3.5`) equals `'PAS'` / `'FACIL'` / `'CRN'`
  (the layout differs between destinations — see below).
- **NHSNumber** — `PID.3` entry where `PID.3.5 == 'NHS'`. Must be emitted even
  when empty (PASAPI `TypeError` otherwise — `pasapi` skill).
- **SecondaryHospitalNumber** — `MRG.1` entry where `MRG.1.5 == 'FACIL'`.
- **VisitID** — `PV1.19.1` (Patient Merge variant appends `_PV1.19.4`).
- **VisitDate / VisitTime** — from `PV2.8.1`, falling back to `PV1.44.1`, sliced
  into `yyyy-MM-dd` / `HH:mm`.
- **ClinicCode** — `PV1.3.1` (uses `PV1.6.1` on `A12`); **DoctorCode** from
  `PV1.9.2`→`PV1.9.1`→`'Unknown'`.
- **VisitStatusXML** — an ADT-event state machine (`MSH.9.2`): `DNA`→Did Not
  Attend, `A02`/`A08`+prior→Transferred, `A08`/discharge→Departed, `A01`→
  Arrived/Attended, `A12`/`A13`→Arrived, `A03`→Discharged/Departed, else
  Scheduled — wrapped as `<AppointmentMapping><Key>Status</Key>...`.

**The problem:** this XSLT + extraction logic is copy-pasted across all 6
destination transformers, and the copies have drifted — e.g. HospitalNumber is
read from `PID.2[PID.2.5=='PAS']` in one destination but `PID.3[PID.3.5=='FACIL']`
or `PID.3[PID.3.4=='CRN']` in others; two different VisitStatusXML state machines
exist (one keys DNA off `PV2.24`, the other off `PV1.14`); the DOB substring
offsets differ (`1,6,9` vs `1,5,7`). Maintaining six near-identical copies is the
core fragility of this channel.

## Refactor: extract a reusable code-template ("sub import")

Move the shared logic into a **code template library** linked to the channel, so
each destination transformer collapses to ~2 steps (call the helper, then the
one destination-specific filter):

- `extractPasFields(msg)` → returns/sets the channelMap fields above in one place.
- `buildPatientXML(msg)` → produces the `<Patient>` body (replacing the inline
  XSLT).

A client whose PAS uses a different PID segment layout (a different
assigning-authority subcomponent, different DOB format, etc.) then swaps **one
function**, not six transformers. While refactoring, also replace the hardcoded
`LOCAL-1-0` (in the XSLT `<IdentifierTypeCode>`, the Clinic List PUT body, and
the PatientMerge URL — 5 occurrences) with `${OE_IDENTIFIER_TYPE}`. Code-template
exports are secret-free and survive redeploy the same way channel XML does
(`subs/secrets-config.md`).
