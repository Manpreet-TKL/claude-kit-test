# Frontend

OE has a themed UI driven entirely by CSS. Presentation comes from layout classes; behaviour from
`js-` classes. Keep them decoupled. See the `c-oe-ui` skill for the page chassis and palettes.

## No inline styling

Never inline-style elements — it breaks the theme. All styling comes from the themed CSS (the `nxblu`
submodule under `protected/assets`).

```html
<div class="oe-event-content">...</div>   <!-- not style="..." -->
```

If a needed style is missing, get it added to IDG / newblue via the Design Authority rather than inlining.

## IDG DOM

Build HTML to match the DOM structure defined on IDG (idg.knowego.com) — don't copy old code structures.
- HTML must be efficient and semantically correct.
- **Never** use a class containing `-idg-` (IDG-internal prototyping classes only).
- Don't reuse icons or design elements outside their original context without Design Authority sign-off — design-language consistency is core to how clinicians work.

## Encapsulated JS

Write new JavaScript as encapsulated modules; avoid jQuery and global state (the legacy pattern), and
avoid adding to per-page request bloat. Prefix DOM classes that drive JS behaviour with `js-`, and
never key behaviour off layout (newblue) classes — so CSS refactors don't break JS.

```html
<button class="js-collapse-data-header expand">Header</button>
```

## Standard UI widgets

- `OpenEyes.UI.AdderDialog` is the standard UI for interacting with elements in forms; `OpenEyes.UI.ElementController` / `ElementController.MultiRow` abstract common element-form behaviour for reuse (examples: Convergence, Accommodation, Sensory Function; complex: Contrast Sensitivity, Nine Positions).
- `OpenEyes.UI.CollapseData` panels toggle display **classes**, never inline styles — header toggles `expand`/`collapse`, content toggles `hidden`/display-class from `data-show-content-display-class`:

  ```html
  <div class="js-collapse-data">
    <div class="js-collapse-data-header expand">Header</div>
    <div class="js-collapse-data-content hidden" data-show-content-display-class="block">Content</div>
  </div>
  ```

---
Source: Frontend development (1585184877).
