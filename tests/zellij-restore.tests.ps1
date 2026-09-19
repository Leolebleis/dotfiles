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

if ($script:failures -gt 0) { Write-Host "$($script:failures) failure(s)"; exit 1 }
Write-Host 'all tests passed'
