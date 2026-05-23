# PowerShell profile — Windows
# Loaded by pwsh 7+ for the current user, current host.

# Dry-run sentinel: set $env:DOTFILES_PROFILE_DRYRUN=1 to source the profile
# without triggering side effects (used by self-tests).
if ($env:DOTFILES_PROFILE_DRYRUN) { return }

# Point Zellij at the chezmoi-managed config (cross-platform consistent path).
# Overrides the legacy persistent env var that pointed to a stale location.
$env:ZELLIJ_CONFIG_DIR = Join-Path $HOME ".config/zellij"

# Prompt
Invoke-Expression (&starship init powershell)

# Start in $HOME, not the wt cwd
Set-Location $HOME

# PSReadLine: history-aware prediction
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Ctrl+U → delete from cursor to start of line (matches zsh / Ghostty macOS).
# PSReadLine in default Windows mode leaves Ctrl+U unbound, so the byte
# sent from Windows Terminal would otherwise reach a no-op.
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteLine

# Upload clipboard image to the Pi
function scp-clip {
    $name = "clip_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
    $tmpfile = "$env:TEMP\$name"

    Add-Type -AssemblyName System.Windows.Forms
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    if ($null -eq $img) { Write-Host 'No image in clipboard'; return }
    $img.Save($tmpfile)

    scp $tmpfile "pi:/tmp/$name" && Write-Host "Uploaded: /tmp/$name"
    Remove-Item $tmpfile
}

# Auto-attach Zellij when launched from Windows Terminal.
# Guards:
#   - $env:ZELLIJ: already inside a Zellij session (prevents infinite loop)
#   - $env:WT_SESSION: only auto-attach in Windows Terminal (skip VSCode, etc.)
#   - zellij must be on PATH
if (-not $env:ZELLIJ -and $env:WT_SESSION -and (Get-Command zellij -ErrorAction SilentlyContinue)) {
    zellij attach -c main
    exit
}
