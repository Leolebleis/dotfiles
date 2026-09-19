#Requires -Version 7
<#
.SYNOPSIS
  Start or restore the named Zellij session, fixing up Claude Code panes.
  Windows-only: Unix keeps Zellij's own resurrection plus the
  post_command_discovery_hook shell script.

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
  Dot-sourcing the script loads the functions without running anything
  (used by tests/zellij-restore.tests.ps1).
#>
[CmdletBinding()]
param(
    [string]$Session = 'main'
)

$ErrorActionPreference = 'Stop'

function Get-KdlArgs {
    # Raw KDL string bodies, still escaped: they are re-emitted as KDL.
    param([string]$Line)
    return @([regex]::Matches($Line, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value })
}

function Get-ClaudeRestoreArgs {
    # Drop resume-style flags Zellij captured (from an older launch or a
    # previous restore) and end with --continue. Each token is single-quoted
    # so pwsh -Command passes it through unchanged.
    param([string[]]$ArgList = @())
    $kept = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $ArgList.Count; $i++) {
        $a = $ArgList[$i]
        if ($a -in '--continue', '-c') { continue }
        if ($a -in '--resume', '-r', '--session-id') {
            if ($i + 1 -lt $ArgList.Count -and -not $ArgList[$i + 1].StartsWith('-')) { $i++ }
            continue
        }
        $kept.Add($a)
    }
    $kept.Add('--continue')
    return (($kept | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ' ')
}

function Convert-ZellijLayoutForRestore {
    param([Parameter(Mandatory)][string[]]$Lines)
    $paneRe = [regex]'^(?<indent>\s*)pane (?<before>.*?)command="(?<cmd>(?:[^"\\]|\\.)*)"\s*(?<after>.*?)(?<open>\{)?\s*$'
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $m = $paneRe.Match($Lines[$i])
        if (-not $m.Success) {
            $out.Add($Lines[$i])
            continue
        }
        $indent = $m.Groups['indent'].Value
        $attrs = ("$($m.Groups['before'].Value) $($m.Groups['after'].Value)".Trim() -replace '\s+', ' ')
        if ($attrs) { $attrs = " $attrs" }

        # A held command pane's body is flat (args / start_suspended lines)
        # and closes with a brace at the same indent.
        $body = [System.Collections.Generic.List[string]]::new()
        if ($m.Groups['open'].Success) {
            while (++$i -lt $Lines.Count -and $Lines[$i] -ne "$indent}") { $body.Add($Lines[$i]) }
        }

        if ($m.Groups['cmd'].Value -match '(^|[\\/])claude(\.exe)?$') {
            $claudeArgs = Get-KdlArgs ($body -match '^\s*args\b' | Select-Object -First 1)
            $relaunch = 'claude ' + (Get-ClaudeRestoreArgs $claudeArgs)
            $out.Add("${indent}pane command=`"pwsh.exe`"$attrs {")
            $out.Add("${indent}    args `"-NoExit`" `"-Command`" `"$relaunch`"")
            $out.Add("${indent}}")
        }
        else {
            # Unknown or misrecorded command: give the pane back as a shell.
            $out.Add("${indent}pane$attrs")
        }
    }
    return $out.ToArray()
}

function Test-ZellijSessionAlive {
    # `list-sessions --no-formatting` is the only CLI probe that marks dead
    # sessions (`--short` drops the EXITED tag).
    param(
        [Parameter(Mandatory)][string]$Session,
        [string[]]$ListOutput = @(& zellij list-sessions --no-formatting 2>$null)
    )
    $line = $ListOutput -match "^$([regex]::Escape($Session))\s" | Select-Object -First 1
    return [bool]($line -and $line -notmatch 'EXITED')
}

function Remove-StaleZellijMarker {
    # zellij-org/zellij#5580: after an unclean shutdown the session marker
    # (which holds the server PID) survives; if that PID is reused, attach
    # hangs forever. Delete the marker when no zellij process owns the PID.
    param(
        [Parameter(Mandatory)][string]$Session,
        [string]$MarkerDir = (Join-Path $env:TEMP 'zellij/contract_version_1'),
        [string]$ProcessName = 'zellij'
    )
    $marker = Join-Path $MarkerDir $Session
    if (-not (Test-Path -LiteralPath $marker)) { return $false }
    $markerPid = (Get-Content -LiteralPath $marker -Raw) -as [int]
    if ($markerPid) {
        try { $name = [System.Diagnostics.Process]::GetProcessById($markerPid).ProcessName } catch { $name = $null }
        if ($name -like "$ProcessName*") { return $false }
    }
    Remove-Item -LiteralPath $marker -Force
    Write-Host "zellij-restore: removed stale session marker for '$Session'"
    return $true
}

function Get-ZellijSessionLayoutPath {
    param([Parameter(Mandatory)][string]$Session)
    return Join-Path $env:LOCALAPPDATA "zellij/cache/contract_version_1/session_info/$Session/session-layout.kdl"
}

function Get-ZellijLaunchArgs {
    # The zellij argument list for this session's state. Writes the rewritten
    # layout (and a backup of the original) under WorkDir when one is needed.
    param(
        [Parameter(Mandatory)][string]$Session,
        [Parameter(Mandatory)][bool]$Alive,
        [Parameter(Mandatory)][string]$LayoutPath,
        [Parameter(Mandatory)][string]$WorkDir
    )
    if ($Alive) { return @('attach', $Session) }
    if (-not (Test-Path -LiteralPath $LayoutPath)) { return @('--session', $Session) }

    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $lines = Get-Content -LiteralPath $LayoutPath
    Set-Content -LiteralPath (Join-Path $WorkDir "$Session.$(Get-Date -Format 'yyyyMMdd-HHmmss').orig.kdl") -Value $lines
    $restored = Join-Path $WorkDir "$Session.kdl"
    Set-Content -LiteralPath $restored -Value (Convert-ZellijLayoutForRestore -Lines $lines) -Encoding utf8NoBOM
    return @('--session', $Session, '--new-session-with-layout', $restored)
}

if ($MyInvocation.InvocationName -eq '.') { return }  # dot-sourced: library only

Remove-StaleZellijMarker -Session $Session | Out-Null
$alive = Test-ZellijSessionAlive -Session $Session
$zellijArgs = Get-ZellijLaunchArgs -Session $Session -Alive $alive `
    -LayoutPath (Get-ZellijSessionLayoutPath -Session $Session) `
    -WorkDir (Join-Path $env:TEMP 'zellij-restore')
if (-not $alive) {
    # A dead session's name cannot be reused until it is deleted (this also
    # drops its cached layout, already backed up). Harmless when absent.
    & zellij delete-session $Session 2>$null | Out-Null
}
# zellij must run at the top level: inside a function whose output is
# consumed (e.g. `exit (f)`), PowerShell captures its stdout and the client
# paints into a variable instead of the terminal.
& zellij @zellijArgs
exit $LASTEXITCODE
