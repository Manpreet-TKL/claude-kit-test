#Requires -Version 5.1
<#
.SYNOPSIS
  Windows/PowerShell equivalent of install.sh - configures a project-local
  .claude directory from this kit.
.DESCRIPTION
  The kit lives in a subfolder (this claude-kit directory) of the repo it
  configures. By default the script installs into the .claude of the folder ONE
  LEVEL ABOVE the kit - i.e. the repo root - so it is reusable across colleagues
  and checkouts. The first prompt shows the resolved target and lets you accept
  it or type a different path.

  Run with no parameters it is fully interactive, asking in order: install
  target, permission tier, session start mode, and the skill model-invocation
  gate. Each of those can be supplied as a parameter instead - -Target,
  -Permissions, -Mode, -SkillsAuto - and -Yes takes the default for anything
  left unanswered, so the script can run unattended. -Quick is -Yes with the
  yolo tier (unless -Permissions names one), mirroring install.sh -q, and
  -NoUpdate skips the CLI install/update step. Advanced knobs stay as env
  overrides (see below); each has a sensible default and is never prompted for.

  Like install.sh it manages the CLI itself: if `claude` is not on PATH it is
  installed with npm, otherwise `claude update` runs. Skip both with -NoUpdate.

  The skill gate defaults to LEAVING THE KIT ALONE - the committed per-skill
  disable-model-invocation values are the authored intent, so a default run does
  not rewrite 40-odd tracked SKILL.md files as an install side effect. Choosing
  'on' snapshots each flagged skill's current value to generated\skills-auto.state
  first (append-only, so a repeat 'on' never overwrites the pre-flip values), and
  'off' restores exactly those values and clears the snapshot; with no snapshot it
  sets every flagged skill to manual and says so. That file and its format are
  shared with install.sh -s, so a flip made under WSL can be reverted from Windows
  and vice versa. It is never a blind true<->false inversion: a skill authored
  auto-invokable must survive an on/off round trip.

  Covers the core config install.sh does: permission tier + session start mode,
  settings.json merge (statusLine, autocompact/budget env vars,
  cleanupPeriodDays, shift-enter fragment, permissions), .claude\CLAUDE.md,
  .claude\statusline.sh, .claude\skills\*, and a one-way backup of live project
  memory (from the user-global ~/.claude/projects/<slug>/memory, which is where
  Claude Code actually stores it regardless of project scope) into this kit's
  memory/ folder. Idempotent: safe to re-run.

  NOT covered (these lean on Unix-only tooling - id -u, pgrep, sh -c - that
  doesn't map cleanly to Windows): the Docker-based Atlassian/GitHub/Codex MCP
  server registration, session pruning, and MCP logout. Also not covered:
  install.sh's -Reset/-Fresh (bloat-archiving and nuke-and-pave operate on
  auth/history/state under the user-global ~/.claude, not this project-local
  directory - irrelevant here). Run install.sh under WSL if you need any of those.

  Windows has no symlinks without Developer Mode/admin, so unlike install.sh
  (which symlinks CLAUDE.md/statusline.sh/skills so kit edits are live), this
  script COPIES them instead. Editing the kit has no effect on the target
  .claude until you re-run this script. The copy is a robocopy /MIR mirror, so a
  file you added by hand inside a kit-managed skill folder would be deleted: the
  script lists any such file and skips that folder instead (-Yes always skips; an
  interactive run offers to delete them).

  The statusLine command stays "bash <path>\statusline.sh" (unchanged script),
  which needs bash + jq on PATH - e.g. Git for Windows' bash (jq isn't bundled;
  `winget install jqlang.jq` or `choco install jq`).

  Env overrides (same names as install.sh): DEFAULT_MODE, CLEANUP_PERIOD_DAYS,
  STATUSLINE_REFRESH, AUTOCOMPACT_PCT, AUTOCOMPACT_WINDOW, FIVE_HOUR_BUDGET,
  WEEKLY_BUDGET.
#>
[CmdletBinding()]
param(
    [string]$Target,
    [ValidateSet('ultra-safe', 'standard', 'trusted', 'yolo')][string]$Permissions,
    [string]$Mode,
    [string]$SkillsAuto,
    [switch]$Yes,
    [switch]$Quick,
    [switch]$NoUpdate
)

function Invoke-Abort {
    Write-Host ''
    Write-Host '****************************'
    Write-Host '*** ABORTED DUE TO ERROR ***'
    Write-Host '****************************'
    Write-Host ''
    Get-Date
    Write-Host 'An error occurred. Exiting...'
}

