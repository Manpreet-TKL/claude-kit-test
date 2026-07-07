# Modern frontend build - Vue 3 + Vite

OpenEyes is migrating islands of UI to Vue 3 mounted into the legacy Yii pages.
This is additive - most of the app is still server-rendered PHP + the
`OpenEyes.UI.*` JS toolkit (`subs/js-toolkit.md`). Reach here only when touching a
Vue island or its asset wiring.

## Where it lives

- **Build root:** repo root `package.json` + `vite.config.js` (Vue 3.5, Vite 7).
- **Entry:** `protected/assets/js/vue/main.js` - a single Vue app that scans the
  page for mount points and hydrates them.
- **Components:** `.vue` SFCs live in **module** `assets/` dirs, not the root -
  e.g. `modules/OphCiExamination/.../Diagnoses/`, `modules/Referral/.../assets/`.
  (Vue adoption is module-by-module, so grep the specific module's `assets/`.)
- **Build output:** `protected/assets/vue/dist/` + `protected/assets/vue/.vite/manifest.json`.
- **Build scripts:** `npm run build` (root) / the `dev` watch task; CI builds
  `dist/` - it is a build artifact, not hand-edited.

## How a built bundle reaches the page (the cache-bust seam)

Vite emits content-hashed filenames and records the mapping in `manifest.json`.
The page resolves the hashed URL via **`AssetManager::urlForManifestFile()`**
(`getManifest()` reads `.vite/manifest.json`). So the modern bundle is
cache-busted by the **Vite content hash**, NOT by the legacy `?v=<filemtime>`
query string. Two regimes coexist - don't apply `?v=` reasoning to Vue assets, and
don't expect a manifest entry for legacy module assets. (Legacy regime ->
SKILL.md "Module assets".)

## Tailwind is NOT here

Tailwind v4 (config-less) exists **only in `oe-laravel/`** (its own
`package.json`/Vite). The root Vue build and every Yii page use the nxblu / core
CSS system (SKILL.md). Do not add Tailwind classes to Yii views or root Vue SFCs.
