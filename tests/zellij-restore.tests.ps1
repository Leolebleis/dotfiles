#Requires -Version 7
# Plain assertion tests for zellij-restore.ps1 (no Pester dependency).
# Run: pwsh -NoProfile -File tests/zellij-restore.tests.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'dot_config/zellij/plugins/zellij-restore.ps1')

$script:failures = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { Write-Host "  ok   $Message" }
    else { Write-Host "  FAIL $Message"; $script:failures++ }
}

Write-Host 'Get-ClaudeRestoreArgs'
Assert-True ((Get-ClaudeRestoreArgs @()) -eq "'--continue'") 'no args -> --continue'
Assert-True ((Get-ClaudeRestoreArgs @('--dangerously-skip-permissions')) -eq "'--dangerously-skip-permissions' '--continue'") 'keeps unrelated flags'
Assert-True ((Get-ClaudeRestoreArgs @('--dangerously-skip-permissions', '--continue')) -eq "'--dangerously-skip-permissions' '--continue'") 'does not duplicate --continue'
Assert-True ((Get-ClaudeRestoreArgs @('--resume', 'abc-123', '--model', 'opus')) -eq "'--model' 'opus' '--continue'") 'strips --resume <id>'
Assert-True ((Get-ClaudeRestoreArgs @('--resume')) -eq "'--continue'") 'strips bare --resume'
Assert-True ((Get-ClaudeRestoreArgs @('--session-id', 'abc-123')) -eq "'--continue'") 'strips --session-id <id>'
Assert-True ((Get-ClaudeRestoreArgs @("it's")) -eq "'it''s' '--continue'") 'escapes single quotes for pwsh'

Write-Host 'Convert-ZellijLayoutForRestore (poisoned fixture)'
$fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/poisoned-session-layout.kdl')
$out = Convert-ZellijLayoutForRestore -Lines $fixture
$text = $out -join "`n"
Assert-True (-not ($text -match 'uv\.EXE')) 'MCP server command removed'
Assert-True (-not ($text -match 'start_suspended')) 'no start_suspended left'
Assert-True (-not ($text -match 'command="(?!pwsh\.exe")')) 'only pwsh wrappers keep command='
Assert-True (($out | Where-Object { $_ -match '^\s*pane cwd="personal"\s*$' }).Count -eq 1) 'WoW uv pane became a plain shell pane with cwd'
Assert-True (($out | Where-Object { $_ -match '^\s*pane cwd="disqt\.com\\\\minecraft-server" size="48%"\s*$' }).Count -eq 1) 'minecraft uv pane keeps cwd and size'
Assert-True (($out | Where-Object { $_ -match '^\s*pane command="pwsh\.exe" cwd="personal\\\\dotfiles" focus=true size="51%" \{\s*$' }).Count -eq 1) 'claude pane wrapped in pwsh with attributes preserved'
Assert-True (($out | Where-Object { $_ -match "^\s*args `"-NoExit`" `"-Command`" `"claude '--dangerously-skip-permissions' '--continue'`"\s*$" }).Count -eq 1) 'claude relaunch args'
Assert-True (($out | Where-Object { $_ -match 'plugin location="zellij:compact-bar"' }).Count -eq 3) 'plugin panes untouched'
Assert-True (($out | Where-Object { $_ -match '^\s*tab name="minecraft" focus=true hide_floating_panes=true \{' }).Count -eq 1) 'tab lines untouched'
Assert-True (($out | Where-Object { $_ -match 'new_tab_template' }).Count -eq 1) 'new_tab_template kept'
$open = [regex]::Matches($text, '\{').Count
$close = [regex]::Matches($text, '\}').Count
Assert-True ($open -eq $close) "braces balanced ($open/$close)"

Write-Host 'Convert-ZellijLayoutForRestore (edge cases)'
$bare = @('layout {', '    pane command="claude" {', '        start_suspended true', '    }', '}')
$out2 = Convert-ZellijLayoutForRestore -Lines $bare
Assert-True (($out2 | Where-Object { $_ -match "^\s*args `"-NoExit`" `"-Command`" `"claude '--continue'`"\s*$" }).Count -eq 1) 'bare claude with no args'
$pwshPane = @('layout {', '    pane command="pwsh.exe" cwd="x" {', '        args "-NoExit" "-Command" "claude --continue"', '    }', '}')
$out3 = Convert-ZellijLayoutForRestore -Lines $pwshPane
Assert-True (($out3 | Where-Object { $_ -match '^\s*pane cwd="x"\s*$' }).Count -eq 1) 'pwsh wrapper pane recorded by Zellij becomes a plain shell pane'
$noBody = @('layout {', '    pane command="claude.exe" cwd="y"', '    pane cwd="z"', '}')
$out4 = Convert-ZellijLayoutForRestore -Lines $noBody
Assert-True (($out4 | Where-Object { $_ -match '^\s*pane command="pwsh\.exe" cwd="y" \{\s*$' }).Count -eq 1) 'body-less claude pane is still wrapped'
Assert-True (($out4 | Where-Object { $_ -match '^\s*pane cwd="z"\s*$' }).Count -eq 1) 'following plain pane untouched'
Assert-True ($out4.Count -eq 6) 'body-less rewrite emits header, args, close'
$escaped = @('layout {', '    pane command="claude" {', '        args "--append-system-prompt" "say \"hi\" to C:\\tmp"', '    }', '}')
$out5 = Convert-ZellijLayoutForRestore -Lines $escaped
Assert-True (($out5 | Where-Object { $_ -match [regex]::Escape('"claude ''--append-system-prompt'' ''say \"hi\" to C:\\tmp'' ''--continue''"') }).Count -eq 1) 'KDL escapes pass through untouched'

