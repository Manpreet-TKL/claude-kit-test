# Models (Yii)

Models must be usable outside the HTTP context they were written in - keep them self-contained and
let them own their validation and persistence behaviour.

## No globals

Never reference `$_GET`, `$_POST`, `$_SESSION` or other global arrays inside a model, and don't add
methods that depend on a controller being available. Set context-specific data on the instance from
the calling layer.

```php
// controller, not the model:
$model->event_id = Yii::app()->request->getParam('event_id');
```

- Sole exception: legacy rich-text "letter string" element methods rendering an HTML template - and even then use `$this->getApp()->controller`, not `Yii::app()->controller`.

## Validation in rules

Put all validation in `rules()` so it runs regardless of data source. Validate lookup/foreign values
with `exist` so invalid values can't be recorded, resolving the class with `::class`.

```php
public function rules()
{
    return [
        ['event_id, lookup_id, comments', 'safe'],
        ['lookup_id', 'exist', 'allowEmpty' => true,
            'attributeName' => 'id', 'className' => Lookup::class,
            'message' => '{attribute} is invalid'],
    ];
}
```

## Safe attributes

Mark every data attribute `safe` - full mass assignment of data attributes is expected.

## Reuse validators

Use core `OE*Validator` rules (`protected/components/`, `protected/validators/`) rather than
re-implementing. A one-off check can be an inline `validate*` method, but once a rule would be
duplicated across **>3 models**, promote it to a core `OE*Validator` **with test coverage**.
Catalogue: `subs/validators.md`.

## Audit-user relations

Track the creating/modifying user on every standard model:

```php
'user'        => [self::BELONGS_TO, \User::class, 'created_user_id'],
'usermodified'=> [self::BELONGS_TO, \User::class, 'last_modified_user_id'],
```

## Relations

Define `HAS_MANY` for one-to-many relationships, then let `BaseActiveRecord` auto-handle them:

```php
protected $auto_validate_relations = true;  // news-up + validate children with the parent
protected $auto_save_relations     = true;  // persist new / delete stale children (HAS_MANY, MANY_MANY, through)
```

Validate `through` behaviour carefully to avoid duplication.

## Pass models

Pass model instances to functions, not their ids (`notify($patient)`, not `notify($patient->id)`);
use eager loading to keep query counts down. Instantiate non-`Yii` manager/component classes via the
factory pattern, not `new`.

## Base classes

`BaseActiveRecord` (plain) -> `BaseActiveRecordVersioned` (history via `<table>_version`) ->
`BaseActiveRecordVersionedSoftDelete` (**default for clinical entities**). Element bases:
`BaseEventTypeElement`, `BaseMedicationElement`, `BaseEsignElement` + `BaseSignature` (signature/PIN).
Also `BaseEventTemplate`, `BaseReport`, `BaseSetting`, `BaseTree`.

---
Source: Model Guidelines (1605074949).
