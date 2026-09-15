# OeDocumentation campaign - lessons, skill paths, ledger

Working notes for the 2026-08-05 completeness/readability campaign. New bugs go
to `knowledge/Openeyes/oe-documentation-bug-ledger.md` (next id BUG-534); this file holds
everything else. BUG-001 through BUG-532 remain in the local historical archive
at `~/openeyes_unverified_bugs.md` and must not be copied into the kit wholesale.

## Lessons learnt

1. **The host `~/openeyes` checkout lags the running container.** On 2026-08-05 the
   host was at `04c938c0a4` (2026-07-29) while the web container ran `53b077c089`
   (2026-08-04), and the database carried two migrations the host checkout did not
   contain (`m260730_120000_remove_rtt_clock_state_option_group_from_clinicoutcome_status`,
   `m260803_140704_remove_constraint_from_referral_rtt_clock_state_option_version_table`).
   Anything documented from the host checkout can therefore describe columns and
   screens that no longer exist. Verify against `docker exec <web> ...` and the live
   DB, not the host clone. The container has its own working `.git`, so
   `git log --oneline -1` inside it is the authoritative version.

2. **`docker cp` cannot read the web container's `/tmp`** - it is a tmpfs mount, and
   docker cp silently reports "Could not find the file ... in container" even though
   `ls` shows it. Stream it instead: `docker exec <container> cat /tmp/x.jpg > host.jpg`.

3. **Node module resolution breaks scripts run from `/tmp` in the container.** A
   puppeteer script at `/tmp/x.cjs` cannot resolve `require('puppeteer')` because
   resolution walks up from the script's own directory. Put the script somewhere
   under the app root (e.g. `protected/runtime/`) and run it with the app root as
   cwd. `capture.cjs` works because it lives inside the app tree.

4. **The visible debug toolbar is `#yii2-debug`** (inner `div.yii2-debug-toolbar`), a
   fixed 40px strip at the bottom of the viewport showing version, PHP version,
   HTTP status, controller action, log count, time, memory and DB timings. It is NOT
   `protected/views/base/_debug.php` - that partial emits an HTML comment and is
   invisible. Screenshots must hide `#yii2-debug`; the perf data it carries is
   analysed elsewhere (see `knowledge/Openeyes/oe-debugbar-data-analysis.md`), so the toolbar
   itself stays on in the environment.

5. **RTT is not the worklist Pathway.** `Pathway`/`PathwayStep` is the clinic-day
   pathway (arrival, check-in, step timers); RTT is the new `Referral` module's
   18-week clock. The only link is `worklist_patient.referral_id`. Readers and
   agents both conflate these; state the distinction explicitly.

6. **A feature can be fully coded, fully seeded with reference data, and still be
   invisible.** RTT ships 19 clock-state options, 7 groups and 72 transitions in the
   sample DB, but zero referrals, zero clock states, and the `enable_rtt_clock_bar`
   setting off - so nothing renders. "Reference data exists" is not "the feature can
   be demonstrated"; the demo-data question has to be asked per feature, not per
   module.

7. **The Add Event dialog offers more than event types.** `AddNewEventManager::
   getAddableEventTypesAndEventSubtypes()` merges the manually-creatable event types
   with every `event_subtype` row carrying `manual_entry = 1`; those subtypes appear
   as ordinary-looking entries that actually create an `OphGeneric` event with an
   `event_subtype` query parameter. There is no admin screen for `manual_entry` -
   it is migration/DB-only - and the subtype branch of `add_new_event.php` performs
   no `checkAccess` call, unlike the event-type branch. On the sample DB no subtype
   has `manual_entry = 1`, so the whole mechanism is invisible unless you read the
   code.

