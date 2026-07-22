# Domain glossary (Phase 14)

Terms an AI agent needs to reason about this corpus, each defined and anchored to where
it actually appears. This is the human-readable companion to `channels.jsonl` /
`schema.json` / `summary.json`. Where a term's meaning was confirmed from channel scripts
it is marked **confirmed**; where it rests on product knowledge not re-derivable from the
exports it is marked **external**.

## Platform

| Term | Definition | In this corpus |
|---|---|---|
| Mirth Connect / BridgeLink | The integration engine hosting the channels. BridgeLink is the NextGen-successor distribution of Mirth Connect. | Export `version` attr is 4.4.2 / 4.5.2 / 4.6.1 (`inventory/versions.md`); "channel" XML is a Mirth channel export. **confirmed** |
| Channel | One integration pipeline: a source connector, optional filters/transformers, and one or more destination connectors. | 102 channels (`ai-corpus/summary.json`). **confirmed** |
| Connector | An endpoint of a channel. The **source** connector receives; each **destination** connector sends. Transport types seen: HTTP Sender/Listener, TCP/MLLP Listener/Sender, DICOM Listener, File Reader/Writer, JavaScript Writer, Channel Reader, Web Service Sender. | `by_source_transport` in `summary.json`; per-channel `source`/`destinations`. **confirmed** |
| Filter / Transformer | Per-connector JavaScript that drops (filter) or rewrites (transformer) a message. This is where the real channel logic lives. | `main_transformer_stages` in taxonomy; L2 test target (`testing/strategy.md`). **confirmed** |
| Channel Reader / Writer | An internal source/destination that reads from or writes to another channel (channel-to-channel routing), not an external wire. | 31 channels source from a Channel Reader (`summary.json`). **confirmed** |
| messageStorageMode | Mirth setting controlling how much of each message is persisted. DEVELOPMENT stores full content + all maps (heaviest, for debugging); PRODUCTION stores enough to reprocess. | 76 PRODUCTION / 26 DEVELOPMENT (SEC-7, `security/findings.md`). **confirmed value / external semantics** |
| globalMap / configurationMap | Mirth key-value stores. globalMap is runtime state shared across channels (may not survive restart); configurationMap is deploy-time config. | Newmedica routing tables in globalMap (`globalMap:hospitalMapping`); `defaultPatientIdentifierType` in configurationMap. **confirmed** |

## HL7 and messaging

| Term | Definition | In this corpus |
|---|---|---|
| HL7v2 | Pipe-delimited healthcare messaging standard used for PAS feeds. | PAS Inbound message format (`hl7/hl7-behaviour.md`). **confirmed** |
| ADT | HL7 "Admit/Discharge/Transfer" message class carrying patient demographics and movements (trigger events A01 admit, A05 pre-admit, A08 update, A40 merge, etc.). | PAS Inbound channels parse ADT into PASAPI calls. **confirmed** |
| SIU | HL7 "Scheduling Information Unsolicited" message class carrying appointments. | Feeds PASAPI PatientAppointment where present (`hl7/hl7-behaviour.md`). **confirmed** |
| ACK | HL7 acknowledgement returned to the sender. | `ack_behaviour` per channel (taxonomy / `hl7`). **confirmed** |
| MLLP | Minimal Lower Layer Protocol - the framing for HL7v2 over TCP. | TCP/MLLP Listener sources (17 channels). **confirmed** |
| PDQ | Patient Demographics Query - an IHE query to an MPI for demographics. | Wales' 8 SOAP query channels (`OpenEyes Query - <board>`). **confirmed** |
| MPI | Master Patient Index - authoritative cross-system patient identity service. | NHS Wales MPI (`mpilivequeries.cymru.nhs.uk`); trust model unresolved (SEC-5). **confirmed endpoint / external role** |
| DICOM | Imaging standard; a DICOM Listener receives image instances. | 18 DICOM Listener sources; DICOM Ingestion category (15). **confirmed** |
| IOLMaster / biometry | Zeiss ophthalmic biometry device output imported for surgical planning. | DICOM channels route Zeiss IOLMaster instances to `/mnt/dicom`; IOLMaster Import category (2). **confirmed** |
| AIS | Advanced Interoperability/imaging integration unique to MEH. | MEH `AIS OUT` / `AIS Sender` (2 channels). **confirmed name / external role** |

