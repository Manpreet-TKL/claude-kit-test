# Naming

## Class names

New module elements are plain `UpperCamelCase` classes - namespacing prevents collisions, so the
legacy module-name prefixes are redundant.

```php
class BirthHistory extends BaseElement {}        // yes
class Element_OphCiExamination_BirthHistory {}   // legacy, pre-namespace
```

- Legacy convention was `Element_OphCiExamination_[type]` for root elements and
  `OphCiExamination_[type]_[purpose]` for children - only keep these on existing unmodified classes.

## Table names

DB tables **cannot** be namespaced, so they keep the legacy prefix conventions even though class
names dropped them:

```
et_ophciexamination_birthhistory        -- base element type table:  et_[module]_[element]
ophciexamination_birthhistory_entry      -- child element table:      [module]_[element]_[purpose]
```

## Name quality

Choose clear, full names; refactor toward better ones as they occur to you.
- Avoid context-related abbreviations - `$appointment_count`, not `$apptCnt`; `$event`, not `$ev`.
- Don't repeat the containing class name in its own properties/methods.
- Clinical abbreviations are fine as labels (it's a clinical record); loop counters (`$i`) are fine.
- "Start long and expressive, then shorten only if a clearly better name appears."

---
Source: Naming Conventions (1570242697).
