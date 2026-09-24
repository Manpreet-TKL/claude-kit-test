# Reorganise the existing kit as ai-kit

Queued: 2026-09-15. Revised: 2026-09-22.
Status: pending implementation. Saving this revision does not start the work.

## Scope and settled decisions

Make one personal, harness-neutral kit for Codex, Claude Code and Gemini CLI on
Linux, native Windows and WSL. Codex is the default harness. Use native features
where available and adapters where the harnesses differ.

Implement in the existing checkout. Preserve its contents, Git history and local
changes. Do not create a replacement kit repository, export or parallel working
tree. The user handles the new remote, fresh history, publishing and any checkout
relocation. Do not commit or push. Leave changes unstaged unless asked to stage.

Use the stored [instruction draft](../instructions/drafts/AGENTS_NEW.md) as the
source for `instructions/INSTRUCTIONS.md` when executing the reorganisation.
Align it with the agreed rules below, install it as the live shared source, then
remove `AGENTS_NEW.md` and its obsolete draft-only README after verification.
Keep `INSTRUCTIONS.md` in the kit; remove the duplicate draft, not the new source.
Saving this plan alone does not switch the live instructions.

This revision replaces the older shared-credential and direct-HOME workspace
rules. Use independent harness state and `~/ai-projects/`. Keep `~/pullrequests/`
for PR skills. Repository relocation and moving private kit material out are in
scope; bulk cleanup of unrelated HOME files is not. Preserve relocated contents.

## Ten changes

### 1. Rename and separate shared content from harness adapters

- Rename the kit identity to `ai-kit`, including documentation, managed profiles,
  image names, installer records and `c-claude-kit` -> `c-ai-kit`.
- Resolve paths from the actual installation directory so the current checkout
  works before the user relocates it. Retain old identifiers only where needed
  to recognise and migrate previous installations.
- Preserve vendor-required names: `.claude`, `.codex`, `.gemini`, `CLAUDE.md`,
  `AGENTS.md` and `GEMINI.md`.
- Keep shared `skills/`, `docker/`, `instructions/`, `knowledge/`, `docs/` and
  `todo/`. Put brand-specific skills, Dockerfiles, settings and helpers under
  `harnesses/<name>/`. Classify by actual dependencies, not current filenames.
- Keep `skills/<name>/SKILL.md` within each source location. Catalogue purpose,
  supported harnesses and platforms explicitly. Reject duplicate skill names
  across shared and selected harness sources.
- Update discovery, validation, relative links, Docker contexts and mounts
  together. Document the adapter contract for another harness.

### 2. Use neutral instructions and load context first

- Promote `instructions/drafts/AGENTS_NEW.md` to `instructions/INSTRUCTIONS.md`,
  installed under each harness's required filename through a symlink or managed
  copy. The approved draft replaces the old policy source. Reconcile its contents
  with this plan before activation, then verify installed paths before deleting
  the draft and obsolete source files. Preserve a rollback copy outside the kit.
- Align the draft's names, credentials, handovers and workspace rules with this
  plan. Put session context near the start and add:

  > Many skills provide background context rather than actions. Before planning or acting, load the relevant context skills first, then load workflow skills as needed. Loading context alone does not authorize an action.

- Preserve its agreed rules: no commits or pushes; no default staging or diff
  dump; a short changes/checks summary; AWS/Jira/Confluence read-only; GitHub
  writes require an explicit action and target and never authorize changing
  read-only integrations to gain access.
- Keep one policy for tools: use existing harness tools and prefer FOSS Docker
  images for extras. Harness CLI installation belongs to the explicit lifecycle
  scripts below, not permission to install arbitrary host tools.
- Keep Astra `xhigh` as Codex's default, removing Sol-default instructions. Use
  supported model selection for Sol or Terra on mechanical work; prose cannot
  silently switch the active model.