8. **The "support services" event-list filter looks like a feature and is dead code.**
   `OpenEyes.UI.Dialog.NewEvent.js` `updateEventList()` hides every event type
   whose `support_services` flag is 0 once `selectedSubspecialty.supportServices`
   is truthy - but the only place that key is ever emitted is
   `NewEventDialogHelper::$support_services_subspecialty` (reached via
   `structureEpisodes()`), while the dialog's lookup table is built from
   `structureAllSubspecialties()`, which never sets it. So the flag is always
   undefined, the filter branch never runs, and the Support Services tile is a
   dead end instead (BUG-128). Reading the JS alone gives exactly the wrong
   answer; the fix was to drive it live. **Two code paths that populate the same
   structure are the trap** - check which one actually feeds the consumer.

9. **The Add Event dialog has session-wide side effects.** Choosing a context calls
   `PatientEventController::setContext()`, which changes the user's active firm for
   the rest of the session, saves it to the user record and writes a `change-firm`
   audit entry. Choosing a different service for an existing episode re-assigns that
   episode's `firm_id` and saves it. Neither is announced on screen.

10. **"It needs a gesture" was being treated as "it needs a human".** Every screen
    that only exists after a click - the Add Event dialog and its three columns
    above all - was marked `needs=` and therefore classified manual, so the single
    most important picture in the corpus could never be refreshed by the pipeline.
    The fix was a new `clicks="sel|sel"` shot attribute (pipe-separated CSS
    selectors clicked in order before capture, `parseShots` -> `gatherShots` ->
    job -> `capture.cjs`): a shot with `clicks` stays **auto**. The rule now is
    `clicks=` for anything a sequence of clicks can reach, and `needs=` only for
    missing data or an application defect that no click can supply. Four Add Event
    markers converted, six images re-captured from one command.

11. **Check order in a classifier is a silent-data-loss bug.** `actionScreenshots`
    tested `$s['unresolved']` (an unfilled `{placeholder}`) before `!$s['auto']`,
    so a marker that honestly declared `needs=` AND carried a placeholder was
    reported as "unsafe" rather than "manual". "Unsafe" was the bucket nobody
    triaged, so those pictures were never taken and never chased. Swapping the two
    checks moved 131 markers into the right bucket and took the unsafe count to
    zero. When a classifier has an error bucket and a legitimate bucket, test the
    legitimate one first, or the error bucket quietly absorbs valid work.

12. **The seed manifest was not the blocker it looked like.** Before installing
    the placeholder-resolution manifest, count what the corpus actually uses: the
    remaining unresolved tokens were 25 `{event_id}`, 2 `{patient_id}` and 1
    `{event}` - all generic, none of which a seeder emitting specific per-recipe
    tokens would ever satisfy, and every one of those markers already carried
    `needs=`. Installing the manifest would have changed nothing. Count the tokens
    before building the machine that fills them.

13. **A stale screenshot is a claim, and it was wrong in a way only the live app
    could show.** The Add Event dialog image showed a list that no longer matched
    the docs' table of 23 event types. Driving it live gave 21 for admin, and two
    distinct reasons: **DNA sample** is unreachable for *everyone* because its
    `event_type.rbac_operation_suffix` is `BloodSample` while the seeded authitem
    is `OprnCreateDnaSample`, so the check fails for every role (BUG-135); and
    **Genetic Results** needs a Genetics role the admin user does not hold. Both
    facts became doc content. "Admin sees everything" is false in OpenEyes - the
    admin role is not a superset - so a count taken from the DB is not the count
    on screen.

## Paths worth adding to the c-oe-nav skill (APPLIED 2026-08-05, approved by Manpreet)

Every bullet below is now folded into `~/claude-kit/skills/c-oe-nav/`: the Add Event
create-URL parameters, Support Services dead end, button states and the
offerable-vs-visible event-type count into `subs/paths.md`'s Add Event section; the
dead `/patient/episode(s)` routes and the change-of-context screen into its patient
section; `editSystemSetting` into its admin section; the two RTT admin pages (with
live-read field tables) replacing the `### Referral` stub in `subs/admin-forms.md`;
the RTT clock bar's location into `subs/examination.md`; the debug-toolbar selector
and the tmpfs `docker cp` correction into `subs/probe.md`. The `mariadb`-not-`mysql`
point was already there. Kept below as the record of where each came from.

