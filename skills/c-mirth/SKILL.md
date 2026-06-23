---
name: c-mirth
description: BridgeLink/Mirth (mc container) ops, REST API, secrets
disable-model-invocation: true
---

# Mirth / BridgeLink (mc)

When loaded as context with no task, reply only `Context loaded.`

BridgeLink 4.6.1 (Innovar fork of Mirth Connect). **"Mirth", "Mirth Connect", "`mc`" and "BridgeLink" are used interchangeably** — the same integration engine; `mc` is the container/service name, BridgeLink is the Innovar fork of Mirth Connect that ships. Container `*-mc-1`, network `<proj>_backend`, `-Xmx512m`. Pin image tags to a patch (`4.6.1` — there is no bare `4.6`). Curl recipes, lifecycle commands, Rhino snippets: `subs/reference.md`. OE PAS specifics: `c-pasapi` skill.

## Mirth/BridgeLink version by OE release

Pin the `mc` image to the BridgeLink line for the OE version (kit pins the patch `4.6.1`):

| OE | Mirth/BridgeLink |
|----|------------------|
| 7–9.x | 4.4 |
| 10.0, 11.0 | 4.5 |
| 11.1, 26.0 | 4.6 |
| 26.1 | 26.3 |

## REST API

`https://localhost:8443/api`, Basic `admin:admin`, `-k` for self-signed. `X-Requested-With: <anything>` header is mandatory (403 without). Send an explicit `Accept:` (`GET /server/version` 406s — use `/server/about`). Import: PUT XML to `/channels/<id>?override=true`; deploy: POST `/channels/<id>/_deploy` → 204 (also runs the global Deploy script).

## Secrets stay out of exports (globalMap pattern)

Channel XML committed to git contains only `${VAR}`, never a password. The global Deploy script (template `/home/toukan/common.js`) resolves each var `/run/secrets` → env → config map → default into `globalMap`, pre-building derived headers (`OE_API_AUTH` = `Basic <base64>`). Channel / code-template / global-script exports are secret-free; the full **Server Configuration export is NOT** (it embeds the configuration map) — never commit it. `PUT /server/configurationMap` replaces the whole map: GET → merge → PUT. No git plugin — "push to git" = export XML, then commit.

## Gotchas

- Velocity `${...}` is NOT substituted in HTTP Sender `username`/`password` (goes out literally → 401): set `useAuthentication=false`, blank user/pass, send `Authorization: ${OE_API_AUTH}` header instead.
- `globalChannelMap` is CLEARED on every (re)deploy — watermarks/seen-sets reset; pollers re-emit everything once.
- Cumulative channel statistics can't be cleared via REST (the clear endpoints 404).
- Rhino: wrap JS strings for Java calls; invoke `HttpURLConnection` methods via reflection on the public superclass; Base64 via `java.util.Base64`.
- Big channel XML chokes the Edit tool — patch with an asserted Python script (count-checked `str.replace`, `.before` backup).
