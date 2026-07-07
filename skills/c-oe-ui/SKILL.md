---
name: c-oe-ui
description: Building or styling OpenEyes frontend pages
---

# OpenEyes frontend / UI patterns

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

How OE pages are put together (Yii side). Facts verified against core CSS and the
special-module sweep of June 2026. For the end-to-end special-module landing-page
recipe, see `create-oe-module` -> `subs/special-module-ui.md`.

This SKILL covers the **page chrome** (grid, ribbon, theming, asset publishing).
For the inside of a clinical event - the part clinicians spend their day in - see
`subs/clinical-element-views.md`. Modern Vue islands -> `subs/vue-vite.md`; the
legacy `OpenEyes.UI.*` interaction layer -> `subs/js-toolkit.md`.

Caveat on the CSS: `protected/assets/nxblu/` is a **git submodule**
(`git@github.com:openeyes/nxblu`) and is **uninitialised in a bare checkout** - the
compiled `dist/css` below only exists on a built/deployed instance (or after
`git submodule update --init`). The exact values here were read off a deployed
instance; if `nxblu/dist` is empty, grep a running container instead.

## Where the core CSS lives

`protected/assets/nxblu/dist/css/style_openeyes.css` - minified, effectively one
line, so grep with `-o`:

```bash
grep -o '\.flex-layout[^{]*{[^}]*}' protected/assets/nxblu/dist/css/style_openeyes.css
```

Theming is CSS variables (`--bg-title`, `--txt-light`, `--bg-main`, ...) keyed off a
`theme-<dark|light>` class on `<html>`. The flow is two-stage: `main.php` emits the
server-side preference as `data-theme` on the root element (from
`SettingMetadata::model()->getSetting('display_theme')`), then client JS reads it
and adds the actual `theme-<light|dark>` class the CSS selectors target. So write
CSS against `.theme-dark ...` / `.theme-light ...`, not `[data-theme]`.

## Page anatomy (the oe-grid chassis)

`body.open-eyes.oe-grid` is a CSS grid with named areas; children slot in via
`grid-area`. Canonical order (see `protected/views/layouts/main.php`):

```
#oe-minimum-width-warning
//base/_debug            (YII_DEBUG only)
//base/_brand            -> banner/logo (grid-area: header)
#oe-restrict-print
//base/_header           -> top nav; renders _form.php -> menu + hotlist;
                           renders the patient panel only when
                           $this->renderPatientPanel === true
<ribbon>                 -> .oe-full-header (grid-area: pageheader)
<content>                -> .oe-full-content or a custom grid-area:main div
//base/_footer
```

The `<ribbon>` and `<content>` slots are **not** partials that `main.php` renders;
they are the action's own view output, injected where `main.php` does `echo
$content`. `main.php` owns the chrome (brand/header/footer/hotlist); your view owns
the `.oe-full-header` + `.oe-full-content` markup.

A module layout that wants OE styling must be a full document and render
`//base/head/_meta` + `//base/head/_assets` in `<head>` - without them the page
renders unstyled in quirks mode.

## The ribbon (`.oe-full-header`)

- `grid-area: pageheader`, dark background `var(--bg-title)`, natively
  `justify-content: flex-start`.
- Title: `.title.wordcaps` - 1.375rem, uppercase, light weight, `var(--txt-light)`.
  Convention: `<div class="title wordcaps"><b>Page Title</b></div>`.
- Buttons inside the ribbon are auto-sized: `height:38px; padding:0 16px`.
- Anything else placed on the ribbon (breadcrumbs, meta text) must be styled
  light-on-dark: 13px, `#c8d6e5`, links the same with hover `#fff` + underline.

## Flex utilities - the space-between gotcha

- `.flex-layout` = `display:flex; justify-content:space-between; align-items:center`.
  With three children it **centers the middle one** - this is how nav tabs end up
  unintentionally centered in a ribbon.
- `.flex-layout.flex-left` = `justify-content:flex-start`.
- Left-aligned tabs next to a title: wrap both in a `flex-layout flex-left` cluster
  inside the space-between ribbon; give the tab group `gap:6px; margin-left:32px`.
- Gap helpers exist (`.gap-10`, ...).

## Content containers

