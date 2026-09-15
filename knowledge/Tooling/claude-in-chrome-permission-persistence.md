# Auto-seeding the Claude in Chrome extension's site permission

How `docker/oe-chrome-agent` gets a fresh Chrome profile to skip the one-time
"always allow" click, by writing the extension's own grant store directly
(implemented 2026-07-23; since 2026-07-25 the same store also carries the saved
claude.ai sign-in - see `seed-extension-state.mjs` / `dump-extension-state.mjs`
and `entrypoint.sh`'s `seedExtensionState()`).

## The problem

The Claude in Chrome extension (id `fcoeoabgfenejglbffodgkkbkcdhcgfn`) gates
navigate/read tool calls per-origin, independently of the CLI's own auth:

- CLI `/login` (`~/.claude/.credentials.json`) authenticates the `claude`
  binary to Anthropic.
- The extension separately tracks which sites it's allowed to act on, and on
  a fresh profile a background/print-mode session (`claude -p --chrome`) gets
  silently denied on first use until a human clicks "always allow" for that
  origin once, in a real browser window.

Two different gates, two different fixes - `/login` cannot be automated (it's
an interactive OAuth flow by design), but the site-permission gate turned out
to be pure local storage with no server round-trip, so it can be pre-seeded.

## Why CDP automation doesn't work

The obvious approach - drive the extension's own options/settings page over
the Chrome DevTools Protocol and click the button - fails categorically:
Chrome silently refuses to return any CDP response for a `chrome-extension://`
target (service worker, background page, or a freshly opened options page).
Identical CDP code against a normal `http://` page target (used elsewhere in
this container for `oe-login.mjs`'s OE auto-login) works instantly. This is a
Chrome-side restriction, not a bug in the calling code - confirmed by testing
the same request pattern against both target types on the same running
Chrome instance.

## Where the grant actually lives

Extension `chrome.storage.local` is backed by a plain LevelDB database (not
IndexedDB - no custom key comparator to fight), one directory per extension:

```
<profile>/Default/Local Extension Settings/<extension-id>/
```

Confirmed empirically (containerized dump of the real store): the DB key is
literally the storage key name as a UTF-8 string (e.g. `permissionStorage`),
and the DB value is `JSON.stringify()` of that key's value. No prefixing, no
extra encoding layer.

The permission grant list lives under the `permissionStorage` key, shaped
like:

```json
{
  "permissions": [
    {
      "action": "allow",
      "createdAt": 1784814276882,
      "duration": "always",
      "id": "<uuid>",
      "lastUsed": 1784830767701,
      "scope": { "netloc": "web", "type": "netloc" }
    }
  ]
}
```

`scope.netloc` is a bare hostname (no scheme/port) - a request to
`http://web/anything` matches a grant with `netloc: "web"`.

Caveat: the same LevelDB store also holds the extension's own OAuth state
(`accessToken`, `refreshToken`, `codeVerifier`, `oauthState`) under other
`chrome.storage.local` keys, in plaintext. Anything that reads this store for
debugging should not log those keys' values.

## Writing it

Node's `classic-level` package (v3, the maintained successor to `leveldown`)
opens this store directly - prebuilt binaries, no host compiler needed, works
fine on `node:22-slim`. Read-modify-write the `permissionStorage` key: append
a grant if one isn't already present for the target netloc, else no-op.

**Execution-order constraint**: this must run *before* Chrome starts, not
after. Chrome holds the LevelDB directory's file lock for its entire process
lifetime, so an external writer can only touch it while Chrome is stopped.
This is why the seed step sits alongside the container's other pre-Chrome
prep (lock cleanup, profile-path linking) rather than after boot.

Make it idempotent and non-fatal: check for an existing `always`-duration
`allow` grant before writing, and swallow any error (missing dir on a
first-ever boot is fine - LevelDB creates it) so a seeding failure just falls
back to the one-time manual click instead of blocking the container.

## Validation methodology

Never experiment against a live/working profile or its container. Instead:

1. Copy the entire Chrome profile directory to a scratch location.
2. Edit only the scratch copy's LevelDB store.
3. Boot a second, disposable container (plain `docker run`, not part of the
   compose stack) pointed at the scratch profile, to prove the before/after
   behavior: denied without the grant, allowed with it.

This proved both the negative (fresh profile really is denied) and the
positive (a surgically-written grant really is honored) without any risk to
the real profile or the real running container.

One gotcha reproducing the compose service with a raw `docker run`: it needs
explicit `-i -t`, matching the compose file's `stdin_open: true` / `tty:
true` - without them `claude --chrome` exits immediately ("Input must be
provided either through stdin or as a prompt argument").

## Portability

Nothing here is OpenEyes-specific - the technique (LevelDB key/value shape,
CDP restriction, pre-Chrome-start write, classic-level tooling) applies to
seeding any Claude in Chrome permission grant, or in principle any other
extension's `chrome.storage.local` state, from outside a running Chrome.
