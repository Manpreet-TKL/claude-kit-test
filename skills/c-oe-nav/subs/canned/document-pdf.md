# Canned walk - Document event + PDF preview temp-leak (`oe_pdf` stub family)

One-command verification of the PDF-preview temp-leak repro on a sample stack. Everything here ran green on v11.0.18 (snail, 2026-07-03): launch a **Haiku** subagent with the Procedure below pasted in - no need to read `probe.md` or `paths.md` for this walk. Main-context cost ~ this file; subagent cost ~ 35k tokens / 2 driver runs.

Parameters: `<web>` = web container (e.g. `snail-web-1`). Sample ids: patient 17891, `context_id=13`, `episode_id=601038`, Document `event_type_id=40` - a stale pair fails fast with HTTP 400 "Episode/Context mismatch"; re-pick via `c-dblogin` only then.

**Patched-or-not, before walking** (predicts the outcome; unpatched = single-line `tempnam(...) . '.png'`, no `finally`):

```bash
docker exec <web> sh -c "grep -n 'oe_pdf' /var/www/openeyes/protected/controllers/BaseEventTypeController.php"
```

Procedure (Bash, in order; upload + Save are authorized writes on sample boxes only):

1. Test PDF (gs ships in web-live; one `showpage` per page):
   `docker exec <web> sh -c 'gs -q -o /tmp/twopage.pdf -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=300 -dDEVICEHEIGHTPOINTS=300 -c "showpage showpage"'`
2. Count before: `docker exec <web> sh -c 'ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l'`
3. Create the Document event; take `<event_id>` from the final snapshot URL `/OphCoDocument/default/view/<event_id>`. Add `{"dump":true}` after the goto only if labels need re-quoting.

   ```bash
   docker exec -i -e OE_ALLOW_WRITE=1 -e OE_ACTIONS='[{"goto":"/patientEvent/create?patient_id=17891&event_type_id=40&context_id=13&episode_id=601038"},{"select":["#Element_OphCoDocument_Document_event_sub_type","1"]},{"upload":["#Document_single_document_row_id","/tmp/twopage.pdf"]},{"wait":2000},{"click":"#et_save"},{"wait":3000}]' \
     -w /var/www/openeyes <web> node --input-type=module - < ~/.claude/skills/c-oe-nav/scripts/journey.mjs
   ```
4. Build the previews (fires `createPdfPreviewImages()`, same endpoint the lightning-viewer icon fires); done when the JSON shows `"page_count":2`:

   ```bash
   docker exec -i -e OE_ACTIONS='[{"goto":"/eventImage/getImageInfo?event_id=<event_id>"},{"read":"body"},{"wait":5000},{"goto":"/eventImage/getImageInfo?event_id=<event_id>"},{"read":"body"}]' \
     -w /var/www/openeyes <web> node --input-type=module - < ~/.claude/skills/c-oe-nav/scripts/journey.mjs
   ```
5. Count after + evidence: `docker exec <web> sh -c 'ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l; ls -la /tmp/oe_pdf* 2>/dev/null | head'`
6. Clean up the test PDF only (`docker exec <web> rm -f /tmp/twopage.pdf`); leave the leaked stubs - they are the evidence.

Expected: unpatched +1 zero-byte `oe_pdfXXXXXX` stub per page (2-page PDF -> +2); patched -> count unchanged. The shipped Steps to Reproduce this verifies are the worked example in `c-oe-repro`'s SKILL.md.
