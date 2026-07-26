# Filter and routing rules - the full catalogue

Every place a message can be dropped, in pipeline order. Read this when the question is
"why did X not arrive". Rule text is as written in the channels, normalised out of the XML
escaping.

564 filter elements exist across the estate, 560 of them rules: 364 rule-builder, 196
JavaScript. They collapse to the dozen distinct rules below. Counts are inflated by
Newmedica's 30-channel clone fleet, which carries each of its rules 30 times over; the
`Sites` column is the number that means something.

---

## 1. Source-level filters - dropped before any destination runs

Only **EK** filters at the source. Both EK PAS inbound channels (main and Maidstone) carry
two rule-builder rules on the source connector:

```
Accept message if MSH-9.2 equals "A01" or "A05" or "A08"
Accept message if MSH-9.2 equals "A11" or "A38"
```

Everything else at EK is dropped at the front door and never appears against a destination.
*A message goes missing here when* the trigger event is anything outside those five - an
A03 discharge or an A40 merge at EK is simply not processed, which is consistent with EK
having no merge destination at all.

Every other site accepts everything at the source and filters per destination, so at those
sites a dropped message still shows in the message list with its destinations marked
filtered. **That difference matters when reading logs**: at EK there is nothing to look at.

---

## 2. Per-destination filters on the PAS inbound path

### 2.1 The merge gate - `MSH-9.2 == "A40"`

Carried by 9 sites (Bedford, Bolton, ENHT, MEH, Newmedica, Optegra, Portsmouth, Sussex,
Wales; 78 rule instances, 60 of them Newmedica clones). It gates two destinations:
`PASAPI - Secondary Patient` and `PASAPI - Patient Merge`.

*A message goes missing here when* a PAS emits a merge as something other than A40 - some
systems use A34 or A18. Neither merge destination fires, no error is raised, and the two
records stay separate in OpenEyes.

EK, Kingston and Pennine have no merge destination at all, so a merge arriving there is
inert regardless of its event code.

### 2.2 The master-file exclusion - `MSH-9.2 != "M05"`

Carried by 10 sites (all but EK and Kingston), on the `PASAPI - Patient` destination.

M05 is a master-file update - a change to a location or clinic definition, not to a patient.
The rule stops those becoming a patient upsert.

*A message goes missing here when* an upstream system reuses M05 for a real patient change:
the demographics never reach OpenEyes. **At Bolton it also loses the appointment**, because
Bolton is the one site whose clinic-list destinations are chained on `PASAPI - Patient`
(`d1`) having sent - see 3 below. Everywhere else the clinic list is written anyway, for a
patient the API was never told about.

EK and Kingston leave `PASAPI - Patient` unfiltered, so M05 reaches the upsert there.

### 2.3 The appointment gate - `Appointment Filter`

A JavaScript rule on `Clinic List - PUT`, present at 11 of 12 sites - **EK has none**, because it
scopes trigger events at the source instead (section 1). The common form:

```javascript
if (   MSH-9.2 == "A01" || "A02" || "A03" || "A05"
    || MSH-9.2 == "A08" || "A11" || "A12" || "A13" )
{
    if (MSH-9.2 == "A08" && PV1-4.1 == "CANCL") { return false; }
    return true;
}
return false;
```

The inner branch is not a drop - it hands the message to `Clinic List - DELETE`, whose filter
is the mirror image. An A08 carrying `PV1-4.1 = CANCL` removes the clinic-list entry instead
of updating it.

Per-site variants, and what each one loses:

| Site | Variant | Consequence |
|---|---|---|
| Bedford, ENHT, Optegra, Pennine, Portsmouth, Sussex, Wales | the common form | - |
| MEH | adds `A04` | registrations also create clinic entries |
| Bolton | set narrowed to `A01/A05/A08/A11`; opens with `if ($('d1').getStatus() != Status.SENT) return false`; then `if ($('ClinicCode') == "ECAS") return false`; then `if (MSH-9.2 != "A05" && $('ClinicCode') == "H2") return false` | **A02, A03, A12 and A13 never reach the clinic list**, and two named clinics are excluded outright or event-scoped |
| Kingston | requires `$('ClinicCode') != ""` **and** event in `A01/A05/A08`; cancel branch tests `PV1-15.1` in `{CHKO, DNA}` rather than `PV1-4.1 == CANCL` | an appointment with no clinic code is dropped; a checkout or DNA is what triggers removal |
| Newmedica | `A08` is commented out, and the whole cancel branch is commented out | **appointment updates never reach the clinic list**, and nothing is ever removed by this route |

