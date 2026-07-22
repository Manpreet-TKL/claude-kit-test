# Base + overlay repository model (Phase 10)

How the templates (Phase 9) and per-site configuration compose into a full,
deployable channel set for one instance. The unit that Phase 9 renders is a single
channel; a real BridgeLink instance runs a *set* of channels (Portsmouth 9, Wales 10,
Newmedica 35, ...). This phase defines the layering and repository layout that turn
"a library of templates + per-site values" into "the exact channel set to deploy at
site X", with secrets kept out of the repository entirely.

Status: the two shipped families (`pas-inbound-newmedica-local`, `pas-query-mpi-wales`)
are live and verified. The instance-manifest and feature-overlay mechanisms below are
the **design** for scaling the model to whole instances and to the additive-destination
cases found in Phase 8; they are described precisely so they can be built, and are
labelled as design rather than as something already generated.

## Three layers, three owners, three lifetimes

| Layer | What it holds | Owner | In git? | Changes when |
|---|---|---|---|---|
| 0 - Template library | channel logic with `${TOKEN}` + `${REDACTED_*}` placeholders | integration engineer | yes | the logic changes (rare; affects all sites) |
| 1 - Site overlay | per-site token values + which channels a site runs | per-site config | yes (no secrets) | a site is added or reparameterised |
| 2 - Secret store | the actual credentials behind `${REDACTED_*}` | ops / secret manager | **no** | a credential rotates |

The strict rule that makes this safe: **layer 2 values never appear in layers 0 or 1**.
A fully rendered layer-0+1 artifact still contains `${REDACTED_PASSWORD}` and is safe
to commit; only the deploy pipeline, holding a secret-store handle, resolves it in
memory (`deployment/deployment-automation.md`). This is the same boundary Wave 0
redaction established, carried forward into deployment.

## Repository layout

```
templates/                         # Layer 0 - shared logic, version-controlled
  <family>/
    channel.template.xml             exemplar + ${TOKEN} + ${REDACTED_*}
    params.json                      token catalogue
    sites.csv                        parameter rows, keyed by site (one row per member)
  overlays/                          # optional additive fragments (design, see below)
    <feature>.fragment.xml           e.g. clinic-list-dna, forward-to-meh, patient-search-prepend
sites/                             # Layer 1 - per-instance assembly, version-controlled
  <instance>/
    channels.csv                     which template family + which sites.csv row each channel uses,
                                     plus enabled/deployed intent and any feature overlays applied
secrets/                           # references only; values live in the external store
  redaction-log.csv                  every placeholder + where it occurs (NO values)
```

`sites.csv` stays per-family (as shipped) because a parameter row is meaningful per
family. `sites/<instance>/channels.csv` is the new composition layer: it names, for one
instance, each channel it should run and binds it to `(family, site_row)` plus its
deploy intent. An instance that runs channels from several families (the norm) lists
one line per channel across those families.

## Composing an instance's channel set

To produce the deployable set for instance X:

1. Read `sites/X/channels.csv`. For each row, take `(family, site_row)`.
2. Load `templates/<family>/channel.template.xml` and the named row from that family's
   `sites.csv`.
3. Apply any feature overlays listed for that channel (design; see below).
4. Site-render (fill `${TOKEN}` from the row). Leave `${REDACTED_*}` intact.
5. Emit the rendered channel; the collection across all rows is instance X's channel
   set, ready for the deploy pipeline to inject secrets and push.

Steps 1-5 are pure and deterministic: same inputs give byte-identical output, so a
rendered set can be diffed against what is live to see exactly what a deploy will
change. This is the property `bin/build_templates.py` already proves per channel; the
instance manifest lifts it to the whole set.

## Feature overlays (design) - additive, not forks

Phase 8 found that several near-identical channels differ only by *adding* an optional
destination or step to a shared core, not by diverging logic
(`comparisons/shared-lineage-diffs.md`):

