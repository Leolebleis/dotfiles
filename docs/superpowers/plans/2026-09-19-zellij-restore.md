# Zellij Restore (Windows) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a fresh Windows Terminal window restore the `main` Zellij session after a reboot with every tab, pane and cwd intact, and every Claude Code pane resuming its conversation.

**Architecture:** A single pwsh script (`zellij-restore.ps1`) owns session startup. It reads Zellij's own serialized layout for the dead session, rewrites the `command=` panes (claude panes get wrapped in `pwsh -NoExit -Command "claude ... --continue"`, everything else becomes a plain shell pane), then relaunches `main` from the rewritten layout. The PowerShell profile calls it instead of `zellij attach -f -c main`. The layout rewrite is a pure function tested with a plain pwsh assertion script (no Pester) that runs locally and in CI.

**Tech Stack:** PowerShell 7, Zellij 0.44.3 (Windows), chezmoi, GitHub Actions.

**Spec:** `docs/superpowers/research/2026-09-19-zellij-restore-windows.md`

## Global Constraints

- Windows-only wiring: the profile lives under `Documents/PowerShell/` which `.chezmoiignore` already restricts to Windows. The script itself is pwsh-portable but only invoked from that profile.
- No long-lived helper processes inside a pane (the serializer wedges on hook children). The script exits by handing the console to `zellij`.
- Never rely on Zellij's serialized `command=` values; only cwd, size, focus, tab names and plugin panes are trusted.
- Keep `session_serialization true`, `serialize_pane_viewport true` in `dot_config/zellij/config.kdl.tmpl` (unchanged).
- Repo conventions: LF endings (`.gitattributes`), no emojis, `.chezmoiignore` must exclude `tests/**`, plan and docs go under `docs/` (already ignored by chezmoi).
- On the Pi this repo is the live chezmoi source and the hourly timer pulls whatever branch is checked out: do the work on a branch, and check `main` back out when done.

---

### Task 1: Layout rewrite function with tests

**Files:**
- Create: `dot_config/zellij/plugins/zellij-restore.ps1`
- Create: `tests/fixtures/poisoned-session-layout.kdl`
- Create: `tests/zellij-restore.tests.ps1`
- Modify: `.chezmoiignore` (add `tests/**`)

**Interfaces:**
- Produces: `Convert-ZellijLayoutForRestore -Lines [string[]] -> [string[]]` (pure; input is the serialized layout split into lines, output is the rewritten layout lines).
- Produces: `Get-ClaudeRestoreArgs -ArgList [string[]] -> [string]` (`$Args` is a PowerShell automatic variable, so the parameter is `ArgList`) (strips `--continue`, `--resume [value]`, `--session-id <value>` from serialized claude args and appends `--continue`; returns the joined argument string).
- Produces: dot-source guard: when `$env:ZELLIJ_RESTORE_LIBRARY` is set the script defines functions and returns without running `Invoke-ZellijRestore`.

- [ ] **Step 1: Save the fixture**

Copy the poisoned layout captured on 2026-09-19 into `tests/fixtures/poisoned-session-layout.kdl`:

```kdl
layout {
    cwd "C:\\Users\\leole\\Documents\\code"
    tab name="WoW" hide_floating_panes=true {
        pane command="C:\\Users\\leole\\AppData\\Local\\Programs\\Python\\Python314\\Scripts\\uv.EXE" cwd="personal" {
            args "tool" "uvx" "workspace-mcp" "--tools" "tasks"
            start_suspended true
        }
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
    }
    tab name="minecraft" focus=true hide_floating_panes=true {
        pane split_direction="vertical" {
            pane command="C:\\Users\\leole\\AppData\\Local\\Programs\\Python\\Python314\\Scripts\\uv.EXE" cwd="disqt.com\\minecraft-server" size="48%" {
                args "tool" "uvx" "workspace-mcp" "--tools" "tasks"
                start_suspended true
            }
            pane command="C:\\Users\\leole\\.local\\bin\\claude.exe" cwd="personal\\dotfiles" focus=true size="51%" {
                args "--dangerously-skip-permissions"
                start_suspended true
            }
        }
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
    }
    new_tab_template {
        pane cwd="C:\\Users\\leole"
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
    }
}
```