- **Referral admin group** (new, absent from `subs/paths.md`'s 33-section table and
  from `subs/admin-forms.md`). Use the long routes only - the short
  `/Referral/admin/rttClockStateOptions` forms the module config declares are dead
  (BUG-144), while the four-segment `/Referral/admin/<Controller>/<action>` form
  does work:
  - `RTT Clock State Options` - `/Referral/ReferralAdmin/RTTClockStateOption/index`,
    edit at `.../edit?id=<id>` or `.../edit/id/<id>`. Fields: Type, Code, Name,
    Group, Guidance, Allowed next options, Clock running, Active.
  - `RTT Clock State Option Groups` -
    `/Referral/ReferralAdmin/RTTClockStateOptionGroup/index`, drag-to-reorder list
    (POST `.../sort`), fields Name and Active.
  - The sidebar group **Referral** sits between "Procedure management" and
    "Request forms", and renders its entries alphabetically, so Groups appears
    above Options even though the config declares Options first.
- **Editing a system setting** - `/admin/editSystemSetting?key=<key>&class=SettingInstallation`
  is the working route; `/admin/editSetting` 500s. With an institution selected in
  the site/institution picker, a system admin editing an installation-level setting
  writes a `SettingInstitution` row instead of the installation value - choose
  "All institutions" first.
- **Referral tables** are `referral_referral`, `referral_referral_rtt_clock_state`,
  `referral_rtt_clock_state_option`, `referral_rtt_clock_state_option_group` and
  `referral_rtt_clock_state_valid_next`, each with a `_version` twin. Not
  `referral` / `referral_rtt_clock_state`, which is the obvious guess and wrong.
- **RTT clock bar** sits inside the Clinical Outcome element of Examination
  (create/update/view), not on any route of its own - worth a line in
  `subs/examination.md` so it is not hunted for as a page.
- **Debug toolbar selector** `#yii2-debug` belongs in `subs/probe.md`'s screenshot
  guidance.
