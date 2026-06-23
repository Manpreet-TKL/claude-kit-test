---
name: c-oe-ui
description: Building or styling OpenEyes frontend pages
---

# OpenEyes frontend / UI patterns

When loaded as context with no task, reply only `Context loaded.`

How OE pages are put together (Yii side). Facts verified against core CSS and the
special-module sweep of June 2026. For the end-to-end special-module landing-page
recipe, see `create-oe-module` → `subs/special-module-ui.md`.

## Where the core CSS lives

`protected/assets/nxblu/dist/css/style_openeyes.css` — minified, effectively one
line, so grep with `-o`:

```bash
grep -o '\.flex-layout[^{]*{[^}]*}' protected/assets/nxblu/dist/css/style_openeyes.css
```

Theming is CSS variables (`--bg-title`, `--txt-light`, `--bg-main`, …) switched by
the `theme-<dark|light>` class on `<html>`, fed from
`SettingMetadata::model()->getSetting('display_theme')`. Some layouts use
`data-theme` instead; the class form is the common one.

## Page anatomy (the oe-grid chassis)

`body.open-eyes.oe-grid` is a CSS grid with named areas; children slot in via
`grid-area`. Canonical order (see `protected/views/layouts/main.php`):

```
#oe-minimum-width-warning
//base/_debug            (YII_DEBUG only)
//base/_brand            → banner/logo (grid-area: header)
#oe-restrict-print
//base/_header           → top nav; renders _form.php → menu + hotlist;
                           renders the patient panel only when
                           $this->renderPatientPanel === true
<ribbon>                 → .oe-full-header (grid-area: pageheader)
<content>                → .oe-full-content or a custom grid-area:main div
//base/_footer
```

A module layout that wants OE styling must be a full document and render
`//base/head/_meta` + `//base/head/_assets` in `<head>` — without them the page
renders unstyled in quirks mode.

## The ribbon (`.oe-full-header`)

- `grid-area: pageheader`, dark background `var(--bg-title)`, natively
  `justify-content: flex-start`.
- Title: `.title.wordcaps` — 1.375rem, uppercase, light weight, `var(--txt-light)`.
  Convention: `<div class="title wordcaps"><b>Page Title</b></div>`.
- Buttons inside the ribbon are auto-sized: `height:38px; padding:0 16px`.
- Anything else placed on the ribbon (breadcrumbs, meta text) must be styled
  light-on-dark: 13px, `#c8d6e5`, links the same with hover `#fff` + underline.

## Flex utilities — the space-between gotcha

- `.flex-layout` = `display:flex; justify-content:space-between; align-items:center`.
  With three children it **centers the middle one** — this is how nav tabs end up
  unintentionally centered in a ribbon.
- `.flex-layout.flex-left` = `justify-content:flex-start`.
- Left-aligned tabs next to a title: wrap both in a `flex-layout flex-left` cluster
  inside the space-between ribbon; give the tab group `gap:6px; margin-left:32px`.
- Gap helpers exist (`.gap-10`, …).

## Content containers

- `.oe-full-content` — `grid-area: main; height: calc(100vh - 98px)`.
- `main.oe-full-main` — `overflow-y:auto; padding: 20px 20px 40px`.
- `.oe-full-content.subgrid` — core two-column grid (300px sidebar): `aside` +
  `main.oe-full-main`. Override the column width in module CSS if needed.
- Custom alternative: your own div with
  `display:grid; grid-template-columns:220px 1fr; grid-area:main; height:100%;
  overflow:hidden` (OeDataDictionary's `.oe-dd-layout`).

## Width cap and `use-full-screen`

At viewport ≥1890px core caps
`.oe-grid :is(.oe-full-header, .oe-full-content, .oe-full-split, .oe-allow-for-fixing-hotlist):not(.use-full-screen)`
to `width:1440px` (69vw at ≥2100px); the pinned hotlist occupies
`calc(100vw - 1440px)` beside it. Consequences:

- If the hotlist is hidden, capped pages leave a dead gutter on wide screens — add
  `use-full-screen` to both the ribbon and the content wrapper to span fully.
- Custom `grid-area: main` divs are not in the capped selector list and are already
  full width; their `.oe-full-header` still needs `use-full-screen` (or
  `width:100%!important; grid-column:1/-1!important` in module CSS — the
  OeDataDictionary variant).

## The patient search / hotlist panel

Render chain: `_header.php` → `_form.php` → `_menu_option_hotlist.php`
(`li.js-hotlist-panel-wrapper`, `data-fixable="<?= $this->fixedHotlist ?>"`) →
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
  `small`, `white hint`. As nav tabs: `<a class="button …">`.
- Tables: `<table class="standard cols-full">` with `<colgroup><col class="cols-3">…`.
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

- `linkAssets` is on when `YII_DEBUG` — published dirs under `/assets/<hash>` are
  symlinks, so source edits are live. In production they are copies.
- nginx serves `/assets/...` with `Cache-Control: max-age=31536000`. **Always**
  append `?v=<?= filemtime($sourceFile) ?>` to CSS/JS URLs, or browsers hold stale
  styles for a year (no revalidation). This applies to both idioms above.
- Config changes (not assets) are cached in APCu — `curl http://localhost/apc_clear.php`.

## House palettes

- Ribbon breadcrumb/meta: 13px, text `#c8d6e5`, links `#c8d6e5` → hover `#fff`
  underline, separators `#7a96b0`, current item `#fff`.
- Dark tool sidebar (OeDataDictionary standard): bg `#1e2a38`, text `#c8d6e5`,
  uppercase letter-spaced headings `#7a96b0`, borders `#2d3e52`, hover `#fff` on
  `#263447`.

## Exemplars to crib from

- `OeDataDictionary` — custom-grid layout, dark sidebar, ribbon breadcrumb.
- `OeConfig` — module layout, left-aligned option tabs, inline-style hotlist hide.
- `NodAudit` — layoutless approach: shared `_nav.php` ribbon partial + per-view
  `oe-full-content` chassis, view-registered assets.
- `OeDatabase` — many-tab ribbon (`flex-wrap`), controller-registered assets.
