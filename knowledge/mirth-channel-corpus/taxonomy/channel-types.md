# Channel taxonomy (Phase 2)

Functional classification of all **102 canonical channels** across the 13 client
instances. Each channel was read in full (redacted `canonical/` copy) and classified
against the controlled vocabulary in `taxonomy/_schema.json`. The judgement work was
done by a swarm of Codex `terra` workers, one per instance (Newmedica split into three
batches); every field in every record carries at least one evidence pointer to the
connector / filter / transformer / script it came from. The full per-channel records
live in `taxonomy/channel-types.json` and the per-batch `taxonomy/_slices/*.json`.

**Read this before trusting a name.** Channel name, file name and even channel `id` do
**not** imply function - 12 channel ids recur across instances, some under different
names and different categories (see "Shared lineage" below). Every category assignment
here is backed by connector/script evidence, not by the channel's name.

Confidence: **96 of 102** records are `confirmed` (read directly in the XML); 6 are
`inferred` (all of Pennine - see caveats).

## Categories in use

Nine of the eleven vocabulary categories are populated; `Routing / Utility` and
`Other` were not needed - every channel fit a substantive category.

| Category | Count | What it does | Canonical example (evidence) |
|---|---|---|---|
| PAS Inbound (HL7 -> PASAPI) | 42 | Receives HL7v2 ADT/SIU from a hospital PAS (MLLP listener) and pushes patient/appointment data into OpenEyes PASAPI | Newmedica `PAS In LOCAL-*` (28 per-practice clones); Wales `PAS IN` (id `7a7288a3`, shared with Bolton/ENHT) |
| DICOM Ingestion | 15 | DICOM Listener receives imaging, writes to a store and/or submits to OpenEyes | shared DICOM id `da67d2ba` in EK/ENHT/Kingston/Pennine/Portsmouth/Wales |
| Document / Correspondence Outbound | 13 | Pushes OpenEyes-generated correspondence out to a file share / SFTP / downstream system | Bedford `Document OUT` (id `375fe7b2`, shared with Sussex `Document Delivery`); ENHT/MEH/Optegra `Docman` + Portsmouth `DOCUMENT-OUT-Minestrone` (shared id `04524f4d`: `File Reader /mnt/docman -> File Writer <remote>`) |
| PAS Outbound (query/response to remote PAS) | 9 | Sends a query or response back toward a remote PAS, typically HTTP-in then MLLP/TCP-out | PAS-OUT id `06f0b8b8` (7 instances) |
| PAS Query / PDQ (MPI SOAP) | 8 | SOAP (Web Service Sender) PDQ query to an MPI; all 8 are Wales per-health-board channels | Wales `OpenEyes Query - <board>` (ABUHB, BCUHB x2, CTMUHB, CVUHB, HDUHB, PTHB, SBUHB) |
| Document / Correspondence Ingestion | 6 | File Reader / listener picks up inbound documents and posts to the OpenEyes Document API | Portsmouth `DOCUMENTS IN HL7` / `General Documents IN`; Optegra `Document Migration`; Newmedica `OpenEyes Document In` |
| PayloadProcessor Submission | 5 | Submits an imaging/document job to `/api/v1/request/queue/add` (PayloadProcessor) | Bedford `Document Upload PP` (id `f703f9cd`) |
| IOLMaster / Biometry Import | 2 | Imports IOLMaster / biometry device output | Optegra `IOL` (id `c14efd23`); Kingston `OpenEyes DICOM IOLMaster Channel` (id `eee5caa4`) |
| AIS Integration | 2 | AIS in/out; unique to MEH | MEH `AIS OUT`, `AIS Sender` |

## Composition per instance

Columns are the categories above (PAS-In, PAS-Out, PDQ, DICOM, IOL, Doc-In, Doc-Out,
PP = PayloadProcessor, AIS).