- **`/patientEvent/create` takes more parameters than the atlas records.**
  `subs/paths.md` currently documents `patient_id`, `event_type_id`, `context_id`,
  `episode_id`. The route also accepts `service_id` (required instead of
  `episode_id` when the dialog added a brand-new subspecialty, and sent alongside
  `episode_id` when the episode's service dropdown is used), `event_subtype`, and
  the worklist pair `step_id` + `worklist_patient_id` - the last of which is how a
  worklist pathway step opens an event without ever showing the dialog. Its error
  responses are worth recording too: 400 on a missing `context_id`/`event_type_id`,
  403 "Permission denied for creating event type.", 422 "Firm mismatch for service
  with existing Episode for patient", 400 "Episode/Context mismatch".
- **Change-of-context screen** - `protected/views/patient/change_event_context.php`
  reuses the Add Event dialog class in a `ChangeContext` mode and lists workflow
  steps fetched from `/ChangeEvent/findWorkflowSteps`. It appears nowhere in
  `subs/paths.md` or `subs/page-index.md`; reach path still to be established.
- **Two routes in the atlas's orbit are dead** and should be marked so nobody
  writes a repro step through them: `/patient/episode/<episode_id>` and
  `/patient/episodes/<patient_id>` both 404 (no `actionEpisode`/`actionEpisodes`
  exists). `/patient/summary/<patient_id>` is the only patient-record route.
- **Support Services is a dialog dead end** worth a line next to the Add Event
  table: for a patient with a support-services episode the Subspecialties column
  carries a `Support Services` tile (`data-subspecialty-id="SS"`); selecting it
  yields an empty Context column and the event list never appears (BUG-128).
- **Add Event button states** for repro steps: `#add-event` inside
  `nav#add-event-sidebar`; disabled "You have View Only rights" in the episode
  sidebar when the patient is deceased or `OprnCreateEpisode` is absent; disabled
  "You have View Only rights and cannot create events" on the no-episodes landing
  page. The two disabled labels differ, which matters when writing an assertion.
- **Two probe mechanics for `subs/probe.md`.** The database container has
  `mariadb` and no `mysql` binary, so every documented one-liner has to say
  `mariadb`. And `docker cp` out of the web container's `/tmp` silently fails
  because that path is a tmpfs - stream the file instead
  (`docker exec snail-web-1 cat /tmp/x.jpg > /host/path.jpg`).

10. **A contract that contradicts the code teaches every future author the wrong
    thing.** `AUTHORING_FORMAT.md` claimed for the corpus's whole life that chapters
    sort alphabetically by title and that front-matter `order:` does nothing;
    `DocSetExporter::groupChapters()` had always sorted by `order`. Two more of the
    same shape: `group:` was described as live-page-only while `chapterKeyFor()`
    always accepted it anywhere, and title normalisation (stripping everything before
    the last `>`) was undocumented behaviour the whole corpus silently depended on.
    When a contract and its implementation disagree, the code is the fact.

11. **`status:` without provenance is decorative.** 643 pages carried `reviewed` with
    no record of when, or against which commit, they were reviewed - so after a month
    of core development none of the stamps meant anything. The new `verified:` block
    (date, commit, methods) makes staleness arithmetic rather than a judgement call.

12. **The front-matter round-trip guarantee only holds for value shapes the parser
    knows.** Adding `access:` as an indented block map would have been silently
    destroyed on the next in-app editor save, because the hand-rolled front-matter
    parser matched no branch for indented lines and the emitter would have written
    "Array" into the file. Any future front-matter shape needs the paired parse and
    emit change or it dies at the next save.

13a. **Not every "missing guard" is a live bug - check the view is reachable.**
    The Add Event audit reported `episodes.php` as missing the `is_deceased`
    guard its two siblings have. True, but `PatientController` has no
    `actionEpisodes` (or `actionEpisode`), nothing renders `//patient/episodes`,
    and both routes 404 live - the view is dead code, and so is
    `_patient_episodes.php`. The real defect underneath was a live one nobody had
    looked for: OphCoCvi's create-cancel redirect points at that dead route
    (BUG-127). Before writing up a view-level defect, prove the view renders.

13b. **Three of the audit's nine defects were already logged.** D1 (Operation
    checklists 500 on `secondary_diagnosis`) is BUG-090, D3 (op-note elements
    with no `data-element-type-id` wrapper) is BUG-042, and D6 (Consent Type
    boundary at age 16) is already spelled out inside BUG-007's Actual section.
    A fresh agent re-finds known bugs at a high rate; grep the log by symptom
    *and* by file path before assigning a number.

13c. **23 event types are offerable, not 24.** `getEventTypeModules()` requires
    `parent_id IS NULL`; DNA extraction (`event_type` 46) has `parent_id = 45`
    (DNA sample), so it never reaches the dialog even though it is registered,
    manually creatable and has its own docs folder. What `admin` actually sees is
    fewer still - 21 on the current role set, because DNA sample and Genetic
    Results are filtered by `$api->createOprn` (`OprnEditDnaSample`,
    `OprnEditGeneticResults`), not by the `OprnCreate<rbac_operation_suffix>`
    pattern. Any "N event types" claim needs the qualifier "offerable" or
    "visible to this role".

13d. **Do not call it "the green Add Event button".** The markup is
    `class="button green add-event"` but the computed background is a slate grey
    on every patient tested. Describe controls by their label and position, not
    by a colour taken from a class name.

14. **Stale agent findings are a real hazard in a parallel campaign.** One agent
    reported "capture.cjs does not hide the debug toolbar" as an open defect; it had
    read the file before a sibling agent patched it. Verify a reported defect against
    the file's current state before acting - the host and container copies are now
    md5-identical and a fresh capture is confirmed toolbar-free.

