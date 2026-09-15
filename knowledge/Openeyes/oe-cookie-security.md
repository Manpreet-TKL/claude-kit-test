# Cookie security in OpenEyes (2026-08, verified against v26)

Read when reviewing what cookies an OpenEyes deployment sets, hardening them,
or answering a pen-test finding about cookie attributes. Everything below was
verified against a v26 stack (PHP 8.4, Yii 1.1, web + dev images); file paths
are inside the web container unless stated. Placeholders like `<oe-host>` and
`<project>` stand for any deployment.

## The cookies OpenEyes sets

Observed on `GET /site/login`:

| Cookie | What it is | Flags observed |
|---|---|---|
| `OESESSID` (oe-deploy renames it `<project>_OESESSID`) | Session id - the "claim ticket" for the server-side session | `HttpOnly; SameSite=Strict; Max-Age=43200; path=/` - **no `Secure`** |
| `YII_CSRF_TOKEN` | Anti-forgery token, matched against a hidden field on every POST | `HttpOnly; SameSite=Lax; path=/` (browser-session lifetime) - **no `Secure`** |

Two more that exist in code but rarely in practice:

- **Remember-me / auto-login cookie**: the mechanism is enabled
  (`'allowAutoLogin' => true` in the `user` component; a ticked box would mean a
  30-day cookie, `protected/models/LoginForm.php` `login()`), but the login view
  never renders the `rememberMe` checkbox, so the cookie is never issued.
- **Laravel session cookie configuration**: `oe-laravel/config/session.php`
  defines a database-backed cookie with `Path=/`, `HttpOnly`, `SameSite=Lax`,
  and `Secure` only when `SESSION_SECURE_COOKIE=true`. The live `/xapi/*` API
  routes use the stateless `api` middleware and HTTP Basic authentication on
  every request, so they do not rely on a Laravel session cookie.

## How the session actually works

- The cookie value is only a random id. Session data (logged-in user id,
  selected institution/site/firm) lives server side in the `user_session` DB
  table: the `session` component is `OESession`
  (`protected/components/OESession.php`), a `CDbHttpSession` with
  `connectionID => db`, `sessionTableName => user_session`.
- **Sliding expiry**: every request rewrites the session row and pushes the
  expiry forward (`OESession::writeSession`), except requests carrying
  `extend_session=false` in the query string - that path
  (`writeSessionWithoutExtending`) updates data without touching `expire`, so
  background polling cannot keep an idle screen alive forever.
- **Two independent lifetimes**:
  - `session.cookie_lifetime = 43200` (12 h) - how long the *browser* keeps the
    cookie, surviving browser restarts.
  - `session.gc_maxlifetime` - the *server-side* idle timeout (image default
    14400 = 4 h; oe-deploy default 1800 = 30 min). `OESession::getTimeout()`
    returns `gc_maxlifetime - 10`. When it expires the DB row dies; the browser
    cookie becomes a worthless ticket.
- **Login regenerates the id**: `CWebUser::changeIdentity()` calls
  `regenerateID(true)` (`vendor/yiisoft/yii/framework/web/auth/CWebUser.php:715`),
  and `session.use_strict_mode = 1` makes PHP refuse ids the server never
  issued. Together these kill session-fixation attacks.
- **Cookie tamper seal**: `enableCookieValidation` is on unless
  `OE_ENABLE_COOKIE_VALIDATION=false` (request component,
  `protected/config/core/common.php`). Yii HMAC-signs cookies managed through
  its request cookie collection with
  `securityManager->validationKey`, which is loaded from
  `/run/secrets/OE_COOKIE_VALIDATION_KEY` or the `OE_COOKIE_VALIDATION_KEY` env
  var (`core/common.php` ~line 1336). This covers application cookies such as
  the CSRF token, not the PHP-managed session id. It is a signature, not
  encryption.
