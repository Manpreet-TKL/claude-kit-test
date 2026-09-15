# Standalone Codex

The kit installs Codex when it is missing, then configures it. Codex itself runs on the host inside its bubblewrap sandbox; MCP services and the browser walker remain containerized.

## Install

Run:

```bash
bash /home/toukan/claude-kit/scripts/codex_bwrap_install.sh
bash /home/toukan/claude-kit/scripts/screen5_install.sh
bash /home/toukan/claude-kit/codex-install.sh -q
```

The first command installs Ubuntu's normal `/usr/bin/bwrap`. On Ubuntu 24.04 it also installs the distribution's restrictive `bwrap-userns-restrict` AppArmor profile if the kernel user-namespace restriction requires it. It never disables AppArmor, changes the global restriction, or makes bubblewrap setuid. Bubblewrap creates the Linux namespaces and bind mounts used to confine host Codex. Without a usable binary, Codex prints `Codex could not find bubblewrap on PATH.` or fails while creating the sandbox.

The screen installer preserves the existing alias and adds:

```bash
alias codex='/usr/local/bin/screen bash /home/toukan/claude-kit/codex.sh'
```

GNU screen 5 reconnects to an existing session after SSH or terminal loss. Run `source ~/.bash_aliases` once in an existing shell. New shells load it automatically.

## Installer flags

`codex-install.sh` accepts the same feature flags as `install.sh`: `-q`, `-p`, `-m`, `-t`, `-s`, `-d`, `-r`, `-F`, `-n`, `-U`, `-y`, `-j`, `-c`, `-J`, `-g`, `-G`, `-x`, `-X`, `-a`, `-A`, `-w`, and `-l <target>`. Run `bash /home/toukan/claude-kit/codex-install.sh -h` for exact values. The `-x` and `-X` flags are accepted no-ops because this entry point already is the standalone Codex setup.

Normal verification validates the shared skill schema and asks Codex itself to
discover the installed skill set. `-n|--no-verify` skips those checks along
with the other post-install verification.

Set the maximum number of concurrent native subagents with `-t <positive integer>`. The installer saves it as `CODEX_AGENT_THREADS` and writes it to the generated Codex profile. For example:

```bash
bash /home/toukan/claude-kit/codex-install.sh -t 50 -U -y
```

Start a new Codex session after changing it. To restore Codex's built-in default, set `CODEX_AGENT_THREADS=` in `generated/.codex.env` and rerun the installer.

The `codex-swarm` skill uses Codex's native multi-agent tools when they are
available. It does not require Claude Code, a Codex MCP registration, or the
`generated/mcp-on/codex` startup gate. The MCP route remains a fallback for
Claude Code sessions. `codex-grill` uses the same native/MCP split. The
`codexmcp` skill is Claude-only and is not linked into standalone Codex.

The main thread defaults to `gpt-6-astra` at `xhigh`. The installer links the
read-only `planner` from `settings/codex/agents/planner.toml`; every non-trivial
plan uses Astra at `max`, then returns to the main thread. Direct Plan mode
defaults to `max` in the profile.

If Codex is missing, the installer uses OpenAI's standalone installer. A normal re-run updates Codex. If an existing global npm installation is root-owned, the installer uses `sudo npm install -g @openai/codex`; otherwise it uses `codex update`. Pass `-U` to leave an existing version unchanged; it does not suppress a required first install.

## Models and controls

Fresh launches through `codex.sh` start with Astra at `xhigh` and medium verbosity.
The launcher resets only model and effort in `~/.codex/claude-kit.config.toml`.
It leaves unrelated keys alone and uses an atomic replacement plus a lock to
serialize simultaneous kit launches. The installer sets `model_verbosity = "medium"`;
the writing instructions ask for simple English and brief explanations of technical terms.

| Control | Effect |
|---|---|
| `/model` | Choose model and effort for the current session, including Sol or Terra. |
| Alt+, or Shift+Down | Decrease reasoning effort. |
| Alt+. or Shift+Up | Increase reasoning effort. |
| Alt+P | Deferred: Codex 0.154.0 has no bindable model-picker action. Use `/model`. |
| `/keymap` | Inspect the bindings available in the installed CLI. |

