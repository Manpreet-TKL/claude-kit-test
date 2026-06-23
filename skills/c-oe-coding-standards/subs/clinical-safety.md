# Clinical safety — non-negotiable invariants

OpenEyes is a clinical record. These override every other rule. When in doubt, stop and ask.
See also `subs/disruptive-ops.md` for the literal-`yes` confirmation pattern on destructive ops.

## Never touch clinical values unasked

Do not change how a clinical value is persisted, calculated, converted, or displayed —
visual acuity, IOP, dose, laterality, drug name/strength, units — without an explicit instruction.
- A "harmless" refactor of a unit conversion or a display rounding is a patient-safety change.
- If a value's representation must change, surface it and get a clear ask first.

## Never bypass audit

Every clinical CRUD runs through `AuditService`. Write through the model layer so it fires —
even in one-off scripts and migrations.
- Never `INSERT`/`UPDATE` clinical tables with raw SQL that skips the model save path.
- `Audit::add('Patient', 'view', $patient->id)` for explicit action auditing.

## Soft-delete only

Clinical data is soft-deleted (`deleted = 1`), never hard-`DELETE`d.
- The default clinical base class is `BaseActiveRecordVersionedSoftDelete` (see `models.md#base-classes`).
- Hard deletes destroy version history and audit trail.

## TestHelper stays out of live

The `TestHelper` module must never be enabled in production — do not loosen its `OE_MODE !== 'live'` gate.

## Modules self-register

A module advertises itself in its own `config/common.php`; `local/common.php` is just the on-switch.
**Never edit `core/common.php` from a module install.** (See the `create-oe-module` skill.)

## voiceControl independent

The `voiceControl` module must stand on its own — no runtime dependency on, shared key with, or
cross-import of `aiSearch`.

---
Source: house rules + OE module-config layering; reinforced across the OPD Developer Guidelines.
