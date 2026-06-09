---
name: mcc
description: Mirth Connect / BridgeLink (the "mc" container) operational know-how learnt on the OE stacks — driving the REST API from curl, the secrets-in-globalMap pattern that keeps channel exports credential-free, velocity-replacement gotchas, Rhino/JDK scripting quirks, and channel import/deploy/inspect. Invoke by name when working on BridgeLink channels, the mc container, configuration/global scripts, or HL7 integration. For OpenEyes PAS API specifics and the OpenMRS->Mirth->OE data flow, use the `pasapi` skill instead.
disable-model-invocation: true
---

# Mirth / BridgeLink (mc) — field notes

BridgeLink 4.6.1 (the Innovar fork of Mirth Connect). Container `*-mc-1`,
network `<proj>_backend`, `-Xmx512m`. Channels are stored as `version="4.4.2"`
XML even on 4.6.1.

## Drive the REST API from curl

```
A=(-sk -u admin:admin -H 'X-Requested-With: x')      # X-Requested-With is REQUIRED; -k for self-signed
B=https://localhost:8443/api
curl "${A[@]}" -H 'Accept: application/json' "$B/server/about"     # version/connectors
```
- Send `Accept: application/json` **or** `application/xml` explicitly. `GET /server/version` returns **406** — use `/server/about`.
- `X-Requested-With` (any value) is mandatory or you get a 403/redirect.

## Channel lifecycle

```
ID=<channelId>
curl "${A[@]}" -H 'Content-Type: application/xml' -X PUT --data-binary @chan.xml "$B/channels/$ID?override=true"   # import -> {"boolean":true}
curl "${A[@]}" -X POST "$B/channels/$ID/_deploy"     # deploy -> 204 (ALSO runs the global Deploy script)
curl "${A[@]}" "$B/channels/statuses"                # STARTED/STOPPED per channel + connector
curl "${A[@]}" -H 'Accept: application/xml' "$B/channels/$ID/messages?includeContent=true&limit=60"
```
Inspect messages: parse `<connectorMessage>` by `<metaDataId>`; `<sent>` holds the
outbound HTTP request (headers included), `<response>` the server reply.

## Keep secrets out of exports (the globalMap pattern)

The whole point: **channel XML committed to git contains only `${VAR}`, never a password.**

- A Global **Deploy** script (template: `/home/toukan/common.js`) resolves each var
  `/run/secrets/<name>` -> env `<name>` -> config map -> default, and puts it
  UPPER-CASED into `globalMap`. Pre-build derived Basic-auth headers there too
  (`globalMap.put('OE_API_AUTH', 'Basic ' + base64(user+':'+pass))`).
- Channels reference bare `${VARNAME}` (globalMap). The mc REST API:
  `GET/PUT /server/globalScripts` — mirror the exact map schema, mutate only the
  `Deploy` entry, PUT -> 204. Deploy any channel to make it run.
- `GET/PUT /server/configurationMap` — **PUT REPLACES the whole map** (GET -> merge ->
  PUT); 204. Good as a server-side, never-exported secret store for a demo box.
- **What is safe to push to git:** channel / code-template / global-script exports —
  they never include `globalMap` or `configurationMap` values. **What is NOT:** the
  full *Server Configuration* export — it embeds the configuration map. Don't commit that.
- BridgeLink 4.6.1 has **no git plugin**; "push channels to git" = export the XML
  (Administrator or REST) then commit. Secret-freeness comes from the pattern, not a tool.
- Acceptance test: `curl GET /channels/{id}` then grep the XML for the plaintext **and**
  the base64 of `user:pass` — both must be absent. (Apostrophes in JS export as `&apos;`,
  so grep for `globalMap.get(&apos;...` not `globalMap.get('...`.)

## Velocity replacement — what is and isn't substituted

- `${...}` **is** replaced in a connector's host, content, and headers — but **NOT** in
  the HTTP Sender's `username`/`password` auth fields (they go out literally -> 401).
  So to authenticate with no literal creds: `useAuthentication=false`, blank user/pass,
  and add header `Authorization: ${OE_API_AUTH}`.
- `${VAR}` resolves against connector/channel/response/source maps, globalChannelMap,
  globalMap, configurationMap. globalMap -> bare `${VAR}`; configurationMap ->
  `${configurationMap['KEY']}`.

## Rhino / JDK scripting gotchas

- JS strings are not `java.lang.String`: wrap before calling Java methods —
  `new java.lang.String(s).getBytes('UTF-8')`; coerce Java values to JS with `'' + x`.
- `new java.net.URL(u).openConnection()` returns a `sun.net.*` impl whose methods aren't
  directly callable. Invoke via reflection on the **public** superclasses
  (`java.net.URLConnection` / `java.net.HttpURLConnection`):
  `Class.forName('java.net.HttpURLConnection').getMethod('setRequestMethod', java.lang.String).invoke(con, 'POST')`.
- Base64: `java.util.Base64.getEncoder().encodeToString(...)` (`javax.xml.bind` is gone in JDK 11+).
- Session reuse in JS: capture `Set-Cookie` (e.g. `JSESSIONID=`) into globalChannelMap and
  replay it as a `Cookie` header on later requests to avoid re-login; drop it and re-auth on 401.

## Operational facts that bite

- `globalChannelMap` is **CLEARED on every (re)deploy** — watermarks / seen-sets reset, so a
  poller re-emits everything once after a redeploy. `globalMap` is repopulated by the Deploy
  script each deploy.
- Cumulative channel **statistics can't be cleared** via REST (the clear endpoints 404).
- Editing big channel XML: the `Edit` tool chokes on large base64/XSLT-heavy files — use an
  **asserted Python patch script** (count-checked `str.replace`, write a `.before` backup) instead.

## When to invoke this skill

`disable-model-invocation: true` — Claude will not auto-load it. Invoke by name when you
want this BridgeLink context loaded fast. OE PAS specifics live in the `pasapi` skill.
