# Windows setup -- status

_Updated 2026-05-23. Zellij upgraded to 0.44.3, keybinding bug resolved._

## What works

- **chezmoi `dot_` vs literal-dir handling.** `AppData/` and `Documents/` are unprefixed (chezmoi treats `dot_` literally per-component -> `dot_AppData` would deploy to `~/.AppData`). `.chezmoiignore` gates both to `windows` only.
- **Windows Terminal config** deployed at `~/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`: Catppuccin Mocha, Cascadia Mono 14pt, 4px padding. Source uses WT's normalized `actions[]+id` JSON format so WT doesn't rewrite the file on save.
- **PowerShell profile** at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`: starship init, PSReadLine history-list prediction, `Ctrl+u` -> `BackwardDeleteLine`, Zellij auto-attach to `main` (guarded by `$env:ZELLIJ` + `$env:WT_SESSION`), `scp-clip` function.
- **Zellij** opens on new WT window, attaches to `main` session, with `pwsh.exe` as `default_shell` (Zellij was falling back to cmd.exe before this fix). Theme + UI render correctly.
- **Alt+key Zellij bindings** (Alt+d, Alt+t, Alt+h/j/k/l, Alt+w, etc.) work correctly on Zellij 0.44.3. See below for the bug that affected 0.44.1.
- **Ghostty** correctly excluded on Windows via `.chezmoiignore` conditional.

## Resolved -- Zellij 0.44.1 key routing bug

**Was broken on 0.44.1, fixed in 0.44.2+ (PR [#5014](https://github.com/zellij-org/zellij/pull/5014)).**

PR [#4967](https://github.com/zellij-org/zellij/pull/4967) (shipped in 0.44.1) introduced a regression in `cast_crossterm_key` -- the Windows console input handler that converts `KEY_EVENT` records to crossterm events. It added VT modifier encoding for non-Char keys but the guard condition also matched Char keys, re-encoding `Alt+letter` into CSI u sequences the server couldn't parse. This produced `Received unknown message from client` IPC errors and client disconnection loops on every Alt+key press.

PR #5014 (shipped in 0.44.2) fixed this by skipping the re-encoding for Char keys.

**Self-tested 2026-05-23:** launched a fresh Zellij 0.44.3 session (`key-test`) in a new WT tab, sent Alt+T / Alt+D / Alt+H / Alt+W via Win32 `keybd_event` API. All bindings fired correctly, zero IPC errors. Compare 0.44.1 which produced `Received unknown message from client` + forced client logout on every keypress.

## What we've explicitly chosen NOT to do

- **Switch to Locked / Unlock-First preset** (the Zellij-blessed way to dodge key conflicts). Rejected -- user wants Alt-letter to act directly without a mode switch.
- **Switch to WSL2.** Rejected -- user wants native Windows.

## Known remaining Windows quirks (0.44.3)

- **ConPTY size errors on startup.** `no ConPTY terminal found for id 0` appears in the log during session init. Non-fatal, resolves after the first resize.
- **CWD errors for non-existent paths.** If a resurrected pane had a CWD that no longer exists, log shows `CWD for new pane '...' does not exist`. Cosmetic.
- **Plugin permission errors.** Some plugins (compact-bar) trigger `RunCommands permission denied` warnings. Cosmetic.

## Diagnostic commands

```powershell
# Zellij log location on Windows
Get-Content "$env:LOCALAPPDATA\Temp\zellij\zellij-log\zellij.log" -Tail 50

# What Zellij thinks its config dir is
zellij setup --check

# CLI-based pane operations
zellij action new-pane --direction right
zellij action move-focus left
zellij action go-to-tab 1

# Inspect PSReadLine bindings (shell-side interceptors)
Get-PSReadLineKeyHandler -Bound | Where-Object Key -Match '^Alt\+'

# Inspect Windows Terminal effective config
Get-Content "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
```