- **CSRF**: `enableCsrfValidation => true`, but the custom `HttpRequest`
  (`protected/components/HttpRequest.php`) detaches the check for any route
  whose URL *starts with* an entry in `noCsrfValidationRoutes`: `site/login`,
  `api/`, `Api/`, the `OphCoDocument` upload actions (oversized-upload error
  handling), and `sso`.

## Cookie terms and their security implications

A **cookie** is a name/value pair that a server asks a client to store and send
back on matching requests. A **session** is the server-side record of the
login. `OESESSID` is only the lookup key for that record, but it is still a
sensitive bearer credential: anyone who steals a live value can use the
session without knowing the password.

| Attribute | What it means | Security effect | Compatibility effect in OpenEyes |
|---|---|---|---|
| `Secure` | Send the cookie only on a secure connection, normally HTTPS. | Prevents the session id being exposed on a plain HTTP request. It does not encrypt the cookie itself, replace TLS, or protect a cookie copied by some other route. | Needed for an HTTPS production deployment. It works when TLS ends at Traefik because the client-facing request is still HTTPS. A client that continues to use plain HTTP will stop returning the session cookie and appear unable to stay logged in. |
| `HttpOnly` | Do not expose the cookie through browser JavaScript APIs. | Makes session theft harder after an XSS injection, although injected script can still make authenticated requests from the page. | Safe for OpenEyes because application JavaScript does not need to read either observed cookie. |
| `SameSite` | Controls whether a browser attaches the cookie when another site initiated the request. "Site" is based on the URL scheme and registrable domain, not the full origin. | Defense in depth against CSRF and some cross-site information leaks. It does not replace the CSRF token. Many non-browser HTTP clients do not enforce it. | `Strict` can withhold the login on the first request from an external link or identity provider. `Lax` still blocks cookies on cross-site `fetch`, images, iframes, and form POSTs. Browser-based cross-site API sessions need a separate design. |
| `Path=/` | Send the cookie for every URL path on the cookie's host. A narrower value such as `/api` is only sent to that path and its descendants. | Reduces accidental exposure to unrelated paths, but it is routing scope, not an access-control boundary. | Keep `/` for the shared OpenEyes web session. Narrowing it can make `/site/login`, clinical pages, or an API path see different login state. |
| `Max-Age=43200` | Keep the cookie for 43,200 seconds (12 hours) from when the client receives it. If both `Max-Age` and `Expires` are present, `Max-Age` takes precedence. | Limits how long a conforming client sends the cookie. It does not revoke the server session or stop an attacker who copied the value and ignores client-side expiry; the server timeout does that. | Expiry logs out cookie-based users, but does not affect APIs that authenticate every request. `session.cookie_lifetime=0` means PHP omits `Max-Age`/`Expires`, creating a browser-session cookie; a literal `Max-Age=0` header instead deletes a cookie. |
| `Expires` | An absolute date/time after which the client removes the cookie. No `Expires` or `Max-Age` normally means a browser-session cookie. | Same security trade-off as `Max-Age`; client storage expiry is separate from the server session expiry. | Browser restore features may retain session cookies, so the OpenEyes idle timeout remains the authoritative control. |
| `Domain` | Selects which hosts receive the cookie. When omitted, the cookie is host-only. | A host-only cookie avoids exposing the session to sibling subdomains. | OpenEyes does not need a broad `Domain` for a normal single-host deployment. Do not broaden it merely to solve CORS or `SameSite`; those are separate browser controls. |

`SameSite` values are a security/compatibility choice:

| Value | Browser sends the cookie on | Main implication |
|---|---|---|
| `Strict` | Same-site requests only. | Strongest CSRF reduction, but external links and some SSO return flows can arrive without the existing session cookie. This is the current `OESESSID` setting. |
| `Lax` | Same-site requests plus cross-site top-level navigation using a safe method such as GET. | External links work more naturally, while cross-site form POST and JavaScript API calls remain without the cookie. This is the current `YII_CSRF_TOKEN` setting. |
| `None` | Same-site and cross-site requests. | Required for a genuinely cross-site cookie-based browser integration. Modern clients require `Secure` with it, and the application needs strong CSRF and CORS controls. Do not use it just to make an integration easier. |

