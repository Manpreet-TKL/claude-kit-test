# Canned walk - Message event -> recipient search ('Send to')

Journey: search a patient, open the record, 'Add Event' -> Message (OphCoMessaging),
type into the 'Send to' recipient search and read the autocomplete dropdown. Walked
live via Claude in Chrome (`docker/oe-chrome-agent/drive.sh`, see
`docs/chrome-agent.md`) on OE develop v26.1.0-pre2 (2026-07-31), one driven stage,
37 turns / ~$1.94.

Parameters: `<web>` = OE URL. `event_type_id=38` is Message on this DB - confirm on
another with `SELECT id FROM event_type WHERE class_name='OphCoMessaging'`.

## Procedure

1. Search a surname in the top toolbar and click the result row (rows have no href)
   to open the Patient Overview. Any patient works. Caution: on the 2026-07 test
   stack BLACKWELL, Elizabeth is `/patient/summary/2476982` - not patient 17891 as
   the atlas's sample-patient note says - and carries only an Accident & Emergency
   episode; verify the id per box before using the direct-URL fallback.
2. Click 'Add Event' (`#add-event`), pick any subspecialty with an existing episode,
   any Context, then 'Message' in 'Select New Event'. Lands on
   `<web>/OphCoMessaging/Default/create?patient_id=<pid>`. Direct fallback:
   `<web>/patientEvent/create?patient_id=<pid>&event_type_id=38&context_id=<ctx>&episode_id=<ep>`.
3. Click into 'Send to' (`#fao-search`, placeholder 'Search for recipient') and type
   a term of 2+ characters (input debounced ~300ms; 'an' returned 1791 mailboxes on
   the sample DB). 'Copy to' (`#copyto-search`) is the same widget on the same
   endpoint, so it shares any dropdown fault.
4. The dropdown is the input's sibling `ul.oe-autocomplete` with `li.oe-menu-item`
   items. Predicate, run as JS in the walk:

```
Array.from(document.querySelectorAll('ul.oe-autocomplete')).find(u=>getComputedStyle(u).display!=='none').children[0].outerHTML
```

5. Server truth for the same term:
   `fetch('/OphCoMessaging/Default/autocompleteMailbox?term=<term>&ajax=ajax', {credentials:'same-origin', headers:{'X-Requested-With':'XMLHttpRequest'}})`
   returns plain `[{id, label}]` JSON (the action requires the ajax header), so any
   markup seen in the dropdown was added client-side.

Nothing needs saving; the dropdown renders before any submit.

Walker gotcha: the page-eval tool refuses `=`-heavy string output - have the walk
swap `=` for a sentinel (e.g. `.replace(/=/g,'\u2550')`) and restore it afterwards.

Driver: `./drive.sh -f subs/canned/message-send-to.md -t <slug> "Follow the procedure and report the predicate reading and the raw server response. Do this now with tool calls, do not answer from memory."`

## Bug ledger

**1. Recipient dropdown shows literal `class="autocomplete-match">an` fragments next
to any name whose label matches the typed term twice or more** (confirmed
2026-07-31, develop v26.1.0-pre2-63-gaa01a1c8e7; first reported on 1.1.33-dev).

- **Predicate reading** (term 'an'): `<a id="ui-id-0" tabindex="-1">Mr Bruce
  All<sp<span class="autocomplete-match">an class="autocomplete-match"&gt;an
  (Consultant Ophthalmic Surgeon)</sp<span></a>` - while a single-match label in the
  same list renders the correct `<span class="autocomplete-match">an</span>` wrap.
- **Server response is clean** (`[{"id":"3","label":"Mr Bruce Allan (Consultant
  Ophthalmic Surgeon)"}, ...]`), so the fault is purely client-side.
- **Mechanism:** `matchSearchTerm()` (`protected/widgets/js/AutoCompleteSearch.js`
  ~L70-84) collects every case-insensitive match of the term, then loops
  `str = str.replace(match, '<span class="autocomplete-match">' + match + '</span>')`.
  A string-pattern `replace` hits the FIRST occurrence each pass and the loop
  re-scans its own output: after pass 1 the earliest 'an' is the one inside the
  injected `<sp an` tag, so pass 2 rewrites the tag itself into
  `<sp<span ...>an</span> class="autocomplete-match">an</span>`. The parser recovers
  `<sp<span ...>` as one unknown element (still carrying class `autocomplete-match`,
  hence the match styling on the garbage) and the orphaned
  ` class="autocomplete-match">an` renders as literal text.
- **Trigger:** the term occurs 2+ times in the label (case-insensitive). Visible tag
  soup additionally needs the term to be a substring of the injected markup ('an' is
  inside 'span'); other multi-match terms silently double-wrap the first occurrence
  and never highlight the rest.
- In the code since the widget landed (OE-7834) - latent, not a regression.
- **Fix shape:** one global regex pass,
  `str.replace(myRegExp, '<span class="autocomplete-match">$&</span>')`, which never
  re-scans its own insertions (and ideally HTML-escape the label first - labels are
  interpolated as raw HTML).
- Evidence: `~/repro-evidence/2026-07-31-messaging-sendto-autocomplete/`
  (transcript.jsonl, dropdown-bug.jpg, result JSON).
