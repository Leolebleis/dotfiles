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

  Research: docs/superpowers/research/2026-09-19-zellij-restore-windows.md
  (dotfiles repo). Upstream bug: zellij-org/zellij#4873.

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

if ($env:ZELLIJ_RESTORE_LIBRARY) { return }

exit (Invoke-ZellijRestore -Session $Session)
