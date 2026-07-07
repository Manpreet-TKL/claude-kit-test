# The event/element domain model

OpenEyes is event-based: every clinical interaction is an **Event** on an
**Episode** on a **Patient**, and an Event is a bag of **Element** rows. This is
the spine you land on for most clinical bugs.

## The spine

`Patient -> Episode -> Event -> EventType -> ElementType -> Element`. The first three
plus EventType/Element are `BaseActiveRecordVersioned` (audited + soft-deleted).

- `Patient` (`patient`) `HAS_MANY Episode`. `protected/models/Patient.php`.
- `Episode` (`episode`) `BELONGS_TO Patient`, `HAS_MANY Event` ordered by
  `event_date`. `protected/models/Episode.php`.
- `Event` (`event`) `BELONGS_TO Episode` and `BELONGS_TO EventType`. It has **no
  element columns of its own** - it discovers its elements at runtime by walking
  `eventType->getAllElementTypes()`, loading each `ElementType.class_name`, and
  `findAll('event_id = ?')`. `Event::getElements()`, `protected/models/Event.php`.
- Soft-delete: a `deleted` flag enforced by `defaultScope` (`deleted = 0`);
  `Event::softDelete()` cascades to each element's `softDelete()`. Never hard-delete
  clinical data - see `c-oe-coding-standards`.

## EventType / ElementType (the registry)

- `EventType` (`event_type`) - one row ~ one module. `class_name` = the module
  folder name (e.g. `OphCiExamination`). `HAS_MANY ElementType`; self
  `parent`/`children` for inherited element types. `getApi()` resolves the module
  API via `class_name`.
- `ElementType` (`element_type`) - one row ~ one element model class. Holds
  `class_name`, `event_type_id`, `display_order`, `default`, `required`,
  `element_group_id`. `getInstance()` = `new $this->class_name()`. (A dummy `id=0`
  row is always filtered out - a MariaDB NULL-unique workaround.)
- **Where `element_type` rows come from:** migrations/seeders, **not** module
  config. A module's `config/common.php` advertises params/menus/components only;
  the `element_type` binding (`class_name` + `display_order` + `default`) is
  `insert()`-ed by a migration. New event vs existing: a controller building a new
  event calls `EventType::getDefaultElements()` (rows where `default=1`, ordered by
  `display_order`); an existing event calls `Event::getElements()`.
  `BaseEventTypeController`.

## Element base-class chain

`CActiveRecord -> BaseActiveRecord -> BaseActiveRecordVersioned -> BaseElement ->
BaseEventTypeElement`.

- `BaseElement` - copy-forward lifecycle (`loadFromExisting`/`copyFromExisting`),
  `applyData`, `canHaveMultipleOf`.
- `BaseEventTypeElement` - the clinical element base: carries
  `event`/`eventType`/`elementType`, eye-sided validators (`requiredIfSide`),
  audit batching, front-end error mapping, and **all the view-name resolvers**
  (below). `protected/models/BaseEventTypeElement.php`.
- Elements extend `BaseEventTypeElement` **directly or via a module-local base** -
  e.g. OphTrOperationnote elements extend `Element_OpNote` (or
  `Element_OnDemand`/`Element_OnDemandEye`), which extends `BaseEventTypeElement`.

## The view triad - `form_`/`view_`/`print_` PREFIX

Resolved by `BaseEventTypeElement`: `getForm_View()` -> `form_<DefaultView>`,
`getView_view()` -> `view_<DefaultView>`, `getPrint_view()` falls back to the view
template; `<DefaultView>` = the class short name. Files live in
`modules/<Module>/views/default/`, e.g.
`form_Element_OphTrOperationnote_Cataract.php`. Because print defaults to view,
`print_` files are sparse. The element body is wrapped by container views
`//patient/element_container_{form,view,print}`.

> Pitfall: the **prefix** form (`form_...php`) is the clinical-element triad. The
> suffix form (`_form.php`, leading underscore) is unrelated Gii CRUD admin
> scaffolding (under a module's `...Admin/views/`). A newer **widget** triad also
> exists - `widgets/views/<Name>_event_{edit,view,print}.php` backed by a
> `BaseEventElementWidget`. UI mechanics for both -> `c-oe-ui`
> `subs/clinical-element-views.md`.

## `et_<module>_<element>` table naming (model level)

Every element model's `tableName()` returns `et_` (event-type element) +
lowercased module name + `_` + element name:
`Element_OphCiExamination_VisualAcuity` -> `et_ophciexamination_visualacuity`,
`Element_OphTrOperationnote_Cataract` -> `et_ophtroperationnote_cataract`. Column /
versioned-table (`*_version`) detail -> `c-oe-db-schema`.

## Module API bridge

`Event::getApi()` = `Yii::app()->moduleAPI->get($this->eventType->class_name)` ->
`<Module>_API extends BaseAPI`. This is the sanctioned cross-module door; never
read another module's element models directly. See SKILL.md "Modules".

## Worked exemplars

- **OphCiExamination** - 69 element models, most extending `\BaseEventTypeElement`
  directly: `Element_OphCiExamination_VisualAcuity` (`et_ophciexamination_visualacuity`,
  views `form_/view_/print_...VisualAcuity.php`), `..._History`, `..._Diagnoses`. Element
  catalogue -> `subs/examination-elements.md`.
- **OphTrOperationnote** - module-local base `Element_OpNote extends
  BaseEventTypeElement`; `..._Anaesthetic extends Element_OpNote`
  (`et_ophtroperationnote_anaesthetic`), `..._Cataract extends Element_OnDemandEye`.