*A message goes missing here when* the event is outside the site's set. At Bolton and
Newmedica that set is materially smaller than the site's PAS actually emits, which is the
single most common cause of "the appointment did not update".

### 2.4 The location gate - `PV1-3.2`

Bedford and MEH only, two rules each:

```
Accept message if PV1-3.2 does not equal "checkin"
Accept message if PV1-3.2 does not equal ""     (JavaScript rule at MEH; rule-builder at Bedford)
```

*A message goes missing here when* the PAS sends the appointment with an empty PV1-3 second
component, or routes it through the named check-in location. Both are legitimate PAS
behaviour, so this drop looks like data loss from the OpenEyes side.

### 2.5 The DNA branch

Bolton and Newmedica carry a `Clinic List - DNA` destination whose filter is a JavaScript
rule:

```javascript
if (MSH-9.2 == "A05" && PV1-14.1 == "DNA") { return true; }
return false;
```

*A message goes missing here when* the did-not-attend outcome is recorded on any event other
than A05, or in a field other than PV1-14. At the other ten sites there is no DNA destination
and the outcome is only ever visible as an appointment status.

### 2.6 The risk gate - `PID-35.1 exists`

MEH only, on the AIS path. No risk segment, no flags call.

---

## 3. Destination chaining - `$('d1').getStatus()`

`d1` means **metaDataId 1**, not the first destination in the export listing, and metaDataId 1
is a different destination in each archetype. Get this wrong and the diagnosis inverts.

| Archetype | `d1` is | Chaining written as | Sites |
|---|---|---|---|
| PAS Outbound | `Send Q21` - the query to the remote PAS | 12 rule-builder rules | Bedford, Bolton, ENHT, MEH, Portsmouth, Sussex |
| PAS Inbound | `PASAPI - Patient` - the patient upsert | 2 JavaScript tests inside the Appointment Filter | **Bolton only** |

### On PAS Outbound - 12 rules, all of them here

`Send Q21` (metaDataId 1) queries the remote PAS; `Convert K21 to XML` (4), `Create response`
(5) and `Respond` (6) each gate on how it went.

| Form | n | Meaning |
|---|--:|---|
| `equals Status.SENT` | 6 | the query reached the PAS - parse and answer |
| `does not equal Status.SENT` | 4 | the query failed - the fallback destination (`Do Nothing`, `Nothing`, `Nothing to do`) absorbs it |
| `is blank` | 2 | `Send Q21` never ran at all, having been filtered itself |

*A search goes missing here when* the remote PAS is unreachable or slow: `Send Q21` errors,
every downstream destination is skipped **without an error of its own**, and the caller gets
an empty result rather than a failure. The message shows one errored destination and three
filtered ones, which reads as a filter problem rather than the connectivity failure it is.

### On PAS Inbound - Bolton only

Bolton's Appointment Filter opens with `if ($('d1').getStatus() != Status.SENT) return false`,
so the clinic list is only touched when the patient upsert succeeded. Destination ordering on
a PAS Inbound channel is `PASAPI - Secondary Patient` (metaDataId 5) first in the listing,
then `PASAPI - Patient` (1), `Clinic List - PUT` (2), `Clinic List - DELETE` (3),
`PASAPI - Patient Merge` (4) - execution follows list order, `$('d1')` follows metaDataId.

*An appointment goes missing here when* the patient upsert fails - a bad identifier, a
rejected payload, an unreachable API - and the clinic-list destinations are silently filtered.
**At the other eleven sites there is no such gate**, so a clinic-list entry can be written for
a patient the API never accepted.

---

## 4. Content routing - `OBX-3.1`

Bolton and Newmedica split an inbound stream by observation identifier:

```
Accept message if OBX-3.1 does not contain "ReportFile"    (patient path)
Accept message if OBX-3.1 contains "ReportFile"            (document path, "OBX document")
```

150 rule instances across the two sites, 90 + 60 of them Newmedica clones.

*A message goes missing here when* the sending system changes the observation identifier
text. The two rules are exact complements, so a message always goes down exactly one path -
but if the literal drifts, every message goes down the patient path and the documents stop
appearing with no error anywhere.

The DICOM path uses the same mechanism at device level rather than segment level: the
`Write out file to IolMasterImport incoming folder when device is a Zeiss IOLMaster`
destination is filtered on the DICOM device header, so a biometry device reporting a
different manufacturer string writes nothing to the import folder while still uploading
normally through `PayloadProcessor API Send`.

