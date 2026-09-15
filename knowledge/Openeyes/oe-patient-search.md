# OpenEyes patient search - how it works

Source analysed: `develop` @ `04c938c0a4` (latest as of 2026-07-30). Live tests were run
against a local dev stack running exactly that commit, driven through the Chrome walker
sidecar (real browser, real clicks). The sample DB has no Throup patients and direct DB
seeding was blocked by session permissions, so the live tests use the sample "Searle"
family (8 patients) - the formats exercised are identical to the Throup examples.

Evidence folders: `~/repro-evidence/2026-07-30-patient-search-formats/` and
`~/repro-evidence/2026-07-30-patient-search-dob-mandatory/`.

## 1. Request flow

1. The home-page search box (`protected/views/base/_search_bar.php`) submits `query` to `site/search`.
2. `SiteController::actionSearch()` first checks the event shortcut `E:123` / `Event:123` (case-insensitive, `:` or `;`) and jumps straight to that event view; anything else redirects to `patient/search?term=...`.
3. `PatientController::actionSearch()` builds `new PatientSearch(true)` (PAS allowed) and runs the search.
4. `PatientSearchTerms::createFromUserInput()` (`protected/components/PatientSearchTerms.php`) parses the term into either a **name search** or a **number (identifier) search** - this is the fork everything else hangs off.
5. Name searches and zero-hit number searches also query any **enabled** PAS (`OEModule\PASAPI\components\PasSearchManager`); PAS results are merged in after local ones. A PAS is enabled only when its `pas_configuration.config` JSON has `enabled: true` - none are enabled on the test stack, so all results below are local-only.
6. Outcome: exactly 1 hit redirects straight to the patient's configured landing page; 2+ hits render the results table; 0 hits flashes a warning and returns to the home page.

Key files:

| Concern | File |
|---|---|
| Term parsing (name vs number, DOB) | `protected/components/PatientSearchTerms.php` |
| Orchestration, PAS merge | `protected/components/patientSearch/PatientSearch.php` |
| Which identifier types are searched | `protected/components/patientSearch/DefaultTypePatientSearchHelper.php`, `AnyTypePatientSearchHelper.php` |
| SQL construction | `protected/components/PatientLocalSearch.php` |
| Regex match + zero-padding of number terms | `protected/helpers/PatientIdentifierHelper.php` (`getPaddedTermRegexResult`) |
| Controller / outcomes | `protected/controllers/PatientController.php` (`actionSearch`) |
| Search box + help popup | `protected/views/base/_search_bar.php` |
| Results page | `protected/views/patient/results.php` |

## 2. Name search - the supported formats

A term is treated as a name search when it matches
`/^([\D]+[ ,]?[\D]*)(\s\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})?$/` - i.e. **no digits anywhere
except an optional trailing DOB**. The name part is then split:

1. Contains a comma: `Surname, Firstname` (split on the first comma).
2. Contains a space (no comma): `Firstname Surname` - the **first word** is the first name, **everything after the first space** is the surname (so `Judy van Throup` parses as first name `Judy`, surname `van Throup`; a multi-word *first* name needs the comma form: `Searle, Katie Mary`).
3. Single word: surname only.

Both names are matched with `LIKE '<term>%'` - an **implicit trailing wildcard, prefix
match** - which is why an initial works for the first name and why `Sea` finds every
`Searle`. DOB, when present, is an exact match on `patient.dob`.

The user's example formats, as parsed:

| Input | first_name LIKE | last_name LIKE | dob = |
|---|---|---|---|
| `Throup 07/05/1954` | - | `Throup%` | 1954-05-07 |
| `Judy Throup 07/05/1954` | `Judy%` | `Throup%` | 1954-05-07 |
| `J Throup 07/05/1954` | `J%` | `Throup%` | 1954-05-07 |
| `Throup, Judy 07/05/1954` | `Judy%` | `Throup%` | 1954-05-07 |

