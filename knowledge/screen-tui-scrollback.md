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
raw_output_mode = true
```

These native settings make transcript output suitable for Screen history and
selection. They are scoped to Codex; the shared Page Up binding supplies the same
Screen history access for the other managed agent alias.

Do not use the wheel for Screen history. If wheel input has already populated an
otherwise empty prompt, Ctrl-u clears that unsent prompt line.

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

1. Start either managed agent alias in a fresh VS Code terminal.
2. Produce more than one page of output.
3. Press Page Up and confirm Screen reports copy mode.
4. Press Page Up again and confirm the viewport moves without changing the prompt.
5. Press Escape and confirm normal input resumes.

Sources:

- https://www.gnu.org/software/screen/manual/html_node/Scrollback.html
- https://www.gnu.org/software/screen/manual/html_node/Copy.html
- https://developers.openai.com/codex/config-reference
