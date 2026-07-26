---
name: c-mirth-estate
description: How the client Mirth estate behaves - flows, filters, per-site deltas
disable-model-invocation: false
---

# Mirth estate - how the channels behave

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

The **rules layer** for 102 BridgeLink channels across 12 client sites: what every channel does the same way, and where each site departs from it. Answer behavioural questions from this file. The corpus at `~/mirth-channel-corpus/` is provenance, not a dependency - never open it to ask "how does this behave" (`taxonomy/channel-types.json` alone is 108k tokens, one canonical XML up to 49k).

Hosts, endpoints and credentials are deliberately absent throughout - none has ever been the answer to a behaviour question. Ports and paths are here because they identify *which feed is which*.

## The estate

BridgeLink version and full channel lists are in the site files; this is what changes an answer.

| Site | Ch | PASAPI | Inbound HL7 | HL7 |
|---|--:|---|---|---|
| Bedford | 5 | V2, merge V1 | 6661 | 2.4 |
| Bolton | 4 | V2, merge V1 | 6661 | 2.4 |
| EK | 7 | V2 | 6661, 6671 | 2.3 |
| ENHT | 4 | V2 | 6661 | 2.4 |
| Kingston | 5 | V2 | 6662 | - |
| MEH | 6 | V2, merge V1 | 6661 | 2.4 |
| Newmedica | 35 | V1 -> V3 | 8558, 8559 | 2.4 |
| Optegra | 6 | V2 | 6661 | 2.4 |
| Pennine | 6 | V1 | 6662 | 2.4 |
| Portsmouth | 9 | V2 | 6661 | 2.4 |
| Sussex | 5 | V2, merge V1 | 6661, 6662 | 2.4 |
| Wales | 10 | V1 | 6661 | 2.4 |

Categories: PAS Inbound 42, DICOM Ingestion 15, Document/Correspondence Outbound 13, PAS Outbound 9, PDQ/MPI SOAP 8, Document Ingestion 6, PayloadProcessor 5, AIS 2, IOLMaster 2.

## The six archetypes

| Archetype | In | Out | Varies per site |
|---|---|---|---|
| PAS Inbound (42) | MLLP ADT, or a Channel Reader for the Newmedica fleet | the PASAPI destination quintet | listen port, PASAPI version, assigning-authority codes, extra destinations |
| DICOM Ingestion (15) | DICOM listener | `PayloadProcessor API Send` + an IOLMaster file drop | DICOM port, AET/device filter, mount path |
| Document Outbound (13) | File Reader on a watched folder | File Writer to a share, or SFTP | source folder, destination path |
| PAS Outbound (9) | HTTP listener carrying search terms | `Send Q21` -> `Convert K21 to XML` -> `Create response` | remote PAS endpoint |
| PDQ / MPI SOAP (8) | HTTP listener, one per Welsh health board | QBP^Q22 out, K21 parsed to a patient list | board assigning-authority code, listen port |
| PayloadProcessor (5) | File Reader or Channel Reader | one queue-add API call | source, optional Patient Search prepend |

## The filter vocabulary

Every filter in the estate. `Sites` is the honest number: raw rule counts are dominated by Newmedica's 30-channel clone fleet, which multiplies each of its rules by 30.

| Rule | Sites | Meaning | A message goes missing here when |
|---|---|---|---|
| `MSH-9.2 == "A40"` | 9 | only a merge event reaches the merge and secondary-patient destinations | a merge arrives as anything but A40 |
| `MSH-9.2 != "M05"` | 10 | master-file updates never become a patient upsert | a real patient update is sent as M05 |
| `Appointment Filter` (JS) | 11 | the event gate on the clinic-list destinations - see below | the trigger event is outside the site's list |
| `OBX-3.1` contains / does not contain `ReportFile` | Bolton, Newmedica | splits an inbound message between the patient path and the document path | the OBX observation id is not the expected literal |
| `$('d1').getStatus()` vs `Status.SENT` | Bedford, Bolton, ENHT, MEH, Portsmouth, Sussex | a destination runs only if metaDataId 1 succeeded - `Send Q21` on PAS Outbound (all 12 rules), `PASAPI - Patient` on Bolton's PAS Inbound | the earlier destination errored or was itself filtered - everything downstream is skipped with no error of its own |
| `MSH-9.2` in `A01/A05/A08`, in `A11/A38` | EK | EK scopes events at the source instead of using the appointment filter | any other event type arrives |
| `PV1-3.2 != "checkin"`, `PV1-3.2 != ""` | Bedford, MEH | excludes a named location, and requires a location at all | the location component is blank or is the excluded one |
| `channelMap BookingType` contains `Cataract` | Bolton, Newmedica | routes cataract bookings down a separate destination | the booking type text does not contain the word |
| `QPD-3 != ""` | Bedford, MEH, Newmedica | drops an empty query rather than asking the PAS for everything | the caller sent no search terms |
| `PV1-19.1 != ""` | Newmedica | requires a visit number before creating an appointment | PV1-19 is absent |
| `PID-35.1 exists` | MEH | flags path only runs when a risk is present | no risk segment |
| `JSON.parse(responseMap 'Search').length` == 0 / == 1 | Optegra | create-vs-update branch on a document search result | more than one match - neither branch fires |

**The Appointment Filter**, present at 11 of 12 sites (EK scopes events at the source instead), is one script with per-site variants. The common form:

```
if (MSH-9.2 in {A01,A02,A03,A05,A08,A11,A12,A13}) {
    if (MSH-9.2 == "A08" && PV1-4.1 == "CANCL") return false;   // the DELETE destination takes it
    return true;
}
return false;
```