Write-Host 'Test-ZellijSessionAlive'
Assert-True ((Test-ZellijSessionAlive -Session 'main' -ListOutput @('main [Created 3months ago] (current)')) -eq $true) 'alive session'
Assert-True ((Test-ZellijSessionAlive -Session 'main' -ListOutput @('main [Created 1day ago] (EXITED - attach to resurrect)')) -eq $false) 'exited session'
Assert-True ((Test-ZellijSessionAlive -Session 'main' -ListOutput @('other [Created 1day ago]')) -eq $false) 'missing session'
Assert-True ((Test-ZellijSessionAlive -Session 'main' -ListOutput @('maintenance [Created 1day ago]')) -eq $false) 'prefix does not match'
Assert-True ((Test-ZellijSessionAlive -Session 'main' -ListOutput @()) -eq $false) 'no sessions'

Write-Host 'Remove-StaleZellijMarker'
$markerDir = Join-Path $env:TEMP ("zellij-restore-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $markerDir | Out-Null
Set-Content -Path (Join-Path $markerDir 'main') -Value '999999' -NoNewline
Assert-True ((Remove-StaleZellijMarker -Session 'main' -MarkerDir $markerDir) -eq $true) 'removes marker whose pid is not a zellij process'
Assert-True (-not (Test-Path (Join-Path $markerDir 'main'))) 'marker file gone'
Set-Content -Path (Join-Path $markerDir 'main') -Value "$PID" -NoNewline
Assert-True ((Remove-StaleZellijMarker -Session 'main' -MarkerDir $markerDir -ProcessName 'pwsh') -eq $false) 'keeps marker whose pid is a live matching process'
Assert-True ((Remove-StaleZellijMarker -Session 'absent' -MarkerDir $markerDir) -eq $false) 'no marker -> nothing to do'
Remove-Item -Recurse -Force $markerDir

Write-Host 'Get-ZellijLaunchArgs'
$work = Join-Path $env:TEMP ("zellij-restore-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
$layoutPath = Join-Path $work 'session-layout.kdl'
$alive = Get-ZellijLaunchArgs -Session 'main' -Alive $true -LayoutPath $layoutPath -WorkDir $work
Assert-True (($alive -join ' ') -eq 'attach main') 'alive -> attach'
$missing = Get-ZellijLaunchArgs -Session 'main' -Alive $false -LayoutPath $layoutPath -WorkDir $work
Assert-True (($missing -join ' ') -eq '--session main') 'dead without layout -> plain new session'
Copy-Item (Join-Path $PSScriptRoot 'fixtures/poisoned-session-layout.kdl') $layoutPath
$dead = Get-ZellijLaunchArgs -Session 'main' -Alive $false -LayoutPath $layoutPath -WorkDir $work
Assert-True (($dead[0..2] -join ' ') -eq '--session main --new-session-with-layout') 'dead with layout -> new session from rewritten layout'
Assert-True ((Test-Path $dead[3]) -and -not ((Get-Content $dead[3] -Raw) -match 'uv\.EXE')) 'rewritten layout written without the MCP command'
Assert-True ((Get-ChildItem $work -Filter 'main.*.orig.kdl').Count -eq 1) 'original layout backed up'
Remove-Item -Recurse -Force $work

Write-Host 'zellij is invoked at top level (its stdout must reach the console)'
$scriptText = Get-Content (Join-Path $root 'dot_config/zellij/plugins/zellij-restore.ps1') -Raw
Assert-True (-not ($scriptText -match '(?m)^\s*exit \(')) 'no exit (expression) capturing a function that runs zellij'
Assert-True ($scriptText -match '(?m)^& zellij @zellijArgs\s*$') 'top-level & zellij @zellijArgs'

if ($script:failures -gt 0) { Write-Host "$($script:failures) failure(s)"; exit 1 }
Write-Host 'all tests passed'