DOB accepts `/` or `-` separators, 1-2 digit day/month, 2-4 digit year, parsed as
day-month-year via `DateTime::createFromFormat('d m Y', ...)`.

### Name/DOB gotchas

1. **Two-digit years are literal**: `07/05/54` becomes year `0054`, not 1954. Always type the full year.
2. **Invalid dates roll over silently**: `31/02/1990` is searched as `1990-03-03` (PHP date rollover), so you get "no results" rather than an error.
3. **A bare year is not a DOB**: `Searle 1950` contains digits without date separators, so the whole term falls through to a *number* search (see 4 below for the confusing message this produces). Confirmed live.
4. **Wildcard injection**: the LIKE conditions are built with escaping disabled, so `%` and `_` typed into a name act as SQL wildcards (`T%p` matches `Throup`). Harmless but surprising.
5. Punctuation other than the comma is not stripped - `O'Brien` searches literally (fine), but a stray `.` after an initial (`J. Throup`) is searched as first name `J.%` and will miss.

## 3. Number (identifier) search

Anything that fails the name regex is a number search:

1. Spaces and dashes are stripped (`432 476 5804`, `432-476-5804` and `4324765804` are identical).
2. The term is tested against the `validate_regex` of each identifier type in the institution/site's **Patient Identifier Display Preferences** (GLOBAL rules first, then LOCAL), skipping rows with `Searchable` unticked.
3. If the raw term fails a type's regex, the type's `pad` format is applied and it is retried - e.g. pad `%07s` turns `498842` into `0498842`. Confirmed live: searching `498842` opens the patient whose ID is `0498842`.
4. If a LOCAL type's regex fails, the term is also retried against the GLOBAL type's regex (NHS-number lookup for the global institution defined by the `global_institution_remote_id` setting).
5. Matching types are queried with **exact** `patient_identifier.value =` equality (no prefix matching for numbers), OR-ed across types.
6. A **protocol prefix** narrows the search to one type: `nhs:432 476 5804` searches only types whose display-preference row lists `nhs` in its `Protocols` column (pipe-separated `search_protocol_prefix`, matched case-insensitively). The special prefix `any:` searches **every identifier type in the system** but only works when the institution's `Any number search allowed` box is ticked.
7. If a number search finds nothing but the value matches a **merged-out** identifier, the warning becomes "Identifier X was merged into Y" (OE-16586).

### Number-search gotcha - the misleading error

When a term contains digits but matches *no* identifier type's regex (e.g. `Searle 1950`,
`AdamSearle`), zero searchable types survive and the red banner says
**"No display preference rules have been setup for your current institution/site."** -
which reads like a config fault but actually just means "this term is neither a valid
name+DOB nor a recognisable identifier". Confirmed live twice.

## 4. Outcomes

| Hits | Behaviour |
|---|---|
| 1 | Immediate redirect to the patient's landing page (per landing-page setting); no results page. With `use_search_term_for_patient_identifier_precedence` on, the matched identifier is remembered in session and takes precedence when displaying that patient's number. |
| 2+ | Results page: sidebar shows Search / Found / Based on (e.g. "LAST NAME, DOB"); table columns are primary identifier, Title, First name, Last name, Born, Age, Sex, institution label; sortable, rows open on click. |
| 0 | Back to the home page with "Sorry, no results for ..." (name searches quote the parsed name/DOB, number searches the term) - or the misleading banner / merged-identifier message described above. |

## 5. How the tooltip (search help popup) works

The link under the search box - `Search by ID, or Name (click for options)` - is not a
hover tooltip; clicking it calls a tiny inline jQuery function `displaySearchPatterns()`
that unhides a pre-rendered `.js-search-popup` div titled **"Available search patterns"**
(`_search_bar.php` lines 76-123). The X calls `.hide()`. Everything in it is rendered
server-side per request:

