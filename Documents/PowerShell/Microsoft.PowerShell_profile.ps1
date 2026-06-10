# PowerShell profile — Windows
# Loaded by pwsh 7+ for the current user, current host.

# Dry-run sentinel: set $env:DOTFILES_PROFILE_DRYRUN=1 to source the profile
# without triggering side effects (used by self-tests).
if ($env:DOTFILES_PROFILE_DRYRUN) { return }

# Point Zellij at the chezmoi-managed config (cross-platform consistent path).
# Overrides the legacy persistent env var that pointed to a stale location.
$env:ZELLIJ_CONFIG_DIR = Join-Path $HOME ".config/zellij"

# Enable VT input mode for Zellij so it uses its byte-level parser
# (KittyKeyboardParser) instead of the native console API path.
# Required for Shift+Enter to work in WT Preview 1.25+ with KKP.
$env:TERM = "xterm-256color"

# Prompt
Invoke-Expression (&starship init powershell)

# Start in $HOME when not inside Zellij (Zellij restores pane cwd from session serialization)
if (-not $env:ZELLIJ) {
    Set-Location $HOME
}

# PSReadLine: history-aware prediction
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Ctrl+U → delete from cursor to start of line (matches zsh / Ghostty macOS).
# PSReadLine in default Windows mode leaves Ctrl+U unbound, so the byte
# sent from Windows Terminal would otherwise reach a no-op.
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteLine

# Free up Alt+keys that Zellij needs. PSReadLine reads console events
# directly via Win32 API, so it intercepts these BEFORE Zellij sees the
# byte stream. Without unbinding, Zellij's NewPane / MoveFocus / GoToTab
# bindings on Alt+d, Alt+h, Alt+1..9 silently fail (PSReadLine consumes
# them, often as a no-op like KillWord at end-of-line).
foreach ($chord in @('Alt+d', 'Alt+h', 'Alt+a',
                     'Alt+0', 'Alt+1', 'Alt+2', 'Alt+3', 'Alt+4',
                     'Alt+5', 'Alt+6', 'Alt+7', 'Alt+8', 'Alt+9')) {
    try { Remove-PSReadLineKeyHandler -Chord $chord -ErrorAction Stop } catch {}
}

# Launch Claude with per-pane session tracking for Zellij resurrection.
# Generates a UUID passed as --session-id; the resurrect hook transforms it
# to --resume <uuid> on next session restore. Use instead of bare `claude`.
function cz {
    $uuid = & python3 -c "import uuid; print(uuid.uuid4())"
    & claude --session-id $uuid @args
}

# Auto-attach Zellij when launched from Windows Terminal.
# Guards:
#   - $env:ZELLIJ: already inside a Zellij session (prevents infinite loop)
#   - $env:WT_SESSION: only auto-attach in Windows Terminal (skip VSCode, etc.)
#   - $env:NO_ZELLIJ: opt-out for "PowerShell" WT profile (bare shell)
#   - $env:CHEZMOI: never attach inside chezmoi run scripts (hijacks apply)
#   - zellij must be on PATH
if (-not $env:ZELLIJ -and $env:WT_SESSION -and -not $env:NO_ZELLIJ -and -not $env:CHEZMOI -and (Get-Command zellij -ErrorAction SilentlyContinue)) {
    # -f (force-run-commands): when resurrecting a dead session, run its saved
    # commands immediately instead of leaving them suspended behind the Enter
    # banner. Windows' KKP/ConPTY input layer makes that manual Enter unreliable
    # (resurrected panes hang); -f sidesteps it. No-op on an already-live session.
    zellij attach -f -c main
    exit
}
