# Standalone Codex usage

Use the kit directly from Codex without installing Codex, Node.js, or another
runtime on the host. Docker is the only host prerequisite.

## Install

Run the standalone installer from anywhere:

```bash
bash ~/claude-kit/codex-install.sh -q
```

Like `install.sh`, a run with no flags at all prints the help and exits with an
error - `-q` is the no-questions run that takes saved answers or defaults.
Without `-q` it prompts for the agent defaults below.

The installer:

- rebuilds the local `claude-kit-codex` image so the containerised Codex CLI is
  current (`-U` reuses an existing image; a missing one is always built);
- saves the non-secret agent defaults to `generated/.codex.env`;
- links `~/.codex/AGENTS.md` to `claude-md/CLAUDE.md`;
- links every kit skill into `~/.agents/skills`;
- regenerates each skill's `agents/openai.yaml`;
- preserves real skill directories and foreign symlinks;
- backs up a real `~/.codex/AGENTS.md` to `AGENTS.md.bak`;
- leaves `~/.codex/config.toml` unchanged;
- verifies the result and prints a summary (`-n` skips the checks).

### Flags

It mirrors `install.sh` flag for flag wherever the feature exists on both sides;
short flags bundle (`-qU`), and every one has a long form.

| Flag | Effect |
|---|---|
| `-q`, `--quick` | Non-interactive run on saved answers or defaults (implies `-y`). |
| `-y`, `--yes` | Take saved/default answers; skip the `--fresh` confirmation. |
| `-s on\|off`, `--skills-auto` | The same skill model-invocation switch, snapshot file and semantics as `install.sh -s` - both agents read the same `SKILL.md` frontmatter. |
| `-r`, `--reset` | Archive Codex's regenerable state (`cache`, `log`, `tmp`, `shell_snapshots`, the `*.sqlite` stores, ...) to `~/.claude-backups/<ts>-codex/`, then install. Auth, config, history and sessions stay put. |
| `-F`, `--fresh` | Nuke and pave: back up `auth.json`, `config.toml`, `history.jsonl` and `sessions/`, delete `~/.codex` and `~/.agents`, reinstall, restore those four. Supersedes `--reset`. |
| `-l`, `--logout` | Standalone: delete `~/.codex/auth.json` and exit, like `install.sh -l codex`. |
| `-U`, `--no-update` | Do not rebuild an image that already exists. |
| `-n`, `--no-verify` | Skip the verification checks. |
| `-h`, `--help` | Full help. |

Permission tiers, `settings.json`, the status line, shift-enter, autocompact env
vars, conversation pruning and project-memory adoption are Claude Code concepts
with no Codex counterpart and are deliberately not ported. Neither is MCP server
registration (`-j`/`-c`/`-g`/`-a`/`-x`): those go through the `claude` CLI into
`~/.claude.json`, whereas Codex declares MCP servers in `config.toml`
`[mcp_servers]` - a different mechanism, not a flag translation.

### Agent defaults

Prompted on an interactive run, read straight through with `-y`/`-q`, and saved
to `generated/.codex.env` - the same file `install.sh -x` uses, so the standalone
runner and the MCP agents cannot drift onto different models. Nothing here is
secret; Codex authenticates with your ChatGPT login under `~/.codex`.

| Key | Default | Notes |
|---|---|---|
| `CODEX_MODEL` | `gpt-5.6-sol` | Flagship model. |
| `CODEX_REASONING_EFFORT` | `xhigh` | `minimal`, `low`, `medium`, `high`, `xhigh`. |
| `CODEX_SANDBOX` | `workspace-write` | Host runs only - see below. |
| `CODEX_APPROVAL` | `on-request` | `untrusted`, `on-failure`, `on-request`, `never`. Standalone only; MCP agents are pinned to `never`. |

`codex.sh` applies these at launch as `-c` overrides. It pins the inner sandbox
to `danger-full-access` because codex's own bwrap sandbox cannot start inside
Docker: the container is the sandbox, writes are confined to the mounted
workspace, and the container carries no git credentials, so a push fails auth.

If authentication is missing, an interactive install starts device login. In a
non-interactive shell it prints this command instead:

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth
```

The credential cache stays under `~/.codex`, outside the kit.

## Run Codex

Start an interactive session in the current directory:

```bash
bash ~/claude-kit/codex.sh
```

Pass normal Codex arguments unchanged:

```bash
bash ~/claude-kit/codex.sh --version
bash ~/claude-kit/codex.sh exec "review the current changes"
```

The native footer shows model and reasoning, current directory, five-hour
limit, and weekly limit. That footer, the model, the reasoning effort, the
sandbox mode and the approval policy are all launch overrides; none of them edit
`~/.codex/config.toml`.

## Use kit instructions and skills

Global rules are live through `~/.codex/AGENTS.md`. Editing
`claude-md/CLAUDE.md` changes the instructions used by the next Codex session.

List skills with `/skills` or mention one explicitly with `$`:

```text
$c-oe-code explain where module configuration lives
$create-pr package the current change
```

Skill links point back into `~/claude-kit/skills`, so skill edits are live.
Re-run `bash ~/claude-kit/codex-install.sh -qU` after adding, removing, or
renaming skills so the manifest and generated metadata are refreshed.

## Compatibility

| Kit capability | Standalone Codex behavior |
|---|---|
| Global instructions | Shared through `~/.codex/AGENTS.md`. |
| Skills | All directories are discoverable from `~/.agents/skills`. |
| Permission JSON tiers | Not used. Codex has its own approvals and sandbox settings. |
| Status line script | Not used. The launcher selects equivalent native footer fields. |
| Existing settings merge | Not used. `~/.codex/config.toml` remains user-owned. |
| Existing memory and session state | Not shared. Codex keeps separate state under `~/.codex`. |
| Existing MCP registrations | Not inherited automatically. |
| Skills tied to another agent's slash commands or MCP tools | May require a Codex-specific adaptation. |

The hard rules in the shared instructions still apply, but they are model
instructions rather than permission-JSON enforcement.

## Run both agent setups

The existing setup and standalone Codex can run at the same time because their
state directories are separate. They can also read the same live kit sources.

Do not let two agents edit the same files concurrently. For parallel
implementation work, create separate Git worktrees and launch one agent from
each worktree:

```bash
git worktree add ../project-codex codex-work
cd ../project-codex
bash ~/claude-kit/codex.sh
```

For one shared working tree, keep one session read-only while the other edits.

## Container mounts

Outside the kit, the launcher mounts:

| Host path | Container access |
|---|---|
| `~/.codex` | Read-write |
| `~/.agents` | Read-only |
| `~/claude-kit` | Read-only |
| Current directory | Read-write at the same absolute path |

When the current directory is inside `~/claude-kit`, the kit is mounted once
read-write. SSH keys, Git credentials, host runtimes, and unrelated home
directories are not mounted.

## Troubleshooting

| Symptom | Action |
|---|---|
| `Docker is required` | Install Docker, then rerun `bash ~/claude-kit/codex-install.sh -q`. |
| `Run ... codex-install.sh first` | Run the installer. |
| Authentication failure | Run `bash ~/claude-kit/codex-install.sh -l`, then install again to sign back in. |
| A new skill is missing | Rerun `bash ~/claude-kit/codex-install.sh -qU`, then restart Codex. |
| Wrong model or reasoning effort | Rerun the installer and answer the prompts, or edit `generated/.codex.env`. |
| A workflow asks for unavailable tools | Check whether the skill depends on another agent's MCP or UI integration. |
