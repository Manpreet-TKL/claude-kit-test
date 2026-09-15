# Helm chart vs `oe-deploy` — full difference list

`~/charts/helm/openeyes` was templated from the `~/oe-deploy` docker-compose
system and has since drifted. oe-deploy is the source of truth and has a wider
feature surface. This is the gap list the reorg (`~/claude-kit/todo/helm-reorg-plan.md`, Phase 5)
must close to keep parity.

## How this was derived

- oe-deploy service inventory: `~/oe-deploy/templates/*.yml` (+ `image:` lines).
- oe-deploy modules: `~/oe-deploy/templates/modules/*.yml`.
- Chart inventory: `~/charts/helm/openeyes/charts/*` and each subchart's
  `values.yaml`.
- Version defaults: oe-deploy `.env`/template `${VAR:-default}` values vs chart
  subchart image tags.

---

## 1. Services in oe-deploy with **no chart subchart**

| oe-deploy | image | role | chart status |
|-----------|-------|------|--------------|
| `bkp` | `mariadb:11.8` | mariabackup full / incremental / dump backup runner | **missing** (chart has a `db-backup` volume + `aws` S3 sync, but no backup job) |
| `db2` | `mariadb:11.8` | second DB instance | **missing** (chart has a single `db`) |
| `mcbl` | `innovarhealthcare/bridgelink` | BridgeLink (Mirth fork) integration engine | **missing** (chart `mc` = nextgenhealthcare/connect only) |
| `notes` | `toukanlabsdocker/notes:1.0.0` | ToukanNotes app | **missing** |
| `pen` | `toukanlabsdocker/pentaho-docker` | Pentaho ETL / reporting | **missing** |
| `rmq` | `rabbitmq` | RabbitMQ message broker | **missing** |
| `rtf` | `toukanlabsdocker/rtf` | RTF / document conversion service | **missing** |
| `tfk` | `traefik:v3.3` | Traefik reverse proxy + TLS | **no Traefik resource** (chart uses an Ingress object; `ingress-matrix` only chooses an ingress *class*) |
| `whi` | `toukanlabsdocker/whiskers` | Whiskers monitoring agent | **missing** (see monitoring doc) |

## 2. Services present in both (parity OK, with caveats)

| oe-deploy | image | chart subchart | caveat |
|-----------|-------|----------------|--------|
| `web` | `oe-web-live` | `web` (on) | image tag stale (`latest` vs `MASTER_TAG 26.0.0`) |
| — | `oe-manager` | `oem` (on) | oe-manager runs in-container cron jobs (`jobs` configMap) — no K8s `CronJob` |
| `db` | `mariadb:11.8` | `db` (on) | **chart pins `mariadb:10.6`** |
| `mys` | `mysql:8.0` | `mysql` (off) | parity OK |
| `ss` | `mssql/server:2022` | `ss` (off) | parity OK |
| `mc` | `connect:4.6.1` | `mc` (off) | **chart pins Mirth `4.4.2`** |
| `iol` | `iolmasterimport` | `iol` (off) | `WAIT_HOSTS` env set but no init container enforces ordering |
| `sig` | `oe-sig-import` | `sig` (off) | parity OK |
| `pay` | `payloadprocessor` | `pay` (off) | env folders backport a `du_pay` rename (see `charts-bugfix-analysis.md`) |
| `portal` | `optom-portal` | `portal` (off) | Laravel; needs `LARAVEL_APP_KEY` (fix already identified) |
| `red` | `redis` | `reddis` (off) | **misspelled** `reddis` |
| `aws` | `aws-cli` | `aws` (off) | S3 sync only; not the full awslogs/CloudWatch pipeline |
| `debug`/`dev` | `oe-web-live:debug` / `oe-web-dev` | web image-tag variants | present as tags, not separate services |
| `du_pay` | (pay variant) | via `pay` | DU payment overlay |

---

## 3. Cross-cutting features in oe-deploy missing from the chart