- [ ] **Step 2: Write the failing tests**

`tests/zellij-restore.tests.ps1`:

```powershell
#Requires -Version 7
# Plain assertion tests for zellij-restore.ps1 (no Pester dependency).
# Run: pwsh -NoProfile -File tests/zellij-restore.tests.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:ZELLIJ_RESTORE_LIBRARY = '1'
. (Join-Path $root 'dot_config/zellij/plugins/zellij-restore.ps1')

$script:failures = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { Write-Host "  ok   $Message" }
    else { Write-Host "  FAIL $Message"; $script:failures++ }
}

Write-Host 'Get-ClaudeRestoreArgs'
Assert-True ((Get-ClaudeRestoreArgs @()) -eq '--continue') 'no args -> --continue'
Assert-True ((Get-ClaudeRestoreArgs @('--dangerously-skip-permissions')) -eq '--dangerously-skip-permissions --continue') 'keeps unrelated flags'
Assert-True ((Get-ClaudeRestoreArgs @('--dangerously-skip-permissions', '--continue')) -eq '--dangerously-skip-permissions --continue') 'does not duplicate --continue'
Assert-True ((Get-ClaudeRestoreArgs @('--resume', 'abc-123', '--model', 'opus')) -eq '--model opus --continue') 'strips --resume <id>'
Assert-True ((Get-ClaudeRestoreArgs @('--resume')) -eq '--continue') 'strips bare --resume'
Assert-True ((Get-ClaudeRestoreArgs @('--session-id', 'abc-123')) -eq '--continue') 'strips --session-id <id>'

Write-Host 'Convert-ZellijLayoutForRestore (poisoned fixture)'
$fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/poisoned-session-layout.kdl')
$out = Convert-ZellijLayoutForRestore -Lines $fixture
$text = $out -join "`n"
Assert-True (-not ($text -match 'uv\.EXE')) 'MCP server command removed'
Assert-True (-not ($text -match 'start_suspended')) 'no start_suspended left'
Assert-True (($out | Where-Object { $_ -match '^\s*pane cwd="personal"\s*$' }).Count -eq 1) 'WoW uv pane became a plain shell pane with cwd'
Assert-True (($out | Where-Object { $_ -match '^\s*pane cwd="disqt\.com\\\\minecraft-server" size="48%"\s*$' }).Count -eq 1) 'minecraft uv pane keeps cwd and size'
Assert-True (($out | Where-Object { $_ -match '^\s*pane command="pwsh\.exe" cwd="personal\\\\dotfiles" focus=true size="51%" \{\s*$' }).Count -eq 1) 'claude pane wrapped in pwsh with attributes preserved'
Assert-True (($out | Where-Object { $_ -match '^\s*args "-NoExit" "-Command" "claude --dangerously-skip-permissions --continue"\s*$' }).Count -eq 1) 'claude relaunch args'
Assert-True (($out | Where-Object { $_ -match 'plugin location="zellij:compact-bar"' }).Count -eq 3) 'plugin panes untouched'
Assert-True (($out | Where-Object { $_ -match '^\s*tab name="minecraft" focus=true hide_floating_panes=true \{' }).Count -eq 1) 'tab lines untouched'
Assert-True (($out | Where-Object { $_ -match 'new_tab_template' }).Count -eq 1) 'new_tab_template kept'
$open = ($text.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$close = ($text.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Assert-True ($open -eq $close) "braces balanced ($open/$close)"

Write-Host 'Convert-ZellijLayoutForRestore (edge cases)'
$bare = @('layout {', '    pane command="claude" {', '        start_suspended true', '    }', '}')
$out2 = Convert-ZellijLayoutForRestore -Lines $bare
Assert-True (($out2 | Where-Object { $_ -match '^\s*args "-NoExit" "-Command" "claude --continue"\s*$' }).Count -eq 1) 'bare claude with no args'
$pwshPane = @('layout {', '    pane command="pwsh.exe" cwd="x" {', '        args "-NoExit" "-Command" "claude --continue"', '    }', '}')
$out3 = Convert-ZellijLayoutForRestore -Lines $pwshPane
Assert-True (($out3 | Where-Object { $_ -match '^\s*pane cwd="x"\s*$' }).Count -eq 1) 'pwsh wrapper pane recorded by Zellij becomes a plain shell pane'

if ($script:failures -gt 0) { Write-Host "$($script:failures) failure(s)"; exit 1 }
Write-Host 'all tests passed'
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `pwsh -NoProfile -File tests/zellij-restore.tests.ps1`
Expected: error that the script file does not exist (dot-source fails).

- [ ] **Step 4: Write the library half of the script**

`dot_config/zellij/plugins/zellij-restore.ps1` (functions only; `Invoke-ZellijRestore` is added in Task 2):

```powershell
#Requires -Version 7
<#
.SYNOPSIS
  Start or restore the named Zellij session, fixing up Claude Code panes.

.DESCRIPTION
  Zellij on Windows (0.44.x, still true on main) records a pane's command as
  an arbitrary child of the pane process. For a resurrected claude pane the
  pane process IS claude.exe, so an MCP server child gets recorded instead and
  the next resurrection launches that. Zellij also relaunches resurrected
  commands without a shell, so the pane dies when claude exits.

  This script never trusts the serialized command. It rewrites the dead
  session's cached layout so that:
    - claude panes become  pwsh.exe -NoExit -Command "claude <args> --continue"
      (a shell stays under claude; claude is the shell's only child so the
      next serialization records it correctly; --continue resumes the most
      recent conversation for that pane's cwd)
    - every other command pane becomes a plain shell pane with the same cwd
    - tabs, sizes, focus, plugin panes and new_tab_template pass through
  then deletes the dead session and starts it again from the rewritten layout.

.PARAMETER Session
  Session name. Default: main.

.NOTES
  Dot-source with $env:ZELLIJ_RESTORE_LIBRARY set to load the functions
  without running (used by tests/zellij-restore.tests.ps1).
#>
[CmdletBinding()]
param(
    [string]$Session = 'main'
)

$ErrorActionPreference = 'Stop'

function Get-ClaudeRestoreArgs {
    # Drop any resume-style flag Zellij captured and end with --continue.
    param([string[]]$ArgList = @())
    $kept = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $ArgList.Count) {
        $a = $ArgList[$i]
        if ($a -eq '--continue' -or $a -eq '-c') {
            $i++
            continue
        }
        if ($a -eq '--resume' -or $a -eq '-r' -or $a -eq '--session-id') {
            $i++
            if ($i -lt $ArgList.Count -and -not $ArgList[$i].StartsWith('-')) { $i++ }
            continue
        }
        $kept.Add($a)
        $i++
    }
    $kept.Add('--continue')
    return ($kept -join ' ')
}

function Get-KdlArgs {
    # Parse a serialized `args "a" "b"` line into its string values.
    param([string]$Line)
    $values = [System.Collections.Generic.List[string]]::new()
    foreach ($m in [regex]::Matches($Line, '"((?:[^"\\]|\\.)*)"')) {
        $values.Add(($m.Groups[1].Value -replace '\\"', '"'))
    }
    return $values.ToArray()
}

function Convert-ZellijLayoutForRestore {
    param([Parameter(Mandatory)][string[]]$Lines)
    $out = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        $m = [regex]::Match($line, '^(?<indent>\s*)pane (?<before>.*?)command="(?<cmd>(?:[^"\\]|\\.)*)"\s*(?<after>.*?)\{\s*$')
        if (-not $m.Success) {
            $out.Add($line)
            $i++
            continue
        }
        $indent = $m.Groups['indent'].Value
        $attrs = (($m.Groups['before'].Value + ' ' + $m.Groups['after'].Value) -replace '\s+', ' ').Trim()
        $cmd = $m.Groups['cmd'].Value
        $exe = ($cmd -split '[\\/]')[-1]

        # Collect the block body (serialized command panes are flat: args /
        # start_suspended lines, then the closing brace at the same indent).
        $body = [System.Collections.Generic.List[string]]::new()
        $i++
        while ($i -lt $Lines.Count -and $Lines[$i] -ne "$indent}") {
            $body.Add($Lines[$i])
            $i++
        }
        $i++  # skip closing brace

        if ($exe -match '^claude(\.exe)?$') {
            $argsLine = $body | Where-Object { $_ -match '^\s*args\b' } | Select-Object -First 1
            $claudeArgs = if ($argsLine) { Get-KdlArgs $argsLine } else { @() }
            $relaunch = 'claude ' + (Get-ClaudeRestoreArgs $claudeArgs)
            $header = if ($attrs) { "${indent}pane command=`"pwsh.exe`" $attrs {" } else { "${indent}pane command=`"pwsh.exe`" {" }
            $out.Add($header)
            $out.Add("${indent}    args `"-NoExit`" `"-Command`" `"$relaunch`"")
            $out.Add("${indent}}")
        }
        else {
            # Unknown or misrecorded command: give the pane back as a shell.
            $out.Add($(if ($attrs) { "${indent}pane $attrs" } else { "${indent}pane" }))
        }
    }
    return $out.ToArray()
}