## 5. Booking-type routing

Bolton and Newmedica: `Accept message if channelMap 'BookingType' contains "Cataract"`.
30 instances, all but one from the Newmedica fleet. Matching is on substring, so a booking
type spelled differently - or cased differently, since this is a `contains` on raw text -
takes the default path instead.

---

## 6. The query guard - `QPD-3 != ""`

Bedford, MEH and Newmedica guard their outbound PAS query with an empty-search-terms check
(rule-builder at Bedford and MEH, JavaScript at Newmedica).

*A message goes missing here when* a caller posts a query with no terms - deliberately, so
the trust PAS is never asked to return everything. The other PAS-outbound sites have no such
guard.

Newmedica adds `Accept message if PV1-19.1 does not equal ''` - no visit number, no
appointment.

## 7. Document create-vs-update - Optegra

```
Accept message if JSON.parse(responseMap.get('Search').getMessage()).length equals 0   -> Create
Accept message if JSON.parse(responseMap.get('Search').getMessage()).length equals 1   -> Update
```

*A message goes missing here when* the search returns two or more matches: neither branch
fires, nothing is created, nothing is updated, and no error is raised. A duplicate document
in OpenEyes therefore jams every subsequent update for that document.

---

## Worked example - "why did these patient numbers get filtered out?"

Trace it in this order; the first mismatch is the answer.

1. **Was the identifier ever selected?** The transformer picks one PID-3 repetition by its
   assigning authority, and the site table in `SKILL.md` says which code. A number arriving
   under any other code is not an error - it is simply not read, so the field is empty and
   the PASAPI path is built from nothing. Kingston selects on `PID-3.4`, not `PID-3.5`.
   Newmedica's NHS code is `NH`, and its hospital number comes from `PID-2`.
2. **Did the event survive the source filter?** At EK only - five events pass, everything
   else is gone before any destination.
3. **Did `PASAPI - Patient` run?** `MSH-9.2 != M05` at 10 sites; EK and Kingston leave it
   unfiltered. If this filtered, the demographics never reached OpenEyes at all.
4. **Was the destination chained?** Bolton only, on the clinic list. There the upsert
   failing silently filters the appointment too - check the *patient* destination's error,
   not the filtered ones. On PAS Outbound the same construct gates the response on
   `Send Q21`, which is a different `d1` entirely (section 3).
5. **Did the appointment gate pass?** The site's event set, plus Bolton's clinic exclusions,
   plus Kingston's non-empty clinic-code requirement, plus Newmedica's missing A08.
6. **Was there a location?** Bedford and MEH only.

If the answer is "none of these", it is not a filter. `Clinic List - DELETE` is unfiltered at
11 of 12 sites, so anything missing on that path is transformer logic or an API rejection.

---

## Re-deriving these counts

Against `~/mirth-channel-corpus/canonical/`. Note the filter element is
`<filter version="4.6.1">`, not a bare `<filter>` - a naive grep finds nothing.

Rule-builder rules, estate-wide:

```
grep -rhoP '(?<=<name>)Accept message if [^<]*' canonical/ | sed "s/&quot;/\"/g;s/&apos;/'/g" | sort | uniq -c | sort -rn
```

The same, broken down per site (this is what the `Sites` columns above are built from):

```
for d in canonical/*/; do grep -rhoP '(?<=<name>)Accept message if [^<]*' "$d" | sort | uniq -c | sed "s|^|${d} |"; done
```

JavaScript rule names per site:

```
for d in canonical/*/; do grep -rh -A3 'JavaScriptRule' "$d" | grep -oP '(?<=<name>)[^<]+' | sort | uniq -c | sed "s|^|${d} |"; done
```

## Provenance

Distilled from a generated corpus of 102 channels across 12 sites
(`ai-corpus/summary.json`: `channel_count: 102`). Rule totals at time of writing: 564 filter
elements, 364 rule-builder rules, 196 JavaScript rules; `MSH-9.2 == A40` x78,
`MSH-9.2 != M05` x70, `Appointment Filter` x72, `OBX-3.1` x151 across both complements,
`BookingType contains Cataract` x30, `getStatus()` x12 (6 equals SENT, 4 not-equal, 2 blank).
Re-run the greps above to check for drift.

**Known corpus error carried forward corrected:** the corpus prose says "13 instances"
throughout. `canonical/`, `ai-corpus/summary.json` and the source export directory all
contain **12**. This skill says 12.
