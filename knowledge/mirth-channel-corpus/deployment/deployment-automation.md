# Deployment automation (Phase 11)

The pipeline that takes a rendered instance channel set (Phase 9 + 10) and deploys it
to a target BridgeLink server: render -> validate -> inject secrets -> deploy -> verify,
with idempotency, rollback, enabled-state control, and BridgeLink-version tolerance.

Scope note on evidence: the corpus is channel *exports*, not API traffic, so it does
not evidence the Mirth Connect REST interface. The API operations below are the
standard NextGen/Mirth Connect REST conventions used as the **design target**; exact
paths, query params and payload media types **must be verified against each target
BridgeLink version** (the corpus spans 4.4.2 / 4.5.2 / 4.6.1, which differ in export
schema and may differ at the API edge). What *is* corpus-grounded - channel ids,
ports, the stateless shared-`api` Basic auth, PASAPI version floors, enabled-state
handling - is cited to its phase.

## Pipeline stages

1. **Resolve** - compose the instance's channel set from `sites/<instance>/channels.csv`
   (Phase 10): for each channel, load its template family, its `sites.csv` row and any
   feature overlays.
2. **Site-render** - fill `${TOKEN}` from the row. Output still contains `${REDACTED_*}`
   and is safe to persist as the deploy artifact / diff baseline.
3. **Validate** (gates below) - fail closed before anything touches the server.
4. **Inject secrets** - resolve `${REDACTED_*}` from the secret store in memory only.
   The secret-bearing XML is never written to disk or logged.
5. **Deploy** - authenticate, upsert each channel by id, deploy the set, set enabled
   state per intent.
6. **Verify** - re-fetch each channel; confirm code/enabled/deployed state matches
   intent; run per-archetype smoke checks.
7. **Rollback on failure** - redeploy the previous known-good rendered set, or undeploy
   channels created in this run.

## Validation gates (stage 3, all must pass)

| Gate | Check | Why |
|---|---|---|
| Well-formed | each rendered channel parses as XML and is a valid single-channel export root | catch a broken render before deploy |
| No unfilled site token | zero `${TOKEN}` (declared site tokens) remain | an unfilled token means a missing `sites.csv` value |
| Secrets still symbolic | every `${REDACTED_*}` is still present at end of stage 2 | proves no credential was baked into the artifact |
| Port uniqueness | no two channels in the instance set share a listener port | no estate port convention exists (`networking/port-map.md`); collisions are silent runtime failures |
| Id uniqueness | channel ids unique within the set, stable vs what is live | ids are the idempotency key; a duplicate would clobber |
| Version floor | target server version satisfies the channel's PASAPI/OE floor (V1<=OE8, V2=OE9-10, V3=OE11+) | a V3 channel against an OE<=8 server will fail at runtime (`openeyes/api-usage.md`) |
| Schema compat | export schema matches the target BridgeLink version, or is migrated to it | 4.4.2 vs 4.6.1 export drift (see version tolerance) |

## Secret injection (stage 4)

The estate today shares a single 11-char `api` password across 356 occurrences
(`secrets/redaction-log.csv`, `auth/persisted-login.md`), so the minimal secret store
is one entry per site keyed to `${REDACTED_PASSWORD}`. The injector:

- fetches the value for `(site, placeholder)` from the external store (Vault, SOPS,
  cloud secret manager - not specified here, only that it is external to the repo);
- substitutes in memory immediately before the API call;
- redacts the substituted body from all logs and error output.

Forward recommendation (`auth/persisted-login.md`): move off the single shared
credential to a distinct per-site `api` secret; the placeholder model already supports
this - it is a secret-store change, no template change. `${REDACTED_PASSPHRASE}` /
`${REDACTED_USERNAME}` are handled the same way where a future family surfaces them.

## Mirth Connect API operations (design target - verify per version)

Preemptive HTTP Basic is what the *channels* use to call OpenEyes; deploying *to*
BridgeLink uses the Mirth admin REST API, which is session-based:

