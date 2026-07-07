---
name: c-mcchannels
description: The three OE BridgeLink integration channels
disable-model-invocation: true
---

# OE BridgeLink channels (mc_channels)

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

The three OpenEyes integration channels exported under `~/mc_channels/`, running
on BridgeLink 4.6.1 (the `mc` container). Generic Mirth/BridgeLink mechanics,
REST recipes, lifecycle, and gotchas: the `c-mirth` skill. OE PASAPI endpoint detail
and the PAS flow: the `c-pasapi` skill. This skill covers what each *channel* does.

## The channels

| Channel | Dir | Source connector (port) | Destinations | OE endpoint(s) |
|---|---|---|---|---|
| PAS IN | inbound | TCP MLLP Listener `:6661` | 6 x HTTP Sender | `PUT http://web/PASAPI/...` |
| PAS OUT | outbound | HTTP Listener `:6663` | 4 (TCP Sender + 3 JS Writer) | TCP MLLP -> remote PAS |
| DICOM | inbound | DICOM Listener `:11112` | 3 (JS + File + HTTP) | `POST http://web/api/v1/request/queue/add` |

PAS IN's 6 destinations (metaDataId / name):
`1` PASAPI - Patient, `5` PASAPI - Secondary Patient, `2` Clinic List - PUT,
`3` Clinic List - DELETE, `4` PASAPI - Patient Merge, `6` Clinic List - DNA.
PAS OUT's destinations: `1` Send Q21 (TCP Sender), `4` Convert K21 to XML,
`5` Create response, `6` Respond (last three are JavaScript Writers).
DICOM's destinations: `7` getDicomHeaders (JS), `1` File Writer (IOLMaster
import), `6` PayloadProcessor API Send (HTTP). Per-destination wiring is in
`subs/connectors.md`; PAS IN's message processing is in `subs/pasin-processing.md`.

## Secret-safe config pattern

The committed channel XML should hold only `${VAR}` placeholders; the global
Deploy script (template `common.js`) resolves each var (`/run/secrets` -> env ->
configurationMap -> default) into `globalMap` at deploy time, and pre-builds the
derived `OE_API_AUTH` = `Basic <base64(user:pass)>` header that the HTTP Sender
destinations send (because Velocity does NOT substitute HTTP Sender
`username`/`password`). See `subs/secrets-config.md` and the `c-mirth` skill.

## GOTCHA: shipped exports are NOT secret-safe

The copies in `~/mc_channels/` are raw exports that embed `api:Password123`
inline in every HTTP Sender - **PAS IN has 6 occurrences of `Password123`,
DICOM has 1, PAS OUT has 0** (it has no HTTP Sender; its TCP Sender carries no
auth). They are therefore unsafe to commit as-is. Templating them into
`${VAR}` + `OE_API_AUTH` is exactly what the oe-deploy automation does before
import. `LOCAL-1-0` is also hardcoded throughout (5x in PAS IN, 3x in DICOM)
and should become `${OE_IDENTIFIER_TYPE}`.

## Key anchors

- `~/mc_channels/PAS IN.xml` - id `7a7288a3-5ade-46bc-921d-56baf0a6bf06`
- `~/mc_channels/PAS OUT.xml` - id `06f0b8b8-5ea0-41a4-a0bc-04b89fb5193c`
- `~/mc_channels/DICOM.xml` - id `c14efd23-2c1c-4e53-a59f-dcfe0e727c3b`

## Subs

- `subs/pasin-processing.md` - PAS IN HL7 parsing + the duplicated-transformer
  problem and the code-template refactor.
- `subs/connectors.md` - per-channel connector config, ports, framing, hardcoded
  hosts to template, the `OE_API_AUTH` header workaround.
- `subs/secrets-config.md` - the `common.js` globalMap resolution model and the
  secret-free-export rules.