For example, `bash /home/toukan/claude-kit/codex.sh --model gpt-5.6-sol` explicitly
selects Sol. Explicit model/effort CLI arguments override defaults and can therefore
produce the native override warning if changed through `/model` later. Environment
values `CODEX_MODEL` and `CODEX_REASONING_EFFORT` can also select launch defaults;
they take precedence over `generated/.codex.env` without adding CLI overrides.

The warning "Saved default model and reasoning effort, but a higher-priority
configuration layer overrides the saved value." came from the kit's unconditional
CLI model/effort flags. Those flags are removed. A normal kit launch now lets
`/model` save successfully; the next fresh launch restores the kit defaults.
`resume`, `fork` and `/new` within an existing CLI follow native behavior. Other
Codex launch methods and machine-managed configuration are outside this change.

## Feature mapping

| Kit feature | Codex mechanism | Compatibility |
|---|---|---|
| Global instructions | `~/.codex/AGENTS.md` links to `claude-md/CLAUDE.md`. | Complete |
| Skills | Each skill carrying `agents/openai.yaml` links into both `~/.agents/skills` and `~/.codex/skills`; the latter also serves the MCP container. | Both roots are synchronized because current Codex releases scan both. Install verification checks schema, policy synchronization, stale client-specific tool names, exact availability, and real `skills/list` discovery. `$skill-name` always loads explicitly. |
| Four permission tiers | Exported TOML profiles in `settings/codex/permissions/` plus Starlark command rules in `settings/codex/rules/`; `yolo` selects Codex's `:danger-full-access` built-in directly. | Close translation; Codex evaluates permissions and command prefixes differently, so refine these source files as needed. |
| Session modes | Launcher maps the existing mode names onto Codex approval policy, reviewer, read-only permissions, or the explicit bypass flag. | Complete within Codex's available controls. |
| Status line | Native `[tui].status_line` configuration in `~/.codex/claude-kit.config.toml`. | Complete; it uses the requested field list and colors. |
| Shift-enter and terminal input | Native Codex TUI. In VS Code, the launcher sets `CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1` only for the child Codex process. | Complete workaround; Ctrl+J remains the newline fallback. See OpenAI issue #16189. |
| Screen resilience | Managed aliases start each CLI inside GNU screen 5 and remain available without nesting from shells already inside screen. | Complete and idempotent |
| Auto-compaction | `model_auto_compact_token_limit` in the Codex profile. | Native equivalent |
| Native subagents | `CODEX_AGENT_THREADS` becomes `[agents].max_concurrent_threads_per_session` in the generated profile. | Configurable with `-t`; applies to new sessions. |
| Planning model | `~/.codex/agents/claude-kit-planner.toml` links to the kit-managed custom agent. | Non-trivial plans use `gpt-6-astra` at `max`; the main thread defaults to `gpt-6-astra` at `xhigh`. |
| Session pruning | `-d` locates old rollout files and calls `codex archive`. | Complete |
| Reset and fresh install | `-r` archives regenerable data; `-F` backs up and restores auth, history, sessions, and memory state. | Complete |
| Memory | Native Codex memories are enabled. Raw memory remains in `~/.codex/memories/` and `~/.codex/memories_*.sqlite*`. | Preserved by reset/fresh; deliberately never copied into the git repository. |
| Jira and Confluence | Read-only container MCP registered with `codex mcp add`. Secrets stay in `~/.claude/mcp-env/`. | Complete after machine-local credentials exist; natively disabled until armed for a new session. |
| GitHub | Read-only container MCP registered with `codex mcp add`. | Complete after machine-local credentials exist; natively disabled until armed for a new session. |
| AWS | Shared official AWS CLI container, reached only through `scripts/agent-aws-cli.sh run`. `-a` starts it and pre-arms one session. | Complete after machine-local credentials exist; the first session to read consumes the gate and new sessions are gated again. |
| Browser walker | Separate `codex-chrome` sidecar with Chrome DevTools MCP and Playwright MCP. | `oe-probe-codex-chrome` is Codex-only; the Claude-in-Chrome skill is pruned. Build and live walk require Docker, the target network, and image downloads. |
| Logout | `-l codex|github|atlassian|aws|all` removes the selected local credential. AWS also stops its container, clears its gates, and removes any legacy MCP registration. | Complete |