| Step | Operation (standard Mirth REST) | Notes |
|---|---|---|
| Authenticate | `POST /api/users/_login` (username/password form) | returns a session cookie; carried on subsequent calls |
| Server version | `GET /api/server/version` | feeds the version-floor and schema-compat gates |
| List live | `GET /api/channels` | detect create-vs-update, capture current state for rollback |
| Upsert channel | `PUT /api/channels/{id}?override=true` (body = rendered channel XML) | idempotent by channel id; this is the create-or-update primitive |
| Deploy set | `POST /api/channels/_deploy` (body = id set, `returnErrors=true`) | per-channel error reporting for partial-failure detection |
| Undeploy | `POST /api/channels/{id}/_undeploy` | used by rollback |
| Enabled state | channel `<exportData>` metadata `enabled` flag, set as part of the upsert (some versions also expose an explicit enabled endpoint) | enable != deploy; keep them distinct (below) |
| Logout | `POST /api/users/_logout` | end the admin session |

Media type (XML vs JSON) is set by the `Accept`/`Content-Type` headers; channels are
XML in the corpus, so XML is the natural body. Confirm the exact set-enabled mechanism
and the deploy payload shape against the target version before relying on them.

## Idempotency

The channel **id** is the idempotency key and is preserved through templating (it is a
site token, `CHANNEL_ID`, not regenerated). Because render is deterministic and upsert
is by id:

- Re-running the pipeline with unchanged inputs produces byte-identical channel XML;
  upserting it is a no-op on the server.
- The pipeline can diff the freshly rendered set against `GET /api/channels` and deploy
  **only** changed channels, so routine runs touch nothing unnecessarily.
- A given `(template, site_row)` always yields the same channel, so "redeploy site X"
  is safe to run repeatedly.

## Enabled / deployed state

Two independent axes, both controlled from `sites/<instance>/channels.csv` intent, never
auto-inferred:

- **Enabled** (channel metadata) - carried in the template from the exemplar
  (`canonical/NORMALISATION-RULESET.md` kept it intact). The pipeline sets it to the
  site's declared intent.
- **Deployed** (runtime) - the deploy call. Which channels are actually live per site is
  an open, user-supplied item (`unresolved/questions.md`), so the pipeline defaults a
  channel's intent to the state observed in that site's export and requires explicit
  confirmation before enable-deploying a channel that was dormant. It never silently
  activates a channel that was off.

`<revision>` renders as 0 (normalised in Wave 0); the server assigns the live revision
on upsert, so revision is not a source of spurious diffs.

## Rollback

- Before deploy, the current live set is captured (`GET /api/channels`) and the previous
  rendered artifact is retained as the known-good baseline.
- `POST /api/channels/_deploy` with `returnErrors=true` reports per-channel outcome, so
  a partial failure is detected rather than assumed-successful.
- On any deploy or verify failure: re-upsert + redeploy the previous known-good set for
  channels that existed before, and `_undeploy` (then optionally delete) channels this
  run newly created. Because ids are stable and render is deterministic, "the previous
  set" is a concrete, reproducible artifact, not a guess.

## BridgeLink version tolerance

The corpus spans BridgeLink 4.4.2, 4.5.2 and 4.6.1 (`inventory/versions.md`), which
differ in export schema. The pipeline does not assume one version:

- BridgeLink version is recorded per channel (`canonical/_manifest.csv`); the target
  server version comes from `GET /api/server/version`.
- The schema-compat gate migrates a rendered channel to the target's export schema when
  they differ, rather than pushing a mismatched schema.
- Capability is verified, not assumed: the version-floor gate checks the target OE can
  serve the channel's PASAPI version (V1<=OE8, V2=OE9-10, V3=OE11+); API path/payload
  differences at the BridgeLink edge are confirmed against the target version before
  first use, per the design-target caveat above.

## What is grounded vs designed

| Grounded in the corpus | Design (verify before build) |
|---|---|
| channel ids as idempotency key; ports and the no-convention finding; stateless shared-`api` Basic; PASAPI version floors; enabled-state kept in canonical; single shared password | the Mirth REST paths/payloads; the secret-store product; the schema-migration step; the exact set-enabled mechanism |

The pipeline is deliberately fail-closed: every stage that could leak a secret or push a
capability the target cannot serve is a gate that blocks the deploy rather than a
best-effort attempt.
