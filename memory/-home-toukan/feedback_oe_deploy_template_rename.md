---
name: oe-deploy is a template - rename, don't copy
description: When bringing up an oe-deploy instance, rename (mv) the oe-deploy folder to the environment name; do not cp. The repo is designed as a template.
type: feedback
originSessionId: 596431f6-e7a0-484f-a3d6-6dd01fd7636a
---
When you need a non-`oe-deploy`-named working directory to satisfy `environment-setup.sh`, **rename** (`mv oe-deploy <envname>`), do **not** copy (`cp -a`).

**Why:** The `oe-deploy` repo is explicitly designed as a template - there is no value in keeping a pristine "source" copy alongside the live deployment. Manpreet flagged a `cp` attempt as wrong; the workflow expects one in-place rename per host.

**How to apply:** When the next step is "I need a directory named `<env>` instead of `oe-deploy`," run `mv oe-deploy <env>` and proceed from inside it. Update any docs (`CLAUDE.md`, `AI_SETUP.md`) to say "rename" rather than "clone into a new directory."
