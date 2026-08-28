# Deprecated element types

An `element_type` row names a model class. The row is data, the class is code, and the two
have separate lifecycles: a row inserted by a migration years ago survives every upgrade,
while the class it names can be deleted, renamed, superseded, or simply never shipped to a
given deployment. When the class cannot be loaded, `Event::getElements()` skips the element
and the event renders without it - correct behaviour, logged at error level.

This document is the inventory for one deployment, the repeatable checks that prove an
element type is genuinely retired rather than accidentally broken, and the process for
retiring the next one.

## Inventory

320 `element_type` rows, of which 319 are reachable by the application. 209 resolve normally.
The remaining 110 do not, and they split into two very different populations.

| Owning event type | Unresolvable element types | Non-deleted events here | Reaches the log path |
|---|---|---|---|
| OphCiExamination | 1 | 7,682,253 | yes |
| OphLeEpatientletter | 1 | 2,047,730 | yes |
| OphDrPrescription | 1 | 1,951,004 | yes |
| OphLeIntravitrealinjection | 1 | 38,977 | yes |
| OphOuAnaestheticsatisfactionaudit | 4 | 3 | yes |
| OphCiAccidentandemergency_Doctor | 28 | 0 | no |
| OphCiAccidentandemergency_Nurseassessment | 25 | 0 | no |
| OphCiAccidentandemergency_Triage | 21 | 0 | no |
| OphCiAccidentandemergency_Discharge | 12 | 0 | no |
| OphCiAccidentandemergency_Scrutiny | 9 | 0 | no |
| OphCiAccidentandemergency_UnableToContact | 2 | 0 | no |
| OphCiAccidentandemergency_TelephoneReview | 2 | 0 | no |
| OphCiAccidentandemergency_Safeguarding | 2 | 0 | no |
| OphInMehPac | 1 | 0 | no |

The dummy row `element_type.id = 0` is excluded from all of this. It exists only so the
`setting_*` tables can carry a non-NULL `element_type_id` where MariaDB will not accept
repeated NULLs in a unique index, and `ElementType::beforeFind()` filters it out of every
find, which is why sweeps see 319 rows rather than 320. Its `event_type_id = 1` points at an
event type that has not existed for years; that dangling reference is expected.

### Retired by core: 2 rows

| id | Class | Backing table | Newest row |
|---|---|---|---|
| 601 | `OEModule\OphCiExamination\models\Element_OphCiExamination_FixAndFollow` | `et_ophciexamination_fixandfollow`, 377 rows across 354 patients | 2022-08-03 |
| 485 | `OEModule\OphDrPrescription\models\Element_OphDrPrescription_PrescriberSignature` | dropped entirely | n/a |

Neither class has ever existed in this repository. A pickaxe over the full history (39,128
commits back to 2011, all 612 refs) finds no commit that ever added either class, and no
migration in `protected/migrations/` inserts either row. They arrived from a site-specific
module or a private branch, the code went away, and the rows stayed.