Variants that change what is dropped: **Bolton** narrows the set to A01/A05/A08/A11, chains on `d1`, drops clinic `ECAS` entirely and drops `H2` unless the event is A05. **Kingston** requires a non-empty clinic code, accepts only A01/A05/A08, and tests `PV1-15.1` in {CHKO, DNA} instead of `PV1-4.1 == CANCL`. **Newmedica** has A08 commented out - appointment *updates* never reach its clinic list - and the cancel branch commented out too. **MEH** adds A04.

## The identifier rule

The usual reason "patient numbers get filtered out". The transformer picks one identifier repetition by its assigning authority; one arriving under an authority the site does not select is **not rejected loudly - it is simply never picked up**. The hospital number also builds the PASAPI URL path, so a missed selection sends the call nowhere useful rather than failing visibly.

| Site | NHS number | Hospital number | Merge secondary |
|---|---|---|---|
| Bedford | `PID-3.5 = NHS` | `PID-2.1` | `MRG-1.5 = MR` |
| Bolton | `PID-3.5 = NHS` | `PID-3.5 = FACIL` | `MRG-1.5 = FACIL` |
| EK | `PID-3.5 = NHS` | `PID-3.5 = MR` | none |
| ENHT | `PID-3.5 = NHS` | `PID-3.5 = FACIL` | `MRG-1.5 = FACIL` |
| Kingston | `PID-3.4 = NHSNBR` | `PID-3.4 = RAX MRN` or `PID-3.5 = MRN` | none |
| MEH | `PID-3.5 = NHS` | `PID-2.5 = PAS` | `MRG-1.5 = PAS` |
| Newmedica | `PID-3.5 = NH` | `PID-2.5 = PAS` | `MRG-1.5 = PAS` |
| Optegra | `PID-3.5 = NHS` | `PID-3.5 = MR` | `MRG-1.5 = MR` |
| Pennine | `PID-3.5 = NHS` | `PID-3.5 = DN` | none |
| Portsmouth | `PID-3.5 = NHS` | `PID-3.5 = PT` | `MRG-1.5 = PT` |
| Sussex | `PID-3.5 = NHS` | `PID-3.5 = FACIL` | `MRG-1.5 = FACIL` |
| Wales | `PID-3` NHS repetition | `PID-3` CRN/PAS repetition | per-board code |

Two traps: **Kingston selects on `PID-3.4`** (the namespace id), not `PID-3.5` like everyone else. **Newmedica's NHS code is `NH`, not `NHS`** - and its hospital number comes from PID-2, not PID-3.

On V1 endpoints the identifier type is a path segment - `LOCAL-1-0` at Bedford, Bolton, MEH, Pennine, Sussex and Wales; a per-practice `${PatientIdentifier}` across the Newmedica fleet. V2 and V3 drop the segment.

## The PASAPI destination quintet

The spine of all 42 PAS Inbound channels. Execution order is list order; `$('d1')` follows metaDataId, which here is `PASAPI - Patient`.

| Order | Destination | Filter | Exceptions |
|--:|---|---|---|
| 1 | `PASAPI - Secondary Patient` | `MSH-9.2 == A40` | absent at EK, Kingston, Pennine |
| 2 | `PASAPI - Patient` (**this is `d1`**) | `MSH-9.2 != M05` | **unfiltered at EK and Kingston** |
| 3 | `Clinic List - PUT` | Appointment Filter | EK uses `MSH-9.2 in A01/A05/A08` instead |
| 4 | `Clinic List - DELETE` | **none - unfiltered at 11 of 12 sites** | EK gates it on `MSH-9.2 in A11/A38` |
| 5 | `PASAPI - Patient Merge` | `MSH-9.2 == A40` | absent at EK, Kingston, Pennine |

Two consequences worth holding on to. `Clinic List - DELETE` runs on **every** message almost everywhere - whatever it deletes is decided inside its transformer, not by a filter, so "the delete did not fire" is never a filter question. And the clinic-list destinations are not gated on the patient upsert anywhere except Bolton, so elsewhere a clinic-list entry can be written for a patient the API rejected.

Site additions: `Clinic List - DNA` (Bolton, Newmedica), `AIS` (MEH), `Send to MEH` (Bedford), `PASAPI - Patient Referral` and `OBX document` (Newmedica). EK, Kingston and Pennine run the three-destination subset - no merge, no secondary patient.

## Name is not function

Twelve channel ids recur across sites, and a shared id does **not** mean shared behaviour: `06f0b8b8` is the PAS query at six sites and an entirely different correspondence router at Kingston. Names collide too - `DICOM` at Optegra is a visual-field feed, `IOL` is the biometry one. **Trust the category, never the channel name.**

Seven things vary per site and nothing else does: ports; the OpenEyes endpoint and its credential; PASAPI version per resource; HL7 version and assigning-authority codes; filesystem paths (`/mnt/dicom`, `/mnt/docman/*`, `/mnt/document-upload`); remote PAS and MPI endpoints; optional extra destinations.

## Where to look next

| The question is about | Go to |
|---|---|
| what the estate does, which archetype, which filter exists | this file - already answered |
| why a message or identifier did not arrive | `subs/rules.md` |
| which HL7 field becomes which OE field, PASAPI version differences | `subs/mapping.md` |
| the end-to-end path of one message class | `subs/flows.md` |
| which port, which transport, what connects to what | `subs/topology.md` |
| what one site does differently | `subs/sites/<Site>.md` (~300 tokens, deltas only) |
| the literal XML of an archetype | `reference/README.md` - it holds Document Outbound and PDQ, and says where the other three live |
| an audit trail or a claim's provenance | the corpus - and only then |

Sibling skills: `c-mirth` (BridgeLink engine, REST API, Velocity/Rhino), `c-mcchannels` (the three reference channels in `~/mc_channels/`), `c-pasapi` (the OpenEyes API itself).
