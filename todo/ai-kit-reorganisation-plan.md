# Reorganise the existing kit as ai-kit

Queued: 2026-09-15. Status: pending, execute only on explicit request.

## Scope

Prepare one personal kit for Codex and Claude Code on Linux, native Windows and
WSL, with a structure that other harnesses can use through an adapter.

The instruction draft is stored at
[instructions/drafts/AGENTS_NEW.md](../instructions/drafts/AGENTS_NEW.md). It is
inactive. Saving this plan and storing that draft are preparation only; no
reorganisation or installer changes have been implemented by this task.

Future implementation modifies the existing checkout in place. Preserve its
contents, Git history, staged work, unstaged changes and untracked additions. Do
not create another repository, export or working tree. The user handles the new
remote, history, publishing and any checkout relocation. Do not commit, push or
stage changes by default.

Retain all current content categories. Apply the new output convention to future
work; do not bulk-move existing project folders or loose files in HOME.

## Ten changes

1. **Rename the kit's identity to ai-kit.** Update branded documentation, skill
   names, profiles, installer records and other managed identifiers. Rename
   `c-claude-kit` to `c-ai-kit`. Resolve paths from the actual installation
   directory so the current folder continues to work. Preserve vendor-required
   names such as `.claude`, `.codex`, `CLAUDE.md` and `AGENTS.md`. Replace source
   references to the old brand; an existing installation path can still contain
   the old folder name until the user relocates it.

2. **Use a neutral instruction source.** Store the active shared instructions as
   `instructions/INSTRUCTIONS.md`, installed under each harness's required name
   through a symlink or managed copy. Preserve the active policy when relocating
   its source. The draft is already stored under `instructions/drafts/`; keep it
   inactive until activation is explicitly requested. Before any later
   activation, align its state and project-folder wording with points 8 and 9,
   preserving its other agreed rules and document styles.

3. **Separate shared and harness-specific components.** Keep reusable skills and
   Docker definitions in top-level `skills/` and `docker/`. Put components that
   require one harness under `harnesses/<name>/skills/` and
   `harnesses/<name>/docker/`. Keep that harness's launcher, settings and hooks
   alongside them. Classify by actual dependencies, not just a component's name.
   Installers combine shared content with the selected harness's content and
   reject conflicting skill names. Update scanners, validation, build contexts,
   mounts and relative links for both source locations. Document the adapter
   needed to support another harness.

4. **Make context skills easier to discover.** Catalogue skills by purpose,
   supported harness and platform requirements. Keep the standard
   `skills/<name>/SKILL.md` shape within each source location. Load relevant
   background context before workflow instructions, without loading every skill.
   Add this line to the inactive draft:

   > Many skills provide background context rather than actions. Before planning or acting, load the relevant context skills first, then load workflow skills as needed. Loading context alone does not authorize an action.

5. **Give every harness the same knowledge map.** Preserve the Database,
   Openeyes, Infrastructure, Tooling and Process categories and their contents.
   Expose one topic index through installed instructions. Retain existing memory,
   handoff, todo, radar and bug records. Continue requiring an explicit request
   before reading unrelated handoffs or starting queued work. Preserve the rule
   that credentials and client data belong outside the kit.

6. **Validate before changing an installation.** Check source completeness and
   compatibility before updating tools or installed configuration. Discover
   skills from both shared and harness-specific directories. Use explicit
   compatibility declarations, not the mere presence of harness metadata. Keep
   invocation preferences separate from source skill files. Diagnose stale
   kit-managed files without deleting manual skills or overwriting user edits.
   Preserve existing installer option meanings and supported lifecycle actions.

7. **Support Linux, native Windows and WSL.** Provide Bash and PowerShell setup
   and launch support for Codex and Claude Code. Handle paths containing spaces
   and managed copies where symlinks are unavailable. Use Docker Desktop for
   container tools and WSL for Linux-specific workflows. Keep screen integration
   specific to Linux and WSL. Use existing harness tools; prefer FOSS Docker
   images for additional tools. Do not add automatic host-tool installation.

