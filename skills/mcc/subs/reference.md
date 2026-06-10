# mcc — curl recipes and snippets

## REST from curl

```
A=(-sk -u admin:admin -H 'X-Requested-With: x')      # X-Requested-With is REQUIRED; -k for self-signed
B=https://localhost:8443/api
curl "${A[@]}" -H 'Accept: application/json' "$B/server/about"     # version/connectors
```

Send `Accept: application/json` **or** `application/xml` explicitly. `GET /server/version` returns 406 — use `/server/about`.

## Channel lifecycle

```
ID=<channelId>
curl "${A[@]}" -H 'Content-Type: application/xml' -X PUT --data-binary @chan.xml "$B/channels/$ID?override=true"   # import -> {"boolean":true}
curl "${A[@]}" -X POST "$B/channels/$ID/_deploy"     # deploy -> 204 (ALSO runs the global Deploy script)
curl "${A[@]}" "$B/channels/statuses"                # STARTED/STOPPED per channel + connector
curl "${A[@]}" -H 'Accept: application/xml' "$B/channels/$ID/messages?includeContent=true&limit=60"
```

Inspect messages: parse `<connectorMessage>` by `<metaDataId>`; `<sent>` holds the outbound HTTP request (headers included), `<response>` the server reply.

## Global scripts and configuration map

- `GET/PUT /server/globalScripts` — mirror the exact map schema, mutate only the `Deploy` entry, PUT → 204. Deploy any channel to make it run.
- `GET/PUT /server/configurationMap` — **PUT REPLACES the whole map** (GET → merge → PUT); 204. Good as a server-side, never-exported secret store for a demo box.
- Deploy-script template: `/home/toukan/common.js` — resolves each var `/run/secrets/<name>` → env `<name>` → config map → default, puts it UPPER-CASED into `globalMap`, and pre-builds derived headers (`globalMap.put('OE_API_AUTH', 'Basic ' + base64(user+':'+pass))`).

## Secret-freeness acceptance test

`curl GET /channels/{id}` then grep the XML for the plaintext **and** the base64 of `user:pass` — both must be absent. Apostrophes in JS export as `&apos;`, so grep for `globalMap.get(&apos;...` not `globalMap.get('...`.

## Velocity resolution

`${VAR}` resolves against connector/channel/response/source maps, globalChannelMap, globalMap, configurationMap. globalMap → bare `${VAR}`; configurationMap → `${configurationMap['KEY']}`. NOT substituted in HTTP Sender `username`/`password` fields.

## Rhino / JDK snippets

- JS strings are not `java.lang.String`: `new java.lang.String(s).getBytes('UTF-8')`; coerce Java→JS with `'' + x`.
- `new java.net.URL(u).openConnection()` returns a `sun.net.*` impl whose methods aren't directly callable — invoke via reflection on the public superclass:
  `Class.forName('java.net.HttpURLConnection').getMethod('setRequestMethod', java.lang.String).invoke(con, 'POST')`.
- Base64: `java.util.Base64.getEncoder().encodeToString(...)` (`javax.xml.bind` is gone in JDK 11+).
- Session reuse: capture `Set-Cookie` (`JSESSIONID=`) into globalChannelMap, replay as a `Cookie` header; drop and re-auth on 401.
