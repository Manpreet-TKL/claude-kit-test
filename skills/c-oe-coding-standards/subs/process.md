# Pull requests & merge

The merge gate for code coming into OpenEyes. See the `create-oe-pr` skill for raising the PR itself.

## PR clarity

Every PR must clearly explain the **purpose** of its changes, using the provided GitHub templates -
separate templates exist for **features** and **bug fixes**; use the right one and fill in purpose,
changes, and testing.

## Standards and tests

- All new code must follow the project's defined coding style and standards (passes phpcs + phpstan and conforms to the Developer Checklist).
- All new code ships **automated tests** as part of the implementation. If the right coverage level is unclear, open the PR as a draft tagged for testing review.

## UI and compatibility

- UI components must adhere to **IDG** designs and guidelines.
- **Version compatibility is the contributor's responsibility:** when changing an older OpenEyes version, ensure the change also works with newer versions (it must forward-merge / port cleanly).

---
Source: Code Merge Rules (2248015882).