- Keep medium detail, technical terms explained in very simple English, and
  brief context before questions after long explanations. Use ASD-STE100
  principles without claiming formal compliance.
- Preserve three document styles: customer documents explain outcome, impact and
  action without investigation mechanics; learning documents explain findings
  and conclusions; DevOps notes use `c-note-style` and are very short.
- Limit `c-ascii` loading to relevant shared prose, including tickets, kit files
  and changed OpenEyes prose. Preserve meaningful symbols and exact output; do
  not sweep unrelated code. Retain the OpenEyes testing rules in point 9.

### 3. Provide a knowledge map and reference-repository library

- Preserve `knowledge/{Database,Openeyes,Infrastructure,Tooling,Process}/` and a
  common index. Add guidance to find local reference repositories at `~/repo/`
  when Git MCP is unavailable. Use portable HOME-relative paths in shared docs.
- Inventory HOME-level repositories, local changes, linked worktrees, submodules,
  mounts and path-dependent scripts before moving them.
- Move eligible repositories into `~/repo/`. Keep `~/ace`, the current kit
  checkout, `~/openeyes-docker`, `~/openeyes-laravel` and every configured
  oe-deploy instance in place. Identify instances from their configuration,
  not a guessed list of names.
- The original pristine `~/oe-deploy` is eligible. It was absent during planning;
  do not substitute an active instance or a similarly named project.
- Preserve contents and Git relationships, repair paths and verify consumers.
  Never reset files, overwrite collisions, discard changes or stop existing
  environments to make relocation easier. Report unsafe cases precisely.
- Reference repositories allow inspection and `git fetch`. Fetch may update
  remote-tracking refs but must not change checked-out branches or working files.
  Do not edit, check out branches, apply patches or develop there.
- Create independent working copies beneath the conversation workspace in
  `~/ai-projects/`. Avoid worktrees that would modify reference-repo metadata.
  Preserve patches, outputs and evidence before removing unneeded copies.
- Use PR skills when requested and keep their `~/pullrequests/` layout. Otherwise
  deliver a patch in the conversation workspace with its base commit, application
  guidance and checks. Preparing files implies no remote PR writes.

### 4. Isolate runtime state and credentials by harness

- Keep configuration, auth, history and runtime state in the native homes:
  `~/.codex`, `~/.claude` and `~/.gemini`. Respect supported overrides using each
  vendor's semantics; home variables do not all mean the same thing. Do not add
  a shared runtime-state directory.
- Source templates/scripts may be shared. Credentials, defaults, gate flags,
  reconnect windows, session markers, browser profiles, containers, backups and
  installed preferences each need one harness owner.
- Pass the owner explicitly from its adapter, never by guessing from inherited
  session variables. Child Codex uses Codex state/gates even when launched by
  Claude Code. Codex must work with `.claude` absent.
- Separate service containers and gates. Opening AWS, GitHub or Atlassian for one
  harness must not authorize another through a reconnect window, matching session
  ID, inherited variable or running container.
- New gate namespaces start closed. Do not import ambiguous legacy flags or adopt
  the shared AWS container silently. Retire legacy resources only after migration
  and after confirming no active task uses them.
- Offer credential setup for one, selected or all harnesses. Enter a service
  credential once and write independent protected copies into selected native
  homes. No shared secret symlinks or cross-home runtime fallback. Allow explicit
  one-time imports. Redact output and keep OAuth vendor-native. Saving credentials
  does not open gates.
- Apply ownership to service wrappers, corpus tools, browser helpers and repair
  commands. Offline corpus searches must not need another harness's credentials.
- Reset, fresh install, logout, disable and uninstall affect only their owner's
  managed files/resources. Backups must survive fresh-install wipes. Preserve
  manual files and external symlinks.
- Keep the optional Claude-to-Codex MCP bridge connection-only. Disabling it must
  not remove standalone Codex instructions, skills, settings or authentication.
- Save invocation preferences in installed state, never by rewriting authored
  skill frontmatter or metadata.

