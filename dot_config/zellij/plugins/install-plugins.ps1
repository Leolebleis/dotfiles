# Download Zellij plugins (run manually or via chezmoi run_once)
# Idempotent: skips plugins that already exist.

$pluginDir = Join-Path $HOME ".config/zellij/plugins"
New-Item -ItemType Directory -Force $pluginDir | Out-Null

$plugins = @{
    "zj-quit.wasm"          = "https://github.com/cristiand391/zj-quit/releases/download/0.3.1/zj-quit.wasm"
    "zellij_forgot.wasm"    = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm"
    "zellij-autolock.wasm"  = "https://github.com/fresh2dev/zellij-autolock/releases/download/0.2.2/zellij-autolock.wasm"
    "room.wasm"             = "https://github.com/rvcas/room/releases/download/v1.2.1/room.wasm"
    "zellij-attention.wasm" = "https://github.com/KiryuuLight/zellij-attention/releases/download/v0.3.1/zellij-attention.wasm"
}

foreach ($name in $plugins.Keys) {
    $dest = Join-Path $pluginDir $name
    if (Test-Path $dest) {
        Write-Host "  exists: $name"
    } else {
        Write-Host "  downloading: $name"
        Invoke-WebRequest -Uri $plugins[$name] -OutFile $dest -UseBasicParsing
    }
}

Write-Host "Zellij plugins installed."