15. **Page-count estimation has to be structural, not word-based.** The campaign
    started from a measured calibration of `actual ~= estimate x 1.2 + 5pp`, fitted
    on user-guide prose. It under-predicts the configuration manuals badly - one
    predicted 56 pages and built 86 - because those are many short pages that are
    mostly headings and table rows, which a words/450 estimator cannot see. The
    replacement, fitted against 33 real builds, is
    `words/600 + shots*0.4 + headings*0.1 + tableRows*0.055 + codeLines*0.03 + 7.5`
    (RMSE 3.9 pages, bias +1.0). Six docsets were over budget the moment the
    estimator became honest. Re-fit if the reference .docx template changes.

16. **A capture pipeline has to assert what it is photographing.** 103 of the shot
    markers pointed at events that were not what the page claimed - 66 at ids the
    database reset had destroyed, 37 at ids now belonging to a different event type
    (the CVI pages asked for what is now a Document event; the Cat-PROM5 pages for
    what is now a CVI). Before the guard, `screenshots --force=1` reported success
    and would have overwritten all 103 images with pictures of unrelated events.
    The fix needed no corpus edit: an OpenEyes event-view URL encodes its own module,
    so the expected type is derivable from the marker and checkable against the
    `event` table in one query. Generalises to any capture that navigates by id.

17. **A completeness gate earns its cost immediately in a parallel campaign.** The
    budget report's "pages no manual claims" check caught four sibling agents' new
    pages within minutes of each being written. Without it the built documents would
    have silently omitted them, and nothing downstream would have noticed.

18. **Seeding through the UI is fast enough that there is no argument for DB
    writes.** 11 recipes - four admin-configuration records, seven events, a user and
    a populated worklist - run in 31 seconds through the frontend, and a second run
    creates nothing. The one genuine exception is worklist patient loading, which no
    OpenEyes screen performs at all (it is a PAS push by design, not a gap).

19. **Placeholder tokens cannot be hyphenated.** `OeDocsCommand::loadDemoManifest()`
    resolves `{token}` with `preg_replace_callback('/\{([A-Za-z0-9_]+)\}/', ...)`,
    so a hyphen terminates the match and `{worklist-id}` can never resolve. The
    vocabulary is `lower_snake_case`, and the consumer only accepts scalar manifest
    entries - anything structured has to hide under a `_`-prefixed key.

20. **The roles list on the user-edit screen is not a curated subset.** It is
    `authManager->getRoles()` verbatim, less `admin` when the editor does not
    themselves hold `admin` - so all 66 roles are tickable, not the "meaningfully
    smaller subset" the plan assumed. Two other surfaces show different lists:
    Custom Menu Items offers all 232 auth items (roles, tasks *and* operations),
    SSO group mapping offers the same 66.

21. **`admin` cannot log in on its own.** It carries no path to `TaskLogin`, so an
    account holding only `admin` is refused at the login screen with the ordinary
    wrong-password message and recorded as a failed login. The minimum sign-in set
    is an active `user_authentication` row plus the `User` role (or
    `Automation Access` for a machine account); add `View clinical` before any
    patient data is reachable at all.

22. **`authitem.name` is `utf8mb3_bin`.** Any `LIKE` audit of the permission tables
    is case-sensitive and silently under-reports unless it is wrapped in `LOWER()`.
    That is how the dead-authitem count came out as 29 rather than the true 25.

23. **Underscored HTTP request headers do not survive to PHP on this stack.** The
    PASAPI README documents `X_OE_IDENTIFIER_RESOLUTION_CODE`; sent that way the
    header never appears in `$_SERVER` and the API answers "No Identifier Type Code
    has been provided", while `X-OE-Identifier-Resolution-Code` works (BUG-138).
    Verified against the container's own Apache, so it is not a proxy artefact.
    Any header this corpus documents must be quoted in the hyphenated wire form.