### 5. Introduce one installer with native adapters and lifecycle helpers

- One main installer accepts flags, defaults to Codex and calls the selected
  harness's configuration script. Each harness has a separate subordinate CLI
  install/update/uninstall helper. Preserve existing option meanings where
  applicable and map to supported native controls.
- Normal setup may install a missing selected harness CLI. Updating and
  uninstalling are explicit actions.
- Provide Bash entry points on Linux/WSL and PowerShell equivalents on native
  Windows. Handle spaces and managed copies when symlinks are unavailable. Use
  Docker Desktop for container tools and WSL for Linux-only workflows. Keep
  screen integration specific to Linux/WSL.
- Validate source completeness and compatibility before updates or configuration
  changes. Diagnose the actual source root and offending files. Preserve edits;
  repair only confirmed stale managed links/metadata. Never bypass validation.
- Recognise old managed links before changing ownership records, including old
  roots, layouts, profiles, planner files, shortcuts and invocation snapshots.
  Update links and records together after verification. Preserve manual files
  and external links; never remove a whole shared skill root.
- Gemini also scans `~/.agents/skills`. That shared location must not expose
  Codex-only skills to Gemini or shadow intended Gemini skills.

### 6. Add Gemini and optional idle CLI updates

- Add Gemini CLI with native settings, `GEMINI.md` and skill support. Declare
  unsupported features clearly rather than copying another harness's controls.
- Keep Astra `xhigh` and medium verbosity as fresh Codex defaults. Preserve native
  resume/session behaviour and explicit user changes, including Sol. Diagnose
  higher-priority model/effort overrides at their source; do not force defaults
  through launch arguments that prevent native selection from persisting.
- Check current native keybinding support for Alt+P model selection and effort
  controls. Implement it if supported; otherwise document the native alternative
  and limitation. Do not maintain a CLI fork or use brittle key injection.
- Offer an opt-in daily CLI update job through a Linux user timer or Windows
  scheduled task. Update selected installed CLIs only when idle. Share an explicit
  lifecycle lock between launchers and updater; skip busy or uncertain cases and
  retry later. Never interrupt a conversation.
- Coordinate native auto-updaters to avoid races. Keep logs, schedule state and
  recovery information in the owning harness home. Report failures without
  replacing working configuration. Never auto-pull or change kit source. Remove
  the owning schedule when uninstalling that CLI.

### 7. Keep only publishable material inside the kit

- Inventory private handovers, raw memory, generated state, backups, credentials,
  client data and runtime artifacts. Move them to the owning harness home or
  project workspace, preserve contents and repair pointers. `.gitignore` does
  not make private working-tree files safe.
- Preserve publishable knowledge, todo, radar and bug records. Retaining a
  category does not require private contents to remain in source. Do not delete
  information to achieve the new layout.
- Keep a publishable handover index with neutral title, intended outcome, status
  and portable external reference that a local resolver can locate. Exclude
  customer identities, secrets and private technical detail.
- Update `c-handoff` to write outside the kit and maintain the safe index.
  Preserve explicit-request rules for reading unrelated handover bodies and
  starting queued tasks. Index discovery alone grants neither permission.
- Check tracked and ignored working-tree paths. Prevent launchers, installers and
  skills from recreating runtime material there. Never print secret values.
  Previously tracked secrets, if found, require human-led rotation; moving files
  does not remove secrets from history.

### 8. Keep conversation work together and reuse related outputs

- Use `~/ai-projects/<project>/sessions/<harness>-<session-id>/` for conversations
  needing output folders: working copies, scratch, reports, evidence and private
  technical notes. If a native session ID is unavailable, create a stable local
  ID and record the native reference later.
- Keep project-level `PROJECT.md` to at most five short lines: purpose, relevant
  repos and pointers to session records. Each session record identifies owner,
  source revisions, outputs, completed work and unfinished work.
