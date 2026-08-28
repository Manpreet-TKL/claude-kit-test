# Standalone Codex

The kit configures an existing host Codex. Codex itself runs on the host inside its bubblewrap sandbox; MCP services and the browser walker remain containerized.

## Install

Install Codex separately, then run:

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

`codex-install.sh` accepts the same feature flags as `install.sh`: `-q`, `-p`, `-m`, `-s`, `-d`, `-r`, `-F`, `-n`, `-U`, `-y`, `-j`, `-c`, `-J`, `-g`, `-G`, `-x`, `-X`, `-a`, `-A`, `-w`, and `-l <target>`. Run `bash /home/toukan/claude-kit/codex-install.sh -h` for exact values. The `-x` and `-X` flags are accepted no-ops because this entry point already is the standalone Codex setup.

The normal run updates Codex. If the global npm installation is root-owned, the installer uses `sudo npm install -g @openai/codex`; otherwise it uses `codex update`. Pass `-U` to leave the installed version unchanged.

## Feature mapping

| Kit feature | Codex mechanism | Compatibility |
|---|---|---|
| Global instructions | `~/.codex/AGENTS.md` links to `claude-md/CLAUDE.md`. | Complete |
| Skills | Each skill carrying `agents/openai.yaml` links into `~/.agents/skills`; the file also supplies Codex UI metadata. | Complete; Codex availability is explicit, links are created in name order, implicit loading follows each skill's `disable-model-invocation` setting, and `$skill-name` always loads explicitly. |
| Four permission tiers | Exported TOML profiles in `settings/codex/permissions/` plus Starlark command rules in `settings/codex/rules/`; `yolo` selects Codex's `:danger-full-access` built-in directly. | Close translation; Codex evaluates permissions and command prefixes differently, so refine these source files as needed. |
| Session modes | Launcher maps the existing mode names onto Codex approval policy, reviewer, read-only permissions, or the explicit bypass flag. | Complete within Codex's available controls. |
| Status line | Native `[tui].status_line` configuration in `~/.codex/claude-kit.config.toml`. | Complete; it uses the requested field list and colors. |
| Shift-enter and terminal input | Native Codex TUI. In VS Code, the launcher sets `CODEX_TUI_DISABLE_KEYBOARD_ENHANCEMENT=1` only for the child Codex process. | Complete workaround; Ctrl+J remains the newline fallback. See OpenAI issue #16189. |
| Screen resilience | Managed `codex` alias starts `codex.sh` inside GNU screen 5. | Complete |
| Auto-compaction | `model_auto_compact_token_limit` in the Codex profile. | Native equivalent |
| Session pruning | `-d` locates old rollout files and calls `codex archive`. | Complete |
| Reset and fresh install | `-r` archives regenerable data; `-F` backs up and restores auth, history, sessions, and memory state. | Complete |
| Memory | Native Codex memories are enabled. Raw memory remains in `~/.codex/memories/` and `~/.codex/memories_*.sqlite*`. | Preserved by reset/fresh; deliberately never copied into the git repository. |
| Jira and Confluence | Read-only container MCP registered with `codex mcp add`. Secrets stay in `~/.claude/mcp-env/`. | Complete after machine-local credentials exist. |
| GitHub | Read-only container MCP registered with `codex mcp add`. | Complete after machine-local credentials exist. |
| AWS | Read-only container MCP registered with `codex mcp add`. Direct `aws` commands are forbidden by Codex rules. | Complete after machine-local credentials exist. |
| Browser walker | Separate `codex-chrome` sidecar with Chrome DevTools MCP and Playwright MCP. | Complete setup path; build and live walk require Docker, the target network, and image downloads. |
| Logout | `-l codex|github|atlassian|aws|all` removes the selected local credential and MCP registration. | Complete |

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

The installer combines the permission TOML files into `~/.codex/claude-kit.config.toml` and copies the selected rule file to `~/.codex/rules/claude-kit.rules`. The launcher maps the kit's `yolo` tier directly to Codex's `:danger-full-access` built-in because custom profiles cannot extend that built-in. The hard floor forbids `git push`, `git commit`, and direct AWS CLI calls. The `yolo` tier permits Docker access; narrower tiers deny the Docker socket.

## Docker access and host files

Host Codex can read `/home/toukan` according to the selected permission profile. It can interact with host containers only when Docker is available and the selected profile permits `/var/run/docker.sock`. The kit's MCP wrappers are the preferred route because they expose a narrow service rather than general Docker control.

If Codex itself is run inside a container, it sees only explicitly mounted host paths and it cannot manage host containers unless `/var/run/docker.sock` is mounted. Mounting that socket is effectively host-root authority. The supported standalone path therefore keeps Codex on the host under bubblewrap and containerizes only service dependencies.

## Browser walker

Run `bash /home/toukan/claude-kit/codex-install.sh -w`. The setup saves the non-secret target network and URL in `generated/.codex-chrome-agent.env`, keeps the Chrome profile outside the repository at `~/.claude/codex-chrome-agent`, starts the sidecar, and registers `chrome-devtools` and `playwright` MCP servers. View it at `http://localhost:6081`.

## VS Code verification

Start a fresh integrated terminal and run `codex`. Confirm Caps Lock, Shift capitalization, held-key repeat, and Shift+Enter. If Shift+Enter is unavailable, use Ctrl+J. The workaround is scoped to Codex and does not alter another CLI's environment or alias. Reference: https://github.com/openai/codex/issues/16189

## Checks

```bash
codex --strict-config --profile claude-kit --version
codex execpolicy check --rules ~/.codex/rules/claude-kit.rules -- git push origin main
readlink -f ~/.codex/AGENTS.md
readlink -f ~/.agents/skills/c-claude-kit
codex sandbox -- /usr/bin/true
```