24. **A generated manifest that is not installed fails silently, and looks exactly
    like a manifest that is installed.** The seed suite wrote a correct
    `artifacts/oedocs_demo_manifest.json` with all ten tokens, but nothing was
    present at `protected/runtime/oedocs_demo_manifest.json` in the app container -
    installing it is a separate step at the end of `seed.sh`, so a partial run, a
    single-recipe run or a container recreate leaves the seeded data in place and
    the resolver blind to it. `loadDemoManifest()` treats an absent file as "no
    tokens" rather than an error, so every `{token}` URI just stays unresolved and
    the shot is classified manual. Re-installing the existing artifact is one
    `docker exec ... sh -c 'cat > path'` and costs nothing; check the file exists
    in the container before concluding that token resolution is unimplemented.

25. **A fact in an agent brief has a shelf life measured in hours.** Five agents
    were briefed that Document, CVI, Checklist, Lab Results, Cat-PROM5 and Device
    Usage hold zero events and that the worklist has one patient. All of that was
    true when written and false ninety minutes later, because the seed suite ran in
    between. In a parallel campaign the orchestrator is the only party that can see
    a shared-state change, and correcting a running agent mid-flight is far cheaper
    than letting it write `needs=` markers for data that now exists. State the
    counts in a brief as "verify this yourself with SQL" rather than as fact.

26. **Brief an agent with the docset id and the folder, never with a guessed list
    of filenames.** Two of five paths handed to the patient-record agent did not
    exist, because the docset map names *subtrees*
    (`user-guides/patients/searching`) and the brief translated them into files
    (`searching.md`). The agent recovered by finding the real pages, but a less
    careful one would have created duplicates that the map would never export and
    the link checker would never see. The map entry is the contract; `ls` the
    folder is the instruction.

27. **A bug already in the ledger will be re-found by a fresh pair of eyes, and
    that is fine as long as the merge catches it.** The patient-record pass
    returned the deceased-patient Add Event wording as a new finding; it is
    BUG-134, logged three weeks earlier from the same two views. Duplicate
    detection has to happen at merge time, by grepping the ledger for the
    *symptom* rather than the file, because the two reports described the same
    defect in completely different words.

28. **A database reset invalidates every event id in the bug ledger, and nobody
    notices until an agent trips over it.** The examination pass reported that
    events 3687019 and 3687021 - cited as evidence on BUG-050 - do not exist. They
    did when that bug was written; the reset to sample took the highest event id
    back to 3687002. Bug evidence should cite the *element or view* that is broken,
    which survives a reset, and treat a specific id as a convenience that expires.
    BUG-050 now carries a note saying so.

29. **Element ids and event ids are different sequences, and an agent will
    conflate them.** The same pass reported that event 3686999 is a "DUMMY - DON'T
    USE" record; it is in fact the Cat-PROM5 event the seeder created this morning,
    undeleted, on the demo patient. Something numbered 3686999 in another table
    carries that label. Any "this id is bad" claim from an agent gets one SQL
    query against `event` before it is acted on, because acting on it means
    re-aiming a shot marker at the wrong screen.

30. **An idempotency probe must test for the state the recipe promises, not for
    the existence of a record of that type.** The seeder's Checklist recipe asked
    "does this patient already have a Checklist event?", found one, and skipped
    its work. The event it found had `checklist_instance` = 0 rows, because the
    application commits an empty Checklist event the instant Checklist is chosen
    in the Add Event dialog (BUG-175) and nobody had ever answered it. The seed run
    therefore reported success, wrote `checklist_event_id` into the manifest, and
    left the corpus pointing at an empty screen. The timestamps are what exposed
    it: every genuinely seeded event landed between 07:45:39 and 07:57:00, and
    that Checklist event was created at 07:18:47. **A manifest token is a claim
    that a screen shows something; verify the something, not the row.** The
    general form: "a record of type X exists" is never the same assertion as "a
    record of type X is in the state this documentation pictures".