1. The pattern/example table has a name-format block chosen by the `dob_mandatory_in_search` setting (DOB-less examples when off; `... + DOB` examples when on), plus the sentence "Search is not case sensitive, there is no need to use uppercase".
2. Identifier example rows are appended per the institution/site's primary and secondary identifier *prompts* (the `short_title` of the first type in the GLOBAL/LOCAL display-preference rules, per the `display_primary/secondary_number_usage_code` settings). Only prompts named NHS, CERA or MEDICARE get an example row (`getSearchExamplePatternBasedOnIdentifierType`) - any other title (like this stack's LOCAL "ID") silently gets none.
3. The link text itself flips to `Search by ID, or Name and Date of Birth (click for options)` when DOB is mandatory. Confirmed live in both states.

**Live popup, DOB off**: Given Family `David Smith` | Family, Given `Smith, David` |
Family only `Smith` | Initial Family only `D Smith` | Family + DOB `Smith 21/03/1975` |
NHS `123-123-1234`.

**Live popup, DOB on**: Given Family + DOB `David Smith 31/12/1975` | Family, Given + DOB
`Smith, David 31/12/1975` | Initial Family + DOB `D Smith 1975` | Family + DOB
`Smith 21/03/1975` | NHS `123-123-1234`.

**Bug**: the `Initial Family + DOB` example `D Smith 1975` does not work - a bare year is
not a valid DOB (section 2), so that exact format returns no results. Confirmed live
(`A Searle 1950` found nothing while `A Searle 21/10/1950` opened the record). OE-15574
(Dec 2025) fixed the same mistake in the `Family + DOB` row but missed this one; worth a
follow-up ticket.

(Separately, OE's generic hover tooltips - `<i class="js-has-tooltip" data-tooltip-content="...">`
info icons - appear on related admin fields, e.g. the `Any number search allowed` checkbox
explains the `any:` protocol on hover. That mechanism is the global `data-tooltip-content`
handler in the OE JS, not the search popup.)

## 6. Admin pages that change search behaviour

| Page (route) | Lever | Effect on search |
|---|---|---|
| Admin > System > Settings (`/admin/settings`) | DOB mandatory in search (`dob_mandatory_in_search`, default off) | On: a name search without a DOB is not treated as a name search at all (falls through to number search, so effectively no results); help link/popup switch to the DOB variants. Identifier searches unaffected. Autocomplete widgets (patient merge etc.) are exempt so lookahead still works. Confirmed live on/off. |
| same | Display Primary/Secondary Number Usage Code (`LOCAL`/`GLOBAL`) | Which usage type is the "primary" identifier - drives the results-table first column, the search-box prompt wording and the popup's identifier example rows. |
| same | Use search term for patient identifier precedence | On: after a single-hit identifier search, the identifier you typed is the one displayed for that patient during the session. |
| same | Global Institution Remote Id (default `NHS`) | Which institution owns the GLOBAL (NHS-number) type - used by the LOCAL-regex-failed fallback and `any:` resolution. |
| Admin > Core > Institutions > edit (`/admin/editinstitution`) | Patient Identifier Numbering Systems | Per-type `validate_regex`, `pad`, prefix/suffix, spacing rule - the regex gate and padding that decide whether a number term can match that type at all. |
| same | Patient Identifier Display Preferences | Per institution/site rules: display order, **Searchable** tick (untick = type invisible to search), **Protocols** (`search_protocol_prefix`) enabling `<prefix>:` searches. No rules at all = every search fails with the "No display preference rules" banner. |
| same | Any number search allowed checkbox | Enables the `any:<number>` protocol for that institution. |
| Admin > Core > Patient Identifier Types (`/Admin/PatientIdentifierType/index`) | Type catalogue | Create/edit the types the above rules reference. |
| PAS configuration (PASAPI admin) | `pas_configuration` enabled flag | An enabled PAS is queried on every name search and on number searches with zero local hits, merging remote patients into the results. |

Note: any setting key present in the PHP config (`Yii::app()->params`) overrides the DB
value, and settings are cached with a short debounce - an admin change can lag a few
seconds behind on a busy page.

## 7. Casing

Search is **fully case-insensitive** end to end - confirmed live (`searle`, `SEARLE, adam`
both behave identically to the capitalised forms), and the popup says so explicitly.

