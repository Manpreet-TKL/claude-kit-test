# Clinical element-view rendering

This is the 95% of OpenEyes UI clinicians actually use - the inside of a clinical
event, not the page chrome. An event view is a stack of **element** views; each
element renders in one of two render paths. The domain/model side (base classes,
`element_type` registration, `et_` naming) is `c-oe-code`
`subs/event-element-model.md`; this sub is the **rendering/wiring** side.

## Two render paths per element

A clinical module renders each element through one of:

1. **Legacy view triad** - plain PHP templates in
   `modules/<Module>/views/default/`:
   `form_<ElementClass>.php` / `view_<ElementClass>.php` / `print_<ElementClass>.php`
   (PREFIX, not `_form.php`). OphCiExamination ships 86 `form_`, 69 `view_`, 8
   `print_`. Resolved by `BaseEventTypeElement::getForm_View()` /
   `getView_view()` / `getPrint_view()` (print falls back to view, so `print_`
   files are sparse).
2. **Widget triad** - `modules/<Module>/widgets/views/<Name>_event_edit.php` /
   `_event_view.php` / `_event_print.php`, backed by a widget class in
   `modules/<Module>/widgets/` extending `BaseEventElementWidget`. The widget picks
   the view via `getViewNameForPrefix('event_edit'|'event_view'|...)`. OphCiExamination
   ships 72 `_event_edit`. `BaseFieldWidget` and `TiledEventElementWidget` are
   related widget bases.

Both are wrapped by the container views `//patient/element_container_{form,view,print}.php`.

> Pitfall: the suffix `_form.php` / `_view.php` files (leading underscore) are Gii
> CRUD **admin** scaffolding under `...Admin/views/...`, NOT element views.

## The event controller

`BaseEventTypeController` drives create/view/print and per-element rendering
(`renderElement` / `renderOpenElements`, plus `actionElementForm` for AJAX
element-add). On create it instantiates `EventType::getDefaultElements()`; on view
it walks `Event::getElements()`. So "why is this field not showing on the form"
usually traces to the `element_type` row (`default`/`display_order`) or the
element's `isEnabled()`, not the view.

## Element form anatomy (edit view)

A typical `form_...`/`_event_edit.php` body:

```php
<div class="element-fields flex-layout full-width" id="<model>_form">
    <?= $form->dropDownList($element, 'field', $options, [
        'nowrapper' => true, 'data-adder-header' => 'Pick...',
    ]) ?>
    <button class="button hint green js-add-select-search" data-adder-trigger="true">Add</button>
</div>
<script>new OpenEyes.UI.ElementController({ container: $('#<model>_form') });</script>
```

- Fields are emitted by core form widgets (`$form->dropDownList(... 'nowrapper'=>true)`)
  and **driven by `data-adder-*` / `data-ec-*` attributes**, not bespoke JS.
- `OpenEyes.UI.ElementController` masks each real `<select>/<input>` into a
  display div and auto-builds an `AdderDialog` from the fields, writing selections
  back on return. `data-adder-trigger="true"` marks the open button;
  `data-adder-header`, `data-adder-requires-item-set/-values` (dependent columns),
  `data-ec-keep-field`, `data-ec-format-*` tune it. Multi-row variant:
  `OpenEyes.UI.ElementController.MultiRow`.
- Behaviour hooks use the `js-` prefix (`js-add-select-search`, `js-comment-field`,
  ...) - never style off them. Widget/JS catalogue -> `subs/js-toolkit.md`.

## EyeDraw elements

EyeDraw is rendered as a Yii **PHP widget**, not a JS toolkit call:
`$this->widget('application.modules.eyedraw.OEEyeDrawWidget', ['mode'=>...,
'side'=>..., 'model'=>$element, 'attribute'=>..., 'listenerArray'=>...])`. Front-end
runtime is `protected/assets/js/eyedraw/EyeDrawManager.js`. The `eyedraw` module
itself is external (not in a base core checkout).

## Rich text

TinyMCE is a Yii core script (`registerCoreScript('tinymce')`); editors init via
`tinymce.init(...)` and rendered HTML lands in `.user-tinymce-content`. Used by
letter bodies (`OphCoCorrespondence`) and HTML settings.
