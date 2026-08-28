# GNU Screen scrollback with full-screen agent CLIs (2026-08)

## Symptom

Inside a managed GNU Screen 5 session, the VS Code terminal wheel does not move
through earlier agent output. It can instead put previous prompt text or a copied
payload into the active prompt.

## Findings

The affected session reported `(196,43)+1000000`, so its one-million-line Screen
history was present. Capacity was not the problem.

Screen owns the history while its alternate buffer is active. In that state, VS
Code can translate wheel movement into Up and Down input. The child TUI sees those
keys as prompt-history navigation. The terminal viewport therefore stays at the
bottom while old input appears in the prompt.

Keep `altscreen on` and keep `termcapinfo xterm* ti@:te@` disabled. Re-enabling
that termcap override exposes outer-terminal scrollback, but full-screen redraws
then smear into it.

Increasing VS Code's `terminal.integrated.scrollback` does not increase the
history available inside Screen. That setting controls only the outer VS Code
terminal buffer; Screen keeps its own per-window history and presents a
cursor-addressed display to the outer terminal.

Screen's `mousetrack` setting is not a wheel-scrollback solution. It watches
mouse clicks so a split display region can be selected. Screen history still has
to be entered through copy mode.

There is no reliable Screen setting that combines native VS Code wheel
scrolling, clean full-screen TUI redraws, and Screen detach/reattach resilience.
The alternate-buffer termcap override trades clean redraws for outer scrollback;
it does not make the two history buffers cooperate.

## Managed fix

The shared Screen configuration contains:

```screen
bindkey -k kP copy
```

Page Up now enters Screen copy mode before the key reaches either managed agent
CLI. Press Page Up again to move back one page, Page Down to move forward, and
Escape to return to the prompt. The standard fallback is Ctrl-a followed by `[`.

The Codex profile also contains:

```toml
[tui]
alternate_screen = "never"
raw_output_mode = false
terminal_title = []
```

`alternate_screen = "never"` leaves completed output in Screen history.
`raw_output_mode = false` uses Codex's default rich renderer. This is terminal
Markdown styling, not a browser preview: headings and code are styled and code
fences are hidden, but heading and list markers can remain visible.
`terminal_title = []` disables the animated title writes that GNU Screen can
mishandle while Codex is working.

Ctrl-t opens Codex's transcript view for easier in-app reading. Page Up remains
the full Screen-history fallback. These settings are scoped to Codex; the shared
Page Up binding supplies Screen history access for the other managed agent alias.

Do not use the wheel for Screen history. If wheel input has already populated an
otherwise empty prompt, Ctrl-u clears that unsent prompt line.

## Native VS Code scrolling alternative

Run Codex directly in the VS Code terminal, outside Screen, when native wheel
scrolling is more important than Screen session resilience. In that layout,
increase `terminal.integrated.scrollback` if more outer-terminal history is
needed.

VS Code persistent terminal sessions are useful but are not equivalent to a
detached Screen session. Process reconnection preserves a terminal across a
window reload. Process revival after a full VS Code restart restores terminal
contents and relaunches the process, rather than preserving the exact live
process. A direct launcher can therefore complement the managed Screen launcher,
but should not replace it when a long-running session must survive disconnects.

## Codex prompt corruption while working

A Codex-only failure can put transient text such as `toukan toukan` into the
prompt while a turn is running. It stops when the display stops changing.
Screen hardcopies do not show extra prompt input, so it is display corruption,
not agent output or stored composer text.

The first suspected cause was Codex's terminal keyboard-enhancement protocol.
The launcher now exports the compatibility setting before selecting the session
mode:

```bash
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    export CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1
fi
```

Two fresh processes inherited this setting and still reproduced the corruption.
It remains a useful VS Code keyboard compatibility guard, but it is not the fix
for the working-only redraw problem.

OpenAI Codex issue 29598 reports the matching GNU Screen behavior. While a turn
is active, Codex's default terminal title contains an animated spinner and the
project name. Each frame emits a BEL-terminated terminal-title sequence. GNU
Screen can expose those updates as repeated beeps, visual activity, or disruptive
title updates. The project component also explains why the repeated visible word
can be the home directory name.

Disable the title surface in the Codex profile:

```toml
[tui]
terminal_title = []
```

The official sample configuration defines an empty list as the way to clear the
title. This removes the activity-driven title writes without disabling normal
TUI status output.

An already-running Codex keeps its startup TUI settings. Do not send keys to it
or restart it during another task. Let it finish, then start a fresh Codex with
the managed alias. To switch an existing session from raw output to rich output,
enter `/raw off` yourself; this does not apply the title fix.

To verify the VS Code keyboard guard on a new process, find its native Codex PID
and run:

```bash
tr '\0' '\n' </proc/<codex-pid>/environ | rg '^CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1$'
```

## Recovery and diagnosis

List sessions:

```bash
/usr/local/bin/screen -ls
```

Show the active window size and history capacity:

```bash
/usr/local/bin/screen -S <session> -p 0 -Q info
```

Recover the current display and complete Screen history without restarting the
child process:

```bash
/usr/local/bin/screen -S <session> -p 0 -X hardcopy -h /tmp/screen-session.hardcopy
```

Apply the Page Up binding to an already-running session:

```bash
/usr/local/bin/screen -S <session> -X bindkey -k kP copy
```

For future sessions, reapply the managed configuration with:

```bash
bash /home/toukan/claude-kit/scripts/screen5_install.sh
```

## Verification

1. Start the managed Codex alias in a fresh VS Code terminal.
2. Request headings, a list, and a code block; confirm they use rich terminal
   styling and that code fences are hidden.
3. Run a turn long enough to show the working state; confirm no project-name text
   appears in the prompt.
4. Press Ctrl-t and confirm the transcript view opens and scrolls.
5. Exit that view, press Page Up twice, and confirm Screen history moves without
   changing the prompt. Press Escape to leave copy mode.

Sources:

- https://www.gnu.org/software/screen/manual/html_node/Scrollback.html
- https://www.gnu.org/software/screen/manual/html_node/Copy.html
- https://www.gnu.org/software/screen/manual/html_node/Mousetrack.html
- https://code.visualstudio.com/docs/terminal/basics
- https://code.visualstudio.com/docs/terminal/advanced
- https://developers.openai.com/codex/config-reference
- https://github.com/openai/codex/issues/16189
- https://github.com/openai/codex/issues/29598
