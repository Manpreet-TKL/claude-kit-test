# Proposed update to the `c-mcchannels` skill (Phase 15)

> **Status: APPLIED.** Added `subs/estate-context.md` to the kit
> (`~/claude-kit/skills/c-mcchannels/`, live via the `~/.claude/skills` symlink) plus the
> one-line SKILL.md "Subs" pointer. The applied sub drops this file's "proposal" framing
> and the literal credential value; content is otherwise as below. This file is retained
> as the review/audit record.

A reviewable delta - per the kit convention, context skills are updated only on approval.
This folds what the 13-instance / 102-channel corpus analysis (`~/claude-kit/knowledge/mirth-channel-corpus`)
adds to the skill's three reference channels: a new sub `subs/estate-context.md` (content
below) plus the one-line SKILL.md pointer in "Subs"; nothing in the existing skill is
wrong and needs removing.

## Why this matters

The skill documents three reference channels from `~/mc_channels/`. All three turn out to
be **shared lineages that recur across the estate** - their channel ids are 3 of the 12
ids that appear in multiple instances. The corpus analysis gives each an estate-wide
context the skill did not have, and confirms two things the skill only implied.

| Skill reference channel | id (short) | Estate siblings (instance:name) | Categories the id lands in |
|---|---|---|---|
| PAS IN | `7a7288a3` | Bolton:PAS IN, ENHT:PAS In, Wales:PAS IN | 1 - all PAS Inbound (consistent) |
| PAS OUT | `06f0b8b8` | Bedford/Bolton/EK/Portsmouth/Sussex:PAS OUT, Kingston:OpenEyes Correspondence, Pennine:OpenEyes PAS Query | 2 - PAS Outbound **and** Document/Correspondence Outbound |
| DICOM | `c14efd23` | Bedford/Bolton/Sussex:DICOM, Optegra:**IOL** | 2 - DICOM Ingestion **and** IOLMaster/Biometry Import |

## What to add (proposed `subs/estate-context.md`)

### 1. Name != function - now with hard evidence
The skill's three references are exemplars of drift, so a reader must not assume a sibling
with the same id/name behaves the same:
- **`06f0b8b8` (PAS OUT)** is the headline case: **one id, three names, two functions**
  across seven sites. Five keep "PAS OUT" but even those split - Bolton/EK are
  reusable-with-config while Bedford/Portsmouth/Sussex drifted into client-specific;
  Kingston's copy is a Correspondence-out channel (different destinations, no OE HTTP
  call at all), and Pennine's is named "OpenEyes PAS Query".
- **`c14efd23` (DICOM)** is "DICOM" in Bedford/Bolton/Sussex but **"IOL" (IOLMaster /
  Biometry Import) in Optegra** - same lineage, different job.
- **`7a7288a3` (PAS IN)** is the reassuring counter-case: consistent PAS Inbound in all
  three siblings.
- Rule for anyone editing from these references: verify the target channel's connectors
  and transformer, do not port behaviour by id or name. Per-channel records with evidence
  pointers are in `~/claude-kit/knowledge/mirth-channel-corpus/ai-corpus/channels.jsonl`.

### 2. The secret pattern is the estate norm (confirms the skill's GOTCHA)
The skill's shipped-export credential gotcha (the reference exports embed a weak `api`
Basic password in clear - value redacted here) is not local to `~/mc_channels/`
- the **same single `api` credential recurs 356 times across the whole estate** (one shared
service account; finding SEC-2 in `security/findings.md`). The secret-safe `${VAR}` +
`OE_API_AUTH` pattern the skill describes is exactly right; the corpus formalises it into a
two-placeholder-class template model (`~/claude-kit/knowledge/mirth-channel-corpus/templates/README.md`):
- **site-parameter tokens** (`${LISTEN_PORT}`, `${BOARD_CODE}`, ...) filled from `sites.csv`
  at render time, safe to commit;
- **redaction placeholders** (`${REDACTED_PASSWORD}`) filled from a secret store at deploy
  time, never committed - the deploy-time resolution the skill's `common.js` model does.
Two template families already exist: Newmedica PAS-In (28 per-practice clones, byte-exact)
and Wales PDQ (8 per-board, logic-exact).

### 3. Security / reliability facts to apply when touching these channels
From the Phase 13 findings (`security/findings.md`), all evidence-cited and mostly
topology-conditional - flag them, do not restate them as absolutes:
- **Plaintext to `web` (SEC-1):** the OE HTTP Sender calls go to `http://web/...` (the
  co-located OE container). This is intra-deployment, not a network hop; it becomes a real
  exposure only if the Mirth<->OE segment is not isolated. MEH is the one instance that
  reaches OE across a network and correctly uses `https://openeyes.moorfields.nhs.uk`.
- **PAS OUT's HTTP Listener is unauthenticated (SEC-3):** the `06f0b8b8` PAS-OUT source is
  an HTTP Listener with `authType=NONE` (bind `0.0.0.0`, SEC-6). Anyone who can reach the
  port can post to it - relevant whenever this channel is redeployed or exposed.
- **Little queue/retry (REL-1/REL-2):** 101/102 channels have destination queueing off and
  97/102 have `retryCount=0`. Correct for synchronous query channels; a gap for the async
  PAS/DICOM/document delivery feeds, where a transient OE outage errors the message.
- **DEVELOPMENT storage mode (SEC-7):** 26/102 channels persist full message content + maps
  (heaviest retention, includes PHI). Check the target channel's `messageStorageMode`
  before assuming production-grade retention.

### 4. Where the machine-readable corpus lives
For any estate-wide question, point at `~/claude-kit/knowledge/mirth-channel-corpus/ai-corpus/`:
`summary.json` (aggregates - load first), `channels.jsonl` (per-channel record with
provenance + evidence), `glossary.md`, `schema.json`. Generic Mirth mechanics stay in
`c-mirth`; PASAPI endpoint detail stays in `c-pasapi`; this skill stays the per-channel
reference and now also the entry point to the wider corpus.

## Proposed SKILL.md edit (one line, in the "Subs" list)

```
- `subs/estate-context.md` - how the three reference channels sit in the 13-instance
  estate: shared-lineage drift (name != function), the estate-wide shared `api` secret,
  the template model, and the security/reliability findings. Full corpus: ~/claude-kit/knowledge/mirth-channel-corpus.
```

## Not proposed
No change to the skill's channel table, port/destination detail, or the `common.js`
secrets model - the corpus corroborates them. The three reference ids' per-instance
connector params (ports especially) **differ** across siblings; this update deliberately
does not copy sibling ports into the skill, since the corpus (`networking/port-map.md`)
already shows there is no estate port convention.
