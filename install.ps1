#Requires -Version 5.1
<#
.SYNOPSIS
  Windows/PowerShell equivalent of install.sh - configures a project-local
  .claude directory from this kit, interactively.
.DESCRIPTION
  The kit lives in a subfolder (this claude-kit-test directory) of the repo it
  configures. By default the script installs into the .claude of the folder ONE
  LEVEL ABOVE the kit - i.e. the repo root - so it is reusable across colleagues
  and checkouts. The first prompt shows the resolved target and lets you accept
  it or type a different path.

  It is fully interactive - there are no command-line flags. Running the script
  asks, in order: install target, permission tier, session start mode, and skill
  auto-invocation, then installs. Advanced knobs stay as env overrides (see
  below); each has a sensible default and is not prompted for.

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
  .claude until you re-run this script.

  The statusLine command stays "bash <path>\statusline.sh" (unchanged script),
  which needs bash + jq on PATH - e.g. Git for Windows' bash (jq isn't bundled;
  `winget install jqlang.jq` or `choco install jq`).

  Env overrides (same names as install.sh): DEFAULT_MODE, CLEANUP_PERIOD_DAYS,
  STATUSLINE_REFRESH, AUTOCOMPACT_PCT, AUTOCOMPACT_WINDOW, FIVE_HOUR_BUDGET,
  WEEKLY_BUDGET.
#>
[CmdletBinding()]
param()

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
    $claudeMdSrc = Join-Path $kitRoot 'claude-md\CLAUDE.md'
    $statuslineSrc = Join-Path $kitRoot 'settings\statusline.sh'

    # Live project memory is stored under the user-global ~/.claude/projects/<slug>/memory
    # regardless of project scope - a separate concern from the settings target below.
    $globalClaudeDir = Join-Path $env:USERPROFILE '.claude'

    ###########################################################################
    ### PROMPTS
    ###########################################################################

    Write-Host ''
    Write-Host 'claude-kit installer'
    Write-Host '-------------------------------'

    # 1) Install target - defaults to the .claude of the folder the kit sits in
    #    (i.e. the repo root, one level above this claude-kit-test folder).
    $defaultTarget = Join-Path (Split-Path $kitRoot -Parent) '.claude'
    Write-Host 'This kit installs into a project-local .claude directory.'
    $answer = Read-Host "Install target [$defaultTarget]"
    $claudeDir = if ([string]::IsNullOrWhiteSpace($answer)) { $defaultTarget } else { $answer.Trim() }

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
    Write-Host ''
    Write-Host 'Choose permission tier: [1] ultra-safe  [2] standard (default)  [3] trusted  [4] yolo'
    $choice = Read-Host 'Selection [2]'
    switch ($choice) {
        { $_ -in '1', 'ultra-safe' } { $Permissions = 'ultra-safe' }
        { $_ -in '3', 'trusted' } { $Permissions = 'trusted' }
        { $_ -in '4', 'yolo' } { $Permissions = 'yolo' }
        default { $Permissions = 'standard' }
    }
    Write-Host "Tier: $Permissions [OK]"
    if ($Permissions -eq 'yolo') {
        Write-Host "  WARNING: 'yolo' tier allows reads of .env/.ssh without prompting."
        Write-Host '           (git push/commit + rm -rf are still denied - hard floor.)'
        Write-Host '           Run only inside a throwaway container/VM.'
    }

    # 3) Session start mode.
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
    Write-Host "Mode: $Mode [OK]"
    if ($Mode -eq 'bypassPermissions') {
        Write-Host "  WARNING: 'bypassPermissions' skips ALL permission checks - the widest mode"
        Write-Host '           Claude Code has. Run only inside a throwaway container/VM.'
    }

    # 4) Skill auto-invocation.
    Write-Host ''
    Write-Host 'Allow kit skills to auto-invoke? [1] off (default)  [2] on'
    $skillsChoice = Read-Host 'Selection [1]'
    switch ($skillsChoice) {
        { $_ -in '2', 'on' } { $SkillsAuto = 'on' }
        default { $SkillsAuto = 'off' }
    }
    Write-Host "Skills auto-invocation: $SkillsAuto [OK]"

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
            Write-Host '  claude CLI not on PATH - skipping update'
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

    function Set-SkillsInvocation {
        if (-not (Test-Path $skillsSrcDir)) {
            Write-Host '  no skills\ dir in kit - skipped'
            return
        }
        if ($SkillsAuto -eq 'on') { $from = 'true'; $to = 'false' } else { $from = 'false'; $to = 'true' }
        $changed = 0
        foreach ($dir in Get-ChildItem -Path $skillsSrcDir -Directory) {
            $skillMd = Join-Path $dir.FullName 'SKILL.md'
            if (-not (Test-Path $skillMd)) { continue }
            $lines = @(Get-Content $skillMd)
            if ($lines.Count -lt 2 -or $lines[0] -ne '---') { continue }
            $closeIdx = -1
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -eq '---') { $closeIdx = $i; break }
            }
            if ($closeIdx -lt 0) { continue }
            $target = "disable-model-invocation: $from"
            $replacement = "disable-model-invocation: $to"
            $modified = $false
            for ($i = 1; $i -lt $closeIdx; $i++) {
                if ($lines[$i] -eq $target) {
                    $lines[$i] = $replacement
                    $modified = $true
                }
            }
            if ($modified) {
                Set-Content -Path $skillMd -Value $lines
                Write-Host "  $from->$to  $($skillMd.Substring($kitRoot.Length + 1))"
                $changed++
            }
        }
        if ($changed -eq 0) {
            if ($SkillsAuto -eq 'on') { Write-Host '  all flagged skills already auto-invokable - no change' }
            else { Write-Host '  all flagged skills already manual - no change' }
        }
        else {
            Write-Host "  flipped $changed skill(s) to auto-invocation $SkillsAuto"
            Write-Host '  restart Claude Code to pick up the change (skills bind at session start)'
        }
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
            robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
            Write-Host "  synced -> $dst"
            $newManifest += $name
        }
        Set-Content -Path $skillsManifest -Value $newManifest
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
    Write-Host 'Updating Claude Code CLI (claude update)...'
    Update-Claude
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

    Write-Host "Ensuring skill auto-invocation state ($SkillsAuto)..."
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
