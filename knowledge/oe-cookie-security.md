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
- **Laravel session cookie** (`/xapi/*` routes): configured separately in
  `oe-laravel/config/session.php` - `database` driver, `http_only` true,
  `same_site` lax, `Secure` only when `SESSION_SECURE_COOKIE=true`.

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
  `protected/config/core/common.php`). Yii HMAC-signs cookie values with
  `securityManager->validationKey`, which is loaded from
  `/run/secrets/OE_COOKIE_VALIDATION_KEY` or the `OE_COOKIE_VALIDATION_KEY` env
  var (`core/common.php` ~line 1336). A signature, not encryption.
- **CSRF**: `enableCsrfValidation => true`, but the custom `HttpRequest`
  (`protected/components/HttpRequest.php`) detaches the check for any route
  whose URL *starts with* an entry in `noCsrfValidationRoutes`: `site/login`,
  `api/`, `Api/`, the `OphCoDocument` upload actions (oversized-upload error
  handling), and `sso`.

## Glossary in plain words

- **Cookie** - a small label the server asks the browser to store and send back
  with every later request. HTTP has no memory of its own; cookies are how the
  server recognises you on request two.
- **Session** - the server-side folder of facts about your login. The cookie is
  just the claim ticket for the folder; nothing sensitive is in the ticket.
- **HttpOnly** - "JavaScript may not read this cookie". If an attacker gets
  script injected into a page (XSS), the script still cannot copy the cookie.
- **Secure** - "only send this cookie over HTTPS". Without it the browser will
  attach the cookie to a plain `http://` request too, where anyone on the
  network path can read it.
- **SameSite** - when *other* websites can make your browser attach the cookie.
  `Strict`: never from another site. `Lax`: only on a top-level click-through,
  never on hidden form posts.
- **CSRF** (cross-site request forgery) - a malicious page makes your logged-in
  browser submit a form to OpenEyes without you knowing. The token defeats it:
  the attacker's page cannot read the token, so it cannot fill in the matching
  hidden field, and the post is rejected.
- **HMAC / cookie validation** - the server signs each cookie value with a
  secret key and discards any cookie whose signature does not match. A tamper
  seal - the content is still readable, just not forgeable.
- **Session fixation** - the attacker plants a session id they already know and
  waits for the victim to log in under it; fresh-id-on-login plus strict mode
  are the standard defences (both present, see above).
- **Max-Age / expires vs server timeout** - Max-Age is how long the browser
  keeps the ticket; the server timeout is how long the folder exists. The
  shorter of the two wins in practice.
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
| Laravel | `oe-laravel/config/session.php` | `SESSION_*` env-driven equivalents for `/xapi` |
| Traefik front end (deploy host) | oe-deploy `templates/tfk.yml`, `traefik-files/traefik.yml`, `traefik-files/ssl.yml` | HTTPS redirect, HSTS middleware, TLS certs/options, router labels |

## What is already good

`HttpOnly` on both cookies, `SameSite=Strict` on the session cookie, strict
mode, id regeneration at login, HMAC cookie validation keyed from a Docker
secret, DB-backed sessions (nothing sensitive client side), sliding expiry
with a polling escape hatch, and a CSP + `X-Robots-Tag: noindex` on responses.

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

- **HSTS largely covers for the missing `Secure` flag - for browsers.** Once a
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

## Gaps and how to improve

1. **`Secure` flag is never set - anywhere.** The image comments it out, live
   mode does not add it, no oe-deploy template sets it. Behind the standard
   Traefik front end HSTS narrows the real-world exposure to first-ever visits
   and non-browser clients (see above), but the flag is still correct
   belt-and-braces and costs one env var. On every HTTPS deployment add to the
   `web` (and `oe-manager`) service environment:
   `PHPI_SESSION.COOKIE_SECURE: 1` - and `SESSION_SECURE_COOKIE=true` if
   Laravel sessions are used. Do *not* set it on plain-HTTP installs (the
   browser would never return the cookie and login would break).
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
   just forces re-logins.
6. **Never disable validation.** `OE_ENABLE_COOKIE_VALIDATION=false` removes
   the tamper seal on every cookie; debugging only.
7. **Do not grow `noCsrfValidationRoutes`.** Each entry re-opens forgery for
   that route prefix (the match is `strpos === 0`, so a broad prefix exempts
   everything under it). `site/login` being exempt is an accepted upstream
   trade-off (login form must work after session expiry) - do not widen it.
8. **Keep the idle timeout short.** oe-deploy's 1800 s default is right for
   clinical settings; raising it lengthens the hijack window on unattended
   machines.

## Verifying a deployment

```bash
# Authoritative - exactly what the browser sees
curl -sI https://<oe-host>/site/login | grep -i set-cookie
# Effective PHP values and their source (97 = image default, 99 = PHPI_ overrides)
docker exec <project>-web-1 grep -h "session.cookie\|session.gc\|session.use_strict" /etc/php/8.4/apache2/conf.d/97-openeyes.ini /etc/php/8.4/apache2/conf.d/99-openeyes.ini
```

Expect `HttpOnly` and `SameSite` on both cookies, plus the literal word
`Secure` on HTTPS deployments; if `Secure` is missing, apply fix (1).

References:
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- https://www.php.net/manual/en/session.security.ini.php
- https://doc.traefik.io/traefik/middlewares/http/headers/