- `.oe-full-content` - `grid-area: main; height: calc(100vh - 98px)`.
- `main.oe-full-main` - `overflow-y:auto; padding: 20px 20px 40px`.
- `.oe-full-content.subgrid` - core two-column grid (300px sidebar): `aside` +
  `main.oe-full-main`. Override the column width in module CSS if needed.
- Custom alternative: your own div with
  `display:grid; grid-template-columns:220px 1fr; grid-area:main; height:100%;
  overflow:hidden` (OeDataDictionary's `.oe-dd-layout`).

## Width cap and `use-full-screen`

At viewport >=1890px core caps
`.oe-grid :is(.oe-full-header, .oe-full-content, .oe-full-split, .oe-allow-for-fixing-hotlist):not(.use-full-screen)`
to `width:1440px` (69vw at >=2100px); the pinned hotlist occupies
`calc(100vw - 1440px)` beside it. Consequences:

- If the hotlist is hidden, capped pages leave a dead gutter on wide screens - add
  `use-full-screen` to both the ribbon and the content wrapper to span fully.
- Custom `grid-area: main` divs are not in the capped selector list and are already
  full width; their `.oe-full-header` still needs `use-full-screen` (or
  `width:100%!important; grid-column:1/-1!important` in module CSS - the
  OeDataDictionary variant).

## The patient search / hotlist panel

Render chain: `_header.php` -> `_form.php` -> `_menu_option_hotlist.php`
(`li.js-hotlist-panel-wrapper`, `data-fixable="<?= $this->fixedHotlist ?>"`) ->
`//base/_hotlist` (`.oe-hotlist-panel`, contains the patient search form).
`BaseController::$fixedHotlist = true` by default, and
`OpenEyes.UI.NavBtnPopup.js` auto-pins the panel open on windows wider than its
`autoHideWidthPixels`. To remove it from a tool page, hide both nodes in module CSS:

```css
.oe-hotlist-panel,
.js-hotlist-panel-wrapper { display: none !important; }
```

Controller flags (`$renderPatientPanel = false`, `$fixedHotlist = false`) are
optional belt-and-braces; the CSS does the hiding.

## Common components (core classes, don't reinvent)

- Buttons: `.button`, active tab `.button.selected`, variants `hint blue|green|orange`,
  `small`, `white hint`. As nav tabs: `<a class="button ...">`.
- Tables: `<table class="standard cols-full">` with `<colgroup><col class="cols-3">...`.
- Alerts: `.alert-box success|error|info|warning with-icon`.
- Icons: `<span class="oe-i tick small pad-right"></span>` (eye-icon sprite set).
- Collapsible groups: `.js-collapse-data .collapse-data show-bg` with
  `.js-collapse-data-header` / `.js-collapse-data-content` (wired by core JS).
- Flash messages: `$this->renderPartial('//base/_messages')` at the top of content.
- Grid helpers: `.cols-12`, `.row.divider`.

## Module assets: publishing and the 1-year cache

Two publish idioms:

```php
// layout: publish dir, emit <link>
$am = Yii::app()->assetManager;
$assetsUrl = $am->publish(
    Yii::getPathOfAlias('application.modules.<Name>') . '/assets',
    false, -1, !$am->linkAssets   // forceCopy only when not symlinking
);

// view/controller: publish + clientScript
$baseUrl = Yii::app()->assetManager->publish(
    Yii::app()->getModule('<Name>')->getBasePath() . '/assets'
);
Yii::app()->clientScript->registerCssFile($baseUrl . '/<file>.css?v=' . filemtime(...));
```

- `linkAssets` is on when `YII_DEBUG` - published dirs under `/assets/<hash>` are
  symlinks, so source edits are live. In production they are copies.
- nginx serves `/assets/...` with `Cache-Control: max-age=31536000`. **Always**
  append `?v=<?= filemtime($sourceFile) ?>` to CSS/JS URLs, or browsers hold stale
  styles for a year (no revalidation). This applies to both idioms above.
- Config changes (not assets) are cached in APCu - `curl http://localhost/apc_clear.php`.

**Two cache-bust regimes coexist.** Everything above is the **legacy** regime
(`assetManager->publish` + `?v=<filemtime>`), which is correct for legacy module
CSS/JS. **Modern Vue bundles** are different: Vite emits content-hashed filenames
and the page resolves them via `AssetManager::urlForManifestFile()` (reading
`assets/vue/.vite/manifest.json`) - **no `?v=`**, the hash is the bust. Don't add
`?v=` to a Vue asset or expect a manifest entry for a legacy one. See
`subs/vue-vite.md`.

## Module dual-theme pattern (verified July 2026, OeDocumentation)

How a module's own CSS supports light + dark without touching core:

- **Bootstrap the theme exactly like core `main.php`** in the module layout -
  never bake the class in server-side:

  ```php
  <html lang="en" data-theme="<?= \SettingMetadata::model()->getSetting('display_theme'); ?>">
  ...
  <?php $this->renderPartial('//base/head/_assets'); ?>
  <script>
      window.OE_DISPLAY_THEME = document.documentElement.dataset.theme;
      OpenEyes.UI.SetHtmlTagDefaults();
  </script>
  ```

  `OpenEyes.UI.SetHtmlTagDefaults.js` (registered by `_assets`; Yii emits it above
  the inline call) maps `data-theme` -> a `theme-light|dark` class and resolves
  `'auto'` via `prefers-color-scheme` with a live media-query listener. A
  server-side `class="theme-<setting>"` yields `theme-auto` for auto users
  (= stuck on light) and ignores the header's theme-switch buttons, which swap
  the `theme-*` class client-side.
- **Scoped custom properties**: define a module palette (`--oedoc-surface`,
  `--oedoc-ink`, ...) at `:root` with **light values as the defaults**, then ONE
  `html.theme-dark { ... }` block overriding the same variables. Selectors key off
  `.theme-dark` only - never `[data-theme]`, never a `.theme-light` block.
- **Don't override fills that carry white text** (solid accent/success buttons,
  tags): they read fine on both themes; darkening them costs contrast.