- **CSRF** (cross-site request forgery) - a malicious page makes your logged-in
  browser submit a request to OpenEyes without you knowing. The token defeats
  it because the attacker's page cannot read and submit the matching value.
- **XSS** (cross-site scripting) - attacker-controlled script runs inside the
  OpenEyes page. `HttpOnly` stops direct cookie reads but does not make XSS safe.
- **HMAC / cookie validation** - the server signs each cookie value with a
  secret key and discards any cookie whose signature does not match. A tamper
  seal - the content is still readable, just not forgeable.
- **Session fixation** - the attacker plants a session id they already know and
  waits for the victim to log in under it; fresh-id-on-login plus strict mode
  are the standard defences (both present, see above).
- **Sliding expiry** - activity pushes the timeout forward; idle time runs it
  out.
- **HSTS** (`Strict-Transport-Security`) - a response header telling browsers
  to refuse plain HTTP for this host entirely; complements the `Secure` flag.

## Where each setting lives

| Layer | File | Holds |
|---|---|---|
| Image PHP defaults | `/etc/php/8.4/apache2/conf.d/97-openeyes.ini` (lines 52-67) | `cookie_httponly 1`, `cookie_lifetime 43200`, `samesite Strict`, `gc_maxlifetime 14400`, `use_strict_mode 1`, `use_only_cookies 1`, and `;session.cookie_secure = 1` **commented out** |
| Live-mode hardening | `98-openeyes-live.ini` (enabled when `OE_MODE=LIVE`) | error display / opcache / `disable_functions` only - **no cookie settings** |
| Per-deployment overrides | `99-openeyes.ini`, written at start by `/init_scripts/20-set_php_vars.sh` from any `PHPI_*` env var (`PHPI_SESSION.NAME=...` or `PHPI_SESSION__NAME=...` both map to `session.name`) | whatever the compose env sets; oe-deploy `templates/web.yml` sets only `PHPI_SESSION.GC_MAXLIFETIME` (default 1800) and `PHPI_SESSION.NAME` (default `<project>_OESESSID`) |
| App config | `protected/config/core/common.php` | `session` component (~532), `request`/CSRF (~510), `securityManager` key wiring (~1336), `user`/`allowAutoLogin` (~571) |
| Laravel | `oe-laravel/config/session.php` | `SESSION_*` env-driven equivalents; the `/xapi` API routes themselves use HTTP Basic on each request |
| Traefik front end (deploy host) | oe-deploy `templates/tfk.yml`, `traefik-files/traefik.yml`, `traefik-files/ssl.yml` | HTTPS redirect, HSTS middleware, TLS certs/options, router labels |

## What is already good

`HttpOnly` on both cookies, `SameSite=Strict` on the session cookie, strict
mode, id regeneration at login, HMAC validation of Yii-managed cookies keyed
from a Docker secret, DB-backed session data, sliding expiry with a polling
escape hatch, and a CSP + `X-Robots-Tag: noindex` on responses. The session id
remains a sensitive bearer credential even though the session data is server
side.

## What the standard Traefik front end adds

Almost every deployment sits behind the Traefik container (v3, default tag
v3.3) exactly as oe-deploy templates it, with no extra settings. The moving
parts live on the deploy host: `templates/tfk.yml` (compose service + router
labels on `web`) mounting `traefik-files/traefik.yml` (static config) and
`traefik-files/ssl.yml` (TLS certs + middleware). Out of the box that buys:

