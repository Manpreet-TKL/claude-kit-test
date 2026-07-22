---
name: project_mirth_channel_corpus_analysis
description: "Mirth/BridgeLink channel corpus analysis project - 13 client instances under ~/client-mirth-channels, 16-phase deliverable, hybrid Claude+Codex swarm."
metadata: 
  node_type: memory
  type: project
  originSessionId: 8c352cdc-6367-445c-9cdf-1167b66abe48
  modified: 2026-07-21T13:35:13.580Z
---

Started 2026-07-21. Analyse all Mirth Connect / BridgeLink channel exports under
`/home/toukan/client-mirth-channels` (READ-ONLY corpus) and produce documentation,
templates, deployment automation design, an AI knowledge corpus, and an expanded
[[c-mcchannels]] skill. Full 16-phase brief; output tree at
`/home/toukan/claude-kit/knowledge/mirth-channel-corpus/`.

Corpus facts (evidence, 2026-07-21): 13 instances (Bedford, Bolton, EK, ENHT,
Kingston, MEH, Newmedica, Optegra, Pennine, Portsmouth, Sussex, Wales), 46 XML
files, 102 channel definitions. BridgeLink versions 4.4.2 / 4.5.2 / 4.6.1.
Files are single `<channel>` or `<channelGroup>` exports; Newmedica/PAS.xml = 30
channels / 102k lines. OpenEyes APIs: PASAPI V1+V2+V3 (Patient, PatientAppointment,
PatientMerge, DidNotAttend, AISFlags) + `/api/v1` (Document create/search/update,
Patient/Search, `request/queue/add` = PayloadProcessor). Auth = HTTP Basic
preemptive, hardcoded `api`/`Password123` (REAL secret). Real hosts
(openeyes.moorfields.nhs.uk), NHS internal IPs, Welsh MPI SOAP endpoints. Connectors:
302 HTTP Sender, 109 JS Writer, 18 DICOM Listener, 17 TCP/MLLP Listener, 8 SOAP.

Approved decisions: (1) Engine = hybrid - Claude coordinates/synthesizes, Codex
smaller workers do per-channel extraction: luna-heavy (~80% mechanical slices),
terra for hard (~20%: HL7 semantics, classification, semantic diffs). NOT Sol
(too many channels). (2) Run scope = STOP at review gate after Phase 1 inventory
+ normalisation/redaction + Phase 2 taxonomy; resume Phases 3-16 only after user
review. (3) User will supply instance -> OpenEyes-version mapping for the Phase 5
compatibility matrix (request before Wave 2).

Plan file: `/home/toukan/.claude/plans/mirth-channel-corpus-dapper-micali.md`.