$ErrorActionPreference = 'Stop'

try {

    # Defaults (overridable via env) ----------------------------------------
    $DefaultMode = if ($env:DEFAULT_MODE) { $env:DEFAULT_MODE } else { 'auto' }
    $AutocompactPct = if ($env:AUTOCOMPACT_PCT) { $env:AUTOCOMPACT_PCT } else { '100' }
    $AutocompactWindow = if ($env:AUTOCOMPACT_WINDOW) { $env:AUTOCOMPACT_WINDOW } else { '200000' }
    $FiveHourBudget = $env:FIVE_HOUR_BUDGET
    $WeeklyBudget = $env:WEEKLY_BUDGET
    $CleanupPeriodDays = if ($env:CLEANUP_PERIOD_DAYS) { $env:CLEANUP_PERIOD_DAYS } else { '365' }
    $StatuslineRefresh = if ($env:STATUSLINE_REFRESH) { $env:STATUSLINE_REFRESH } else { '5' }

    # Kit source paths (travel with the script) ------------------------------
    $kitRoot = $PSScriptRoot
    $permissionsDir = Join-Path $kitRoot 'settings\permissions'
    $shiftEnterFile = Join-Path $kitRoot 'settings\shift-enter.json'
    $skillsSrcDir = Join-Path $kitRoot 'skills'
    $memorySrcDir = Join-Path $kitRoot 'memory'
    $generatedDir = Join-Path $kitRoot 'generated'
    # Shared with install.sh -s: same file, same tab-separated format, so a flip
    # made under WSL can be reverted from Windows and vice versa.
    $skillsAutoState = Join-Path $generatedDir 'skills-auto.state'
    $claudeMdSrc = Join-Path $kitRoot 'claude-md\CLAUDE.md'
    $statuslineSrc = Join-Path $kitRoot 'settings\statusline.sh'

    # Live project memory is stored under the user-global ~/.claude/projects/<slug>/memory
    # regardless of project scope - a separate concern from the settings target below.
    $globalClaudeDir = Join-Path $env:USERPROFILE '.claude'

    # -Quick mirrors install.sh -q: no questions, yolo tier unless -Permissions
    # names one, and it implies -Yes. Anything a parameter did not answer falls
    # back to its default rather than being asked for.
    if ($Quick) {
        $Yes = $true
        if (-not $Permissions) { $Permissions = 'yolo' }
    }
    $noPrompt = [bool]$Yes

    ###########################################################################
    ### PROMPTS
    ###########################################################################

    Write-Host ''
    Write-Host 'claude-kit installer'
    Write-Host '-------------------------------'

    # 1) Install target - defaults to the .claude of the folder the kit sits in
    #    (i.e. the repo root, one level above this claude-kit folder).
    $defaultTarget = Join-Path (Split-Path $kitRoot -Parent) '.claude'
    Write-Host 'This kit installs into a project-local .claude directory.'
    if ($Target) {
        $claudeDir = $Target.Trim()
    }
    elseif ($noPrompt) {
        $claudeDir = $defaultTarget
    }
    else {
        $answer = Read-Host "Install target [$defaultTarget]"
        $claudeDir = if ([string]::IsNullOrWhiteSpace($answer)) { $defaultTarget } else { $answer.Trim() }
    }

    # Derived target paths ---------------------------------------------------
    $claudeSkillsDir = Join-Path $claudeDir 'skills'
    $skillsManifest = Join-Path $claudeDir '.claude-kit-skills'
    $settingsFile = Join-Path $claudeDir 'settings.json'
    $settingsBak = "$settingsFile.bak"
    $claudeMdFile = Join-Path $claudeDir 'CLAUDE.md'
    $claudeMdBak = "$claudeMdFile.bak"
    $statuslineFile = Join-Path $claudeDir 'statusline.sh'
    $statuslineBak = "$statuslineFile.bak"
    Write-Host "Target: $claudeDir [OK]"

    # 2) Permission tier.
    if (-not $Permissions) {
        if ($noPrompt) {
            $Permissions = 'standard'
        }
        else {
            Write-Host ''
            Write-Host 'Choose permission tier: [1] ultra-safe  [2] standard (default)  [3] trusted  [4] yolo'
            $choice = Read-Host 'Selection [2]'
            switch ($choice) {
                { $_ -in '1', 'ultra-safe' } { $Permissions = 'ultra-safe' }
                { $_ -in '3', 'trusted' } { $Permissions = 'trusted' }
                { $_ -in '4', 'yolo' } { $Permissions = 'yolo' }
                default { $Permissions = 'standard' }
            }
        }
    }
    Write-Host "Tier: $Permissions [OK]"
    if ($Permissions -eq 'yolo') {
        Write-Host "  WARNING: 'yolo' tier allows reads of .env/.ssh without prompting."
        Write-Host '           (git push/commit + rm -rf are still denied - hard floor.)'
        Write-Host '           Run only inside a throwaway container/VM.'
    }

    # 3) Session start mode.
    if (-not $Mode) {
        if ($noPrompt) {
            $Mode = $DefaultMode
        }
        else {
            Write-Host ''
            Write-Host 'Choose session start mode:'
            Write-Host '  [1] auto (default)  [2] default  [3] plan  [4] acceptEdits  [5] dontAsk  [6] bypassPermissions'
            $modeChoice = Read-Host 'Selection [1]'
            switch ($modeChoice) {
                { $_ -in '2', 'default' } { $Mode = 'default' }
                { $_ -in '3', 'plan' } { $Mode = 'plan' }
                { $_ -in '4', 'acceptEdits' } { $Mode = 'acceptEdits' }
                { $_ -in '5', 'dontAsk' } { $Mode = 'dontAsk' }
                { $_ -in '6', 'bypassPermissions' } { $Mode = 'bypassPermissions' }
                { $_ -in '1', 'auto' } { $Mode = 'auto' }
                default { $Mode = $DefaultMode }
            }
        }
    }
    # Checked after resolution, not with a ValidateSet on the parameter: $Mode can
    # also arrive from DEFAULT_MODE, and install.sh validates the resolved value.
    if ($Mode -notin 'default', 'plan', 'acceptEdits', 'auto', 'dontAsk', 'bypassPermissions') {
        throw "Invalid mode '$Mode' - must be default|plan|acceptEdits|auto|dontAsk|bypassPermissions"
    }
    Write-Host "Mode: $Mode [OK]"
    if ($Mode -eq 'bypassPermissions') {
        Write-Host "  WARNING: 'bypassPermissions' skips ALL permission checks - the widest mode"
        Write-Host '           Claude Code has. Run only inside a throwaway container/VM.'
    }

    # 4) Skill auto-invocation. Default is to change NOTHING: the committed
    #    per-skill values are the authored intent, and rewriting 40-odd tracked
    #    SKILL.md files as a side effect of installing is not what you asked for.
    if (-not $SkillsAuto -and -not $noPrompt) {
        Write-Host ''
        Write-Host 'Skill model-invocation gate: [1] leave as committed (default)  [2] on  [3] off'
        $skillsChoice = Read-Host 'Selection [1]'
        switch ($skillsChoice) {
            { $_ -in '2', 'on' } { $SkillsAuto = 'on' }
            { $_ -in '3', 'off' } { $SkillsAuto = 'off' }
            default { $SkillsAuto = '' }
        }
    }
    if ($SkillsAuto -and $SkillsAuto -notin 'on', 'off') {
        throw "Invalid -SkillsAuto '$SkillsAuto' - must be on|off"
    }
    if ($SkillsAuto) { Write-Host "Skills auto-invocation: $SkillsAuto [OK]" }
    else { Write-Host 'Skills auto-invocation: leave as committed [OK]' }

    ###########################################################################
    ### CHECKS
    ###########################################################################

    Write-Host ''
    Write-Host 'Starting pre-flight checks ...'
    Write-Host '-------------------------------'

    Write-Host 'Validating retention / statusline options...'
    if ($CleanupPeriodDays -notmatch '^[1-9][0-9]*$') {
        throw "Invalid CLEANUP_PERIOD_DAYS '$CleanupPeriodDays' - must be a positive integer (days)"
    }
    if ($StatuslineRefresh -notmatch '^[0-9]+$') {
        throw "Invalid STATUSLINE_REFRESH '$StatuslineRefresh' - must be a whole number of seconds (0 = event-driven only)"
    }
    Write-Host "Retention: cleanupPeriodDays=$CleanupPeriodDays [OK]"

    Write-Host "Ensuring $claudeDir exists..."
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    Write-Host 'Checks complete ...'
    Write-Host '-------------------------------'

    ###########################################################################
    ### FUNCTIONS
    ###########################################################################

    function Update-Claude {
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
                Write-Host '  claude CLI not on PATH and npm is missing - install Node.js, then run:'
                Write-Host '    npm install -g @anthropic-ai/claude-code'
                Write-Host '  (or the official installer: irm https://claude.ai/install.ps1 | iex)'
                return
            }
            Write-Host '  claude CLI not on PATH - installing with npm...'
            try {
                npm install -g @anthropic-ai/claude-code
                # A native command's non-zero exit is not a PowerShell error.
                if ($LASTEXITCODE -ne 0) { throw "npm exited $LASTEXITCODE" }
                Write-Host '  [OK] Claude Code CLI installed'
            }
            catch {
                Write-Host '  WARNING: install failed - run it by hand: npm install -g @anthropic-ai/claude-code'
            }
            return
        }
        Write-Host "  running 'claude update'..."
        try {
            claude update
            Write-Host '  [OK] Claude Code CLI up to date'
        }
        catch {
            Write-Host "  WARNING: 'claude update' failed (offline, or package-manager-managed install?) - continuing"
        }
    }

    function Copy-KitFile {
        param([string]$Src, [string]$Dst, [string]$Bak, [string]$Label)
        if (-not (Test-Path $Src)) {
            Write-Host "  missing kit source: $Src"
            return
        }
        if (Test-Path $Dst) {
            $sameHash = (Get-FileHash $Dst -Algorithm SHA256).Hash -eq (Get-FileHash $Src -Algorithm SHA256).Hash
            if ($sameHash) {
                Write-Host "  $Label already up to date - no change"
                return
            }
            Copy-Item -Path $Dst -Destination $Bak -Force
            Write-Host "  backed up -> $Bak"
        }
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-Host "  copied    -> $Dst (from $Src)"
    }

    function Merge-Settings {
        $tierFile = Join-Path $permissionsDir "$Permissions.json"
        if (-not (Test-Path $tierFile)) { throw "Missing tier file: $tierFile" }
        $perms = Get-Content $tierFile -Raw | ConvertFrom-Json
        $perms | Add-Member -NotePropertyName 'defaultMode' -NotePropertyValue $Mode -Force

        $shift = [PSCustomObject]@{}
        if (Test-Path $shiftEnterFile) {
            $shift = Get-Content $shiftEnterFile -Raw | ConvertFrom-Json
        }

        $oldRaw = ''
        $settings = [PSCustomObject]@{}
        if (Test-Path $settingsFile) {
            $oldRaw = Get-Content $settingsFile -Raw
            if ($oldRaw -and $oldRaw.Trim()) { $settings = $oldRaw | ConvertFrom-Json }
        }

        foreach ($prop in $shift.PSObject.Properties) {
            $settings | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }

        $envBlock = [PSCustomObject]@{}
        if ($settings.PSObject.Properties['env']) { $envBlock = $settings.env }
        foreach ($legacy in 'CLAUDE_MONTHLY_LIMIT_USD', 'CLAUDE_MONTHLY_TOKEN_BUDGET', 'CLAUDE_5H_TOKEN_BUDGET', 'CLAUDE_WEEKLY_TOKEN_BUDGET') {
            if ($envBlock.PSObject.Properties[$legacy]) { $envBlock.PSObject.Properties.Remove($legacy) }
        }
        $envBlock | Add-Member -NotePropertyName 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' -NotePropertyValue $AutocompactPct -Force
        $envBlock | Add-Member -NotePropertyName 'CLAUDE_CODE_AUTO_COMPACT_WINDOW' -NotePropertyValue $AutocompactWindow -Force
        if ($FiveHourBudget) { $envBlock | Add-Member -NotePropertyName 'CLAUDE_5H_TOKEN_BUDGET' -NotePropertyValue $FiveHourBudget -Force }
        if ($WeeklyBudget) { $envBlock | Add-Member -NotePropertyName 'CLAUDE_WEEKLY_TOKEN_BUDGET' -NotePropertyValue $WeeklyBudget -Force }
        $settings | Add-Member -NotePropertyName 'env' -NotePropertyValue $envBlock -Force

        $statuslineUnixPath = ($statuslineFile -replace '\\', '/')
        $statusLineObj = [ordered]@{ type = 'command'; command = "bash `"$statuslineUnixPath`"" }
        if ($StatuslineRefresh -ne '0') { $statusLineObj['refreshInterval'] = [int]$StatuslineRefresh }
        $settings | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue ([PSCustomObject]$statusLineObj) -Force

        $settings | Add-Member -NotePropertyName 'cleanupPeriodDays' -NotePropertyValue ([int]$CleanupPeriodDays) -Force
        $settings | Add-Member -NotePropertyName 'permissions' -NotePropertyValue $perms -Force

        if ($settings.PSObject.Properties['mcpServers']) { $settings.PSObject.Properties.Remove('mcpServers') }

        $newJson = $settings | ConvertTo-Json -Depth 20

        if ($oldRaw -and ($oldRaw.Trim() -eq $newJson.Trim())) {
            Write-Host '  settings.json already current - no change'
            return
        }
        if (Test-Path $settingsFile) {
            Copy-Item -Path $settingsFile -Destination $settingsBak -Force
            Write-Host "  backed up -> $settingsBak"
        }
        Set-Content -Path $settingsFile -Value $newJson
        Write-Host "  merged -> $settingsFile"
    }

    # Read a skill's disable-model-invocation value, or '' if it carries no flag.
    # Restricted to the frontmatter block, so a literal mention in the body is
    # never seen. Mirrors skillGateValue() in lib/skills.sh.
    function Get-SkillGateValue {
        param([string[]]$Lines)
        if ($Lines.Count -lt 2 -or $Lines[0] -ne '---') { return '' }
        for ($i = 1; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -eq '---') { return '' }
            if ($Lines[$i] -eq 'disable-model-invocation: true') { return 'true' }
            if ($Lines[$i] -eq 'disable-model-invocation: false') { return 'false' }
        }
        return ''
    }

    function Set-SkillGateValue {
        param([string]$Path, [string[]]$Lines, [string]$Value)
        for ($i = 1; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -eq '---') { break }
            if ($Lines[$i] -eq 'disable-model-invocation: true' -or $Lines[$i] -eq 'disable-model-invocation: false') {
                $Lines[$i] = "disable-model-invocation: $Value"
            }
        }
        # LF and UTF-8 without a BOM, not Set-Content: on Windows PowerShell 5.1
        # Set-Content writes CRLF - every tracked SKILL.md would show as fully
        # rewritten, and install.sh's frontmatter sed stops matching once a CR
        # trails the value - and it defaults to ASCII, replacing any non-ASCII
        # byte with '?'.
        [System.IO.File]::WriteAllText($Path, ($Lines -join "`n") + "`n")
    }

    function Show-SkillsInvocationTally {
        $auto = 0; $manual = 0; $always = 0
        foreach ($dir in Get-ChildItem -Path $skillsSrcDir -Directory) {
            $skillMd = Join-Path $dir.FullName 'SKILL.md'
            if (-not (Test-Path $skillMd)) { continue }
            switch (Get-SkillGateValue -Lines @(Get-Content $skillMd)) {
                'true' { $manual++ }
                'false' { $auto++ }
                default { $always++ }
            }
        }
        Write-Host "  $auto auto-invokable, $manual manual, $always always-auto (no flag)"
    }

    # Flip the model-invocation gate across kit skills.
    #
    # 'on' snapshots each flagged skill's CURRENT value to generated\skills-auto.state
    # before setting everything to false, and 'off' puts those exact values back. A
    # blind false->true inversion would silently demote skills that were authored
    # auto-invokable rather than flipped there, so it is never used. Skills carrying
    # no flag at all (the deliberate auto-load set) are untouched in both directions.
    # With no choice made the function only reports: the committed values are the
    # authored intent.
    function Set-SkillsInvocation {
        if (-not (Test-Path $skillsSrcDir)) {
            Write-Host '  no skills\ dir in kit - skipped'
            return
        }
        if (-not $SkillsAuto) {
            Write-Host '  left as committed (choose on/off at the prompt to change)'
            Show-SkillsInvocationTally
            return
        }

        New-Item -ItemType Directory -Force -Path $generatedDir | Out-Null
        $changed = 0

        if ($SkillsAuto -eq 'on') {
            # Append-only. A snapshot already on disk holds the PRE-flip values, so a
            # repeat 'on' must not overwrite them with the flipped ones it is about to
            # read back - that would silently turn 'off' into a no-op and strand every
            # manual skill on auto. Skills added to the kit since the first 'on' are
            # appended at their current value.
            $snapshot = New-Object 'System.Collections.Generic.List[string]'
            $seen = New-Object 'System.Collections.Generic.HashSet[string]'
            if (Test-Path $skillsAutoState) {
                foreach ($line in @(Get-Content $skillsAutoState)) {
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    $snapshot.Add($line) | Out-Null
                    $seen.Add(($line -split "`t")[0]) | Out-Null
                }
            }
            foreach ($dir in Get-ChildItem -Path $skillsSrcDir -Directory) {
                $skillMd = Join-Path $dir.FullName 'SKILL.md'
                if (-not (Test-Path $skillMd)) { continue }
                $lines = @(Get-Content $skillMd)
                $value = Get-SkillGateValue -Lines $lines
                if (-not $value) { continue }
                if (-not $seen.Contains($dir.Name)) {
                    $snapshot.Add("$($dir.Name)`t$value") | Out-Null
                    $seen.Add($dir.Name) | Out-Null
                }
                if ($value -eq 'false') { continue }
                Set-SkillGateValue -Path $skillMd -Lines $lines -Value 'false'
                Write-Host "  true->false  $($skillMd.Substring($kitRoot.Length + 1))"
                $changed++
            }
            # LF, not CRLF: install.sh reads this same file with `read -r`, and a
            # trailing CR would end up inside the restored value.
            [System.IO.File]::WriteAllText($skillsAutoState, ($snapshot -join "`n") + "`n")
            Write-Host "  snapshot holds $($snapshot.Count) pre-flip value(s) in generated\skills-auto.state"
        }
        elseif (Test-Path $skillsAutoState) {
            foreach ($line in @(Get-Content $skillsAutoState)) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $parts = $line -split "`t"
                $name = $parts[0]
                $value = $parts[1]
                $skillMd = Join-Path (Join-Path $skillsSrcDir $name) 'SKILL.md'
                if (-not (Test-Path $skillMd)) {
                    Write-Host "  skipped $name - no longer in the kit"
                    continue
                }
                $lines = @(Get-Content $skillMd)
                if ((Get-SkillGateValue -Lines $lines) -eq $value) { continue }
                Set-SkillGateValue -Path $skillMd -Lines $lines -Value $value
                Write-Host "  restored $value  $($skillMd.Substring($kitRoot.Length + 1))"
                $changed++
            }
            Remove-Item -Force $skillsAutoState
            Write-Host '  snapshot consumed and cleared'
        }
        else {
            Write-Host '  no snapshot to restore - setting every flagged skill to manual'
            foreach ($dir in Get-ChildItem -Path $skillsSrcDir -Directory) {
                $skillMd = Join-Path $dir.FullName 'SKILL.md'
                if (-not (Test-Path $skillMd)) { continue }
                $lines = @(Get-Content $skillMd)
                if ((Get-SkillGateValue -Lines $lines) -ne 'false') { continue }
                Set-SkillGateValue -Path $skillMd -Lines $lines -Value 'true'
                Write-Host "  false->true  $($skillMd.Substring($kitRoot.Length + 1))"
                $changed++
            }
        }

        if ($changed -eq 0) { Write-Host '  nothing to change' }
        else {
            Write-Host "  $changed skill(s) rewritten"
            Write-Host '  restart Claude Code to pick up the change (skills bind at session start)'
        }
        Show-SkillsInvocationTally
    }

    # Files present in a target skill dir but not in the kit - i.e. exactly what
    # robocopy /MIR would delete. Comparing directly beats parsing robocopy /L.
    function Get-ExtraTargetFiles {
        param([string]$Src, [string]$Dst)
        if (-not (Test-Path $Dst)) { return @() }
        $srcRel = @(Get-ChildItem -Path $Src -Recurse -File |
            ForEach-Object { $_.FullName.Substring($Src.Length).TrimStart('\') })
        @(Get-ChildItem -Path $Dst -Recurse -File |
            ForEach-Object { $_.FullName.Substring($Dst.Length).TrimStart('\') } |
            Where-Object { $srcRel -notcontains $_ })
    }

    function Sync-Skills {
        if (-not (Test-Path $skillsSrcDir)) {
            Write-Host '  no skills\ dir in kit - skipped'
            return
        }
        New-Item -ItemType Directory -Force -Path $claudeSkillsDir | Out-Null

        $prevNames = @()
        if (Test-Path $skillsManifest) {
            $prevNames = @(Get-Content $skillsManifest | Where-Object { $_ -ne '' })
        }
        $currentNames = @((Get-ChildItem -Path $skillsSrcDir -Directory).Name)

        foreach ($prev in $prevNames) {
            if ($currentNames -contains $prev) { continue }
            $dst = Join-Path $claudeSkillsDir $prev
            if (Test-Path $dst) {
                Remove-Item -Recurse -Force $dst
                Write-Host "  removed -> $dst (removed from kit)"
            }
        }

        $newManifest = @()
        foreach ($name in $currentNames) {
            $src = Join-Path $skillsSrcDir $name
            $dst = Join-Path $claudeSkillsDir $name
            $wasKitManaged = $prevNames -contains $name
            if ((Test-Path $dst) -and -not $wasKitManaged) {
                Write-Host "  skip  -> $dst (exists and not kit-managed - leaving alone)"
                continue
            }
            # /MIR deletes anything in the destination that is not in the source.
            # install.sh cannot lose data this way (it symlinks), so say what would
            # go rather than destroying a hand-added file without a word.
            $extra = @(Get-ExtraTargetFiles -Src $src -Dst $dst)
            if ($extra.Count -gt 0) {
                Write-Host "  WARNING: $dst holds $($extra.Count) file(s) not in the kit - /MIR would delete them:"
                foreach ($e in $extra) { Write-Host "             $e" }
                $go = if ($noPrompt) { 'n' } else { Read-Host '           Delete them and re-sync? [y/N]' }
                if ($go -notmatch '^[Yy]') {
                    Write-Host "  skip  -> $dst (left alone - move them into the kit, or delete them, then re-run)"
                    # Still ours: keep it claimed so pruning works if the kit drops it.
                    $newManifest += $name
                    continue
                }
            }
            robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
            Write-Host "  synced -> $dst"
            $newManifest += $name
        }
        $manifestText = if ($newManifest.Count -gt 0) { ($newManifest -join "`n") + "`n" } else { '' }
        [System.IO.File]::WriteAllText($skillsManifest, $manifestText)
    }

    function Sync-Memory {
        New-Item -ItemType Directory -Force -Path $memorySrcDir | Out-Null
        $projectsDir = Join-Path $globalClaudeDir 'projects'
        if (-not (Test-Path $projectsDir)) {
            Write-Host "  no $projectsDir - nothing to sync"
            return
        }
        $count = 0
        foreach ($proj in Get-ChildItem -Path $projectsDir -Directory) {
            $live = Join-Path $proj.FullName 'memory'
            if (Test-Path $live) {
                $kitmem = Join-Path $memorySrcDir $proj.Name
                robocopy $live $kitmem /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
                Write-Host "  backed up -> $kitmem (from $live)"
                $count++
            }
        }
        if ($count -eq 0) { Write-Host '  no live project memory found - nothing to sync' }
        else { Write-Host '  (one-way: live -> kit only; the kit does not push back into projects\<slug>\memory)' }
    }

    function Show-Hints {
        Write-Host '  shift-enter.json fragment merged into settings.json. If Shift+Enter still'
        Write-Host "  doesn't insert a newline in your terminal, run /terminal-setup once inside"
        Write-Host "  an interactive Claude Code session."
        Write-Host '  statusLine runs via bash + jq - make sure both are on PATH (e.g. Git for'
        Write-Host '  Windows'' bash; jq via winget install jqlang.jq).'
    }

    function Test-Verification {
        $failed = $false
        Write-Host ''
        Write-Host 'Verification checks'
        Write-Host '-------------------------------'
        $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json

        if ($settings.PSObject.Properties['statusLine'] -and $settings.statusLine) {
            Write-Host '[PASS] (1) statusLine configured'
        }
        else { Write-Host '[FAIL] (1) statusLine missing'; $failed = $true }

        Write-Host '[INFO] (2) /terminal-setup not script-forceable; fallback printed above'

        $haveMode = $settings.permissions.defaultMode
        if ($haveMode -eq $Mode) {
            Write-Host "[PASS] (3) tier '$Permissions' rules + mode '$Mode' applied (defaultMode=$haveMode)"
        }
        else { Write-Host "[FAIL] (3) defaultMode mismatch (have='$haveMode', want='$Mode')"; $failed = $true }

        $pct = $settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
        $win = $settings.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW
        if ($pct -and $win) {
            Write-Host "[PASS] (4) auto-compact env vars set ($pct%, $win tokens)"
        }
        else { Write-Host "[FAIL] (4) auto-compact env vars missing (pct='$pct', win='$win')"; $failed = $true }

        $deny = @($settings.permissions.deny)
        $hasPush = $deny -contains 'Bash(git push *)'
        $hasCommit = $deny -contains 'Bash(git commit *)'
        if ($hasPush -and $hasCommit) {
            Write-Host '[PASS] (5) git push + git commit denied'
        }
        else { Write-Host "[FAIL] (5) git deny rules incomplete (push=$hasPush, commit=$hasCommit)"; $failed = $true }

        if ((Test-Path $claudeMdFile) -and
            ((Get-FileHash $claudeMdFile -Algorithm SHA256).Hash -eq (Get-FileHash $claudeMdSrc -Algorithm SHA256).Hash)) {
            Write-Host '[PASS] (6) .claude/CLAUDE.md matches kit source'
        }
        else { Write-Host "[FAIL] (6) .claude/CLAUDE.md differs from $claudeMdSrc"; $failed = $true }

        $cpd = "$($settings.cleanupPeriodDays)"
        if ($cpd -eq $CleanupPeriodDays) {
            Write-Host "[PASS] (8) cleanupPeriodDays=$cpd"
        }
        else { Write-Host "[FAIL] (8) cleanupPeriodDays mismatch (have='$cpd', want='$CleanupPeriodDays')"; $failed = $true }

        $slr = if ($settings.statusLine.PSObject.Properties['refreshInterval']) { "$($settings.statusLine.refreshInterval)" } else { '0' }
        if ($slr -eq $StatuslineRefresh) {
            Write-Host "[PASS] (9) statusLine.refreshInterval=${slr}s"
        }
        else { Write-Host "[FAIL] (9) statusLine.refreshInterval mismatch (have='$slr', want='$StatuslineRefresh')"; $failed = $true }

        Write-Host '-------------------------------'
        if (-not $failed) {
            Write-Host 'All scriptable checks passed.'
        }
        else {
            Write-Host 'One or more checks failed - see above.'
            return $false
        }
        return $true
    }

    function Show-Summary {
        Write-Host ''
        Write-Host 'Summary'
        Write-Host '-------------------------------'
        Write-Host "  tier        : $Permissions  (allow/ask/deny rule-set)"
        Write-Host "  mode        : $Mode  (permissions.defaultMode)"
        Write-Host "  settings    : $settingsFile  (backup: $settingsBak)"
        Write-Host "  statusline  : $statuslineFile  (copied from $statuslineSrc; refresh $(if ($StatuslineRefresh -eq '0') { 'on events only' } else { "every ${StatuslineRefresh}s + events" }))"
        Write-Host "  guidelines  : $claudeMdFile  (copied from $claudeMdSrc)"
        Write-Host "  skills      : $claudeSkillsDir\  (copied from $skillsSrcDir)"
        Write-Host "  memory      : $globalClaudeDir\projects\<project>\memory  (backed up into $memorySrcDir, one-way)"
        Write-Host "  autocompact : $AutocompactPct% / $AutocompactWindow tokens"
        Write-Host "  retention   : cleanupPeriodDays=$CleanupPeriodDays"
        Write-Host '-------------------------------'
    }

    ###########################################################################
    ### EXECUTION
    ###########################################################################

    Write-Host ''
    if ($NoUpdate) {
        Write-Host 'Skipping Claude Code CLI install/update (-NoUpdate)...'
    }
    else {
        Write-Host 'Installing/updating Claude Code CLI...'
        Update-Claude
    }
    Write-Host "[Done]`n"

    Write-Host 'Ensuring settings.json exists...'
    if (-not (Test-Path $settingsFile)) {
        Set-Content -Path $settingsFile -Value '{}'
        Write-Host "  created fresh -> $settingsFile"
    }
    Write-Host "[Done]`n"

    Write-Host 'Copying statusline script...'
    Copy-KitFile -Src $statuslineSrc -Dst $statuslineFile -Bak $statuslineBak -Label 'statusline.sh'
    Write-Host "[Done]`n"

    Write-Host 'Merging statusLine + env + permissions into settings.json...'
    Merge-Settings
    Write-Host "[Done]`n"

    Write-Host 'Copying .claude/CLAUDE.md from kit source...'
    Copy-KitFile -Src $claudeMdSrc -Dst $claudeMdFile -Bak $claudeMdBak -Label '.claude/CLAUDE.md'
    Write-Host "[Done]`n"

    if ($SkillsAuto) { Write-Host "Setting skill auto-invocation state ($SkillsAuto)..." }
    else { Write-Host 'Checking skill auto-invocation state...' }
    Set-SkillsInvocation
    Write-Host "[Done]`n"

    Write-Host 'Copying skills into .claude/skills/...'
    Sync-Skills
    Write-Host "[Done]`n"

    Write-Host 'Backing up project memory into the kit (memory/)...'
    Sync-Memory
    Write-Host "[Done]`n"

    Write-Host 'Shift+Enter / terminal setup...'
    Show-Hints
    Write-Host "[Done]`n"

    Show-Summary

    $verifyOk = Test-Verification

    Write-Host ''
    Write-Host '**************************************************'
    Write-Host '*************** INSTALL COMPLETE *****************'
    Write-Host '**************************************************'

    if (-not $verifyOk) { exit 1 }
    exit 0
}
catch {
    Invoke-Abort
    Write-Error $_
    exit 1
}