| Instance | PAS-In | PAS-Out | PDQ | DICOM | IOL | Doc-In | Doc-Out | PP | AIS | Total |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| Bedford | 1 | 1 | | 1 | | | 1 | 1 | | 5 |
| Bolton | 1 | 1 | | 1 | | | 1 | | | 4 |
| EK | 2 | 1 | | 1 | | | 3 | | | 7 |
| ENHT | 1 | 1 | | 1 | | | 1 | | | 4 |
| Kingston | 1 | | | 1 | 1 | | 1 | 1 | | 5 |
| MEH | 1 | 1 | | 1 | | | 1 | | 2 | 6 |
| Newmedica | 29 | 1 | | 1 | | 1 | 1 | 2 | | 35 |
| Optegra | 1 | | | 1 | 1 | 1 | 1 | 1 | | 6 |
| Pennine | 1 | 1 | | 4 | | | | | | 6 |
| Portsmouth | 1 | 1 | | 1 | | 4 | 2 | | | 9 |
| Sussex | 2 | 1 | | 1 | | | 1 | | | 5 |
| Wales | 1 | | 8 | 1 | | | | | | 10 |
| **Total** | **42** | **9** | **8** | **15** | **2** | **6** | **13** | **5** | **2** | **102** |

Shape of the estate: PAS inbound dominates (42, of which 28 are Newmedica per-practice
clones); Wales is almost entirely PDQ/MPI; MEH is the only AIS site; IOLMaster/biometry
is a two-channel long tail.

## Shared lineage (name and id do not imply function)

12 channel ids recur across instances. Most keep one function, but several were cloned
and then drifted - the same id now serves a different purpose under a different name.
This is the core reason classification is evidence-based, not name-based.

| Channel id (short) | Instances | Names seen | Distinct categories |
|---|--:|---|--:|
| `06f0b8b8` | 7 | PAS OUT (x5), OpenEyes Correspondence (Kingston), OpenEyes PAS Query (Pennine) | 2 |
| `da67d2ba` | 6 | DICOM / DICOM_11118 | 1 |
| `c14efd23` | 4 | DICOM (x3), IOL (Optegra) | 2 |
| `d69815ee` | 4 | PAS IN / PAS IN V2 | 1 |
| `04524f4d` | 4 | Docman (x3), DOCUMENT-OUT-Minestrone (Portsmouth) | 1 |
| `7a7288a3` | 3 | PAS IN / PAS In | 1 |
| `375fe7b2` | 2 | Document OUT, Document Delivery | 1 |
| `f703f9cd` | 2 | Document Upload PP, General Documents IN | 2 |
| `7a04b9d1` | 2 | CORRESPONDENCE OUT, Filedrop Correspondence | 1 |
| `ba5419a3` | 2 | OpenEyes DICOM Channel | 2 |
| `eee5caa4` | 2 | OpenEyes DICOM IOLMaster Channel | 2 |
| `6c3a10d1` | 2 | OpenEyes PAS | 1 |

The `06f0b8b8` group is the headline case: one lineage, three names, two functions
across seven sites. `c14efd23` and `f703f9cd` are similar. The `ba5419a3` /
`eee5caa4` pairs (Kingston vs Pennine, same id and name) landed in two categories - a
classification split flagged for reconciliation (see caveats).

## Reusable vs client-specific

| Class | Count | Meaning |
|---|--:|---|
| reusable-with-config | 61 | Same core logic, differs only by parameters (endpoint, port, practice id, board code) - the template candidates |
| client-specific | 41 | Bespoke logic that would not transfer without rework |

The reusable-with-config majority is the evidence base for Phase 9 templating: the
Wales PDQ-8 and Newmedica PAS-In-28 families alone are 36 near-identical channels.

## OpenEyes API surface

PASAPI version tokens observed per instance (corroborates and sharpens the Phase 1
inference in `unresolved/questions.md`):

| Instance | V1 | V2 | V3 | api/v1 | Notes |
|---|--:|--:|--:|--:|---|
| Bedford | 1 | 1 | | 2 | mixed V1+V2 |
| Bolton | 1 | 1 | | 1 | mixed V1+V2 |
| EK | | 2 | | 1 | V2 |
| ENHT | | 1 | | 1 | V2 |
| Kingston | | 1 | | 3 | V2 |
| MEH | 1 | 2 | | 1 | mixed V1+V2 |
| Newmedica | 30 | | 28 | 3 | **mid-migration V1 -> V3** |
| Optegra | | 1 | | 3 | V2 (+ one `api/v2`, see caveats) |
| Pennine | 1 | | | 4 | V1 |
| Portsmouth | | 1 | | 5 | V2 |
| Sussex | 2 | 2 | | 1 | mixed V1+V2 |
| Wales | 1 | | | 1 | V1 |