| Feature | Base family it augments | Sites observed |
|---|---|---|
| `Clinic List - DNA` destination | PAS Inbound (`7a7288a3`, `d69815ee`) | Bolton |
| `Send to MEH` forward destination | PAS Inbound (`d69815ee`) | Bedford |
| Patient-Search prepend before upload | PayloadProcessor (`f703f9cd`) | Portsmouth |
| `Send Q21 test empi` test destination | PAS Query (`06f0b8b8`) | EK |

The model treats each as an **overlay fragment**: a self-contained destination/step
that a site's `channels.csv` line opts into, applied on top of the base template rather
than by forking a new template. This keeps one template per archetype and represents
per-site variation as a short, reviewable list of enabled features. It directly encodes
the Phase 8 conclusion that these are additive parameters, not distinct channels.

Two cases are explicitly **not** overlays because they are genuine forks, and must stay
separate templates/entries:
- Kingston's `06f0b8b8`, which shares an id with the PAS-query sextet but is a rewritten
  ORU correspondence router (a hard fork - `comparisons/shared-lineage-diffs.md`).
- The `6c3a10d1` PASAPI V1-vs-V2 script-body difference (Kingston vs Pennine), which is
  an API-version axis. This is better handled as a parameter (see below) than as an
  overlay, because it changes existing script bodies rather than adding a destination.

## The config surface every overlay/parameter must externalise

Consolidated from Phase 8 (`comparisons/commonality.md`), these are the axes an
instance overlay has to be able to set; they are the columns a mature `sites.csv` /
`channels.csv` pair must cover as more families are templated:

1. Listener ports (no estate standard - `networking/port-map.md`).
2. OpenEyes base URL + the single shared `api` credential (`auth/persisted-login.md`).
3. PASAPI version per resource (V1/V2/V3) - the `6c3a10d1` axis; a parameter, since it
   changes script bodies, unlike an additive overlay.
4. HL7 version (2.3/2.4/2.5) and assigning-authority codes (NHS/FACIL/DN; Wales board
   codes - already a token in the Wales family).
5. File-system paths (`/mnt/dicom`, `/mnt/docman/*`, `/mnt/document-upload`) and
   SFTP/SMB targets.
6. Remote PAS / MPI host:port endpoints.
7. Optional per-site destinations (the four overlays above) as feature flags.

The two shipped families already externalise their slice of this surface (ports, board
codes, practice ids, the two behaviour toggles). Extending the library means declaring
tokens/overlays for the remaining axes as each new family is templated, with the same
render-back proof gating each addition.

## Enabled / deployed state

Wave 0 kept channel enabled/deployed state intact in `canonical/` (it was not
normalised away - `canonical/NORMALISATION-RULESET.md`), so the template carries the
exemplar's `<enabled>` flags. Whether a channel is *deployed and enabled in production*
is a per-site deploy decision, so it belongs in layer 1 (`channels.csv`), not baked
into the template. Which channels are actually live at each site is an open,
user-supplied item (`unresolved/questions.md`); until confirmed, `channels.csv` should
default a channel's intent to the state observed in that site's export and flag it for
confirmation, never silently deploy-enable a channel that was dormant. `<revision>`
ships as 0 (normalised); the deploy step lets the server assign the live revision.

## Why this shape

- One template per archetype keeps the logic in one place; a fix propagates to every
  site by re-render, not by editing N copies (the current estate is exactly the N-copies
  problem this project exists to remove).
- Per-site values in a flat, diffable overlay make "what is different about site X" a
  short table, reviewable in a pull request.
- Secrets never enter the repository, so templates and overlays are freely shareable and
  the deploy pipeline is the only component that ever holds a live credential.
- Additive variation as overlays (not forks) preserves the Phase 8 evidence that most
  cross-site difference is parameters plus optional destinations, and keeps genuine
  forks (Kingston `06f0b8b8`) honestly separate.
