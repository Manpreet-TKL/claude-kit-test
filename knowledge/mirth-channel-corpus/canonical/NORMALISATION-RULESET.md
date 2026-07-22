# Canonicalisation & normalisation ruleset

The contract for turning raw corpus exports into the `canonical/` copies. Produced
by `bin/build_canonical.py`, deterministically (a re-run is byte-identical). The
**original exports remain the authoritative source** and are never modified - the
canonical copies exist only for safe sharing, agent input, and comparison.

## What the canonical copy IS
- One `<channel>` per file (channelGroups are split into their member channels).
- Byte-faithful to the original **except** the two transforms below.
- A valid standalone Mirth single-channel export root.

## Transform 1 - secret + sensitive-data redaction (always applied)
| Element | Rule | Result | Logged in |
|---|---|---|---|
| `<password>` (non-empty) | value replaced | `${REDACTED_PASSWORD}` | `secrets/redaction-log.csv` |
| `<passPhrase>` (non-empty) | value replaced | `${REDACTED_PASSPHRASE}` | same |
| `<username>` (non-empty, not `api`/`anonymous`) | value replaced (service-account identifiers) | `${REDACTED_USERNAME}` | same |
| `<inboundTemplate>` / `<outboundTemplate>` (non-empty) | content blanked | empty element (logged `(blanked)`) | same |

Generic usernames `api` and `anonymous` are **kept** (non-sensitive, useful
classification signal). The redaction log records instance, source file, channel,
nearest connector name, secret type, placeholder and original value **length** -
never the value. Corpus evidence: a single 11-char literal password value recurs
(356 identical occurrences, value withheld); no non-empty passphrases; no hardcoded
Basic/Bearer tokens or `user:pass@` URLs anywhere in scripts (verified).

The `inbound`/`outboundTemplate` fields are Mirth transformer **sample messages** used
only by the mapping UI - they are not read at runtime, so blanking them does not change
any channel's behaviour or any structural/analytical extraction. In this corpus some
carried **patient-shaped data** (names, dates of birth, hospital/NHS numbers), so all
166 non-empty occurrences (135 inbound + 31 outbound, across 75 channels) are blanked;
each is logged by length only. This was added after the first pass (which redacted only
credentials); re-baselining changed the `canon_sha256` of the 75 affected channels while
every `raw_sha256` stayed identical (the read-only corpus was never touched).

## Transform 2 - noise normalisation (for meaningful comparison)
| Field | Rule | Why |
|---|---|---|
| `<time>NNN</time>` | -> `<time>0</time>` | export/modify timestamps are pure churn |
| `<revision>N</revision>` | -> `<revision>0</revision>` | per-instance edit counters differ meaninglessly |

## Deliberately NOT normalised in this wave (kept intact)
- **Channel IDs / connector metaDataIds / UUIDs** - identity-bearing; needed for the
  inventory and for the cross-instance shared-lineage finding (12 IDs recur across
  instances). ID neutralisation is deferred to the Phase 8 semantic-diff wave, where
  it is applied only to the comparison inputs.
- **Hosts / IPs / ports / endpoints** - environment-specific but operationally
  meaningful; recorded in the inventory (`env_ips`, `env_nhs_hosts`) and parameterised
  later during template design (Phase 9), not stripped here.
- **Enabled / deployed state, export ordering** - left as-is; the split already
  removes ordering ambiguity by giving each channel its own file.

## Not found in the corpus (so no rule needed)
CDATA sections (0), real XML namespaces (0 - the `xmlns` strings are inside
entity-escaped script text), separate code-template libraries or global-script
exports (0). Recorded so later waves do not assume they exist.
