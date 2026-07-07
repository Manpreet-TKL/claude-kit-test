---
name: voiceControl must be independent of aiSearch
description: Voice control module work is standalone; never depend on, install alongside, or wire into aiSearch.
type: feedback
originSessionId: 3edf3f74-8cd5-4d68-9e64-24d0878d1895
---
The voiceControl OE module (under `/home/toukan/voiceControl/`) must be a **completely independent** OE Yii module. No runtime dependency on aiSearch, no installing aiSearch alongside, no driving aiSearch's search box from voiceControl as an "integration".

**Why:** User stated explicitly when I proposed "Phase B: hook voice into aiSearch's search textarea" — they want voice control to stand on its own, with its own UI surface (e.g. site-wide injection into OE's main layout, or its own page), so it's not coupled to one feature's lifecycle.

**How to apply:**
- Follow the generic OE module conventions in `/home/toukan/aiSearch/MODULE.md` **Part 1** as a reference for Yii 1.1 / OE patterns — that section is explicitly generic and reusable. Don't read or import from aiSearch's actual source (controllers/services/views).
- Phase B for voiceControl is NOT "dictate into aiSearch's textarea" — it's a floating mic widget injected into OE's main layout, command grammar that maps speech to DOM actions site-wide.
- If a future voice feature *would* legitimately need to drive aiSearch, build it as a generic "dictate into focused textarea" action, not an aiSearch-specific endpoint.
