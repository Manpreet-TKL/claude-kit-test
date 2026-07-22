# Authentication and session persistence (Phase 6)

How the channels authenticate to OpenEyes and to their document/file destinations, and
whether any of them persist a login/session. Source records: `deepdive/_slices/*.json`
(auth block per channel); every claim carries an `evidence[]` pointer.

## Headline: there is no persisted login

**Every OpenEyes-calling channel authenticates statelessly, per message.** Across all 76
deep records:

- `token_or_cookie_cached = false` for every OE-calling channel; not one caches a bearer
  token, cookie or session.
- `relogin_trigger = per-message` - HTTP Basic credentials are sent preemptively on each
  outbound request; there is no login call, no 401-then-retry handshake, no token refresh.
- `session_persistence.uses_global_map = true` for exactly **one** channel (Newmedica
  `OpenEyes PAS In`), and its global-map keys are **routing tables, not credentials**
  (`globalMap:hospitalMapping`, `globalMap:channelLookup` - used to pick the per-practice
  target channel from `PV1-3.9`). No channel stores an auth token in a global map.

This directly answers the standing open question ("do global maps survive a BridgeLink
restart, and does that matter for login?"): **it does not matter for authentication.** No
auth state lives in a global map, so global-map persistence across restart has no bearing
on login. (It still matters for Newmedica's routing table - noted in `unresolved/`.)

## Authentication method by destination type

| Destination | Method | Channels |
|---|---|---|
| OpenEyes PASAPI / PayloadProcessor / Document API | HTTP Basic, preemptive | every OE-calling channel (PAS In, DICOM, document, PP) |
| Remote PAS query response (HTTP listener -> MLLP out) | none (MLLP has no HTTP auth) | PAS OUT family, MEH/Pennine PAS Query |
| NHS Wales MPI (SOAP Web Service Sender) | none at the HTTP-Basic layer | Wales `OpenEyes Query - *` (8) |
| SFTP / SMB file share | other (SFTP/SMB password) | Docman, Document OUT/Delivery, Correspondence movers |

"Preemptive" means the connector is configured to send the `Authorization: Basic` header
on the first request rather than waiting for a 401 challenge - confirmed on the HTTP
Sender connectors (`usePreemptiveAuthentication`).

## Credential source (values never reproduced)

Credentials live in the **connector configuration fields** of each HTTP Sender (username
+ password), not in a secret store, not in a config/global map. The username is the shared
literal `api`; the password was redacted at canonicalisation and is recorded only by
location in `secrets/redaction-log.csv` (placeholder, never value). The same
`api` / <redacted> pair recurs across channels and instances - a single shared service
credential, not per-channel identities.

| Credential facet | Finding |
|---|---|
| Username | `api` (shared literal across the estate) |
| Password | single redacted value, reused across channels; stored inline in the connector |
| Storage | connector field (plaintext in the export before redaction) |
| Rotation | none expressed in the channels; a change means editing every connector |

## Security observations (feed Phase 13)

1. **Shared, inline, non-rotatable credential.** One `api` account, its password embedded
   in every HTTP Sender connector. Rotation touches every channel; compromise is estate-wide.
   Phase 9 templating should externalise it to a `${OE_API_PASSWORD}` placeholder / secret
   manager (the redaction already models this).
2. **Per-message Basic over the trust network.** No token, so the credential crosses the
   wire on every call. Acceptable only because traffic is on RFC1918 NHS trust networks
   (see `networking/port-map.md`); it is not defence in depth.
3. **Unauthenticated inbound listeners.** Portsmouth `PAS OUT` is an explicitly
   unauthenticated HTTP listener on :6663 (any caller on the network can trigger a PAS
   query). The PAS-OUT/PDQ trigger listeners generally rely on network isolation, not auth.
4. **MPI SOAP auth not in the channel.** Wales MPI calls carry no HTTP-Basic layer; any
   WS-Security / transport auth is handled outside the channel config (endpoint / network
   trust). Confirm the MPI trust model with the Wales deployment owner.

## The one global-map user (not auth)

Newmedica `OpenEyes PAS In` reads `globalMap:hospitalMapping` and
`globalMap:channelLookup` to route each inbound message to the correct per-practice
`PAS In LOCAL-*` channel (keyed on the first five chars of `PV1-3.9`). These are
deployment-populated lookup tables, not session state. If they are not repopulated after a
restart the routing fan-out breaks - tracked as an operational dependency in
`unresolved/questions.md`, separate from authentication.