- Check relevant project markers and the current workspace before creating a
  folder. Reuse a clear match; ask when several destinations are plausible.
  Do not crawl unrelated files or native chat histories.
- Link related conversations and outputs through these records. Never merge or
  edit native transcripts. Check existing deliverables before recreating them
  and verify old findings against current source.
- Each session owns its notes; generate a shared index without overwriting other
  sessions. Save useful checkpoints during work, not only at shutdown. Provide
  guidance and an explicit loading command where native hooks are unavailable.
- File-free short conversations need no durable folder. Delete disposable proof
  files after verification; retain reusable SQL and requested deliverables.
  Preserve others' work. PR skills keep `~/pullrequests/`; link to those outputs
  from the project record when useful.

### 9. Track and clean up task-owned resources

- Plan cleanup when creating files, containers, networks and volumes. Track the
  owning harness, project, session and task. Preserve requested outputs/evidence
  before removing disposable resources.
- Clean up on actual task completion or failure and verify removal. An assistant
  end of turn is not necessarily completion. Retain resources needed by unfinished
  work and record why.
- Never use global Docker prune, delete shared images/external volumes or stop
  unrelated environments. Stop shared services only when no active consumer
  needs them.
- Before testing OpenEyes code, check CPU load, available RAM and disk headroom.
  If capacity is inadequate, report it; never stop another environment to free
  resources. Presume existing environments are in use.
- Create a fresh oe-deploy instance for the change. Follow `c-oe-deploy` for the
  test-up script or dev-image checkout and include actual local/uncommitted
  changes. Reuse only that dedicated instance for the same change's iterations.
- For one-off tests, preserve evidence, then tear down that instance, including
  after setup/test failure. Verify only its containers, networks and disposable
  volumes were removed; retain persistent data requested as a deliverable.

### 10. Add a Jira-ready change-request skill

- Create a shared, explicitly invoked `a-change-request` skill. Turn the current
  conversation into a local client-facing CR and a separate private implementation
  note. Do not create or edit Jira issues.
- Shape the form from `~/jira-corpus/cr-change-requests` without copying client
  data into the kit. Repeated fields include summary, existing behaviour, desired
  new/improved behaviour, key requirements, acceptance criteria and further info.
- Include scope, assumptions, dependencies and exclusions. Add migration,
  interfaces, reporting, configuration, usability and priority only when relevant.
  Do not guess Jira custom-field IDs from corpus JSON.
- Explain the change, its benefit and why it falls outside ordinary support.
  Use the known support agreement or mark that conclusion as an assumption;
  do not classify all requests as billable by default.
- Write a persuasive, evidence-based business case in extremely simple English.
  Do not invent savings, urgency or contractual obligations.
- Estimate days with investigation, implementation and testing rows, and separate
  DevOps/development columns. Development covers OpenEyes, PayloadProcessor and
  IOLMasterImport, including their investigation and tests. Other work is DevOps.
  Include totals, assumptions and uncertainty. Add money only when rates exist.
- The separate private note links the technical implementation document and records
  evidence, existing implementation and remaining work. Do not hide it in a
  supposedly secret section of a client document or expose its private link there.
- Do not describe completed work as unstarted or invent development days. A
  truthful fixed-price proposal may explain delivery, validation, deployment and
  support value separately from remaining engineering effort.

## Findings to verify during implementation

These are planning observations, not claims that affected systems are repaired.
Recheck current files and installed versions before changing them.

The supplied `~/codex_install_error.txt` came from another machine or copy. The
original investigation found five validation failures involving Claude-only
`codexmcp` and `oe-probe-chrome` skills and obsolete `release-radar`. The local
checkout then passed validation with 49 Codex skills. Add early advice for
obtaining matching complete source and repairing confirmed stale managed files.
Preserve local edits and keep compatibility validation enabled.

