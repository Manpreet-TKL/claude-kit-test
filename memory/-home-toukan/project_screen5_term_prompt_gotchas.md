---
name: screen5-term-prompt-gotchas
description: "GNU screen 5 gotchas - defbce changes TERM to -bce breaking colour prompts, emoji VS16 gets mangled, detached tests show TERM=unknown"
metadata: 
  node_type: memory
  type: project
  originSessionId: 94beccc2-8787-4967-8238-2ce6947be6d5
---

Found 2026-07-12 while debugging "white prompt + _ _ line" inside the source-built screen 5.0.1 (installed by ~/screen_install.sh):

1. `defbce on` makes screen advertise `TERM=screen-256color-bce`. The stock Ubuntu ~/.bashrc colour case only matches `xterm-color|*-256color`, so the prompt (and colour detection generally) goes white. Fix: never add defbce; screen_install.sh no longer does.
2. GNU screen cannot pass emoji + VS16 (U+FE0F) through: it emits the emoji then `BS + ESC(0 _ ESC(B`, painting a DEC-graphics underscore over the glyph - the user's PS1 eye `${STY:+ ...}` markers rendered as `_ _`. Bare U+1F441 passes cleanly but renders monochrome (text presentation). Final fix 2026-07-12: glyph-conditional on STY - a single eye (U+1F441+VS16, colour) outside screen where VS16 is safe, the one-glyph eyes pair U+1F440 inside screen (default emoji presentation, passes screen byte-clean; U+1F9FF nazar also passes). In ~/.bashrc and the oe-deploy PR drop-in as OE_EYES. Keep the escapes explicit ($'\U0001F441\uFE0F') - literal VS16 in source is invisible and Edit-tool old/new strings look identical. ~/snail/.bashrc still carries the interim VS16-strip edit.
3. Test-methodology trap: `screen -dm` without a controlling pty gives windows `TERM=unknown` - a red herring. Attach through `script -qec "screen ..." out.raw` for realistic captures; screen also re-encodes SGR, so grep for patterns like `\x1b\[[0-9;]*m`, not exact bytes.
4. Claude Code inside screen renders fine; screen silently drops sync-output mode 2026 (claude issue #19533, closed not-planned) but nothing user-visible came of it. Claude picks truecolor from the leaked COLORTERM, ignoring terminfo.

Related: [[oe-deploy-conventions]] (env repos deploy the .bashrc template; host-setup.sh overwrites the alias/screenrc blocks).
