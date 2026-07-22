# HL7 behaviour (Phase 4)

HL7v2 message handling across the corpus, extracted by deep-reading each channel's
connector config and transformer JavaScript/XSLT (not names). Source records:
`deepdive/_slices/*.json` (76 deep records; every claim here carries an `evidence[]`
pointer in those records). 39 channels parse or emit HL7; the rest are DICOM, file /
SFTP document movers, or the OpenEyes Document API.

## Message classes in use

| Class | Direction | Where | What it carries |
|---|---|---|---|
| ADT (A01-A40) | inbound | every PAS Inbound channel | patient demographics + appointment (PV1) into PASAPI |
| QBP / RSP (Q21/Q22/K21) | outbound query | PAS Outbound + Wales PDQ | patient lookup against a remote PAS / MPI |
| QRY / K21 | outbound query | Bolton PAS OUT (older form) | legacy patient query variant |
| SIU (S12/S26) | inbound | Newmedica PAS In / Document In | appointment scheduling alongside ADT |
| ORU (R01) | inbound | Kingston OpenEyes Correspondence | results/correspondence message |
| ADT A60 | inbound/outbound | MEH AIS OUT / AIS Sender | allergy/adverse-reaction (AIS) event |

## HL7 version per instance (as declared/parsed)

| Instance | Inbound ADT | Query | Notes |
|---|---|---|---|
| Bedford, Bolton, ENHT, MEH, Optegra, Portsmouth, Sussex, Newmedica, Wales | 2.4 | 2.4 (Wales PDQ 2.5) | 2.4 is the house default |
| EK | 2.3 | 2.4 | EK PAS feeds are a version behind |
| Kingston | (PAS unset) 2.3 correspondence | - | `OpenEyes PAS` MSH carries no explicit version token; `OpenEyes Correspondence` is 2.3 ORU |

## Inbound ADT trigger-event coverage

The PAS Inbound family clusters into two trigger profiles:

| Profile | Trigger events | Instances |
|---|---|---|
| Full (register + update + move + merge) | A01 A02 A03 A04 A05 A08 A11 A12 A13 A38 A40 | Bedford, Bolton, ENHT, MEH, Wales, Newmedica (+ S26 SIU) |
| Reduced | A01 A05 A08 A11 A31 A38 (EK adds A31; Portsmouth/Sussex/Optegra drop A04/A11 variants) | EK, Kingston, Optegra, Portsmouth, Sussex |

A38 (cancel pre-admit) and A40 (patient merge) are handled by most; A40/MRG drives a
`PatientMerge` PASAPI call (see `openeyes/api-usage.md`). A08 is treated as a partial
update at Pennine (`X-OE-Partial-Record: 1` header when `MSH-9.2=A08`).

## ACK behaviour

| ACK mode | Meaning | Channels |
|---|---|---|
| auto | Mirth auto-responder returns ACK after the source transformer runs | all inbound PAS/ADT and document-HL7 listeners |
| custom | ACK/response built in a transformer step (query result assembled into RSP/K21) | PAS Outbound query channels, Wales PDQ, MEH PAS Query, Newmedica PAS Out |
| application | ACK generated after the downstream application call | Bedford PAS OUT, Kingston Correspondence, MEH AIS Sender, Sussex PAS OUT |
| none | no ACK path (fire-and-forget or non-HL7 response) | ENHT PAS Out, MEH AIS OUT |

## Canonical PAS-Inbound field map (ADT -> PASAPI Patient/Appointment)

The richest and most representative mappings are Bolton `PAS IN` (25 fields) and Pennine
`OpenEyes PAS` (19 fields); the rest of the PAS Inbound family is a subset of this shape.
This is the template field map for a new PAS Inbound channel.