## Permissions

The exported files are versioned and contain no secrets:

```text
settings/codex/permissions/ultra-safe.toml
settings/codex/permissions/standard.toml
settings/codex/permissions/trusted.toml
settings/codex/permissions/yolo.toml
settings/codex/rules/ultra-safe.rules
settings/codex/rules/standard.rules
settings/codex/rules/trusted.rules
settings/codex/rules/yolo.rules
```

The installer generates `~/.codex/claude-kit.config.toml` from its native base settings and the permission TOML fragments, then links `~/.codex/rules/claude-kit.rules` to the selected rule file. The global instructions, skills, custom planner, and selected static rules are symlinked back to the kit. Before a fresh launch, the launcher writes model/effort defaults into the kit profile under a lock and replaces the file atomically. It preserves other keys and maps mode and permission tier at session start. It also maps the kit's `yolo` tier directly to Codex's `:danger-full-access` built-in because custom profiles cannot extend that built-in, so `codex.sh` remains required. The hard floor forbids `git push`, `git commit`, and direct AWS CLI calls. The `yolo` tier permits Docker access; narrower tiers deny the Docker socket.

The AWS session gate governs compliant wrapper use rather than isolating AWS
from a yolo session: direct Docker can bypass the wrapper. The read-only IAM
principal is the hard boundary.

## MCP startup gates

Registered MCP servers are stored with `enabled = false`, so a normal Codex startup skips them without producing failed-handshake warnings. Arm one with `touch /home/toukan/claude-kit/generated/mcp-on/<server>`, then start a new Codex session. The launcher enables it for that session only. The first wrapper spawn consumes the flag and opens a 60-second startup grace window for repeated connection attempts.

Codex cannot enable a natively disabled MCP inside an existing TUI session. Exit the current session before arming it, or arm it from another shell and then restart Codex. The supported server names are `atlassian`, `github`, `chrome-devtools`, and `playwright`. AWS is not an MCP and its wrapper gate takes effect immediately. The `enabled` setting is documented in the [official MCP configuration reference](https://learn.chatgpt.com/docs/extend/mcp?surface=cli#other-configuration-options).

## Docker access and host files

Host Codex can read `/home/toukan` according to the selected permission profile. It can interact with host containers only when Docker is available and the selected profile permits `/var/run/docker.sock`. The kit's MCP wrappers are the preferred route because they expose a narrow service rather than general Docker control.

If Codex itself is run inside a container, it sees only explicitly mounted host paths and it cannot manage host containers unless `/var/run/docker.sock` is mounted. Mounting that socket is effectively host-root authority. The supported standalone path therefore keeps Codex on the host under bubblewrap and containerizes only service dependencies.

## Browser walker

Run `bash /home/toukan/claude-kit/codex-install.sh -w`. The setup saves the non-secret target network and URL in `generated/.codex-chrome-agent.env`, keeps the Chrome profile outside the repository at `~/.claude/codex-chrome-agent`, starts the sidecar, and registers the natively disabled `chrome-devtools` and `playwright` MCP servers. View it at `http://localhost:6081`.

## VS Code verification

Start a fresh integrated terminal and run `codex`. Confirm Caps Lock, Shift capitalization, held-key repeat, and Shift+Enter. If Shift+Enter is unavailable, use Ctrl+J. The workaround is scoped to Codex and does not alter another CLI's environment or alias. Reference: https://github.com/openai/codex/issues/16189

## Checks

```bash
bash /home/toukan/claude-kit/scripts/validate-skills.sh -c
codex --strict-config --profile claude-kit --version
codex execpolicy check --rules ~/.codex/rules/claude-kit.rules -- git push origin main
readlink -f ~/.codex/AGENTS.md
readlink -f ~/.codex/agents/claude-kit-planner.toml
readlink -f ~/.agents/skills/c-claude-kit
codex sandbox -- /usr/bin/true
```
