# Secrets & config resolution (common.js / globalMap)

REST recipes for reading/writing the configurationMap and importing channels are
in the `c-mirth` skill — don't duplicate them here. This sub records how the three
`mc_channels/` channels get their config and why the exports are structured the
way they are.

## Resolution model

The global **Deploy** script (template `common.js`, run on every
`POST /channels/<id>/_deploy`) resolves each variable through a fixed precedence
and writes the result into `globalMap` under an **UPPERCASE** key:

```
/run/secrets/<name>   →   env var   →   configurationMap   →   hardcoded default
```

So a Docker/Compose secret wins, then an environment variable, then the
BridgeLink configuration map, then a baked-in fallback. Channels reference the
results as Velocity `${VAR}` and never hold a literal secret.

## Derived auth header

After resolving `OE_API_USER` and `OE_API_PASS`, the Deploy script pre-computes:

```
OE_API_AUTH = 'Basic ' + base64(OE_API_USER + ':' + OE_API_PASS)
```

into `globalMap`. The HTTP Sender destinations send `Authorization: ${OE_API_AUTH}`
as a header (with `useAuthentication=false`), because Velocity does **not**
substitute the connector's own `username`/`password` fields (`c-mirth` skill,
`subs/connectors.md`). The same pattern would template `OE_IDENTIFIER_TYPE`
(replacing the hardcoded `LOCAL-1-0`) and `PAS_OUT_REMOTE_HOST`/`_PORT`.

## What is and isn't secret-free to export

- **Secret-free** (safe to commit): channel XML, code-template (library) exports,
  and global-script exports — provided they only reference `${VAR}` and carry no
  inline credentials. The raw `~/mc_channels/*.xml` are **not yet** in this state:
  PAS IN embeds `api:Password123` 6 times and DICOM once (PAS OUT is clean). They
  must be templated before they belong in git.
- **NOT secret-free:** the full **Server Configuration export** — it embeds the
  configurationMap (which holds the resolved/default values). Never commit it.

## Map lifetimes across redeploy

- **configurationMap** — persisted server state; **survives** redeploys (and is
  the layer the Deploy script reads). Replace the whole map via REST: GET → merge
  → PUT (`c-mirth`).
- **globalChannelMap** — **cleared** on every (re)deploy, so any watermark /
  seen-set kept there resets and pollers re-emit once. Don't store durable
  config there. (`globalMap`, where the Deploy script writes resolved vars, is
  re-populated on each deploy by the script itself.)
