---
name: c-oe-helm
description: OpenEyes Helm umbrella chart - deploy/debug/extend
---

# OpenEyes Helm chart

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

A Helm 3 **umbrella chart** that deploys the full OpenEyes stack to Kubernetes.
It was templated from `~/oe-deploy` (the docker-compose source of truth) and is
meant to deploy the same services with the same ease-of-use: **adding or tuning
a service is a values-only edit.**

Location: canonical repo `git@github.com:ToukanLabs/helm.git`, checked out at
`~/helm` on this host (chart at `~/helm/openeyes`, docs under `~/helm/docs/`).
The repo `.gitignore` excludes the umbrella `/values.yaml` and `secrets.toml` -
both are supplied per environment, so a fresh clone ships neither. The
per-environment copies under `~/charts` (`nl`, `alpha`, `prod`, `uat`, `train`)
are the legacy layout, each carrying its own `values.yaml` + `secrets.toml`
(and some local bug fixes - see `~/charts-bugfix-analysis.md`). helm/kubectl
binaries are NOT installed on this host - renders and deploys happen elsewhere.

## Chart identity

`apiVersion: v2`, `name: openeyes`, `type: application`, `version: 0.1.0`,
`appVersion: "1.16.0"`. **No `dependencies:` declared** - the subcharts are
loose-vendored under `charts/` rather than declared dependencies.

## Layout

```
openeyes/
├── Chart.yaml                 # umbrella, NO dependencies block
├── values.yaml                # global + per-service config
├── files/
│   ├── ingress-matrix.yaml        # architecture-keyed (aws/gcp/microk8s) defaults
│   └── storageclass-matrix.yaml   #   consumed via .Files.Get
├── templates/                 # umbrella GLUE
│   ├── _helpers.tpl (408)  _apis.tpl (259)  _main_helpers.tpl (86, registry helpers)
│   ├── ingress.yaml        # HARDCODED  / -> web:80
│   ├── secret.yaml         # builds Secrets from secrets.toml via .Files.Get
│   ├── storageclass.yaml   # lookup-guarded
│   ├── namespace.yaml      # commented out / disabled
│   ├── NOTES.txt
│   └── tests/test-connection.yaml   # disabled
└── charts/                    # 12 subcharts (see inventory)
```

## The two mechanisms that make it work

1. **Factory pattern.** Each subchart's `templates/` (deployment.yaml,
   service.yaml, configmap.yaml, secret.yaml, pv.yaml, pvc.yaml, scaling.yaml)
   are thin - they `include` shared named templates that build the actual
   resource from that service's `values.yaml`. You define a service by writing
   values, not Kubernetes YAML.

2. **Architecture matrix.** `files/ingress-matrix.yaml` and
   `files/storageclass-matrix.yaml` are keyed by architecture (`aws`, `gcp`,
   `microk8s`). Templates pull the right block via `.Files.Get`, so ingress
   class and storage class default correctly per platform with no manual edit.
   Set the architecture in values; the matrix does the rest.

## Values model

- **Global** values (top of `openeyes/values.yaml`): architecture selector,
  registry/image-pull config, shared toggles.
- **Per-service**: each subchart has its own `values.yaml` with an `enabled`
  flag, image/tag, env, volumes, resources, scaling, probes.
- Enable/disable today is the per-service `enabled` flag (there is no
  `condition:`/`tags:` dependency wiring yet - that is a reorg target).

## Secrets

`templates/secret.yaml` reads `secrets.toml` (per env) via `.Files.Get` and
emits `Secret` objects. Special case: a `dockerPassword` key is rendered as a
`kubernetes.io/dockerconfigjson` pull secret. **`secrets.toml` is gitignored,
not committed** - it is supplied per environment in clear text (base64 only)
and holds real secrets; never fold it into an upstream PR, and rotate anything
that leaks.

## Subchart inventory (12)