31. **A seed run that reports success can still leave a recipe undone.** Because
    of the above, treat the manifest as untrusted input to the screenshot pass:
    before re-aiming any marker at a token, query for the rows that make that
    screen worth photographing. This cost nothing to check and would have
    produced a wrong picture in the finished manual otherwise.

32. **A path repeated in eleven agent briefs is worth checking once.** Every brief
    this campaign pointed agents at `docs/help/AUTHORING_FORMAT.md` for the corpus
    conventions. The file is at the repository ROOT, `AUTHORING_FORMAT.md`; there
    has never been a copy under `docs/help/`. Capable agents recover by searching,
    but the failure mode when they do not is the worst one available - an agent that
    cannot find the conventions file invents conventions, and the damage only shows
    up at export. Anything a brief template asserts about the filesystem should be
    verified once, on the first use of the template, not on the eleventh.

33. **The docset map is checkable as a partition, and checking it is cheap.**
    Every page under `user-guides/` and `devops/` should be claimed by exactly one
    `manual` docset; `topic` docsets sit outside the partition by design and are
    excluded. A 40-line script over `data/docsets.php` answers three questions at
    once - which pages no manual would export, which two manuals would both export
    the same page, and which selectors point at nothing. Run at 2026-08-05 it
    returned 655 pages, zero unowned, zero genuinely double-owned, zero unresolved
    selectors. That is a stronger completeness guarantee than any per-docset review
    gives, and it is worth re-running as the last gate before Phase E builds.
    Script kept at `scratchpad/partition_check.py`. One caveat: a docset that names
    an `overview:` page AND `include:`s the folder containing it reports as
    double-owned and is not a defect - `resolveDocset()` filters the overview back
    out of the chapters before emitting.

34. **A folder-selected docset needs `order:` and `group:`, or the exporter
    guesses.** With `include:` (rather than an explicit `chapters` map) the exporter
    chapters each page by its parent folder name and sorts within a chapter by
    `order:` ascending, falling back to alphabetical-by-title for anything with no
    `order:`. Two consequences bite: a branch `_overview.md` swept up by a folder
    selector is NOT lifted out as the manual's introduction unless the docset also
    names it in an `overview:` key, and a page meant to lead its chapter will not
    unless it carries the lowest `order:` in that folder. Both were true of
    `roles-and-permissions` until fixed. `group:` in front matter overrides the
    folder-derived chapter name and is the right way to name a chapter something
    other than its directory - but it is ignored entirely when the docset uses an
    explicit `chapters` map, where the map wins.

35. **Two samples are not a calibration, and a plan document is not the code.**
    Building two docsets and counting their PDF pages made the estimator look
    badly over-calibrated - both raw estimates landed within 4% of reality. Building
    all 34 reversed it completely: the raw estimator has 15.3% mean error and
    under-predicts by 6 pages systematically, while the implemented `raw + 7.5`
    has 8.4% error and near-zero bias. The two "accurate" samples were noise.
    A whole-population measurement here cost one background command and almost no
    tokens, which is the general shape of it - when the population is small and
    the measurement is mechanical, measure the population, do not sample it.
    Second half of the lesson: the plan text said the calibration was `x1.2 + 5pp`,
    and the code does `+ 7.5`. I computed error bars against the plan's formula and
    got a table of meaningless numbers. Derive the formula from the output you are
    checking (every budget row differed from its estimate by exactly 7.5), not from
    the document that describes it.

## Screenshot conventions confirmed in practice

- **1280x900 is the corpus viewport.** It is the `oedocs screenshots` default and the
  width of all 404 existing images in `docs/screenshots/**`. Ad-hoc captures at other
  widths (a 1440-wide one appeared this session) make the built Word documents render
  inconsistently, so every capture - command-driven, agent-driven or walker-driven -
  uses 1280x900.
- **The debug toolbar suppression is live and working.** `#yii2-debug` is hidden in
  both the host and the in-container copy of `resources/capture.cjs`, and a spot check
  of a freshly captured admin page confirms the toolbar is absent from the image.
