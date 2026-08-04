# Canned walk - Lightning Viewer (patient sidebar icon -> event page previews)

Opens a patient's Lightning Viewer from the sidebar icon, selects an event and watches its page previews build. Walked green on develop (2026-08-04) via Claude in Chrome; replays are rung 1 with the scripted procedure below. The viewer is the frontend trigger for `EventImageManager` preview renders (`createPdfPreviewImages()` for Document PDFs), so this journey is the UI half of every event-image render or temp-leak repro.

Parameters: `<web>` = web container; `<patient_id>`, `<event_id>` from the instance (re-pick via `c-dblogin`).

Frontend path (Chrome walk or human):

1. Log in and open any patient record (top-bar 'Search' box, surname or ID, then click the result row).
2. The icon: left sidebar, in the small grey icon strip directly below the green 'Add Event' button (which sits below the blue patient banner). The strip reads `CA PC GL MR <bolt> <person>`; the lightning bolt is the 5th item, between the 'MR' link and the person icon. 15x15, blue bolt on grey, inverting to white-on-blue when hovered/active. NO tooltip, title, alt or aria-label - nothing on screen names it. Markup: `<a href="/patient/lightningViewer/<patient_id>" class="lightning-viewer-icon">`.
3. The viewer opens on the 'Letters' timeline: a horizontal strip across the top with year headings (each with a count) and one unlabeled icon per event; a white callout at the top-left of the preview stage names type/date on hover; stage hint "swipe to scan | click to lock".
4. Timeline type menu: the lightning/chevron button at the far LEFT of the strip. There is NO 'Document' entry - Document events file under 'General'. Pick the type, then click the event's icon to lock it.
5. While previews build: spinner plus "No preview is available at this time"; on completion the pages render and the event's image count goes 0 -> N.

Gotchas (hard-won):

- An open viewer page POLLS `/eventImage/getImageInfo` and re-fires `generateImage` whenever rows are missing - a viewer tab left open (e.g. in the walker container) keeps re-rendering wiped events, showing up as no-UA internal GETs to `/OphCoDocument/default/createImage/<id>` in access.log. Close the tab or reboot the walker before measuring anything render-related.
- Scripted replays skip the viewer entirely: an authenticated GET to `/OphCoDocument/default/createImage/<event_id>` deletes the event's `event_image` rows and re-renders unconditionally - no DB wipe needed to force a render.
- develop's multi-step site picker breaks journey.mjs `login()`; prefix OE_ACTIONS with: `[{"login":false},{"goto":"/site/login"},{"click":"li.js-site[data-id=\"1\"]"},{"wait":800},{"fill":["#LoginForm_username","admin"]},{"fill":["#LoginForm_password","admin"]},{"click":"#login_button"},{"wait":3000}]` (sample-box default credentials).
- Detecting in-flight ImageMagick scratch in the web container: use `ls -la /tmp | grep magick`; the glob form `ls /tmp/magick-*` intermittently fails to match files that exist when run inside `docker exec` watch loops (mechanism undiagnosed; it burned three watch runs).

Scripted replay (rung 1, Haiku subagent) - force a render, then confirm completion:

1. `docker exec -i -e OE_ACTIONS='[<login prefix above>,{"goto":"/OphCoDocument/default/createImage/<event_id>"},{"wait":1000}]' -w /var/www/openeyes <web> node --input-type=module - < ~/.claude/skills/c-oe-nav/scripts/journey.mjs`
2. Completion: `{"goto":"/eventImage/getImageInfo?event_id=<event_id>"},{"read":"body"}` shows `"page_count":N`, or count `event_image` rows via `c-dblogin`.

Bug ledger:

- Imagick scratch leak (`magick-*`): scratch (a 1-byte pixel-cache file, one ~42KB delegate output per PDF page, and a symlink to the source PDF) lives in /tmp only during the render and is fully removed on clean completion; killing the apache2 worker mid-render orphans all of it, and later clean renders never remove the orphans. Reproduced 2026-08-04 on develop; PR: `~/pullrequests/pushed/oe-pr-tmp-imagick-scratch-leak`.
- `oe_pdf` stub leak: +1 zero-byte `oe_pdfXXXXXX` stub per PDF page on EVERY render, clean or interrupted (sibling walk `canned/document-pdf.md`).
- Viewer paging glitch: an event whose previews finish building only after the viewer page loaded is backfilled by the poll but left `data-paged=""` - only page 1 gets a layout box; pages 2-N sit in the DOM at zero size and cannot be scrubbed to until the viewer is reloaded.
