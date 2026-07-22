# Shared-lineage semantic diffs (Phase 8)

The 12 channel ids that recur across instances, diffed at the logic level. Method: a
deterministic logic-signature (source transport, destination-connector name set, and the
sha1 of every normalised `<script>` body) computed per channel from `canonical/`, then
compared within each id group; the objective result in `comparisons/_logic-diff.json` is
cross-checked against the Phase 4-6 deep records (`deepdive/_slices/*.json`). "Logic
identical" means source + destination names + every script body match byte-for-byte after
whitespace normalisation, so any remaining difference is confined to connector parameters
(ports, endpoints, credentials, ids).

## Verdict summary

| id | n | Instances | Names | Verdict | Delta |
|---|--:|---|---|---|---|
| `06f0b8b8` | 7 | Bedford,Bolton,EK,Kingston,Pennine,Portsmouth,Sussex | PAS OUT / OpenEyes PAS Query / OpenEyes Correspondence | **6 parameterised clones + 1 hard fork** | 6 are the QBP/K21 PAS-query pattern (EK adds a test destination); **Kingston forked the id into a completely different ORU correspondence router** |
| `da67d2ba` | 6 | EK,ENHT,Kingston,Pennine,Portsmouth,Wales | DICOM / DICOM_11118 | **Logic identical** | connector parameters only (DICOM port, /mnt path) |
| `c14efd23` | 4 | Bedford,Bolton,Optegra,Sussex | DICOM / IOL | **Parameterised clone** | same source + destinations; Optegra merely renamed it "IOL"; Bolton has one extra transformer step |
| `d69815ee` | 4 | Bedford,Optegra,Portsmouth,Sussex | PAS IN / PAS IN V2 | **Parameterised clone (additive)** | common PASAPI+Clinic core; Bedford adds a "Send to MEH" forward, Sussex/Bedford add a no-op destination |
| `04524f4d` | 4 | ENHT,MEH,Optegra,Portsmouth | Docman / DOCUMENT-OUT-Minestrone | **Parameterised clone** | file-in -> SFTP-out mover with ~no transformer; endpoints only (Optegra adds a "Nothing to do" no-op) |
| `7a7288a3` | 3 | Bolton,ENHT,Wales | PAS IN / PAS In | **Parameterised clone (additive)** | common PASAPI+Clinic core; Bolton adds a "Clinic List - DNA" destination |
| `375fe7b2` | 2 | Bedford,Sussex | Document OUT / Document Delivery | **Logic identical** | destination file share only |
| `f703f9cd` | 2 | Bedford,Portsmouth | Document Upload PP / General Documents IN | **Minor functional drift** | both submit to PayloadProcessor; Portsmouth prepends a Patient Search destination |
| `7a04b9d1` | 2 | Bolton,EK | CORRESPONDENCE OUT / Filedrop Correspondence | **Logic identical** | source folder + destination share only |
| `ba5419a3` | 2 | Kingston,Pennine | OpenEyes DICOM Channel | **Logic identical** | DICOM port + parameters only |
| `eee5caa4` | 2 | Kingston,Pennine | OpenEyes DICOM IOLMaster Channel | **Logic identical** | DICOM port + parameters only |
| `6c3a10d1` | 2 | Kingston,Pennine | OpenEyes PAS | **Drifted by PASAPI version** | identical structure (same 3 destinations, 12 scripts) but script bodies differ: Kingston calls PASAPI V2, Pennine V1 |

Five groups are logic-identical; five are parameterised clones (two with additive per-site
destinations); one drifted by API version; one contains a genuine hard fork.

## The headline: `06f0b8b8` (name != function, proven)

One lineage, three names, two functions across seven sites:

- **Six sites** (Bedford, Bolton, EK, Pennine, Portsmouth, Sussex) run it as the
  PAS-outbound query: an HTTP-triggered QBP to a remote PAS, `Convert K21 to XML` ->
  `Create response` -> `Send Q21`. Script counts vary 5-9 (per-site response tweaks); EK
  carries an extra `Send Q21 test empi` test destination. These are parameterised siblings.
- **Kingston** kept the same channel id but rewrote it into an **ORU (R01) correspondence
  router** - source `/mnt/docman` RTF files, destinations `Send HL7 to Cerner` and
  `Send JSON to DocMan` (deep record `deepdive/_slices/Kingston.json`). It shares nothing
  functional with the other six.

This is the single strongest piece of evidence that channel id and name cannot be trusted
to imply function, and why every classification in this project is connector/script-based.

## Phase 2 caveats closed by this diff

1. **`ba5419a3` / `eee5caa4` "category split" (Kingston vs Pennine) - resolved: labelling,
   not function.** Both ids are **logic-identical** across Kingston and Pennine (source,
   destination names and every script body match). The two Phase 2 workers put them in
   different categories; the channels themselves are the same. Reclassify both consistently.
2. **`c14efd23` DICOM-vs-IOL split - resolved: a rename, not a fork.** Optegra's "IOL" is
   the standard DICOM-ingestion channel (same source, same `getDicomHeaders` /
   `PayloadProcessor API Send` / IOLMaster-file destinations). The name differs; the
   function does not. Bolton's one extra script is a minor per-site step, not a category
   change.
3. **`6c3a10d1` (Kingston/Pennine OpenEyes PAS) - same lineage, split by migration.**
   Identical destination structure; the script bodies differ only because Kingston moved to
   PASAPI V2 while Pennine remains on V1. This is the version axis a template parameterises,
   not two different channels.

## Method note

This diff was produced deterministically (structural logic-signature) and reconciled with
the existing deep records, rather than by re-spawning per-channel judgment agents to
re-read the same XML - the objective script-hash comparison plus the Phase 4-6 semantic
records already establish same-vs-drifted with evidence. If an independent second read of
the two non-trivial cases (`06f0b8b8` Kingston fork, `6c3a10d1` V1/V2 mapping delta) is
wanted for the record, that is a small terra escalation on request.
