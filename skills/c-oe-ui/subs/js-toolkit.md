# The `OpenEyes.UI.*` JS toolkit

The legacy (and still dominant) interaction layer is a hand-rolled jQuery-era
namespace, `OpenEyes.UI.*`, plus a `js-` behaviour-hook convention. Vue islands
(`subs/vue-vite.md`) are the exception, not the rule. Source lives in
`protected/assets/js/src/` (and `protected/assets/js/openeyes/`); published via the
asset pipeline (SKILL.md "Module assets").

## The `js-` hook convention

Class names prefixed `js-` are **JavaScript behaviour hooks, never style hooks**:
`js-add-select-search`, `js-comment-field`, `js-nav-hotlist-btn`,
`js-element-eye`, ... JS binds to them; CSS must not. When adding interactive
behaviour, attach a `js-` class rather than styling an existing one.

## Core widgets (most-used)

- **`OpenEyes.UI.AdderDialog`** - the ubiquitous "+ Add" picker (multi-select
  popup that writes chips/rows back into an element). Family: `AdderDialog.ItemSet`,
  `AdderDialog.Item`, plus search/quick-add variants. This is the single most
  common clinical-form interaction.
- **`OpenEyes.UI.ElementController`** (+ `.MultiRow`) - wires a clinical element's
  fields to AdderDialogs and display masks via `data-adder-*` / `data-ec-*`
  attributes. The backbone of `form_...`/`_event_edit` views - see
  `subs/clinical-element-views.md`.
- **`OpenEyes.UI.CollapseData`** - expand/collapse for long event/element sections.
- **`OpenEyes.UI.NavBtnPopup`** / **HotList** - the right-hand patient hotlist
  panel and nav-button popups (SKILL.md "Hotlist").
- **`OpenEyes.UI.Dialog`** (`.Alert`, `.Confirm`, ...) - modal dialogs (jQuery UI
  under the hood).
- **`OpenEyes.UI.Tooltip`**, **`OpenEyes.UI.PatientElementController`**,
  **`OpenEyes.UI.EpisodeSidebar`**, **`OpenEyes.UI.Search`** - supporting pieces.

Pattern: instantiate in an inline `<script>` at the end of a view, handing it a
container selector - `new OpenEyes.UI.ElementController({ container: $('#..._form') })`.

## EyeDraw (the eye-diagram editor)

EyeDraw is **not** an `OpenEyes.UI.*` call - it is a Yii PHP widget
(`application.modules.eyedraw.OEEyeDrawWidget`) with a JS runtime at
`protected/assets/js/eyedraw/EyeDrawManager.js` (+ `oe-eyedraw.js`). It draws to
`<canvas>` and serialises a JSON doodle string into a hidden input on the element.
The `eyedraw` module is external (absent from a base core checkout). Rendering
detail -> `subs/clinical-element-views.md`.

## TinyMCE

Rich-text editors load via Yii `registerCoreScript('tinymce')` and init through
`tinymce.init(...)`; saved HTML renders inside `.user-tinymce-content`. Main users:
`OphCoCorrespondence` letter bodies, HTML-typed settings.