The only trace of either is `e1c9515da2` (2022-04-19, "OE-12877: Remove Fix and Follow
element from Admin page"), a one-line commit adding the class to
`ExaminationHelper::elementFilterList()`. It is on exactly one branch and was never merged to
develop, so until now the element was still offered in the Examination workflow-step admin -
an admin could add a broken element to a workflow.

`PrescriberSignature` was superseded by `Element_OphDrPrescription_Esign`, introduced in
`1b22a8cb39` ("OE-11520 Electronic Signature in Prescription Event"). The `et_` tables for
`Esign` exist across five modules; nothing named `prescriber_signature` remains.

These two are the only rows stamped `deprecated_date` by the migration in this change.

### Absent modules: 108 rows

Everything else names a class from a module this distribution does not ship. That is not
retirement - it is a deployment fact, and a different site running those modules must not
find them silently marked deprecated. They are left unstamped on purpose.

102 of them never reach the logging path here because no non-deleted event of the owning type
exists: 101 Accident and Emergency rows and one `OphInMehPac`. The other 6 do.
`OphLeEpatientletter` has 2,047,730 events and `OphLeIntravitrealinjection` has 38,977, so
every one of those loads logs an error today; `OphOuAnaestheticsatisfactionaudit` contributes
4 rows against 3 events.

The `OphLe*` and `OphOu*` element types are the obvious candidate for a **site-specific**
migration stamping `deprecated_date`, once whoever owns this deployment confirms those
modules are never coming back. That decision does not belong in core.

## Proving an element type is deprecated

Four independent checks. Any one of them can mislead on its own; together they settle it.

**1. Can the class be loaded?**

The definitive test is `class_exists()` under the real application autoloader, not a file
search - namespaced element classes live at paths that do not match their class names, and
several modules register extra autoload roots.

`docker exec <web> bash -lc 'cd /var/www/openeyes && ./protected/yiic checkelementtypes'`

The command reports every row that does not resolve and classifies it:

| Status | Condition | Meaning |
|---|---|---|
| OK | class resolves | normal |
| DEPRECATED | class missing, `deprecated_date` set | retired on purpose, silent at runtime |
| MODULE OFF | class missing, owning module not installed | benign on this deployment |
| UNEXPLAINED | class missing, not deprecated, module installed | needs a decision |

It exits non-zero only on `UNEXPLAINED`, so it can be wired into a post-upgrade check.
`MODULE OFF` is advisory in the report and never silences anything at runtime, because
`event_type.class_name` is not always a module key.

**2. What happened to the backing table?**

Dropped means the element was retired and cleaned up; retained with no recent writes means
the element was retired but its history was kept, which is the case that must never be
deleted.

`docker exec <db> mariadb -uopeneyes -popeneyes openeyes -e "SELECT COUNT(*), MAX(last_modified_date) FROM et_ophciexamination_fixandfollow"`

A table that is still being written to is not deprecated, whatever the row says.

**3. What does the history say?**

`git log --all --oneline -- protected/modules/<Module>/models/<Class>.php` shows whether the
model ever existed. `git log --all --oneline -S '<ExactClassName>'` is the stronger form: it
finds the class by content across renames and across every branch, and an empty result on a
full clone means the class was never part of this repository at all. `git log -S` on the
superseding class name then dates the replacement.

Check the clone is not shallow before trusting an empty pickaxe result:
`git rev-list --count HEAD` and `[ -f .git/shallow ] && echo shallow`.

**4. Is the owning module registered?**

`Yii::app()->hasModule($element_type->event_type->class_name)` separates "retired" from
"never installed here". It is a hint, not proof: `event_type.class_name` is not always a
module key, which is why the sweep treats `MODULE OFF` as advisory only.

## The retirement process

1. Never delete an `element_type` row or its `et_*` table while historic events reference
   them. The row is what lets an old event still name its element; the table is the data.
2. Add a migration stamping `element_type.deprecated_date` for the class, matched on
   `class_name` and skipped when the row is absent, so fresh installs are unaffected.
3. For Examination elements, add the class to `ExaminationHelper::elementFilterList()` so it
   stops being offered in the workflow-step admin.
4. Only then remove the model class and its views.
5. Run `yiic checkelementtypes` and confirm no element type is reported unexplained.

The same process is recorded in the PHPDoc on `ElementType::resolveClassName()` and in the
command's `getHelp()`, so it is visible from the code as well as from here.

## Measured effect

238 events sampled across every event type, including 50 with fix-and-follow data and 50
prescriptions, loaded through `Event::getElements()` with the change reverted and reapplied.

| | Log lines | At error level |
|---|---|---|
| Before | 149 | 127 |
| After | 44 | 22 |

The 105 removed lines are the two retired classes (55 fix-and-follow, 50 prescriber
signature). The 22 that remain are the unstamped `OphLe*` and `OphOu*` rows, which is the
intended behaviour: an absent module is not a retirement decision.

The element sets themselves are identical before and after - same element type ids, same
model classes, same element ids, same order, across all 238 events and 658 loaded elements.
Rendering is untouched; only the logging changes.

## Follow-ups, out of scope here

- Collapse `ExaminationHelper::elementFilterList()` into a `deprecated_date` query once the
  column has shipped, so the hard-coded list stops being a second source of truth.
- A site-specific migration stamping the `OphLe*` and `OphOu*` element types on deployments
  where those modules are gone for good.
- Wire `yiic checkelementtypes` into the post-upgrade checks; it already exits non-zero on
  anything unexplained.