- **Deliberately-dark chrome stays literal**: a navy tool sidebar, dark code
  blocks, lightbox overlays are dark by design in both themes - keep their hex
  values out of the variable system so the dark block stays small.
- **Native form fields need explicit colours** in the variable system
  (`background: var(--...-surface-card); color: var(--...-ink)`) or they stay
  white-on-white in dark.
- **Theme resolution order in the DB**: `setting_user` (per-user) beats
  `setting_installation` beats `setting_metadata.default_value` (ships as
  `'auto'`, usually no installation row). To test as a user, flip **their
  `setting_user` row** - inserting an installation row does nothing for a user
  who has one. `setting_metadata` has no `value` column; only the other two do.

## House palettes

- Ribbon breadcrumb/meta: 13px, text `#c8d6e5`, links `#c8d6e5` -> hover `#fff`
  underline, separators `#7a96b0`, current item `#fff`.
- Dark tool sidebar (OeDataDictionary standard): bg `#1e2a38`, text `#c8d6e5`,
  uppercase letter-spaced headings `#7a96b0`, borders `#2d3e52`, hover `#fff` on
  `#263447`.

## Exemplars to crib from

These four are **special/admin modules** (deployment add-ons, not part of a base
`protected/modules` core checkout) - grep them on a deployed instance, and treat
them as landing-page patterns rather than clinical-event UI.

- `OeDataDictionary` - custom-grid layout, dark sidebar, ribbon breadcrumb.
- `OeConfig` - module layout, left-aligned option tabs, inline-style hotlist hide.
- `NodAudit` - layoutless approach: shared `_nav.php` ribbon partial + per-view
  `oe-full-content` chassis, view-registered assets.
- `OeDatabase` - many-tab ribbon (`flex-wrap`), controller-registered assets.

## Subs

- `subs/clinical-element-views.md` - the inside of a clinical event: the
  `form_`/`view_`/`print_` + widget `_event_edit` render triads, `ElementController`
  + `AdderDialog` wiring, EyeDraw, TinyMCE.
- `subs/vue-vite.md` - Vue 3 + Vite islands, the manifest cache-bust seam, and why
  Tailwind is `oe-laravel`-only.
- `subs/js-toolkit.md` - the `OpenEyes.UI.*` widget catalogue and the `js-`
  behaviour-hook convention.