The isolation audit found shared AWS containers/gates, cross-harness reconnect
flags, Codex credentials/browser state under `.claude`, shared generated defaults
and invocation state, and Claude lifecycle actions affecting standalone Codex.
Audit both installers, launchers, service/corpus/browser wrappers and installed
configuration together. Documentation mentioning another home is not itself a
runtime dependency; verify actual reads, writes and behaviour.

Gemini implementation references:

- [Installation](https://geminicli.com/docs/get-started/installation/): verify
  current prerequisites and supported native platforms.
- [Configuration](https://geminicli.com/docs/reference/configuration/): check
  native settings, home overrides and auto-update behaviour.
- [Skills](https://geminicli.com/docs/cli/skills/): account for `.gemini` and
  `.agents` discovery and precedence.

## Execution order

1. Inventory files, Git state, repository relationships, private content and
   runtime ownership. Keep migration/rollback records outside the kit.
2. Separate harness state and credentials; move private kit material without
   losing it or disrupting active consumers.
3. Reorganise shared/harness sources, add Gemini and the installer dispatcher.
   Prepare `INSTRUCTIONS.md` from the draft and align it with the agreed rules.
4. Add explicit credential fan-out and optional idle CLI updates.
5. Relocate eligible reference repositories and repair dependent paths.
6. Add project discovery, external handovers, ownership-based cleanup and the CR
   skill. Verify the final instruction paths/rules, activate `INSTRUCTIONS.md`
   for the configured harnesses and remove the duplicate draft and stale pointers.
7. Verify real launchers/migrations, document the layout and report tested and
   untested behaviour. The user handles publishing.

## Acceptance checks

- Fresh, repeated and upgraded installs preserve manual settings, skills and
  external links. Validation runs before mutation; conflicts name offending
  files and give useful repair advice.
- Codex works without `.claude`. Each harness can configure, launch, reset, log
  out and uninstall without changing another's state or resources.
- Opening one gate leaves the other two blocked, including matching session IDs,
  inherited variables, reconnect windows and running containers. Legacy shared
  flags do not authorize sessions.
- Credential fan-out creates independent protected copies. Editing one copy or
  invocation preference leaves other homes and authored source unchanged. No
  secrets reach output or the kit. Fresh-install backups survive reset.
- Disabling bridge support leaves standalone Codex working. Shared discovery
  exposes only compatible skills and preserves the intended catalogue.
- Idle updates honour locks, skip active sessions and leave source untouched.
  Logs and recovery stay under the owning home.
- Docker builds use correct contexts/mounts. No runtime operation recreates
  private state in source. Knowledge links and live instructions resolve to the
  approved `INSTRUCTIONS.md`. `AGENTS_NEW.md`, the obsolete draft README and stale
  draft links are gone; the canonical instruction source remains in the kit.
- Fresh Codex defaults to Astra `xhigh` and medium verbosity. Native model changes,
  explicit Sol choice and resume work without forced overrides. Report any
  native keybinding limitation honestly.
- Repo relocation preserves local changes, worktree/submodule relationships and
  path consumers. Exclusions stay put; reference fetch leaves working files
  unchanged; development copies remain independent.
- Related sessions reuse outputs without merging transcripts or overwriting
  notes. Project markers stay at most five lines; simple chats leave no durable
  folder. Disposable proofs are removed.
- PR skills still use `~/pullrequests/`; other patches identify their base and
  checks. Public handover indexes expose no private material.
- OpenEyes tests use fresh dedicated instances after resource checks. Success
  and failure cleanup touch only owned disposable resources and preserve evidence.
- CR documents separate client/internal material, classify the three development
  codebases correctly, total effort accurately and make truthful claims.
- Run Linux, native Windows and WSL smoke tests: actual launchers, fresh-shell
  shortcuts and paths with spaces. PowerShell tests on Linux alone do not prove
  native Windows support; report unavailable platform tests.
- No replacement kit repository, commits, pushes or parallel kit tree are created.