| Subchart | Image | Default | Notes |
|----------|-------|---------|-------|
| `web` | oe-web-live | **on** | main OpenEyes app |
| `oem` | oe-manager | **on** | runs in-container cron (`jobs` configMap) |
| `db` | mariadb | **on** | pins `10.6` (oe-deploy is `11.8`) |
| `mysql` | mysql 8.0 | off | alternative DB engine (`mys` in oe-deploy) |
| `ss` | mssql/server 2022 | off | SQL Server engine |
| `mc` | nextgenhealthcare/connect | off | Mirth Connect; pins `4.4.2` (oe-deploy `4.6.1`) |
| `iol` | iolmasterimport | off | IOLMaster import; has `WAIT_HOSTS` but no init container |
| `sig` | oe-sig-import | off | signature import (simplest subchart) |
| `pay` | payloadprocessor | off | payments; env folders backport a `du_pay` rename |
| `portal` | optom-portal | off | Laravel; needs `LARAVEL_APP_KEY` secret |
| `reddis` | redis | off | **misspelled**; Redis cache (`red` in oe-deploy) |
| `aws` | aws-cli | off | S3 sync (not the full awslogs/CloudWatch pipeline) |

**Critical tech debt:** every subchart ships a byte-identical `_helpers.tpl`
(736 lines) + `_apis.tpl` (259 lines) - ~11,000 duplicated lines, md5-identical
across subcharts modulo the chart-name prefix. A one-line helper fix needs 12
edits. Fixing this (a `type: library` chart) is the headline reorg target.

## Modules

OpenEyes feature modules are configured through `web`/`oem` values rather than
overlay files. oe-deploy's equivalent overlays are under
`~/oe-deploy/templates/modules/` (apache, cito, cocoa, csd, hie, international,
mailer, optom, pfbackup, tfk, wcrs, worklist, debug, dev). `pfbackup`
(CIFS/SMB) has no obvious chart equivalent.

## Known gotchas

- Ingress is hardcoded `/ -> web:80` (`templates/ingress.yaml`), not values-driven.
- `namespace.yaml`, health probes, and `tests/` are disabled by default.
- `reddis` is misspelled.
- Image tags are stale vs oe-deploy and several pin `latest` (non-reproducible).
- `secrets.toml` is plaintext.

## Divergence from oe-deploy

The chart lags oe-deploy. Missing services: `bkp` (mariabackup backups), `db2`,
`mcbl` (BridgeLink), `notes`, `pen` (Pentaho), `rmq` (RabbitMQ), `rtf`, `tfk`
(Traefik), `whi` (Whiskers). Missing cross-cutting features: DB backup
CronJobs, encrypted secrets (git-secret/GPG), db-setup/bootstrap Jobs, K8s
CronJobs, log shipping, WAIT_HOSTS init containers, monitoring. Full list:
`/home/toukan/helm-vs-oe-deploy-differences.md`.

## Planning docs (in /home/toukan)

- `helm-reorg-plan.md` - library-chart refactor + phased, golden-file-verified migration.
- `helm-vs-oe-deploy-differences.md` - complete parity gap list.
- `helm-monitoring-integration.md` - Prometheus + Grafana integration design.
- `charts-bugfix-analysis.md` - per-env bug fixes (LARAVEL_APP_KEY, zero-downtime rollout, configMap mountPath).

## Deploy workflow

Mirrors oe-deploy's per-environment model: pick the env folder, supply its
`values.yaml` + `secrets.toml`, then **always template before deploying**:
`helm template <release> ./openeyes --debug > out.yaml` (the `htemplatee` alias
in `.k8s_bash_aliases` renders to a timestamped file in `$HOME`) and inspect
the render - secrets present, image tags right, namespace right - BEFORE any
`helm install`/`helm upgrade`. Note `helm template` has no `--dry-run` flag;
`--debug` is the proven form. Namespace resolution is the `openeyes.namespace`
helper: the release namespace wins unless it is "default", in which case
`global.namespace` is used (commands documented in `~/helm/docs/namespace.md`).
Architecture selection in values drives the ingress/storage matrix automatically.
