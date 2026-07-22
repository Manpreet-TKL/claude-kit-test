# Mirth / BridgeLink channel corpus - analysis output

Generated analysis of the exported Mirth Connect / BridgeLink configuration under
`/home/toukan/client-mirth-channels` (13 client instances, 102 channels). The corpus
is treated as **read-only**; everything here is generated into this directory.

Full brief: analyse -> document -> template -> deploy, delivered in waves. All six
waves are complete: **Wave 0 (canonicalise + redact), Wave 1 (Phase 1 inventory,
Phase 2 taxonomy), Wave 2 (Phase 3 networking, Phase 4 HL7, Phase 5 OpenEyes API,
Phase 6 auth/session, Phase 7 dataflows), Wave 3 (Phase 8 commonality + semantic
diffs), Wave 4 (Phase 9 templates, Phase 10 overlay/repo model, Phase 11 deployment
automation), Wave 5 (Phase 12 testing strategy, Phase 13 security/reliability
findings) and Wave 6 (Phase 14 AI knowledge corpus, Phase 15 c-mcchannels skill
update proposal, Phase 16 integration dataflow overview)**. All 16 phases delivered.

## Layout
```
bin/                     deterministic build scripts (re-runnable, byte-identical output)
  build_canonical.py       split channelGroups -> per-channel, redact secrets, normalise noise
  build_inventory.py       structural inventory over canonical/
canonical/               one redacted+normalised <channel> per file, per instance
  NORMALISATION-RULESET.md the canonicalisation contract (what is redacted / normalised)
  _manifest.csv          channel identity + hashes
secrets/
  redaction-log.csv      every redacted secret: location + type + placeholder (NO values)
inventory/
  corpus-inventory.json  full per-channel structural record
  channels.csv           one flat row per channel
  dependencies.csv       config/global-map + routing dependencies
  versions.md            BridgeLink versions, PASAPI->OE inference, shared-lineage IDs
unresolved/              open questions requiring user input (added per wave)
taxonomy/                Phase 2 channel classification (evidence-cited)
  channel-types.md       human-readable taxonomy: 9 categories, per-instance matrix
  channel-types.json     merged machine records (102), category + shared-id index
  _schema.json           per-channel record schema + category vocabulary
  _slices/               14 per-batch Codex terra worker outputs (audit trail)
networking/              Phase 3 ports + network dependencies
  port-map.md            de-facto port conventions, anomalies, outbound/external hosts
  port-map.csv           every listen/outbound endpoint (67 rows)
deepdive/                Phase 4-6 per-channel deep records (HL7 + OE API + auth)
  _schema.json           deep-record schema
  _slices/               12 per-instance Codex terra worker outputs (76 records)
hl7/hl7-behaviour.md     Phase 4: message classes, versions, ACK, field maps
openeyes/api-usage.md    Phase 5: PASAPI V1/V2/V3 + api/v1,v2 endpoint usage
auth/persisted-login.md  Phase 6: stateless per-message Basic; no session persistence
dataflows/dataflows.md   Phase 7: 5 pipeline archetypes (Mermaid) + cross-channel routing
dataflows/integration-overview.md  Phase 16: estate-level system integration (external systems, boundaries, coupling/SPOF)
comparisons/             Phase 8 commonality + semantic diffs
  shared-lineage-diffs.md  12 shared-id verdicts (identical / clone / drifted / fork)
  commonality.md         6 archetypes: common core vs parameter axes; clone families
  _logic-diff.json       deterministic logic-signature diff (audit trail)
templates/               Phase 9 parameterised channel templates (self-verifying)
  README.md              template model: two placeholder classes, render, families
  pas-inbound-newmedica-local/  channel.template.xml + sites.csv + params.json (28 sites, byte-exact)
  pas-query-mpi-wales/          channel.template.xml + sites.csv + params.json (8 boards, logic-exact)
deployment/              Phase 10-11 deployment design
  overlay-model.md       base template + per-site overlay repository model; feature overlays
  deployment-automation.md  render -> validate -> inject secrets -> deploy -> verify pipeline
testing/                 Phase 12 testing strategy
  strategy.md            layered tests (render-back, static lint, transformer, integration); synthetic-only data; replay-safety
security/                Phase 13 security + reliability findings
  findings.md            SEC/REL findings, severities, recommendations (evidence-cited)
  security-scan.csv      per-channel deterministic audit trail (transport, auth, scheme, queue, retry)
ai-corpus/               Phase 14 machine-readable knowledge corpus for AI agents
  channels.jsonl         one consolidated per-channel record (102), provenance + evidence
  summary.json           estate aggregates (load first for grounding)
  schema.json            record schema: every field -> meaning + source artifact
  glossary.md            domain glossary (PASAPI, PDQ, MPI, PayloadProcessor, MLLP, ...)
skill/                   Phase 15 c-mcchannels skill update
  c-mcchannels-update.md reviewable proposal (not applied): estate context for the 3 reference channels
```

## Regenerate
```
python3 bin/build_canonical.py     # corpus -> canonical/ + secrets/redaction-log.csv
python3 bin/build_inventory.py     # canonical/ -> inventory/
python3 bin/build_templates.py     # canonical/ -> templates/ (renders back + self-verifies)
python3 bin/build_security_scan.py # canonical/ -> security/security-scan.csv (+ aggregates)
python3 bin/build_ai_corpus.py     # joins all wave artifacts -> ai-corpus/ (channels.jsonl + summary + schema)
```

## Rules honoured
- No secret value or patient-identifiable data appears in any generated file.
- No original export is modified (verified: corpus mtime unchanged across runs).
- Every inventory fact is structural extraction; judgement-based classification
  (taxonomy and later phases) is produced separately with per-claim evidence.

## Evidence conventions
Cite `instance / channel-name / channel-id / source-file / connector-or-script`.
Name != function: 12 channel ids recur across instances, some under different names.
Confidence is marked `confirmed` (read directly) or `inferred`.
