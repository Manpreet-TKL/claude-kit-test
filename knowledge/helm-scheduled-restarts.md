# Scheduled container restarts in the OpenEyes Helm chart

## Why

Some services in the stack are long-running JVM processes — **Mirth Connect (`mc`)**
and **Pentaho (`pen`)** — that slowly accumulate heap and threads. A periodic
restart sheds that and keeps them healthy. The chart had no Kubernetes-native
scheduling (the only cron is *inside* the `oem` container and can't restart pods),
so this adds the missing piece: declare "restart these deployments on this schedule"
in values, nothing else.

## How it works

A `CronJob` runs on the schedule, executes `kubectl rollout restart deployment …`
against the named deployments, and (by default) waits on `kubectl rollout status`
so a failed bounce surfaces as a failed Job. A small **namespace-scoped** RBAC grant
lets the job's ServiceAccount patch deployments — nothing cluster-wide.

```
CronJob (schedule) ──> Job ──> pod: kubectl rollout restart deployment mc pen -n <ns>
                                         │ uses
                                         ▼
                         ServiceAccount restart-runner
                           └─ Role (apps/deployments: get,list,watch,patch)
                              └─ RoleBinding
```

`kubectl rollout restart` works by patching the deployment's pod-template
`kubectl.kubernetes.io/restartedAt` annotation, which triggers the deployment's
normal rolling update — so this respects each deployment's update strategy and
readiness probes; it is **not** a hard `kill`.

Deployment names equal the subchart names (`mc`, `pen`, `web`, `oem`, …), so the
`targets` list is just those names. One CronJob can restart several deployments in
a single command.

## Where it lives

Two umbrella templates, alongside `ingress.yaml`/`secret.yaml`:

- `openeyes/templates/restart-cronjob.yaml` — one `CronJob` per `restart.jobs` entry.
- `openeyes/templates/restart-rbac.yaml` — `restart-runner` ServiceAccount + Role + RoleBinding.

They reuse the chart's existing helpers (`openeyes.namespace`, `openeyes.labels`,
`openeyes.annotations`, `openeyes.cronjob.api`, `openeyes.role.api`, …) — no new
helpers, no new subchart. The kubectl image defaults to the public
`bitnami/kubectl`; set `restart.dockerRepo: true` to route it through the private
mirror instead.

## Configuration

The whole feature is **off unless `restart.enabled: true`** — existing installs are
unaffected. Add this block to an environment's values:

```yaml
restart:
  enabled: true
  image: bitnami/kubectl         # generic kubectl image (public by default)
  tag: "1.33"                    # pin near your cluster's kube version
  imagePullPolicy: IfNotPresent
  # dockerRepo: true             # route the image via .Values.dockerRepo mirror
  # imagePullSecrets: [{ name: docker-pull-key }]
  defaults:                      # fallbacks applied to every job below
    timeZone: "Europe/London"    # CronJob .spec.timeZone — needs Kubernetes >= 1.27
    concurrencyPolicy: Forbid
    waitForRollout: true
  jobs:
    nightly-java:
      schedule: "0 3 * * *"      # 03:00 every day
      targets: [mc, pen]
    # weekly-web:
    #   schedule: "0 4 * * 0"    # 04:00 Sundays
    #   targets: [web, oem]
```

Per-job keys (`schedule`, `targets` are required; `timeZone`, `concurrencyPolicy`,
`waitForRollout`, `rolloutTimeout`, history/deadline limits are optional and fall
back to `restart.defaults`). Each entry becomes one CronJob named `restart-<key>`.

## How to verify

1. Render with the block enabled and confirm the CronJob + RBAC look right:
   ```
   helm template t openeyes -f <env-values>.yaml --show-only templates/restart-cronjob.yaml
   helm template t openeyes -f <env-values>.yaml --show-only templates/restart-rbac.yaml
   ```
   Expect `schedule: "0 3 * * *"`, `rollout restart deployment mc pen`, and a Role with
   `apps/deployments` verbs `[get,list,watch,patch]`.
2. Render with `restart.enabled: false` (or no `restart:` block) → both `--show-only`
   renders are empty. Default-off proven.
3. On a cluster, trigger immediately instead of waiting for the schedule:
   ```
   kubectl create job --from=cronjob/restart-nightly-java smoke -n <ns>
   kubectl logs job/smoke -n <ns>     # "deployment.apps/mc restarted", rollout OK, no "forbidden"
   ```
