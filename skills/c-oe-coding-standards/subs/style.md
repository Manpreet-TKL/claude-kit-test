# Code style & structure

Base style is **PSR-12**, enforced by `phpcs.xml` (with documented legacy/Yii exceptions). Laravel
and Shared codespaces follow modern Laravel conventions and are the "gold standard"; legacy Yii keeps
its historical rules. Run the tooling — see `tooling.md`.

## Casing

- **Yii**: variables `$snake_case`, methods `camelCase`. Exception: Yii magic getters/setters that
  define a `snake_case` property, e.g. `getDisplay_weight()` defines `$display_weight`.
- **(replatform)** `OEShared` / `OELaravel`: variables `$camelCase` (deliberate inversion; Nov-2025 release).
- **JavaScript**: variables `camelCase`.
- DB-column-derived attributes stay `snake_case` everywhere (they mirror table columns).

## Short arrays

Use `[]`, never `array()`. Reformat legacy long-array syntax when you touch it.

```php
$x = ['a' => 1];   // yes
$x = array('a'=>1); // no
```

## Class constant

Reference other classes with import + `::class`, never a quoted FQN string — including in relation definitions.

```php
use OEModule\OphCiExamination\models\BirthHistory_DeliveryType;
'delivery_type' => [self::BELONGS_TO, BirthHistory_DeliveryType::class, 'birth_history_delivery_type_id'],
```

## const over static

Use `const` rather than `static` variables for class constants: `const GLOBAL = 'global';`.

## String interpolation

Use `{$var}` or `$var`; avoid the `${var}` / `${(var)}` forms deprecated in PHP 8.2.

```php
"Hello {$world}";  // ok      "Hello ${world}"; // deprecated
```

## Short methods

Keep methods short — extract complex logic and multi-clause conditionals into descriptively-named methods.

```php
if ($this->isEligibleForBooking($patient)) { ... }
```

## Nesting depth

Logic **SHOULD NOT** exceed two levels of nesting and **MUST NOT** exceed three. Use early returns
or extracted methods to flatten.

## Member order

In new classes declare `public` → `protected` → `private`, and `static` before instance methods.
(MUST in new classes; SHOULD when adding methods to existing ones.)

## Type hints

Type-hint method parameters and return types wherever possible: `public function find(int $id): ?Patient`.

## Traits over CBehavior

Prefer traits over Yii `CBehavior` abstractions, unless `CBehavior` gives a specific benefit.

## Header and namespace

Every file starts with the OpenEyes copyright/licence header; the `namespace` declaration sits
directly beneath it.

```php
<?php
/* copyright header ... */

namespace OEModule\Example;
```

## Namespace modules

Namespace all new modules under `OEModule\[Name]` (reference modules: `OphCiExamination`,
`PatientTicketing`). *(replatform: `OELaravel\Modules\[Name]\Models`)* — capitalise segments correctly.

## Target PHP version

Write for the latest supported PHP without breaking the minimum supported version (e.g. cast
possibly-null values to literals: `(string) ($user->name ?? '')`). Rector enforces the target
version — see `tooling.md#rector`.

---
Sources: Coding Standards (1570668569), Coding & Architecture Standards (3015540745), Developer Checklist (2227634177).
