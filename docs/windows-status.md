# Windows setup — status

_As of 2026-05-23. PR [#3](https://github.com/Leolebleis/dotfiles/pull/3) (`chore/windows-ghostty-ignore`)._

## What works

- **chezmoi `dot_` vs literal-dir handling.** `AppData/` and `Documents/` are unprefixed (chezmoi treats `dot_` literally per-component → `dot_AppData` would deploy to `~/.AppData`). `.chezmoiignore` gates both to `windows` only.
- **Windows Terminal config** deployed at `~/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`: Catppuccin Mocha, Cascadia Mono 14pt, 4px padding. Source uses WT's normalized `actions[]+id` JSON format so WT doesn't rewrite the file on save.
- **PowerShell profile** at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`: starship init, PSReadLine history-list prediction, `Ctrl+u` → `BackwardDeleteLine`, Zellij auto-attach to `main` (guarded by `$env:ZELLIJ` + `$env:WT_SESSION`), `scp-clip` function.
- **Zellij** opens on new WT window, attaches to `main` session, with `pwsh.exe` as `default_shell` (Zellij was falling back to cmd.exe before this fix). Theme + UI render correctly.
- **`zellij action new-pane --direction right`** from the CLI splits the pane correctly. Zellij itself works.
- **Alt+Shift+keys** (e.g., `Alt+Shift+D` for `Terminal.DuplicatePaneAuto`) work because Windows Terminal intercepts them — the keystroke never has to go through Zellij's broken key routing.
- **Ghostty** correctly excluded on Windows via `.chezmoiignore` conditional.

## What's broken — Zellij Windows-native key routing

**Symptom.** Custom `Alt+letter` Zellij bindings (e.g., `Alt+d` → `NewPane "Right"`) do not fire. Pressing the key produces a brief flicker and no action.

**Root cause.** Zellij 0.44.1 Windows-native IPC between client and server is buggy. Log evidence at `~/AppData/Local/Temp/zellij/zellij-log/zellij.log`:

```
ERROR pty_writer ... os_input_output_windows.rs:544: a non-fatal error occurred
  Caused by:
    0: failed to set terminal 0 to size (120, 28)
    1: no ConPTY terminal found for id 0
ERROR server_router ... route.rs:2652: Received unknown message from client.
ERROR server_router ... route.rs:2655: Client sent over 1000 consecutive unknown messages,
       this is probably an infinite loop, logging client out
```

The server cannot decode certain message types from the client → client gets logged out → reconnects → repeats. Key events appear to be among the affected message types; CLI actions (which use a different RPC path) are not.

**Things ruled out:**

- PSReadLine shadowing (`Alt+d → KillWord`). Verified unbinding via `Remove-PSReadLineKeyHandler -Chord 'Alt+d'` does not fix it — Alt+d still doesn't reach Zellij as a binding.
- chezmoi deployment / config dir issues. `zellij setup --check` confirms config dir resolves to `~/.config/zellij` and the user config loads.
- Stale Zellij server / version mismatch. Server PID 12728 and client PID 24908 are the same binary at `~/AppData/Local/Zellij/zellij.exe` (mtime 2026-04-07). Same version, same binary.
- Windows Terminal intercepting `Alt+d`. WT settings.json does not bind plain `Alt+d`; only `Alt+Shift+D` (DuplicatePaneAuto).

**Related upstream issues** (all open as of search date):

- [#4745](https://github.com/zellij-org/zellij/issues/4745) — umbrella for Windows implementation issues
- [#5009](https://github.com/zellij-org/zellij/issues/5009) — `[windows]: dead session`
- [#5007](https://github.com/zellij-org/zellij/issues/5007) — `Render thread panics with OS error 1450 on stdout flush`
- [#5021](https://github.com/zellij-org/zellij/issues/5021) — `Zellij on windows displays garbage`
- [#4868](https://github.com/zellij-org/zellij/issues/4868) — `sessions: crashing in windows`
- [#5167](https://github.com/zellij-org/zellij/issues/5167) — `Renderer Corruption and occasional panic`
- [#2170](https://github.com/zellij-org/zellij/issues/2170) — `Received empty message from server` (closest match to our error class)

Filing a new issue with our specific `Received unknown message from client` log signature would be worthwhile.

## What we've explicitly chosen NOT to do

- **Switch to Locked / Unlock-First preset** (the Zellij-blessed way to dodge key conflicts). Rejected — user wants Alt-letter to act directly without a mode switch.
- **Switch to WSL2.** Rejected — user wants native Windows.

## Options on the table for the Alt-binding problem

Ranked by recommendation:

1. **Use Alt+Shift+letter for Zellij bindings on Windows.** WT intercepts Alt+Shift before Zellij; route through WT's `sendInput` action or via `wt` action calling `zellij action new-pane …`. Survives the broken Zellij IPC. Different muscle memory from current macOS bindings — that's the cost.
2. **Use Windows Terminal panes instead of Zellij panes** on Windows. WT pane splits (Alt+Shift++ right, Alt+Shift+- down) are reliable. Zellij stays for tabs and sessions only.
3. **Wait for Zellij to fix Windows.** No ETA. 15+ open Windows issues.
4. **Switch to tmux on Windows** (via msys2 or similar). More mature, but a different ecosystem from macOS.

## Diagnostic commands worth remembering

```bash
# Zellij log location on Windows
tail -50 "$LOCALAPPDATA/Temp/zellij/zellij-log/zellij.log"

# What Zellij thinks its config dir is
zellij setup --check

# Dump Zellij default config (to compare against user config)
zellij setup --dump-config

# CLI-based pane operations (bypass the broken key routing)
zellij action new-pane --direction right
zellij action move-focus left
zellij action go-to-tab 1

# Inspect PSReadLine bindings (shell-side interceptors)
Get-PSReadLineKeyHandler -Bound | Where-Object Key -Match '^Alt\+'

# Inspect Windows Terminal effective config
cat "$LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
```