- **Element crops keep the element's own width.** The 1280x900 rule is the viewport,
  not the image: a selector-clipped crop comes out as wide as the element, and in
  `docs/screenshots/user-guides/patients/adding-events/examination/` that is 1080px
  for 75 of the 89 existing shots. Match the neighbours in the folder rather than
  padding a crop out to 1280.
- **`fullPage: true` does not solve a tall admin page.** It produced a 900px-tall
  image that still clipped the navigation. Capture at viewport 1280x2400 with
  `fullPage: false` instead.
- **Admin pages legitimately look grey.** The washed-out tone of admin screenshots is
  the application's own admin theme, not a leftover loading mask - existing corpus
  images from the previous campaign have exactly the same tone. Do not "fix" it.
- **Some create forms write on the GET, so a capture URL is not automatically a read.**
  `ChecklistManager::addRequiredChecklists()` runs its create branch only when the
  request is *not* a POST, and it is called from the create actions of Operation note,
  Laser, Intravitreal injection and Examination (BUG-177). On this installation
  `checklist_sets` is empty so nothing is written, but the moment an administrator
  configures a checklist set, every screenshot run aimed at those URLs would start
  seeding Checklist events. Separately, `/OphCoChecklist/default/create` writes
  unconditionally (BUG-175). The rule: before pointing a marker at any `create` action,
  read the controller - do not assume a GET is safe because GETs usually are.
- **An op-note element clip has to be aimed at `/update/`, not `/view/`.** BUG-042
  suppresses the `section[data-element-type-id]` wrapper on the view route only;
  `Element_OnDemand::getContainer_form_view()` returns a real view, so the wrapper is
  present on the edit route. That single re-aim turned fifteen op-note element shots
  from "blocked by an app bug" into ordinary auto-captures - worth checking for on any
  other event type whose elements refuse to clip.

## Ledger of system-state changes made during the campaign

(recorded so the sample DB stays re-resettable and reproducible)

**Seeded through the interface** (reproducible by re-running the seed suite; no
revert needed, and none of it edits shipped sample data):

- 4 administration records: a checklist type and its category, and the
  supporting lookup rows the checklist screens need.
- 7 clinical events across the previously empty event types, on the
  demonstration patient.
- 1 user, `docwalker` (id 6670), holding the minimum roles that allow sign-in,
  plus the roles granted one at a time as the permission ladder hit blocks.
- 1 worklist populated with 5 patients, through the API exception recorded in
  `docs/help/demo-data-recipes.md`.

**Seeded for the RTT pages, partly outside the interface** (the referral has no
interface path at all - see the recipe). Left in place so the captures can be
re-checked; revert with:

`DELETE FROM referral_referral_rtt_clock_state WHERE id IN (1,2); DELETE FROM referral_referral_rtt_clock_state_version WHERE id IN (1,2); UPDATE worklist_patient SET referral_id=NULL, visit_reference=NULL WHERE id=1; DELETE FROM referral_referral WHERE id=1; DELETE FROM referral_referral_version WHERE id=1; UPDATE event SET event_date='2023-01-12 11:22:18' WHERE id=3686621; DELETE FROM setting_installation WHERE id=104;`

- `setting_installation` id 104 - `enable_rtt_clock_bar` = 1. The setting had no
  row at all before; the shipped default is off.
- `referral_referral` id 1 - external reference `DOCS-RTT-0001`, patient
  1961284, institution 1, referral date 2026-05-20.
- `referral_referral_rtt_clock_state` ids 1 and 2 - the running clock and the
  outcome recorded against examination event 3686621.
- `worklist_patient` id 1 - gained `referral_id` and `visit_reference`, both
  previously NULL.
- `event` 3686621 - **`event_date` moved** from 2023-01-12 to 2026-08-05 so that
  event would be the clock's tip. This is the one change in the campaign that
  edits pre-existing sample data, and it should not be repeated: the recipe now
  says to add the clock state on a new examination instead.