| Protection | Source | Effect |
|---|---|---|
| Forced HTTPS | global redirect on the `:80` entrypoint (`traefik.yml`) | every plain-HTTP request is answered with a redirect to `https://` before it reaches OpenEyes |
| HSTS | `hsts@file` middleware (`ssl.yml`), attached to every routed service (the OE `web` router, portal, complog) | `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` on every response |
| TLS termination | file-provided cert `/certs/cert.pem` + `/certs/server.key` (a Let's Encrypt resolver is defined but only the complog module template references it) | traffic on the wire is encrypted; OpenEyes itself keeps speaking plain HTTP internally |
| Deny-by-default routing | `exposedByDefault: false` on the docker provider | only containers labelled `traefik.enable=true` are reachable from outside (web, portal, complog); db, redis, oe-manager and master are never routed |
| Proxy access log | `accessLog: {}` | a request trail at the edge, independent of the application's audit log |

What this means for the cookie picture:

- **HSTS reduces, but does not replace, the missing `Secure` flag.** Once a
  browser has seen the header (one year, subdomains included) it rewrites
  every `http://` URL for the host to `https://` internally, so the session
  cookie stops being sendable in plaintext even though the cookie lacks
  `Secure`. The residual window: the first-ever request from a fresh browser
  profile (`stsPreload` only *emits* the token - the domain must still be
  submitted to hstspreload.org to be baked into browsers), plus non-browser
  clients that ignore HSTS entirely.
- **The hardened TLS options block is dormant.** `ssl.yml` defines
  `myCustomCert` (`minVersion: VersionTLS12`, `sniStrict`, a client-cert CA)
  but no router references it, so Traefik's built-in defaults apply (which
  also floor at TLS 1.2). Activating it needs a router label:
  `traefik.http.routers.oe.tls.options=myCustomCert@file`.
- **Traefik-to-web is plain HTTP** on the compose bridge network - fine on a
  single host, worth remembering if containers ever spread across hosts.
- Two non-cookie exposures to know about: host port `8081` maps to Traefik's
  `:8080` entrypoint on all interfaces (the dashboard/api lines are commented
  out, so it only answers `/ping`), and the Docker socket is mounted
  (read-only) into the Traefik container.

## Will changing the attributes break login or API access?

Adding `Secure` to `OESESSID` is the recommended change for an HTTPS deployment.
The decision depends on the URL and authentication method used by each client:

| Client or flow | Effect of `Secure` on `OESESSID` | Required check |
|---|---|---|
| Browser uses `https://<oe-host>` | No login break is expected. Traefik may forward plain HTTP to the web container; that internal hop does not change the HTTPS URL seen by the browser. | Complete a normal login, page navigation, idle-timeout, and logout check over HTTPS. |
| Browser or script uses `http://<oe-host>` | Cookie login breaks by design because the client will not return `OESESSID` over HTTP. A redirect is sufficient only if the client follows it before login and uses HTTPS thereafter. | Find and replace direct HTTP bookmarks, monitoring, scripts, and service URLs before rollout. |
| `/xapi`, legacy `Api`, or PASAPI client sends HTTP Basic credentials on every request | Authentication is not dependent on a stored session cookie, so `Secure` does not block the API user. Credentials must still be sent only over HTTPS. | Make one representative request without a cookie jar and confirm the expected non-401 response. |
| Script posts credentials to `/site/login` and reuses a cookie jar | Works when login and later requests are HTTPS. It fails if later requests use ordinary HTTP. | Test the exact client library because cookie handling belongs to the client. |
| OpenEyes document generation uses `http://localhost` internally | Current libcurl treats `http://localhost` as a secure cookie context, so `DocmanRetriever` should continue to return the session cookie. Other libraries and non-localhost hostnames may not. | Generate and retrieve a real document after the change; also exercise `SessionGenerator` if that path is enabled. |
| Browser JavaScript calls OpenEyes from a genuinely different site using the web session | `Secure` adds no new restriction over HTTPS, but the current `SameSite=Strict` session cookie already blocks this pattern. | Do not weaken to `SameSite=None` without designing CORS, `credentials: include`, and CSRF protection together. |
| SSO redirects through another site | `Secure` is safe when the complete flow is HTTPS. Changing `SameSite` can be disruptive, and `PHPI_SESSION.COOKIE_SECURE` does not alter OpenID Connect's separate state/nonce cookies. | Run the complete SSO login and logout flow if SSO is enabled. |

