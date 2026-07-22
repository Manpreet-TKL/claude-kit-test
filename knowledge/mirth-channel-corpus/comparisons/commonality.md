# Commonality and difference (Phase 8)

What is common across the estate (the template skeletons) versus what varies per site (the
parameters), derived from the shared-lineage diffs (`shared-lineage-diffs.md`), the clone
families below, and the Phase 4-7 deep records. This is the direct input to Phase 9
templating: each archetype's common core becomes a template, each parameter axis a config
value.

## Six archetypes, their common core, and their parameter axes

| Archetype | Common logic core (constant across sites) | Parameter axes (vary per site) | Members |
|---|---|---|---|
| PAS Inbound | source MLLP listener; destinations `PASAPI - Patient`, `PASAPI - Patient Merge`, `PASAPI - Secondary Patient`, `Clinic List - PUT`, `Clinic List - DELETE`; ~23 transformer scripts mapping PID/PV1 -> PASAPI | listen port; PASAPI version (V1/V2/V3); HL7 version (2.3/2.4); assigning-authority codes (NHS/FACIL/DN); OE base URL + credential; optional extra destinations (DNA, forward-to-MEH) | Bedford, Bolton, EK(x2), ENHT, Kingston, MEH, Optegra, Pennine, Portsmouth, Sussex(x2), Wales, Newmedica-fleet |
| PAS Outbound / Query | HTTP listener trigger; `Convert K21 to XML` -> `Create response` -> `Send Q21` | remote PAS host:port; optional test destination | `06f0b8b8` x6 (Bedford, Bolton, EK, Pennine, Portsmouth, Sussex) |
| PDQ / MPI query (SOAP) | build QBP^Q22 from HTTP params; parse K21 response -> patient list | board assigning-authority code (in-script constant); MPI SOAP endpoint; listen port | Wales x8 |
| DICOM ingestion | DICOM listener; `getDicomHeaders`; `PayloadProcessor API Send`; `Write ... IolMasterImport ... when device is a Zeiss IOLMaster` | DICOM listen port (11112/11113/11114/11118/11119); /mnt/dicom path; AET/SOP filter; OE credential | da67d2ba x6, c14efd23 x4, ba5419a3/eee5caa4, plus per-site DICOM channels |
| Document mover (file -> share) | file reader source; SFTP/SMB writer; little or no transformer | source folder; destination host/path/credential | 04524f4d x4, 375fe7b2 x2, 7a04b9d1 x2, Docman/Delivery/Correspondence set |
| PayloadProcessor upload | build job; `PayloadProcessor API Send` (`/api/v1/request/queue/add`) | source (file/channel); optional Patient Search prepend; OE credential | f703f9cd x2, Newmedica Generic Document processor, DICOM channels (as a destination) |

The PASAPI destination quintet (`Patient`, `Patient Merge`, `Secondary Patient`,
`Clinic List PUT`, `Clinic List DELETE`) is the single most reused unit in the estate - it
is the spine of every PAS Inbound channel and the natural core of the first template.

## The two prime clone families (deterministically confirmed)

Both are the highest-confidence template targets; they differ in *how* they are
parameterised, which sets the Phase 9 approach.

| Family | n | Logic uniformity | Where the parameter lives | Template implication |
|---|--:|---|---|---|
| Newmedica `PAS In LOCAL-*` | 28 | **script bodies byte-identical** across all 28 | connector fields (practice id / routing), outside the scripts | clean: one template + a per-practice config row; no script edits |
| Wales `OpenEyes Query - <board>` | 8 | 99.4% identical; sole script-level difference is one integer | **baked into script text** (the QPD-3 assigning-authority code) + connector port/endpoint | needs the board code extracted from script into a config variable before templating |

### Wales PDQ-8 parameter table (the entire per-board delta)

| Board | Assigning-authority code | Listen port |
|---|---|---|
| ABUHB | 139 | 6668 |
| BCUHB - Central | 109 | 6662 |
| BCUHB - West | 110 | 6663 |
| CTMUHB | 126 | 6667 |
| CVUHB | 140 | 6664 |
| HDUHB | 149 | 6665 |
| PTHB | 170 | 6666 |
| SBUHB | 108 | 6669 |

Every other token in all 8 scripts is identical. The MPI SOAP endpoint and listen port are
the only connector-level differences (`networking/port-map.md`).

## Reuse picture (sharpened from Phase 2)

Phase 2 split the estate 61 reusable-with-config / 41 client-specific. Phase 8 raises the
confidence on the reusable side with objective evidence:

- **36 channels are near-identical clones today** (Newmedica-28 byte-identical + Wales-8 at
  99.4%) - the two families alone.
- **A further ~24 channels** are parameterised siblings of a shared id (the `06f0b8b8`
  query sextet, the `da67d2ba` DICOM six, `c14efd23`, `d69815ee`, `7a7288a3`, the document
  movers) that differ only by connector parameters or one additive destination.
- **Genuinely client-specific** logic concentrates in: MEH AIS (unique), Kingston's forked
  `06f0b8b8` correspondence router, Portsmouth's Patient-Search-prepended upload, and the
  per-site additive destinations (Bedford->MEH forward, Bolton DNA).

## Difference axes a template must externalise

Consolidated from every diff above - the config surface for Phase 9:

1. Ports (every listener; no estate standard - `networking/port-map.md`).
2. OpenEyes base URL + the single shared `api` credential (`auth/persisted-login.md`).
3. PASAPI version (V1/V2/V3) per resource.
4. HL7 version (2.3/2.4/2.5) and assigning-authority codes (NHS/FACIL/DN, Wales board codes).
5. File-system paths (/mnt/dicom, /mnt/docman/*, /mnt/document-upload) and SFTP/SMB targets.
6. Remote PAS / MPI host:port endpoints.
7. Optional per-site destinations (DNA, forward-to-MEH, Patient-Search prepend) as feature
   toggles, not forks.