8. **Keep harness state in its normal location.** Authentication, configuration
   and conversation history remain under the harness's existing home, such as
   `~/.claude` and `~/.codex`, respecting configured alternatives. Kit
   installation records can live beneath the corresponding home where needed.
   Preserve existing credential locations and pointers, including integrations
   shared by the harnesses. Do not introduce a separate shared state directory
   or copy new conversation memory into the kit. Shared templates and scripts
   remain in the kit; runtime state follows the relevant harness.

9. **Create project folders only when useful.** For lengthy work, repeat work or
   reusable outputs, use one suitable folder directly under `$HOME`. Reuse an
   existing folder when possible; do not require a `~/projects/` parent. Put
   disposable proof files in temporary storage and clean them up after
   verification. For example, delete SQL written solely to prove a PR works;
   retain SQL with future use in the relevant project folder. Keep `PROJECT.md`
   to at most five short lines describing the purpose and pointing to source
   repositories and session notes. Before creating a folder, inspect existing
   project markers for related work. Ask only when the match or destination is
   unclear. Preserve deliverables and remove only the session's own temporary
   material. Keep sensitive working material outside the kit.

10. **Continue related work through short project records.** Use supported hooks
    and installed guidance to discover project folders and load relevant
    context. Start with project markers directly beneath HOME and the current
    project; do not crawl unrelated files or native chat histories. Match the
    current task and repository to an existing project, asking when several are
    plausible. Record session references, completed outputs and unfinished work
    in separate session notes. Check those records and existing files before
    recreating outputs. Keep native conversations intact. Each session owns its
    notes so concurrent sessions do not overwrite one another; generate a shared
    index from those records. Save useful checkpoints during work rather than
    relying solely on shutdown hooks. Recheck important findings against current
    files. If a harness lacks hooks, provide the same discovery instructions and
    an explicit context-loading command through its adapter.

## Installer error

The supplied `codex_install_error.txt` came from another machine or copy. During
planning, it showed five validation failures involving the Claude-only
`codexmcp` and `oe-probe-chrome` skills and the obsolete `release-radar` skill.
The local checkout passed validation with 49 Codex skills. This is a planning
observation, not a claim that the affected copy has been repaired; verify the
current state again when executing this plan.

Add early diagnostics that identify the actual source directory and offending
files, explain how to obtain matching complete source, and provide precise
repair steps. Preserve local edits and repair only confirmed kit-managed stale
metadata and links. Keep compatibility validation enabled. Do not recommend
bypassing verification as the repair.

Migration must recognise existing managed links before changing their ownership
records, including links whose targets use the previous directory layout or
installation root. Update the link and its ownership record together only after
verification. Preserve manually installed files and external symlinks. This also
applies to renamed profiles, planner files, shell shortcuts and skill-invocation
snapshots.

## Implementation order and checks

When this queued plan is explicitly selected for execution:

1. Inventory the current working state and preserve staged and unstaged changes.
2. Reorganise instructions, shared components and harness-specific components in
   place. Keep the draft inactive.
3. Update installers, path handling, compatibility checks and repair messages.
4. Add project discovery and session records.
5. Verify the actual installed launchers and document the resulting layout.

Acceptance checks:

- Fresh, repeated and upgraded installations work without losing custom
  configuration or skills; shared and harness-specific skill-name collisions
  produce clear errors.
- Shared and harness-specific containers build and resolve the intended mounts.
- Knowledge links work, active instructions resolve correctly and the draft
  remains inactive.
- Harness state stays in its normal locations; installation does not rewrite
  source skill files to save local preferences.
- Astra `xhigh`, medium verbosity and native model switching continue working
  without a forced model/effort configuration override.
- Linux, native Windows and WSL receive appropriate smoke tests, including real
  launchers, fresh shell shortcuts and paths containing spaces. PowerShell
  checks on Linux alone do not establish native Windows compatibility.
- Short tasks leave no unnecessary project folder or disposable proof files.
- Lengthy or repeated work finds an existing project and reuses useful outputs;
  unclear matches prompt for a choice, and PROJECT.md remains extremely short.
- Concurrent sessions preserve one another's records. Missing or stale notes do
  not get presented as current verified results.
- OpenEyes testing retains resource checks, fresh instances dedicated to the
  change and cleanup of only the session's own one-off environment. Existing
  environments are presumed to be in use.
- No commits, pushes, repository creation or parallel working tree are performed.