| HL7 source | PASAPI target | Transform (confirmed) |
|---|---|---|
| PID-3.1 where PID-3.5=NHS | Patient.NHSNumber | XSLT selects the NHS-authority repetition |
| PID-3.1 where PID-3.5=FACIL/DN | Patient.HospitalNumber + PUT path | also copied to channelMap HospitalNumber; drives the endpoint URL |
| PID-5.1 | Patient.Surname | direct |
| PID-5.2 / PID-5.3 | Patient.FirstName | given + optional middle, space-joined |
| PID-5.5 | Patient.Title | first char upper, remainder lower |
| PID-7.1 | Patient.DateOfBirth | YYYYMMDD -> YYYY-MM-DD |
| PID-8.1 | Patient.Gender | F/M kept, else U (Pennine: direct) |
| PID-11.1..5, .7 | Patient.AddressList.Address | .7 H->HOME else CORR; country GB |
| PID-13.1 / PID-14.1 | Patient.TelephoneNumber / MobilePhoneNumber / Email | emitted only when numeric |
| PID-22.1 | Patient.EthnicGroup | NKN/NSP -> ZX (Bolton) |
| PID-29.1 / PID-30.1 | Patient.DateOfDeath / IsDeceased | Y -> IsDeceased=1, date reformatted |
| PD1-3.3 / PD1-4.1 | Patient.PracticeCode / GpCode | truncated (6 / 8 chars), default G... |
| PV1-19.1(.4) | PatientAppointment VisitID + PUT path | concatenated component form |
| PV1-44.1 (PV2-8.1 preferred at Pennine) | AppointmentDate / AppointmentTime | YYYY-MM-DD + HH:MM |
| PV1-3.1/.2 | Clinic / Session | site-specific ward/clinic fallbacks |
| PV1-9 | Doctor | display-name assembly, default UNKNOWN |
| MSH-9.2 + EVN-2.1 + PV1-6/14/44 + PV2-24/27 | Appointment Status | derives Attended / Did Not Attend / Transfer / Scheduled |
| MRG-1.1 where MRG-1.5=FACIL | PatientMerge.SecondaryPatientNumber | A40 merge path |
| PV1-14.1=DNA with MSH-9.2=A05 | DidNotAttend | separate DNA PASAPI call |

Site drift on this shape is real and evidence-backed: Bolton capitalises Title and maps
ethnicity to ZX; Pennine fixes country to GB and gates telephone on a numeric test;
Newmedica routes on `PV1-3.9` (first five chars index a global hospital-mapping table)
before applying an XSLT that builds the whole Patient body. Do not assume two PAS Inbound
channels share a mapping without diffing (Phase 8).

## PDQ / query field map (Wales, canonical for MPI lookup)

Wales `OpenEyes Query - <board>` builds an outbound QBP^Q22 (HL7 2.5) to the NHS Wales
MPI and parses the K21 response back to an OpenEyes patient list:

| Direction | Field | Detail |
|---|---|---|
| out | HTTP param hosnum -> QPD-3 (@PID.3.1, @PID.3.4=139, @PID.3.5=PI) | hospital-number query |
| out | HTTP param nhsnum -> QPD-3 (@PID.3.4=NHS, @PID.3.5=NH) | used when hosnum absent |
| out | givenname/familyname/dob -> QPD-3 @PID.5.2/.5.1/.7 | names uppercased; dob yyyy-MM-dd -> yyyyMMdd |
| in | K21 PID-3/5/7/8/11/13/22/29/30, PD1-3/4 -> PatientList.Patient | identifiers, name, DOB, gender, address, GP |

The 8 board channels are identical except the QPD assigning-authority code / MPI endpoint
/ listener port (see `deepdive/_slices/Wales.json` and `networking/port-map.md`). Pennine
`OpenEyes PAS Query` and MEH `OpenEyes PAS Query v2` are the non-Wales query variants (QBP
to a remote hospital PAS over MLLP rather than SOAP/MPI).

## Anomalies

1. Portsmouth `DOCUMENTS IN HL7` is HL7-framed (MLLP :6662) but records no ADT
   message/trigger type - it is a document-carrying HL7 feed (8-field map to a
   PayloadProcessor submission), not a PAS feed. Classify by connector, not the "HL7" in
   its name.
2. Kingston `OpenEyes PAS` MSH carries no explicit version token (parsed as 2.3-era);
   flagged for the Phase 8 diff against the 2.4 sites.
3. EK runs HL7 2.3 on its inbound PAS feeds while querying at 2.4 - a per-site version
   mismatch a template must parameterise, not hardcode.
4. Wales PDQ is the only HL7 2.5 traffic in the estate.