Changing other attributes has separate effects. Keep `Path=/` unless sessions
are deliberately split by URL. Reducing `session.cookie_lifetime` makes browser
logins disappear sooner or at browser close, but does not change Basic-auth API
requests. Changing `SameSite` affects browsers, external links, SSO, and
cross-site JavaScript; it normally has no effect on server-to-server API tools.

## Gaps and how to improve

1. **`Secure` is absent from the observed OpenEyes cookies.** The image comments
   out the PHP session setting, live mode does not add it, and no oe-deploy web
   template sets it. HSTS narrows the browser exposure but leaves first visits
   and non-browser clients, so `Secure` is still required on an HTTPS
   production deployment. Add to the `web` (and inherited `oe-manager`) service
   environment:
   `PHPI_SESSION.COOKIE_SECURE: 1` - and `SESSION_SECURE_COOKIE=true` if
   Laravel web sessions are used. `PHPI_SESSION.COOKIE_SECURE` changes only the
   PHP session cookie; it does not add `Secure` to `YII_CSRF_TOKEN`, OpenID
   Connect cookies, or other Yii-managed cookies. Those need separate
   application configuration. Do *not* set it on a plain-HTTP deployment.
2. **12-hour persistent cookie on shared workstations.** The session cookie
   survives browser restarts for 12 h. `PHPI_SESSION.COOKIE_LIFETIME: 0` makes
   it a browser-session cookie: closing the browser discards it. The
   server-side idle timeout still applies either way.
3. **HSTS preload is emitted but not submitted.** The `hsts@file` middleware
   already sends the `preload` token; actually being baked into browsers
   requires submitting the domain at hstspreload.org. Optional - it closes the
   first-visit window described in (1).
4. **Activate the dormant TLS options.** Add
   `traefik.http.routers.oe.tls.options=myCustomCert@file` to the `web` labels
   if `sniStrict` or client certificates are wanted; today the block in
   `ssl.yml` does nothing.
5. **Key hygiene.** `OE_COOKIE_VALIDATION_KEY` is a password: long, random,
   unique per deployment, delivered via `/run/secrets`, never in git. Rotation
   invalidates Yii-managed signed cookies; existing PHP sessions may remain
   valid until their normal timeout.
6. **Never disable validation.** `OE_ENABLE_COOKIE_VALIDATION=false` removes
   the tamper seal from Yii-managed application cookies; debugging only.
7. **Do not grow `noCsrfValidationRoutes`.** Each entry re-opens forgery for
   that route prefix (the match is `strpos === 0`, so a broad prefix exempts
   everything under it). `site/login` being exempt is an accepted upstream
   trade-off (login form must work after session expiry) - do not widen it.
8. **Keep the idle timeout short.** oe-deploy's 1800 s default is right for
   clinical settings; raising it lengthens the hijack window on unattended
   machines.

## Verifying a deployment

```bash
# Authoritative - inspect the headers from the same GET used by a browser
curl -sS -D - -o /dev/null https://<oe-host>/site/login | grep -i '^set-cookie:'
# Effective PHP values and their source (97 = image default, 99 = PHPI_ overrides)
docker exec <project>-web-1 grep -h "session.cookie\|session.gc\|session.use_strict" /etc/php/8.4/apache2/conf.d/97-openeyes.ini /etc/php/8.4/apache2/conf.d/99-openeyes.ini
```

Expect `HttpOnly` and `SameSite` on both cookies. After applying fix (1), expect
the literal word `Secure` on the `OESESSID` header. Do not assume the same PHP
setting changes `YII_CSRF_TOKEN`; inspect each `Set-Cookie` header separately.

References:
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
- https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- https://www.php.net/manual/en/session.configuration.php
- https://www.php.net/manual/en/session.security.ini.php
- https://curl.se/docs/http-cookies.html
- https://doc.traefik.io/traefik/middlewares/http/headers/
