# Special-module landing-page UI - the consistent pattern

The signed-off UI recipe for `oe_special_module` (admin/infrastructure) modules.
Reference implementations: **OeDataDictionary** (gold standard, custom-grid layout),
**OeConfig** (module layout with left-aligned option tabs), **NodAudit** (no layout -
ribbon partial + per-view chassis). For the underlying core CSS mechanics see the
`c-oe-ui` skill.

Rules: the OE banner (`//base/_brand`) and top nav (`//base/_header`) are never
touched; the patient search ("hotlist") panel is hidden; the module spans the full
page width; the ribbon follows one canonical shape.

## 1. Page skeleton

Either give the module its own layout (set `public $layout =
'application.modules.<Name>.views.layouts.<name>'` on the controller), or use
`public $layout = '//layouts/main'` and emit the ribbon + chassis at the top of each
view (NodAudit renders a shared `_nav.php` partial from every view).

A module layout must be the full document:

```php
<!DOCTYPE html>
<html lang="en" class="theme-<?= CHtml::encode(\SettingMetadata::model()->getSetting('display_theme')) ?>">
<head>
    <?php $this->renderPartial('//base/head/_meta'); ?>
    <?php $this->renderPartial('//base/head/_assets'); ?>
    <link rel="stylesheet" href="<?= $assetsUrl ?>/css/<name>.css?v=<?= filemtime(Yii::getPathOfAlias('application.modules.<Name>') . '/assets/css/<name>.css') ?>">
</head>
<body class="open-eyes oe-grid">
    <div id="oe-minimum-width-warning">Device width not supported</div>
    <?php $this->renderPartial('//base/_brand'); ?>   <!-- banner: leave alone -->
    <?php $this->renderPartial('//base/_header'); ?>  <!-- top nav: leave alone -->
    <!-- ribbon (section 2) -->
    <!-- content (section 3) -->
    <?php $this->renderPartial('//base/_footer'); ?>
</body>
</html>
```

## 2. Canonical ribbon

```html
<div class="oe-full-header flex-layout use-full-screen">
    <div class="flex-layout flex-left">
        <div class="title wordcaps"><b>Module Title</b></div>
        <!-- optional left-aligned option tabs -->
        <div class="flex-layout" style="gap:6px; margin-left:32px;">
            <a class="button selected" href="...">Tab A</a>
            <a class="button" href="...">Tab B</a>
        </div>
    </div>
    <!-- optional right-side breadcrumb / meta -->
    <nav class="<name>-breadcrumb">
        <a href="...">Home</a> › <span>Current</span>
    </nav>
</div>
```

- Title is always `.title.wordcaps > <b>Title</b>` - never a raw `<h1>` with custom
  font sizing.
- `.flex-layout` alone is `justify-content: space-between` - with three children it
  **centers** the middle one. That is the bug the left cluster
  (`.flex-layout.flex-left`, core class, `justify-content: flex-start`) exists to
  avoid: title + tabs go inside it, tabs stay left-aligned next to the title.
- Right-side breadcrumb/meta sits on the dark ribbon (`--bg-title`), so style it
  light: `font-size:13px; color:#c8d6e5;` links the same, hover `#fff` + underline.
  Never default link blue / grey - unreadable on the ribbon.
- Many tabs: add `flex-wrap:wrap; row-gap:4px` to the tab div (OeDatabase).

## 3. Full-width content

Core caps `.oe-full-header` / `.oe-full-content` at 1440px on screens >=1890px to
leave room for the pinned hotlist. Since the hotlist is hidden (section 4), opt out with
core's own `use-full-screen` class on **both** the ribbon and the content wrapper:

```html
<div class="oe-full-content use-full-screen oe-<name>">
    <main class="oe-full-main">
        <?php $this->renderPartial('//base/_messages') ?>
        ...
    </main>
</div>
```

Sidebar variants: `oe-full-content subgrid use-full-screen` (core 300px sidebar
grid, override columns in module CSS), or a fully custom div with
`display:grid; grid-template-columns: 220px 1fr; grid-area: main;`
(OeDataDictionary's `.oe-dd-layout`) - custom grid-area divs escape the width cap
without `use-full-screen`, but their `.oe-full-header` then needs either
`use-full-screen` or the DD override
(`width:100%!important; grid-column:1/-1!important`).

## 4. Hide the patient search (hotlist) panel

CSS-only, in the module stylesheet - do not touch controllers or `_header.php`:

```css
/* Hide the patient hotlist panel - not relevant here */
.oe-hotlist-panel,
.js-hotlist-panel-wrapper {
    display: none !important;
}
```

Modules without an `assets/` dir can put this in an inline `<style>` in their
layout `<head>` (AiSearch, VoiceControl). Optionally also set
`public $renderPatientPanel = false; public bool $fixedHotlist = false;` on the
controller (OeConfig), but the CSS is what actually hides it.

## 5. Module CSS registration - always cache-bust

nginx serves published `/assets/...` with `Cache-Control: max-age=31536000` (1
year). An unversioned CSS URL means browsers keep stale styles for a year. Always
append `?v=filemtime(<source file>)`:

```php
// view/controller idiom
$baseUrl = \Yii::app()->assetManager->publish(
    \Yii::app()->getModule('<Name>')->getBasePath() . '/assets'
);
\Yii::app()->clientScript->registerCssFile(
    $baseUrl . '/<name>.css?v=' . filemtime(\Yii::app()->getModule('<Name>')->getBasePath() . '/assets/<name>.css')
);
```

(Layout `<link>` idiom in section 1.) In debug, `linkAssets` symlinks the published dir so
file edits are live; in production they are copies - the `?v=` matters in both.

## 6. Sidebar palette (when the module has one)

Match OeDataDictionary's dark sidebar: background `#1e2a38`, text `#c8d6e5`,
section headings `#7a96b0` (uppercase, letter-spaced), borders `#2d3e52`,
hover `#fff` (bg `#263447`).

## Checklist

1. Ribbon: `oe-full-header flex-layout use-full-screen` > left cluster
   (`flex-layout flex-left`) > `title wordcaps > b`; tabs left-aligned in the
   cluster; breadcrumb/meta right, light-on-dark.
2. Content: `oe-full-content use-full-screen` > `main.oe-full-main` (or custom
   `grid-area: main` div).
3. Hotlist hidden via the two-selector CSS rule.
4. Module CSS linked with `?v=filemtime`.
5. Banner, top nav, footer partials untouched.
6. Verify logged-in with curl: page 200, contains `oe-full-header` and the
   versioned CSS URL, no PHP errors.
