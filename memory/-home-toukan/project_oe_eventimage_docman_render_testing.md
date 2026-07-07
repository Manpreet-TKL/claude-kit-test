---
name: project_oe_eventimage_docman_render_testing
description: "On sample OE containers, yiic eventimage fails silently (docman auth) - drive renders via a direct admin web session instead"
metadata: 
  node_type: memory
  type: project
  originSessionId: 07be89dc-286d-4f20-a4b0-9874e2333c4c
---

To behaviourally test OE document/correspondence rendering (Puppeteer/imagick/ghostscript `/tmp`
leaks) on a sample container, do **not** rely on `yiic eventimage`. `createImageForEvent` curls
`/{module}/default/createImage/{id}` server-side using **docman** creds, which fail on the
sample web containers (e.g. `snail-web-1`): the cookie jar is still written (so a cookie-jar
leak still reproduces) but the render is never invoked, and the command does **not** check the
curl HTTP code - it prints "Successfully created EventImages" while creating nothing. It also
**deletes** existing `event_image` rows before (failing to) regenerate, so it silently wipes
preview caches.

**How to apply:** authenticate a direct web session with `admin`/`admin` **plus**
`LoginForm[institution_id]` and `LoginForm[site_id]` (1/1 on the sample - both are required;
CSRF is cookie-backed so the hidden token field may be empty), then
`GET /{module}/default/createImage/{id}` (or `/PDFprint/{id}`) yourself and diff `/tmp`
before/after. `event_image` is a regenerable derived cache, not clinical data. Document-leak
paths (OphCoDocument imagick/ghostscript/pdf-preview) need an OphCoDocument event **with a file
attachment** - the seeded sample DB has none. See `~/oe-tmpfix-notes.md`.
Related: [[reference_oe_puppeteer_temporarydirectory_mkdtemp]], [[project_monkey_remote_chrome]].