## OpenEyes integration

| Term | Definition | In this corpus |
|---|---|---|
| OpenEyes (OE) | The ophthalmology EHR these channels feed. | Destination of PAS/document/imaging flows (`openeyes/api-usage.md`). **external** |
| PASAPI | OpenEyes' Patient Administration System API. Versioned V1/V2/V3, mapping to OE releases: **V1 = OE <= 8, V2 = OE 9-10, V3 = OE 11+**. Resources: Patient, PatientAppointment, PatientMerge, DidNotAttend, AISFlags. | `oe_api_versions` per channel; inference table in `unresolved/questions.md`. **confirmed calls / version-map user-supplied** |
| PayloadProcessor | OE asynchronous job intake at `POST /api/v1/request/queue/add`; a channel enqueues an imaging/document job rather than calling a resource directly. | PayloadProcessor Submission category (5); `uses_payload_processor` flag. **confirmed** |
| Document API | OE document intake: `/api/v1/Document` and Optegra's `/api/v2/Document/{create,search,update}`. | Document Ingestion (6) / Outbound (13); `openeyes/api-usage.md`. **confirmed** |
| `web` (host) | The internal service name of the co-located OpenEyes web container. `http://web/...` is a Mirth-to-OE call inside the deployment, not an external hop. | 294 plaintext endpoints target `web` (SEC-1). Only MEH calls an external FQDN over TLS. **confirmed** |

## Security, auth, and this project's model

| Term | Definition | In this corpus |
|---|---|---|
| HTTP Basic (preemptive) | Username:password sent on every request in the Authorization header, no session. | The estate's OE auth method; stateless per message (`auth/persisted-login.md`). **confirmed** |
| Shared `api` credential | A single service-account password reused across the whole estate (356 identical occurrences). | SEC-2; blast-radius finding. Value never stored - see redaction. **confirmed** |
| Redaction placeholder | `${REDACTED_PASSWORD}` etc. - a secret value removed from the canonical copies and logged by length only, filled from a secret store at **deploy** time; never in version control. | `secrets/redaction-log.csv`; `canonical/NORMALISATION-RULESET.md`. **confirmed** |
| Site-parameter token | `${LISTEN_PORT}`, `${BOARD_CODE}`, ... - a per-site value lifted into a template and filled from `sites.csv` at **render** time; safe to commit. | `templates/README.md` (two-placeholder-class model). **confirmed** |
| Canonical copy | The redacted + noise-normalised single-channel file under `canonical/` used for all analysis; the raw export is never modified. | `canonical/`, `_manifest.csv`; determinism verified. **confirmed** |
| Template family | A set of channels that are line-aligned clones of one exemplar, parameterised into one template. | `pas-inbound-newmedica-local` (28), `pas-query-mpi-wales` (8). **confirmed** |
| Replay safety / idempotency | Whether re-sending the same message is harmless. Reads/upserts are safe; merges, job-enqueues and document-creates are not (may duplicate or mis-merge). | `reliability.safe_to_replay` per channel; classification table in `testing/strategy.md`. **confirmed flag / inferred idempotency** |
| Shared lineage | A channel `id` (or name) that recurs across instances - which does **not** guarantee the same function; several drifted into different categories. | 12 shared ids (`summary.json` `shared_channel_ids`; `comparisons/shared-lineage-diffs.md`). **confirmed** |

## Reading rule for agents

Trust `category`, `functional_purpose`, and the `evidence` pointers - not the channel
name. `channel_name` and even `channel_id` recur across instances under different
functions (the `06f0b8b8` lineage is one id, three names, two functions across seven
sites). Every substantive field in `channels.jsonl` carries a provenance flag and, where a
deep read was done, an `evidence` array pointing at the exact connector/script lines.