if ($env:ZELLIJ_RESTORE_LIBRARY) { return }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pwsh -NoProfile -File tests/zellij-restore.tests.ps1`
Expected: every line `ok`, final line `all tests passed`, exit code 0.

- [ ] **Step 6: Ignore tests in chezmoi and commit**

Append to `.chezmoiignore` after `.github/**`:

```
tests/**
```

Verify: `chezmoi managed --source . 2>/dev/null | grep -c tests` prints `0` (or run `chezmoi apply --source . --dry-run --verbose` and confirm no `tests/` entries).

```bash
git checkout -b feat/zellij-restore-windows
git add dot_config/zellij/plugins/zellij-restore.ps1 tests/ .chezmoiignore
git commit -m "feat(zellij): layout rewrite for Windows session restore"
```

---

### Task 2: Session startup flow in the script

**Files:**
- Modify: `dot_config/zellij/plugins/zellij-restore.ps1` (append below the library guard)

**Interfaces:**
- Consumes: `Convert-ZellijLayoutForRestore` from Task 1.
- Produces: `Invoke-ZellijRestore -Session <name>` which ends by launching `zellij` in the foreground (attach, restore, or create) and returns its exit code. `Get-ZellijSessionState -Session <name>` returns `'alive'`, `'dead'` or `'missing'`. `Remove-StaleZellijMarker -Session <name>` returns `$true` when it deleted a stale marker.

- [ ] **Step 1: Write the failing tests**

Append to `tests/zellij-restore.tests.ps1` before the final failure check:

```powershell
Write-Host 'Get-ZellijSessionState'
Assert-True ((Get-ZellijSessionState -Session 'main' -ListOutput @('main [Created 3months ago] (current)')) -eq 'alive') 'alive session'
Assert-True ((Get-ZellijSessionState -Session 'main' -ListOutput @('main [Created 1day ago] (EXITED - attach to resurrect)')) -eq 'dead') 'exited session'
Assert-True ((Get-ZellijSessionState -Session 'main' -ListOutput @('other [Created 1day ago]')) -eq 'missing') 'missing session'
Assert-True ((Get-ZellijSessionState -Session 'main' -ListOutput @('maintenance [Created 1day ago]')) -eq 'missing') 'prefix does not match'
Assert-True ((Get-ZellijSessionState -Session 'main' -ListOutput @()) -eq 'missing') 'no sessions'

Write-Host 'Remove-StaleZellijMarker'
$markerDir = Join-Path ([System.IO.Path]::GetTempPath()) ("zellij-restore-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $markerDir | Out-Null
Set-Content -Path (Join-Path $markerDir 'main') -Value '999999' -NoNewline
Assert-True ((Remove-StaleZellijMarker -Session 'main' -MarkerDir $markerDir) -eq $true) 'removes marker whose pid is not a zellij process'
Assert-True (-not (Test-Path (Join-Path $markerDir 'main'))) 'marker file gone'
Set-Content -Path (Join-Path $markerDir 'main') -Value "$PID" -NoNewline
Assert-True ((Remove-StaleZellijMarker -Session 'main' -MarkerDir $markerDir -ProcessName 'pwsh') -eq $false) 'keeps marker whose pid is a live matching process'
Remove-Item -Recurse -Force $markerDir
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pwsh -NoProfile -File tests/zellij-restore.tests.ps1`
Expected: FAIL with `Get-ZellijSessionState` not recognized.

- [ ] **Step 3: Implement the startup flow**

Insert these functions *above* the `if ($env:ZELLIJ_RESTORE_LIBRARY) { return }` line, and add the main call after it:

```powershell
function Get-ZellijSessionState {
    # 'alive' | 'dead' | 'missing' from `zellij list-sessions --no-formatting`.
    param(
        [Parameter(Mandatory)][string]$Session,
        [string[]]$ListOutput = $null
    )
    if ($null -eq $ListOutput) {
        $ListOutput = @(& zellij list-sessions --no-formatting 2>$null)
    }
    $escaped = [regex]::Escape($Session)
    $line = $ListOutput | Where-Object { $_ -match "^$escaped\s" } | Select-Object -First 1
    if (-not $line) { return 'missing' }
    if ($line -match 'EXITED') { return 'dead' }
    return 'alive'
}

function Remove-StaleZellijMarker {
    # zellij-org/zellij#5580: after an unclean shutdown the session marker
    # (which holds the server PID) survives; if that PID is reused, attach
    # hangs forever. Delete the marker when no zellij process owns the PID.
    param(
        [Parameter(Mandatory)][string]$Session,
        [string]$MarkerDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'zellij/contract_version_1'),
        [string]$ProcessName = 'zellij'
    )
    $marker = Join-Path $MarkerDir $Session
    if (-not (Test-Path -LiteralPath $marker)) { return $false }
    $raw = (Get-Content -LiteralPath $marker -Raw -ErrorAction SilentlyContinue)
    $pidValue = 0
    if ([int]::TryParse(($raw ?? '').Trim(), [ref]$pidValue)) {
        $proc = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -like "$ProcessName*") { return $false }
    }
    Remove-Item -LiteralPath $marker -Force
    Write-Host "zellij-restore: removed stale session marker for '$Session'"
    return $true
}

function Get-ZellijSessionLayoutPath {
    param([Parameter(Mandatory)][string]$Session)
    $cacheRoot = if ($IsWindows) { Join-Path $env:LOCALAPPDATA 'zellij/cache' } else { Join-Path $HOME '.cache/zellij' }
    return Join-Path $cacheRoot "contract_version_1/session_info/$Session/session-layout.kdl"
}

function Invoke-ZellijRestore {
    param([Parameter(Mandatory)][string]$Session)
    if (-not (Get-Command zellij -ErrorAction SilentlyContinue)) {
        Write-Host 'zellij-restore: zellij not on PATH'
        return 1
    }
    if ($IsWindows) { Remove-StaleZellijMarker -Session $Session | Out-Null }

    switch (Get-ZellijSessionState -Session $Session) {
        'alive' {
            & zellij attach $Session
            return $LASTEXITCODE
        }
        'missing' {
            & zellij --session $Session
            return $LASTEXITCODE
        }
        'dead' {
            $src = Get-ZellijSessionLayoutPath -Session $Session
            if (-not (Test-Path -LiteralPath $src)) {
                # Nothing to rewrite; let Zellij do its own resurrection.
                & zellij attach $Session
                return $LASTEXITCODE
            }
            $workDir = Join-Path ([System.IO.Path]::GetTempPath()) 'zellij-restore'
            New-Item -ItemType Directory -Force -Path $workDir | Out-Null
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            Copy-Item -LiteralPath $src -Destination (Join-Path $workDir "$Session.$stamp.orig.kdl")
            $restored = Join-Path $workDir "$Session.kdl"
            $lines = Get-Content -LiteralPath $src
            Set-Content -LiteralPath $restored -Value (Convert-ZellijLayoutForRestore -Lines $lines) -Encoding utf8NoBOM
            & zellij delete-session $Session | Out-Null
            & zellij --session $Session --new-session-with-layout $restored
            return $LASTEXITCODE
        }
    }
}
```

and, after the guard line at the bottom of the file:

```powershell
exit (Invoke-ZellijRestore -Session $Session)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pwsh -NoProfile -File tests/zellij-restore.tests.ps1`
Expected: all `ok`, exit 0.

- [ ] **Step 5: Manual verification in an isolated session (do not touch `main`)**

Per memory `zellij-debug-lessons`: never test resurrection against the live config from this shell; use an isolated `--config-dir`.

```powershell
$dbg = "$env:LOCALAPPDATA\Temp\zellij-restore-dbg"
New-Item -ItemType Directory -Force "$dbg\layouts" | Out-Null
Copy-Item "$HOME\.config\zellij\layouts\clean.kdl" "$dbg\layouts\"
@'
default_shell "pwsh.exe"
default_layout "clean"
session_serialization true
'@ | Set-Content "$dbg\config.kdl"
# 1. Rewrite the real poisoned layout into a test layout and validate it parses:
$env:ZELLIJ_RESTORE_LIBRARY = '1'
. "$HOME\.config\zellij\plugins\zellij-restore.ps1"
Set-Content "$dbg\layouts\restored.kdl" -Value (Convert-ZellijLayoutForRestore -Lines (Get-Content (Get-ZellijSessionLayoutPath -Session main)))
(Get-Content "$dbg\config.kdl") -replace 'default_layout "clean"', 'default_layout "restored"' | Set-Content "$dbg\config.kdl"
zellij --config-dir $dbg setup --check   # must print the config without a parse error
# 2. From a NEW Windows Terminal tab (not inside Zellij, not this Claude pane):
#    zellij --config-dir $dbg --session restore-dbg --new-session-with-layout "$dbg\layouts\restored.kdl"
#    Expect: WoW tab with a pwsh prompt in personal/; minecraft tab with pwsh
#    in minecraft-server/ and a claude pane resuming in personal/dotfiles.
#    Quit claude with /exit: the pane must drop to a pwsh prompt, not die.
#    Then: zellij --config-dir $dbg kill-session restore-dbg; zellij --config-dir $dbg delete-session restore-dbg
```

- [ ] **Step 6: Commit**

```bash
git add dot_config/zellij/plugins/zellij-restore.ps1 tests/zellij-restore.tests.ps1
git commit -m "feat(zellij): restore dead session from rewritten layout"
```

---

### Task 3: Wire the profile and CI

**Files:**
- Modify: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (auto-attach block at the bottom)
- Modify: `.github/workflows/ci.yml` (`validate-powershell` job)

**Interfaces:**
- Consumes: `~/.config/zellij/plugins/zellij-restore.ps1 -Session main` from Task 2.

- [ ] **Step 1: Replace the attach line in the profile**

Replace the block:

```powershell
    # -f (force-run-commands): when resurrecting a dead session, run its saved
    # commands immediately instead of leaving them suspended behind the Enter
    # banner. Windows' KKP/ConPTY input layer makes that manual Enter unreliable
    # (resurrected panes hang); -f sidesteps it. No-op on an already-live session.
    zellij attach -f -c main
    exit
```

with:

```powershell
    # zellij-restore.ps1 attaches to a live `main`, or rebuilds a dead one from
    # its serialized layout with claude panes relaunched as
    # `pwsh -NoExit -Command "claude ... --continue"` and every other recorded
    # command dropped to a plain shell. Zellij's own resurrection is not used
    # because on Windows it records an arbitrary child (often an MCP server)
    # as the pane command and relaunches it without a shell. See
    # docs/superpowers/research/2026-09-19-zellij-restore-windows.md.
    $restore = Join-Path $HOME '.config/zellij/plugins/zellij-restore.ps1'
    if (Test-Path $restore) { & $restore -Session main } else { zellij attach -c main }
    exit
```

- [ ] **Step 2: Add the test run to CI**

In `.github/workflows/ci.yml`, job `validate-powershell`, add after the "Parse PowerShell profile" step:

```yaml
      - name: Run zellij-restore tests
        shell: pwsh
        run: pwsh -NoProfile -File tests/zellij-restore.tests.ps1
```

- [ ] **Step 3: Verify the profile parses and chezmoi renders**

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile("$PWD/Documents/PowerShell/Microsoft.PowerShell_profile.ps1", [ref]$null, [ref]$errors) | Out-Null
$errors.Count   # expect 0
chezmoi apply --source . --dry-run --verbose 2>&1 | Select-String 'zellij-restore|PowerShell_profile'
```
Expected: two lines showing the script and profile would be written, nothing under `tests/`.

- [ ] **Step 4: Commit**

```bash
git add Documents/PowerShell/Microsoft.PowerShell_profile.ps1 .github/workflows/ci.yml
git commit -m "feat(zellij): start main via zellij-restore from the pwsh profile"
```

---

### Task 4: Docs and cleanup

**Files:**
- Modify: `docs/windows-status.md` (add a "Session restore" section under "What works")
- Modify: `docs/sessions.md` (Session Resurrection section: Windows note)
- Modify: `CLAUDE.md` (Quick Reference item 12)
- Modify: `dot_config/zellij/config.kdl.tmpl` (update the disabled-hook comment)

- [ ] **Step 1: windows-status.md**

Add under "## What works":

```markdown
- **Session restore after reboot** goes through `~/.config/zellij/plugins/zellij-restore.ps1` (called from the profile), not `zellij attach -f`. Zellij's Windows command discovery records an arbitrary child of the pane process, so a resurrected claude pane (which has no shell) gets serialized as one of its MCP servers; the script rewrites the cached layout instead (claude panes -> `pwsh -NoExit -Command "claude ... --continue"`, other commands -> plain shell) and relaunches `main` from it. Also clears the stale session marker from zellij-org/zellij#5580. Research: `docs/superpowers/research/2026-09-19-zellij-restore-windows.md`. Tests: `tests/zellij-restore.tests.ps1`.
```

- [ ] **Step 2: sessions.md**

Add after the `--force-run-commands` example:

```markdown
**Windows note:** command discovery on Windows is ppid-based and records an arbitrary child of the pane process (zellij-org/zellij#4873; fixed for Unix only in 0.45.0). This setup does not rely on it: the pwsh profile runs `zellij-restore.ps1`, which rewrites the serialized layout before relaunching. See `docs/windows-status.md`.
```

- [ ] **Step 3: CLAUDE.md quick reference item 12**

Replace:

```markdown
12. **Session resurrection**: on by default (`session_serialization true`); sessions survive reboot
```

with:

```markdown
12. **Session resurrection**: on by default (`session_serialization true`); on Windows the profile restores `main` through `zellij-restore.ps1` (claude panes resume with `--continue`, other recorded commands drop to a shell) because Zellij's own resurrection records the wrong command there
```

- [ ] **Step 4: config.kdl.tmpl comment**

Replace the Windows comment block above the commented-out `post_command_discovery_hook` line with:

```kdl
// Disabled 2026-06-09: wedges Zellij 0.44.3 Windows within minutes of any session
// start -- serialization never completes, route actions time out, clients get
// kicked ("1000 consecutive unknown messages"), pty thread panics on teardown.
// Superseded on Windows by plugins/zellij-restore.ps1 (profile-driven restore
// that rewrites the serialized layout instead of hooking discovery).
```

- [ ] **Step 5: Verify CI checks still pass locally, commit, and return to main**

```bash
chezmoi execute-template < dot_config/zellij/config.kdl.tmpl > /tmp/zj-config.kdl && head -3 /tmp/zj-config.kdl
git add docs/windows-status.md docs/sessions.md CLAUDE.md dot_config/zellij/config.kdl.tmpl docs/superpowers/
git commit -m "docs(zellij): document Windows session restore path"
```

Then open the PR (suggest `/simplify` first per session guidance) and `git checkout main` so the Pi timer keeps pulling main.
