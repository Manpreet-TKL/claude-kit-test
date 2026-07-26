# Wales

Channels: 10.  BridgeLink 4.4.2.  PASAPI **V1 only**.  HL7 2.4.
Identifiers: `PID-3` repetitions, selected by NHS / CRN / PAS authority. Merge uses the
per-board code.

## Deltas from the general rules

- **Eight PDQ channels, one per health board**, on their own HTTP ports. Same skeleton as the
  PAS-outbound archetype, but the remote is a national MPI over SOAP rather than a trust PAS
  over MLLP.
- **The entire per-board delta is one assigning-authority integer**, and it is baked into the
  script text *and* repeated in the XSLT `vSender` element rather than held in config. If the
  two disagree the MPI answers for the wrong board. Lifting that integer into a config
  variable is the prerequisite for templating this archetype.

  | Board | Code | Port |
  |---|--:|--:|
  | BCUHB - Central | 109 | 6662 |
  | BCUHB - West | 110 | 6663 |
  | CVUHB | 140 | 6664 |
  | HDUHB | 149 | 6665 |
  | PTHB | 170 | 6666 |
  | CTMUHB | 126 | 6667 |
  | ABUHB | 139 | 6668 |
  | SBUHB | 108 | 6669 |

  A per-board message-archive toggle also varies and is a real behavioural switch, not a
  cosmetic one.
- **V1 for everything**, with `LOCAL-1-0` as the identifier type. Only Wales and Pennine are
  still fully on V1.
- :6663 is a **PDQ listener** here, not the PAS-outbound trigger it is at every other site.
  That is the most likely cross-site confusion when reading a Wales config.
- DICOM is on :11118, not :11112.
- PAS inbound is otherwise the estate baseline: the standard quintet, common Appointment
  Filter, `MSH-9.2 == A40` and `!= M05`.

## Channels

| Name | Archetype | Notable |
|---|---|---|
| `PAS IN` | PAS Inbound | MLLP :6661. Standard quintet, V1 endpoints. Shares its id with Bolton and ENHT. |
| `OpenEyes Query - <board>` x8 | PDQ / MPI SOAP | HTTP :6662-:6669. Template family `pas-query-mpi-wales`; 99.4% identical to each other. |
| `DICOM` | DICOM Ingestion | :11118. Shares its id with EK, ENHT, Kingston, Pennine and Portsmouth. |
