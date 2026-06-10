# Claude Code hook -> zellij-attention bridge.
# Invoked as: pwsh -NoProfile -File zellij-attention-notify.ps1 <waiting|completed>
# Reads $env:ZELLIJ_PANE_ID natively (no outer-shell interpolation), so one
# command works whether Claude Code runs hooks via cmd, sh, or pwsh.
#
# Two things that bit us, baked in here:
#  - `zellij pipe` reads stdin for its payload and BLOCKS until EOF. We close
#    stdin immediately so it can't hang (an open console stdin = forever-block).
#  - A zero-recipient broadcast pipe also blocks by design, so we cap the wait
#    at 2s and kill -- a hung hook would stall Claude Code.
# Session is resolved from $env:ZELLIJ_SESSION_NAME (set inside every pane), so
# no --session needed; bare `pipe` targets the current session.
param([Parameter(Mandatory)][ValidateSet('waiting', 'completed')][string]$State)

# No-op outside a Zellij pane.
if (-not $env:ZELLIJ_PANE_ID) { exit 0 }

try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new('zellij')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    'pipe', '--name', "zellij-attention::$State::$($env:ZELLIJ_PANE_ID)" |
        ForEach-Object { $psi.ArgumentList.Add($_) }
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Close()          # immediate EOF -> pipe won't block on stdin
    if (-not $proc.WaitForExit(2000)) {   # zero-recipient guard
        try { $proc.Kill() } catch {}
    }
} catch {
    # zellij not on PATH, or any spawn failure: never surface to Claude Code.
}
exit 0