1. `contact.first_name` / `contact.last_name` are `utf8mb3_general_ci`; `patient_identifier.value` is `utf8mb3_unicode_ci`, so all SQL comparisons ignore case. (The `contact` *table default* is `utf8mb3_bin` - the name columns override it, but be wary of comparing other contact columns.)
2. Protocol prefixes are lowercased on both the input and the configured side (`NHS:` works).
3. **The one real gotcha**: the identifier `validate_regex` gate runs in PHP *before* the SQL and is case-sensitive unless the regex carries `/i`. Digit-only regexes (this stack's ID/CRN) can't care, and the shipped NHS regex has `/i`, but a deployment with alphanumeric identifiers (e.g. CERA `LL01-0028`) whose regex lacks `/i` will silently fail lowercase input - it never reaches the (case-insensitive) database.

## 8. Live test results

Walk 1 - formats, `dob_mandatory_in_search` off (institution "Kings (Monachs)", site Uveitis; family: 8x Searle):

| # | Term | Result |
|---|---|---|
| 1 | `Searle` | List, 8 rows, based on LAST NAME |
| 2 | `searle` | List, 8 rows (case-insensitive) |
| 3 | `Searle 21/10/1950` | Straight to record: Searle, Adam, ID 0498842 |
| 4 | `Adam Searle 21/10/1950` | Straight to Adam Searle |
| 5 | `A Searle 21/10/1950` | Straight to Adam Searle (initial = prefix) |
| 6 | `Searle, Adam 21/10/1950` | Straight to Adam Searle |
| 7 | `SEARLE, adam` | Straight to Adam Searle (casing + comma form) |
| 8 | `Searle, Katie Mary 23/02/2005` | Straight to Katie Mary Searle (multi-word first name) |
| 9 | `Sea` | List, the same 8 Searles (prefix match; DB confirms Searle is the only `Sea%` surname) |
| 10 | `Searle 1950` | No results + misleading "No display preference rules..." banner |
| 11 | `0498842` | Straight to Adam Searle (LOCAL ID) |
| 12 | `498842` | Straight to Adam Searle (`%07s` zero-padding) |
| 13 | `432 476 5804` | Straight to Eileen Searle (NHS, spaces stripped) |
| 14 | `432-476-5804` | Straight to Eileen Searle (dashes stripped) |

Walk 2 - `dob_mandatory_in_search` toggled On via `/admin/settings`, then reverted to Off (both changes verified in the UI):

| Step | Result |
|---|---|
| Link text | Becomes "Search by ID, or Name and Date of Birth (click for options)"; reverts after |
| Popup | Switches to the `+ DOB` pattern set, including the broken `D Smith 1975` row |
| `Searle` | No results, "No display preference rules..." banner |
| `Adam Searle` | No results, same banner |
| `Searle 21/10/1950` | Still straight to Adam Searle |
| `A Searle 1950` | No results (proves the popup's own example format fails) |

## 9. Recent changes to this area

| When | Commit | Change |
|---|---|---|
| 2026-03-24 | `28069a3f` | PHP 8.4 upgrade - mechanical, no behaviour change |
| 2025-12-08 | `3870d743` | OE-15574: help popup `Family + DOB` example corrected to `Smith 21/03/1975` (left `D Smith 1975` broken) |
| 2025-11-18 | `81092aae` | OE-16602: `PatientIdentifierHelper` refactor (caching/structure, behaviour preserved) |
| 2025-04-07 | `799163a0` | OE-16586: "identifier X was merged into Y" message when searching a merged-out local identifier |
| 2024-04-09 | `83d30b9d` | OE-15463: fix patient search outside the home page |
| 2024-04-02 | `97b9b126` | OE-15245: avoid duplicate PAS searches for global endpoints |

The parser itself (`PatientSearchTerms`) has not changed behaviourally since early 2024;
nothing search-related landed in 2026 beyond the PHP 8.4 sweep.
