# Estate context: the three reference channels across 13 instances

The three channels this skill documents (from `~/mc_channels/`) are not one-offs - each
is a **shared lineage that recurs across the wider client estate**. Their channel ids are
3 of the 12 ids that appear in more than one instance. The full 13-instance / 102-channel
analysis is at `~/claude-kit/knowledge/mirth-channel-corpus/`; this sub distils what it adds.

| Skill reference channel | id (short) | Estate siblings (instance:name) | Categories the id lands in |
|---|---|---|---|
| PAS IN | `7a7288a3` | Bolton:PAS IN, ENHT:PAS In, Wales:PAS IN | 1 - all PAS Inbound (consistent) |
| PAS OUT | `06f0b8b8` | Bedford/Bolton/EK/Portsmouth/Sussex:PAS OUT, Kingston:OpenEyes Correspondence, Pennine:OpenEyes PAS Query | 2 - PAS Outbound **and** Document/Correspondence Outbound |
| DICOM | `c14efd23` | Bedford/Bolton/Sussex:DICOM, Optegra:**IOL** | 2 - DICOM Ingestion **and** IOLMaster/Biometry Import |

## 1. Name != function - with hard evidence

These three references are exemplars of clone-and-drift, so do **not** assume a sibling
with the same id/name behaves the same:

- **`06f0b8b8` (PAS OUT)** is the headline case: **one id, three names, two functions**
  across seven sites. Five keep the "PAS OUT" name but even those split by reuse class -
  Bolton/EK are `reusable-with-config`, Bedford/Portsmouth/Sussex drifted into
  `client-specific`. Kingston's copy is `OpenEyes Correspondence`, a document-outbound
  channel (different destinations, no OE HTTP call at all); Pennine's is named
  `OpenEyes PAS Query` (and is `inferred`, not directly confirmed).
- **`c14efd23` (DICOM)** is DICOM Ingestion in Bedford/Bolton/Sussex but **`IOL`
  (IOLMaster / Biometry Import) in Optegra** - same lineage, different job.
- **`7a7288a3` (PAS IN)** is the reassuring counter-case: consistent PAS Inbound,
  `reusable-with-config`, in all three siblings.

Rule when editing from these references: verify the target channel's connectors and
transformer; do not port behaviour by id or name. Per-channel records with evidence
pointers are in `~/claude-kit/knowledge/mirth-channel-corpus/ai-corpus/channels.jsonl`.

## 2. The secret pattern is the estate norm (confirms the GOTCHA)

This skill's shipped-export credential gotcha (the reference exports embed a weak `api`
Basic password in clear - value redacted in the corpus) is not local to `~/mc_channels/`:
the **same single `api` credential recurs 356 times across the whole estate** (one shared
service account; finding SEC-2). The secret-safe `${VAR}` + `OE_API_AUTH` pattern this
skill describes is exactly right; the corpus formalises it into a two-placeholder-class
template model (`~/claude-kit/knowledge/mirth-channel-corpus/templates/README.md`):

- **site-parameter tokens** (`${LISTEN_PORT}`, `${BOARD_CODE}`, ...) filled from
  `sites.csv` at **render** time - safe to commit;
- **redaction placeholders** (`${REDACTED_PASSWORD}`) filled from a secret store at
  **deploy** time - never committed (the deploy-time resolution the `common.js` model does).

Two template families already exist: Newmedica PAS-In (28 per-practice clones, byte-exact)
and Wales PDQ (8 per-board, logic-exact).

## 3. Security / reliability facts when touching these channels

From the Phase 13 findings (`~/claude-kit/knowledge/mirth-channel-corpus/security/findings.md`) - all
evidence-cited and mostly topology-conditional; flag them, do not restate as absolutes:

- **Plaintext to `web` (SEC-1):** OE HTTP Sender calls go to `http://web/...` (the
  co-located OE container). This is intra-deployment, not a network hop; a real exposure
  only if the Mirth<->OE segment is not isolated. MEH is the one instance that reaches OE
  across a network and correctly uses `https://openeyes.moorfields.nhs.uk`.
- **PAS OUT's HTTP Listener is unauthenticated (SEC-3):** the `06f0b8b8` PAS-OUT source is
  an HTTP Listener with `authType=NONE`, bind `0.0.0.0` (SEC-6). Anyone who can reach the
  port can post to it - relevant whenever this channel is redeployed or exposed.
- **Little queue/retry (REL-1/REL-2):** 101/102 channels have destination queueing off and
  97/102 have `retryCount=0`. Correct for synchronous query channels; a gap for the async
  PAS/DICOM/document-delivery feeds, where a transient OE outage errors the message.
- **DEVELOPMENT storage mode (SEC-7):** 26/102 channels persist full message content + maps
  (heaviest retention, includes PHI). Check the target channel's `messageStorageMode`
  before assuming production-grade retention.

## 4. The machine-readable corpus

For any estate-wide question, point at `~/claude-kit/knowledge/mirth-channel-corpus/ai-corpus/`:
`summary.json` (aggregates - load first), `channels.jsonl` (per-channel record with
provenance + evidence), `glossary.md`, `schema.json`. Generic Mirth mechanics stay in
`c-mirth`; PASAPI endpoint detail stays in `c-pasapi`; this skill stays the per-channel
reference and is now also the entry point to the wider corpus.
