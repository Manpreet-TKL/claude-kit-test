# OpenEyes Helm chart — reorganisation plan

Re-organise `~/charts/helm/openeyes` to follow Helm best practices **without
losing any functionality** and while preserving its two defining strengths:

1. **Parity with `~/oe-deploy`** — the chart was templated from the oe-deploy
   docker-compose system and must keep feature parity with it (see
   `~/claude-kit/knowledge/helm-vs-oe-deploy.md`).
2. **Ease of use / no manual work** — adding or tuning a service is a
   values-only edit; architecture defaults (aws/gcp/microk8s) are selected
   automatically. This UX must survive the refactor.

Companion docs: `~/claude-kit/knowledge/helm-vs-oe-deploy.md` (the full gap list),
`~/claude-kit/knowledge/helm-monitoring-integration.md` (Prometheus + Grafana). Working context for the
chart is captured in the `oe-helm` skill (`~/.claude/skills/oe-helm/SKILL.md`).

---

## 1. Current-state assessment (verified)

`Chart.yaml`: `apiVersion: v2`, `name: openeyes`, `type: application`,
`version: 0.1.0`, `appVersion: "1.16.0"`, **no `dependencies:`**.

Layout:

```
openeyes/
├── Chart.yaml                 # umbrella, NO dependencies declared
├── values.yaml                # global + per-service config
├── files/
│   ├── ingress-matrix.yaml        # architecture-keyed defaults (aws/gcp/microk8s)
│   └── storageclass-matrix.yaml   #   consumed via .Files.Get
├── templates/                 # umbrella glue
│   ├── _helpers.tpl (408)  _apis.tpl (259)  _main_helpers.tpl (86)
│   ├── ingress.yaml        # HARDCODED  / -> web:80
│   ├── secret.yaml         # builds Secrets from secrets.toml via .Files.Get
│   ├── storageclass.yaml   # lookup-guarded
│   ├── namespace.yaml      # commented out / disabled
│   ├── NOTES.txt
│   └── tests/test-connection.yaml   # disabled
└── charts/                    # 12 loose-vendored subcharts
    └── aws db iol mc mysql oem pay portal reddis sig ss web
```

### What is good (keep)

- **Factory pattern** — every resource (Deployment/Service/PVC/ConfigMap/Secret/
  scaling) is assembled from shared named templates driven by each service's
  `values.yaml`. Adding a service = values, not YAML authoring.
- **Architecture matrix** — `files/*-matrix.yaml` keyed by `aws`/`gcp`/`microk8s`
  and pulled in via `.Files.Get`, so ingress class and storage class default
  correctly per platform with no manual edits.
- **Secret loader** — `templates/secret.yaml` reads `secrets.toml` and emits
  `Secret` objects (special-casing `dockerPassword` → `dockerconfigjson`).

### What is wrong (the reorg targets)

| # | Problem | Evidence |
|---|---------|----------|
| D1 | **Massive helper duplication.** Every subchart ships an identical `_helpers.tpl` (736 lines) + `_apis.tpl` (259 lines). | md5 of the normalised files is identical across web/db/oem/mc/portal/sig — only the chart-name prefix differs. ~11,000 duplicated lines; a one-line helper fix needs 12 edits. |
| D2 | **Subcharts are not declared dependencies.** They sit loose under `charts/`; there is no `dependencies:` block, no `Chart.lock`, no version pinning, no `condition`/`tags` toggles. | `Chart.yaml` has no `dependencies:`. |
| D3 | **Ingress hardcoded.** `templates/ingress.yaml` pins `/ -> web:80`; no values-driven host/path/TLS. | `templates/ingress.yaml`. |
| D4 | **Disabled-by-default scaffolding.** `namespace.yaml`, health probes and `tests/` are commented out. | templates as above. |
| D5 | **Plaintext secrets.** `secrets.toml` is committed per-env in the clear (base64 only). oe-deploy encrypts the equivalents with git-secret/GPG. | every env folder under `~/charts`. |
| D6 | **Naming / drift.** `reddis` (sic) for redis; `appVersion 1.16.0` and image tags (`mariadb:10.6`, Mirth `4.4.2`) lag oe-deploy (`11.8`, `4.6.1`, `MASTER_TAG 26.0.0`). | subchart `values.yaml`. |

---

## 2. Target architecture — the Helm **library chart**

The industry-standard fix for D1/D2 is a **library chart** (`type: library`)
holding the one copy of the helpers + resource factories, consumed by thin app
subcharts. This is the bjw-s `app-template` / Bitnami `common` pattern.

```
openeyes/                          # umbrella: type: application, WITH dependencies:
├── Chart.yaml                     #   12 subchart deps (+ optional monitoring, default-off)
├── Chart.lock                     #   committed; `helm dependency build` in CI
├── values.yaml
├── values.schema.json             #   NEW — validates the values contract
├── files/{ingress,storageclass}-matrix.yaml      # unchanged
├── templates/                     # umbrella GLUE ONLY
│   ├── ingress.yaml   (values-driven, multi-path)   secret.yaml
│   ├── storageclass.yaml   namespace.yaml   NOTES.txt
└── charts/
    ├── oe-common/                 # ★ type: library — the ONE copy
    │   └── templates/
    │       ├── _helpers.tpl  _apis.tpl                 # merged, single source
    │       ├── _deployment.tpl _service.tpl _pvc.tpl
    │       ├── _configmap.tpl  _secret.tpl  _scaling.tpl
    │       ├── _servicemonitor.tpl  _dashboard.tpl     # for monitoring
    └── web/ oem/ db/ … ×12        # ★ THIN app subcharts
        ├── Chart.yaml             #   one dependency: oe-common (same pinned version)
        ├── values.yaml            #   the ONLY per-service surface that changes
        └── templates/main.yaml    #   `{{ include "oe-common.all" . }}`
```

