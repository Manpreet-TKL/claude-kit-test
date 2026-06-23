# Comments & documentation

## Why not what

Comments explain *why*, not *what* — the code itself reveals the what. Aim for self-documenting code.

```php
// widen tolerance: scanner clocks drift up to 2s between sites
$window = 2;
```

## DTO docblocks

Every DTO gets a one-line PHPDoc summary, an `@property` line per property (type **and** description —
even with constructor property promotion), and a custom `@table` tag for the underlying model table.
This feeds future centralised model-documentation generation.

```php
/**
 * An OpenEyes User.
 * @property ?int $id - primary key for the User
 * @property ?string $first_name - the given name of the User
 * @table user
 */
```

## View headers

Head each PHP view file with `Ref:` lines for the rendering `class::method`(s) and `@var` type-hints
for injected variables — views are often included via dynamically-built strings, which defeats global search.

```php
/**
 * Ref: OEModule\OphCiExamination\DefaultController::actionCreate
 * Ref: OEModule\OphCiExamination\DefaultController::actionEdit
 *
 * @var OEModule\OphCiExamination\DefaultController $this
 * @var OEModule\OphCiExamination\models\Diagnoses $element
 */
```

## JS headers

Head each JavaScript file with a short description and one or more `Ref:` lines pointing to the file
path(s) that include it.

```js
/**
 * Provides mechanism to link examination element to core diagnoses VueJS UI
 * Ref: /protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_Diagnoses.php
 */
```

Note: the view/JS reference-header specs are provisional, awaiting formal adoption.

---
Sources: Developer Checklist (2227634177), Inline documentation (3287449608), Tracking Code References (2654896155).