| Feature | oe-deploy | chart gap |
|---------|-----------|-----------|
| **DB backups** | `mariabackup.sh` — full (Sat), incremental (Mon–Fri), dump (Sun) on cron, via the `bkp` service | no `CronJob` resources |
| **Secret encryption** | git-secret + GPG (`.gitsecret/`, ~30 secrets) | plaintext `secrets.toml`, base64 only |
| **Bootstrap automation** | `build.sh` (compose assembly), `host-setup.sh`, `environment-setup.sh` (dinopass secret gen), `db-setup.sh` (DB users, migrations) | no install `Job` / db-setup `Job` equivalent |
| **Cron jobs** | docman delivery, unique-code generation, S3 sync, pf backup | run *inside* the `oem` container via the `jobs` configMap; no K8s `CronJob`s |
| **Log shipping** | per-service `awslogs` driver → CloudWatch (+ `aws_cloudwatch_agent_config.json`) | none (would be Fluent Bit / CloudWatch agent on K8s) |
| **Protected-files backup** | `pfbackup` module — CIFS/SMB mount | not represented |
| **Startup ordering** | `WAIT_HOSTS` (iol/pay wait for web) | env var present but **no initContainer** enforces it |
| **DB engine choice** | MariaDB / MySQL / SQL Server selectable at deploy | `db`/`mysql`/`ss` subcharts exist but no selector logic |
| **Health checks** | per-service `healthchecks/` on by default | probes exist in the factory but **disabled by default** |
| **Reverse proxy / TLS** | Traefik (`tfk`, `traefik-files/`), routing + certs | Ingress object only; no Traefik/IngressRoute, no TLS wiring |
| **Monitoring** | `whi` (Whiskers) + collectd PUTVAL exporter scripts | nothing — see `helm-monitoring-integration.md` |

---

## 4. Version drift (concrete)

| Component | oe-deploy default | chart | action |
|-----------|-------------------|-------|--------|
| OpenEyes (`MASTER_TAG`) | `26.0.0` | `appVersion 1.16.0`, web tag `latest` | bump appVersion + pin web tag |
| MariaDB | `11.8` | `10.6` | bump |
| Mirth Connect | `4.6.1` | `4.4.2` | bump |
| MySQL | `8.0` | `8.0` | OK |
| SQL Server | `2022-latest` | `2022-latest` | OK |
| Traefik | `v3.3` | — | add (if Traefik path chosen) |

> Most chart subcharts pin `latest`, which is non-reproducible. Pin explicit
> tags to match oe-deploy during Phase 4.

---

## 5. Module parity

oe-deploy ships 14 module overlays:

```
apache  cito  cocoa  csd  debug  dev  hie  international
mailer  optom  pfbackup  tfk  wcrs  worklist
```

The chart implements modules through `web`/`oem` values rather than overlay
files. **Verify per-module parity during migration** — in particular
`pfbackup` (CIFS/SMB protected-files backup) has no obvious chart equivalent,
and `tfk`/`apache` proxy modules depend on the ingress/Traefik decision in
Phase 4.

---

## 6. "Present but flawed" in the chart (fix in place, not a parity gap)

- Ingress hardcoded to `/ -> web:80` (`templates/ingress.yaml`).
- `namespace.yaml`, health probes, and `tests/test-connection.yaml` disabled.
- `reddis` misspelling.
- `secrets.toml` committed in clear text.
- ~11k lines of duplicated `_helpers.tpl`/`_apis.tpl` across subcharts
  (the headline reorg target, D1 in the plan).

---

## 7. Suggested porting order (Phase 5)

1. **Backups** (`bkp` → `CronJob` running mariabackup) — data-safety first.
2. **db-setup `Job`** — replaces `db-setup.sh` so installs are self-bootstrapping.
3. **WAIT_HOSTS init containers** — correctness for `iol`/`pay` ordering.
4. **`rmq`, `rtf`, `pen`, `whi`, `mcbl`, `db2`** subcharts — feature parity.
5. **Log shipping** (Fluent Bit / CloudWatch) and **pfbackup** — operational parity.
