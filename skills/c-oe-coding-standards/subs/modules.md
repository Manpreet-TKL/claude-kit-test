# Modules & architecture

A module owns its data and the logic that touches it. Dependencies between modules go through the
module API, never direct model imports. See the `create-oe-module` skill for scaffolding.

## Module API access

Retrieve another module's data only through `Yii::app()->moduleAPI->get('[Module]')`, guarding for
the module's absence. Never import another module's models directly.

```php
if ($api = Yii::app()->moduleAPI->get('OphCiExamination')) {
    $iop = $api->getMostRecentIop($patient);
}
```

- `<Module>_API` extends `BaseAPI`; `CoreAPI` for core data.
- Exception: raw SQL for reports/view definitions - even then encapsulate the view in the module that owns the source data where feasible.
- Required going forward; refactor non-compliant code when you're in the area.

## API shape

- A module API returns an **abstract data structure** assembled from its model(s), **not** model instances - so consumers are shielded from how the module stores things.

  ```php
  return [
      'iop_right' => $latest->hasRight() ? $latest->right_iop : null,
      'iop_left'  => $latest->hasLeft()  ? $latest->left_iop  : null,
  ];
  ```

- Correspondence shortcode "letter string" methods use the fixed signature:

  ```php
  public function getLetter[StringDescription](\Patient $patient, bool $use_context = false)
  ```

- Split a large module API into **traits** per data concept (Visual Acuity, Refraction, ...) rather than one monolith (Examination is the cautionary tale). A trait may span several elements.
- Rendering an element isn't only via the API - `BaseEventElementWidget`-based widgets can encapsulate an element for display:

  ```php
  $this->widget(SystemicSurgeryWidget::class, [
      'patient' => $this->patient,
      'mode'    => BaseEventElementWidget::$PATIENT_SUMMARY_MODE,
  ]);
  ```

## Self-contained

Everything a module needs lives in its own directory.
- A `README` covering its key functional elements, integration hooks, and dependencies.
- PHPUnit tests in a `test/` dir split into `unit/` and `feature/`, namespaced under the module.
- Encapsulate functionality in module code rather than the application core - even "core" functionality (e.g. Diagnosis 2.0). Refactor logic spread through the codebase back into its module when the opportunity arises.

## ADRs

Record an Architecture Design Record whenever a specific decision is made about how a solution should
be implemented or structured.
- Stored in `docs/adr/`.
- Use the adr-tools CLI (github.com/npryce/adr-tools), bundled in the standard OpenEyes image, to init new ADRs and deprecate old ones.

---
Sources: Module API (1604419607), Modules (2232745985), Architecture Design Records (2226454529).
