# Integrating Prometheus + Grafana into the OpenEyes Helm chart

How to add external monitoring sub-charts (Prometheus + Grafana) to
`~/charts/helm/openeyes` without coupling cluster-wide monitoring to a single
app release. This is Phase 6 of `~/claude-kit/todo/helm-reorg-plan.md`.

## Recommendation in one line

**Install `kube-prometheus-stack` as its own release** (it owns the operator +
CRDs + Grafana); the **app chart ships only flag-gated `ServiceMonitor`/
`PodMonitor` + Grafana dashboard ConfigMaps**, generated from the `oe-common`
library. Do **not** make the stack a hard dependency of the app umbrella.

---

## Why not bundle the stack as a subchart dependency

- **Helm does not upgrade CRDs.** CRDs installed from a chart's `crds/` dir are
  created once and never updated by `helm upgrade`. If the app umbrella owns the
  Prometheus Operator CRDs, every operator bump becomes a manual CRD surgery.
- **Ownership conflict.** Two app releases that both bundle the stack fight over
  the same cluster-scoped CRDs and the single Prometheus/Grafana instance.
- **Lifecycle coupling.** Monitoring should outlive and span app releases;
  binding it to one app's `helm uninstall` would tear down cluster monitoring.

So: monitoring infra is a **platform** concern (one release, one namespace); the
app only **declares what to scrape and what to graph**.

---

## Architecture

```
namespace: monitoring                 namespace: openeyes
┌─────────────────────────┐           ┌──────────────────────────────┐
│ kube-prometheus-stack   │  scrapes  │ web / oem / db / …           │
│  • Prometheus Operator  │ ◀──────── │   Service (named port metrics)│
│  • Prometheus (CRDs)    │           │   ServiceMonitor  (from chart)│
│  • Grafana + sidecar    │ ◀──────── │   ConfigMap dashboard         │
└─────────────────────────┘  loads    │     label grafana_dashboard=1 │
   installed SEPARATELY               └──────────────────────────────┘
                                         shipped BY the openeyes chart
```

---

## Step 1 — install the stack once (platform release)

Separate release, own namespace, configured to discover app-shipped monitors
across namespaces:

```yaml
# values for the kube-prometheus-stack release (namespace: monitoring)
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false   # discover ALL ServiceMonitors
    serviceMonitorNamespaceSelector: {}               # ...in any namespace
    podMonitorSelectorNilUsesHelmValues: false
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard          # picks up labelled ConfigMaps cluster-wide
      searchNamespace: ALL
    datasources:
      enabled: true
```

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

---

## Step 2 — app chart ships the monitors + dashboards (flag-gated, default OFF)

Add to the `oe-common` library two factories, rendered per service from values:

`charts/oe-common/templates/_servicemonitor.tpl`

```yaml
{{- define "oe-common.servicemonitor" -}}
{{- if .Values.metrics.serviceMonitor.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "oe-common.fullname" . }}
  labels: {{- include "oe-common.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels: {{- include "oe-common.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: metrics
      path: {{ .Values.metrics.serviceMonitor.path | default "/metrics" }}
      interval: {{ .Values.metrics.serviceMonitor.interval | default "30s" }}
{{- end -}}
{{- end -}}
```

Per-service values contract (default off, so the chart still renders where the
CRDs are absent):

```yaml
metrics:
  enabled: false          # adds a named "metrics" port to the Service
  port: 9090
  serviceMonitor:
    enabled: false        # requires the Prometheus Operator CRDs to exist
    path: /metrics
    interval: 30s
```

The Service factory already builds ports from values — add a `metrics` named
port when `metrics.enabled`. Each app that exposes `/metrics` then becomes a
scrape target with one flag.

Dashboards ship as ConfigMaps labelled `grafana_dashboard: "1"`; the Grafana
kiwigrid sidecar auto-loads them — no Grafana restart, no manual import.
`charts/oe-common/templates/_dashboard.tpl` wraps a `.Files.Get` of a JSON
dashboard under `files/dashboards/`.

---

## Step 3 (optional) — one-command dev/demo bundling

For throwaway demo clusters only, the stack *may* be an **optional, default-OFF**
umbrella dependency with **CRDs disabled** (managed separately), gated by a tag:

```yaml
# umbrella Chart.yaml
dependencies:
  - name: kube-prometheus-stack
    version: "<pinned>"
    repository: https://prometheus-community.github.io/helm-charts
    condition: monitoring.enabled
    tags: [observability]
```

```yaml
# umbrella values.yaml
monitoring:
  enabled: false
kube-prometheus-stack:
  crds:
    enabled: false        # never let the app release own the CRDs
```

Production keeps `monitoring.enabled: false` and uses the separate platform
release from Step 1.

---

## Step 4 — migrate the existing oe-deploy signals

oe-deploy monitors via **collectd PUTVAL exporters**, not Prometheus:

- `~/oe-deploy/monitoring/count_active_users.sh`
- `~/oe-deploy/monitoring/count_apache_workers.sh`
- `~/oe-deploy/monitoring/docker_health.sh`
- plus the `whi` (Whiskers) agent service.

Port each to a Prometheus metric so the signals survive:

| oe-deploy signal | Prometheus equivalent |
|------------------|-----------------------|
| active users (collectd) | app `/metrics` gauge, or a small exporter sidecar |
| apache workers (collectd) | `apache_exporter` against the web service |
| container health (collectd) | kube-state-metrics + `kube_pod_status_*` (built into the stack) |
| Whiskers (`whi`) | fold its checks into exporters/ServiceMonitors |

kube-state-metrics (shipped with kube-prometheus-stack) already covers most
container/pod health, so `docker_health.sh` largely disappears for free.

---

## Verification

1. `helm template` the app chart with `metrics.serviceMonitor.enabled=false` →
   no monitoring CRDs in output (renders on any cluster).
2. With the stack installed and the flag on → `ServiceMonitor` appears, target
   shows **UP** in Prometheus, dashboard appears in Grafana automatically.
