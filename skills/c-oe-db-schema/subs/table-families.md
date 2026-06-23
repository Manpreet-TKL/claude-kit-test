# Table-family inventory

Volatile — counts/families shift per OE version. Counts are **base tables** (each clinical family ≈ doubles with `_version` mirrors). Confirm against `information_schema` before relying on any one table. See the parent `SKILL.md` for the prefix-decode key.

## Ophthalmology clinical families (`oph<domain>…`)

Domain segment: `ci` clinical-info/exam · `tr` treatment/operation · `co` correspondence/outcome · `dr` drugs · `in` investigations.

- `ophciexamination` (~248) — examination elements: VA, anterior/posterior segment, refraction, IOP, risks, allergies, comorbidities, social/family history, management & follow-up.
- `ophtroperationnote` (~69) — operation notes: cataract, trabeculectomy, glaucoma tubes, retinal buckle, CXL, anaesthetic, post-op instructions.
- `ophtroperationbooking` (~37) — surgery scheduling: theatre sessions, admission/cancellation letters, whiteboard, pre-assessment.
- `ophtroperationchecklists` (~22) — perioperative checklists: admission, nursing, clinical, anaesthetic, dilation, discharge, observations.
- `ophtrconsent` (~36) — surgical consent: capacity, best-interest, procedures, leaflets, signatures, supplementary consent.
- `ophtrintravitinjection` (~18) — intravitreal injection: anaesthetic, antiseptic, drug, lens status, complications, warnings.
- `ophtrlaser` (~6) — laser procedures: type, site, complications, post-op lenses.
- `ophcotherapya` (~27) — therapy advisory: decision trees, patient suitability, intervention outcomes, costs.
- `ophcocorrespondence` (~25) — clinical letters: templates, macros, recipients, signatures, internal referrals.
- `ophcocvi` (~14) — Certification of Vision Impairment: clinical + clerical info, preferred communication, delivery.
- `ophdrprescription` (~9) — prescriptions: dispensing locations, conditions, edit reasons, item tapering.
- `ophdrpgdpsd` (~8) — Patient Group Direction / PSD: assigned teams/users, medications, signatures.
- `ophinbiometry` (~8) — IOL calculations: formulas, lens types/positions, measurements.
- `ophin…` (visualfields, geneticresults, dnaextraction, labresults) — investigation modules.
- `ophgeneric` (~7) — generic/specialty-configurable assessment elements.

## Element tables (`et_…`)

`et_` (~230) — element ("event type") tables, historically ≈ the same as `oph`; roughly 1:1 with module elements (e.g. `et_ophcocorrespondence_*`). Treat as the element layer of the matching `oph` module.

## Reference / coding data (lookup-shaped, deployment-dependent)

- `medication*` (~23) + `drug*` — OE medication master: attributes, dose/frequency/route/laterality, forms, sets, auto-rules, tapering, search index. "Drug" ≈ "medication".
- `f_*` (~47) — NHS **dm+d** drug ontology import: `f_vtm/vmp/vmpp/amp/ampp/ingredient/lookup_*` (BNF-like hierarchy).
- `disorder` — diagnosis store (**~64k rows, SNOMED-backed**). `speciality`/`oph` flag marks eye vs systemic. Use `v_patient_diagnoses` to avoid manual joins.
- OPCS procedure coding: `opcs_code` (~556 rows), `proc` (~390 rows, OE procedure master), `proc_opcs_assignment` (proc → OPCS, one proc can map to several codes), plus `procedure_complication|risk|benefit`, `proc_set*`, `proc_subspecialty*`.
- **No dedicated `icd10`/`icd11`/`snomed` tables in this build** — ICD/SNOMED are deployment- or version-dependent; query before assuming. SNOMED concepts back the `disorder` table here.

## Non-ophthalmology feature families

- `pathway*` / pathstep (~9) — care-pathway steps for a clinic visit (arrival → triage → exam → discharge).
- `worklist*` (~16) — clinic lists / queues, definitions, mappings, attributes, wait-time analytics.
- `patientticketing*` (~22) — patient communication / virtual-clinic tickets (workflow, not audit).
- `document*` (~12) — document management: instances, data, logging, external indexing.
- `pas*` (~13) — PAS integration: hospital booking / correspondence inbound.
- `sso*` (~14) — single sign-on / external authentication.
- `request*` (~14) — request/referral infrastructure (overlaps `referral`, `pasapi`).
- `common*` (~8) — shared lookups (institutions, sites, firms, settings).
- `checklist*` (~12), `assessment*` (~14) — operational/clinical checklists and non-examination assessments.
- `commissioning*` (~12) — service commissioning data.
- `trdeviceusagerecord*` (~10) — device usage logging (lasers, biometry…).
- `genetics*` / `pedigree` (~12) — genetics module: pedigrees, study subjects, relationships.
- `eyedraw*` (~9) — EyeDraw canvas doodles: tags, flyout options, report-text policy.
- `anaesthetic*` — anaesthetic master: agents, delivery methods, complications.
- `event_*` (~23) — event **metadata/config** (types, subtypes, groups, icons, images, drafts, exports) — not clinical event data (that lives in the `oph*`/`et_` element tables).