**Why this preserves ease of use:** the values contract per service is
unchanged. Authors still edit one `values.yaml`; the matrix files and `.Files`
loaders stay exactly as they are. The refactor removes duplication *behind* the
same UX, it does not change how a service is defined.

**Library-chart rule:** pin every subchart to the **same** `oe-common` version.
Mixed library versions inside one umbrella cause named-template collisions at
render time.

---

## 3. Migration plan — "lose no functionality" is enforced by a golden-file test

The guarantee is mechanical: after each phase, `helm template` must render
**byte-identical** output (modulo whitespace) to the pre-refactor baseline for
every environment. Any diff is reviewed and must be intentional.

| Phase | Action | Verify |
|-------|--------|--------|
| **0 — Baseline** | For each env folder, capture `helm template . -f <env>/values.yaml` to a golden file. Add `values.schema.json`. Land the two independent, already-identified fixes (`LARAVEL_APP_KEY` secret; zero-downtime `rollingUpdate`) — see `charts-bugfix-analysis.md`. | golden files committed; chart still installs |
| **1 — Library seed** | Create `oe-common` from the existing umbrella+subchart helpers (they are already identical). Convert **one** subchart (`sig`, the simplest) to `include` it; delete its local `_helpers.tpl`/`_apis.tpl`. | `helm template` for `sig` byte-identical to baseline |
| **2 — Roll out** | Convert the remaining 11 subcharts the same way; delete all 12 duplicated helper copies (~11k lines gone). | identical render at **every** step |
| **3 — Real dependencies** | Add a `dependencies:` block to the umbrella `Chart.yaml` (the 12 subcharts) with `condition: <svc>.enabled` and `tags:` so enable/disable is declarative. Generate `Chart.lock`. | per-env enable/disable matches today's behaviour |
| **4 — Harden** | Values-driven, multi-path **ingress** (un-hardcode `web`); fix `reddis` alias; document/select the `db` vs `mysql` engine; bump stale image tags to oe-deploy parity; externalise secrets (Phase D5 below). | diffs are intentional only |
| **5 — Parity gaps** | Add the missing services as subcharts where needed (`bkp`, `rmq`, `rtf`, `pen`, `whi`, `mcbl`, `db2`) and the missing cross-cutting features (backups, db-setup Job, WAIT_HOSTS init containers). See differences doc. | new services render and deploy |
| **6 — Monitoring** | Implement `~/claude-kit/knowledge/helm-monitoring-integration.md`. | dashboards + scrape targets appear |

Phases 0–3 are pure refactor (no behaviour change). Phases 4–6 are additive
parity/hardening and can be sequenced independently once the library exists.

---

## 4. Secrets hardening (Phase 4 detail)

`secrets.toml` is committed in the clear. Three production-grade options, in
order of preference for a GitOps/K8s setup:

1. **External Secrets Operator (ESO)** — secrets live in AWS Secrets Manager /
   SSM; the chart ships `ExternalSecret` manifests. Cleanest for the AWS targets
   this chart already favours.
2. **Sealed Secrets** — encrypt into the repo, controller decrypts in-cluster.
   Closest analogue to oe-deploy's git-secret workflow.
3. **SOPS + helm-secrets** — file-level encryption, mirrors git-secret most
   directly but adds a plugin dependency.

Keep the current `secrets.toml` loader as the local/dev path; gate the encrypted
path behind a value so demo installs stay one-command.

---

## 5. Distribution / packaging

- Publish the umbrella and `oe-common` to an **OCI registry** (the same
  `toukanlabsdocker` org already used for images) so `helm dependency update`
  resolves versioned charts instead of relying on vendored `charts/`.
- `Chart.lock` committed; `helm dependency build` (not `update`) in CI for
  reproducible resolution.

---

## 6. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Refactor silently changes rendered output | Golden-file `helm template` diff after every phase (Phase 0 gate). |
| Library version skew across subcharts | Single pinned `oe-common` version; CI check that all 12 match. |
| Losing oe-deploy parity while adding K8s features | Track every gap in `~/claude-kit/knowledge/helm-vs-oe-deploy.md`; Phase 5 closes them explicitly. |
| Secret exposure during migration | Rotate any secret that was ever committed in clear text before publishing the chart. |

---

## 7. References (exemplars)

- bjw-s `common` / `app-template` — the canonical library-chart app pattern.
- Bitnami `common` — widely-used library chart of helpers.
- Helm docs: *Library Charts*, *Subcharts and Global Values*, *Chart
  Dependencies* (`condition`/`tags`/`import-values`), *Schema Files*.
