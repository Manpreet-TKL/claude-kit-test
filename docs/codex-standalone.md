# Standalone Codex usage

Use the kit directly from Codex without installing Codex, Node.js, or another
runtime on the host. Docker is the only host prerequisite.

## Install

Run the standalone installer from the kit root:

```bash
cd ~/claude-kit
./install-codex.sh
```

The installer:

- builds or reuses the local `claude-kit-codex` image;
- links `~/.codex/AGENTS.md` to `claude-md/CLAUDE.md`;
- links every kit skill into `~/.agents/skills`;
- regenerates each skill's `agents/openai.yaml`;
- preserves real skill directories and foreign symlinks;
- backs up a real `~/.codex/AGENTS.md` to `AGENTS.md.bak`;
- leaves `~/.codex/config.toml` unchanged.

If authentication is missing, an interactive install starts device login. In a
non-interactive shell it prints this command instead:

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth
```

The credential cache stays under `~/.codex`, outside the kit.

## Run Codex

Start an interactive session in the current directory:

```bash
~/claude-kit/codex.sh
```

Pass normal Codex arguments unchanged:

```bash
~/claude-kit/codex.sh --version
~/claude-kit/codex.sh exec "review the current changes"
```

The native footer shows model and reasoning, current directory, five-hour
limit, and weekly limit. This is a launch override and does not edit
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
Re-run `./install-codex.sh` after adding, removing, or renaming skills so the
manifest and generated metadata are refreshed.

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
~/claude-kit/codex.sh
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
| `Docker is required` | Install Docker, then rerun `./install-codex.sh`. |
| `Run ./install-codex.sh first` | Run the installer from `~/claude-kit`. |
| Authentication failure | Run the device-login command above. |
| A new skill is missing | Rerun `./install-codex.sh`, then restart Codex. |
| A workflow asks for unavailable tools | Check whether the skill depends on another agent's MCP or UI integration. |