Newmedica is the standout: its per-practice PAS-In fleet straddles PASAPI V1 (OE <=8)
and V3 (OE 11+), i.e. an in-progress migration, not a single OE release. Exact OE
releases remain user-supplied per `unresolved/questions.md`.

## Caveats and reconciliation items

> Update: caveats 1-3 below were settled by the Wave 2 deep-read and the Phase 8
> logic diff. Pennine is now `confirmed` (caveat 1); Optegra `api/v2/Document` is a
> real endpoint (caveat 2, `openeyes/api-usage.md`); the `ba5419a3`/`eee5caa4`
> Kingston-vs-Pennine split was a labelling difference on logic-identical channels
> (caveat 3, `comparisons/shared-lineage-diffs.md`). The text below is the original
> Phase 2 record.
>
> Correction (Phase 16 reconciliation): the "Composition per instance" matrix and two
> category examples above were regenerated from the authoritative
> `taxonomy/channel-types.json` (the source of `ai-corpus/channels.jsonl`), which
> disagreed with the original hand-tallied markdown on two points - see caveat 5. The
> category **totals** were already correct; only the per-instance distribution and the
> Doc-In / IOL examples were wrong. All other tables are unchanged.


1. **Pennine confidence.** All 6 Pennine records are marked `inferred` while every
   other instance is `confirmed`. The classifications are consistent with the shared-id
   lineage (e.g. Pennine `DICOM_11118` shares id `da67d2ba`; `OpenEyes PAS` shares
   `6c3a10d1` with Kingston), so this reads as conservative labelling by that one
   worker rather than weaker evidence. Cheap to re-affirm on request.
2. **Optegra `api/v2`.** `Document Migration` cites an `api/v2` endpoint; the Phase 1
   inventory only recorded `api/v1`. Single-source observation - reconcile against the
   raw XML in Phase 5 (OE API) before relying on it.
3. **`ba5419a3` / `eee5caa4` category split.** Kingston and Pennine share these ids and
   names but were classified into two categories by their separate workers. Confirm
   whether this is a genuine functional difference or a labelling inconsistency during
   the Phase 8 semantic diff.
4. **Protocol / message-format strings** in the JSON are each worker's free-text
   phrasing (e.g. "MLLP and HTTP" vs "HTTP / MLLP"); the category and connector fields
   are the normalised signal. Canonicalisation of these strings is deferred to Phase 8.
5. **Matrix corrected against the JSON (Phase 16) - two markdown-only errors.** The
   original hand-tallied composition matrix mis-placed:
   (a) the ENHT/MEH "Docman" channels (shared id `04524f4d`) under **Doc-In**; the
   connectors are `File Reader /mnt/docman -> File Writer <remote host>` (the sibling is
   named `DOCUMENT-OUT-Minestrone`), so they are **Doc-Out** document delivery, no OE
   ingestion. Confirmed Doc-In is only Newmedica / Optegra / Portsmouth.
   (b) Kingston's IOLMaster channel (`eee5caa4`) as a document channel, and cited
   Portsmouth `IOL Documents IN` as the second **IOL** example - but that Portsmouth
   channel is Document ingestion (name != function); the two real IOL channels are
   Optegra `IOL` and Kingston `OpenEyes DICOM IOLMaster Channel`.
   The authoritative `channel-types.json` was correct on both; the markdown matrix and
   the Doc-In/IOL examples are now regenerated to match it. Downstream artifacts
   (`ai-corpus/`, `dataflows/integration-overview.md`) already used the JSON and needed
   no change.

## Files

- `taxonomy/channel-types.json` - merged machine-readable records (102), category
  counts, shared-id index; one object per channel matching `_schema.json`.
- `taxonomy/_slices/*.json` - the 14 per-batch worker outputs (audit trail).
- `taxonomy/_schema.json` - the record schema and category vocabulary.
