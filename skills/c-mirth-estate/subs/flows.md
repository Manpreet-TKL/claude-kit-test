# The six flows, end to end

Each archetype as a message actually travels it. Endpoints are named by the role they serve,
never by address - which is also all that a behaviour question ever needs.

---

## 1. PAS Inbound - 42 channels, every site

```
trust PAS --MLLP--> TCP Listener :6661
                    |  auto-ACK is generated BEFORE processing (AA / AE / AR)
                    |
                    +-> PASAPI - Secondary Patient   [MSH-9.2 == A40]      PUT  Patient/{secondary}
                    +-> PASAPI - Patient  (= d1)     [MSH-9.2 != M05]      PUT  Patient/{hospitalNumber}
                    +-> Clinic List - PUT            [Appointment Filter, d1 SENT]
                    |                                                      PUT  PatientAppointment/{visitId}
                    +-> Clinic List - DELETE         [cancel branch, d1 SENT]
                    |                                                      DELETE PatientAppointment/{visitId}
                    +-> PASAPI - Patient Merge       [MSH-9.2 == A40]      PUT  PatientMerge/{hospitalNumber}
                    +-> (site extras)
```

**The ACK is generated before processing and does not wait for it.** The trust PAS gets an
`AA` whether or not any destination succeeded. Nothing upstream ever learns that a message
was filtered or that the API rejected it - which is why "the PAS says it sent it" and "it is
not in OpenEyes" are both true simultaneously, and why the destination status in BridgeLink
is the only source of truth.

Site extras: `Clinic List - DNA` (Bolton, Newmedica), `AIS` (MEH), `Send to MEH` (Bedford -
forwards the message on to another site's engine), `PASAPI - Patient Referral` and
`OBX document` (Newmedica), a no-op absorber named `Do Nothing` / `Nothing` / `Nothing to do`
(Bedford, Sussex, Newmedica) that catches messages where `d1` did not send.

Three sites run a reduced form with no merge handling at all: EK, Kingston and Pennine have
only `PASAPI - Patient`, `Clinic List - PUT` and `Clinic List - DELETE`.

**Newmedica is shaped differently.** `OpenEyes PAS In` on :8558 is the only MLLP listener; it
fans out to 28 `PAS In LOCAL-*` channels via Channel Reader sources, one per practice. Each
clone carries the identical script body - the per-practice delta lives entirely in connector
fields (practice code, identifier type, destination id, and a per-practice
respond-after-processing toggle). So at Newmedica a message crosses two channels before it
reaches PASAPI, and a drop can be in either.

## 2. DICOM ingestion - 15 channels

```
imaging device --DICOM--> DICOM Listener :1111x
                          |
                          +-> getDicomHeaders            (present at 6 sites; parses the header set)
                          +-> Write out file to IolMasterImport incoming folder
                          |     [filtered on device == Zeiss IOLMaster]  -> a mount path
                          +-> PayloadProcessor API Send  -> POST /api/v1/request/queue/add
```

The queue-add call carries institution id, identifier type, file name, content type
`application/dicom`, a system message holding the local AET, request type `dicom_request`,
and a source platform tag. The biometry drop is a *filtered destination inside the same
channel*, not a separate channel - which is why there is no `IOLMASTER` template anywhere and
should not be one.

Kingston and Pennine each additionally run a legacy pair (`OpenEyes DICOM Channel`,
`OpenEyes DICOM IOLMaster Channel`) with generically named destinations. At Pennine those
collide on port with the current `DICOM_1111x` channels - two listeners cannot bind the same
port, so one side of each pair must be disabled. The current, AET-aware channels are the
`DICOM_1111x` ones.

## 3. Document / correspondence outbound - 13 channels

```
OpenEyes writes a file --> File Reader on a watched folder
                           |  little or no transformer
                           +-> File Writer to a share   (8 sites)
                           +-> SFTP                     (Bedford, Sussex)
```

The simplest archetype in the estate and the most duplicated: three shared-id groups
(`04524f4d` x4, `375fe7b2` x2, `7a04b9d1` x2) that differ only by source folder and
destination path. Destination names vary cosmetically - `Destination 1`, `Copy file to
share`, `SFTP` - and carry no meaning.

Kingston's is the odd one: a File Reader that fans to **two** destinations, one a TCP Sender
speaking HL7 to the trust EPR and one posting JSON to the document manager. It shares a
channel id with the PAS-query channels at six other sites and has nothing in common with
them - the clearest instance of the name-is-not-function rule.

## 4. Document / correspondence ingestion - 6 channels

Two shapes:

- **File-driven** (Portsmouth x3, Optegra migration): File Reader -> optional
  `Patient Search` (`/api/v1/patient/search`) to resolve the patient -> `PayloadProcessor API
  Send`. Portsmouth prepends the search; nobody else does.
- **HL7-driven** (Newmedica `OpenEyes Document In` on :8559, Portsmouth `DOCUMENTS IN HL7` on
  :6662, Optegra `DOCUMENTS IN`): a TCP Listener whose messages carry the document in an OBX
  segment. Newmedica's is a full copy of the PAS inbound destination set plus an
  `OBX document` destination, split by the `OBX-3.1` content filter.

## 5. PAS outbound / query - 9 channels

```
OpenEyes --HTTP--> HTTP Listener :6663      (query parameters: search terms)
                   |
                   +-> Send Q21              -> builds QBP^Q22, MLLP to the trust PAS
                   +-> Convert K21 to XML    -> parses the RSP^K21 reply
                   +-> Create response       -> builds PatientList/Patient XML
                   +-> Respond               (5 sites; the others respond from destination 3)
```

Six of these share one channel id (`06f0b8b8`) and differ only in the remote endpoint and, at
EK, an extra `Send Q21 test empi` destination pointing at a second MPI. Bedford, MEH and
Newmedica guard the entry with the `QPD-3` empty-query check.

The HTTP listeners carry **no authentication** - all 18 HTTP listeners in the estate are
unauthenticated. They are reachable only from inside the deployment network, which is the
whole of the control.

## 6. PDQ / MPI SOAP - 8 channels, Wales only

Same skeleton as flow 5, but the remote is a national MPI reached over SOAP rather than a
trust PAS reached over MLLP, and there is one channel per health board on its own port
(6662-6669).

The **only** difference between the eight is a single assigning-authority integer, and it is
baked into the script text and repeated in the XSLT `vSender` element rather than held in
config. That is the one thing to lift out before templating this archetype: a board code that
disagrees between the two places produces queries the MPI answers for the wrong board.

## 7. PayloadProcessor submission - 5 channels

Not really a flow of its own - it is destination 3 of flow 2 and the tail of flow 4, plus
three standalone channels (Bedford `Document Upload PP`, Newmedica's two generic document
processors) whose only job is `POST /api/v1/request/queue/add`. Sources are a File Reader or
a Channel Reader.

## Reliability, across all flows

Worth knowing before diagnosing a loss: **101 of 102 channels have no destination queue, and
97 have no retry**. A destination that fails fails once and the message is done. 26 channels
run in DEVELOPMENT storage mode, which discards content that PRODUCTION mode would have kept
for replay. Combined with the pre-emptive ACK in flow 1, there is no automatic recovery
anywhere in the estate - every fix is a manual replay.
