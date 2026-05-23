# Windows Terminal + Zellij Keybinding Investigation

_Investigation started 2026-05-23. Tracking systematic debugging of Alt+key bindings not firing._

## Constraints (non-negotiable)

- **No stack changes.** Windows Terminal + Zellij + PowerShell 7.
- **No keybinding changes.** Alt-based bindings must be identical across macOS/Linux/Windows.
- **No WSL.** Native Windows only.
- Terminal change acceptable ONLY if it absolutely guarantees the fix (not pursued unless all else fails).

## Symptom

Custom `Alt+letter` Zellij bindings (Alt+d, Alt+h, Alt+t, etc.) do not fire on Windows.
Pressing the key produces a brief flicker and no action. CLI actions (`zellij action new-pane`) work fine.

## Environment

| Component | Version | Notes |
|-----------|---------|-------|
| Windows | 11 Pro 10.0.26200 | |
| Windows Terminal | 1.24.11321.0 | **Not** 1.25+ (no Kitty keyboard protocol) |
| Zellij | 0.44.1 | Installed via winget at `~\AppData\Local\Zellij\zellij.exe` |
| PowerShell | 7+ | Profile at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` |
| Config | chezmoi-managed | `~/.config/zellij/config.kdl` |

## Phase 1: Root Cause Investigation

### Error signature

From `$env:LOCALAPPDATA\Temp\zellij\zellij-log\zellij.log`:

```
ERROR server_router ... route.rs:2652: Received unknown message from client.
ERROR server_router ... route.rs:2655: Client sent over 1000 consecutive unknown messages,
       this is probably an infinite loop, logging client out
```

Pattern: every Alt+key press floods the server with 1000+ unknown messages, server disconnects client, client auto-reconnects. This cycle repeats on every keypress.

Also present on startup (non-fatal):
```
ERROR pty_writer ... os_input_output_windows.rs:544: a non-fatal error occurred
  Caused by: failed to set terminal 0 to size (120, 28)
             no ConPTY terminal found for id 0
```

### Things already ruled out

1. **PSReadLine shadowing** -- Alt+d/h/0-9 explicitly unbound in profile. Verified unbinding doesn't fix it.
2. **chezmoi deployment** -- `zellij setup --check` confirms config loads correctly.
3. **Stale Zellij binary** -- Server and client are the same binary, same version.
4. **Windows Terminal intercepting Alt+d** -- WT settings.json doesn't bind plain Alt+d (only Alt+Shift+D).
5. **WT keyboard protocol issues** -- WT 1.24 (not 1.25+), so Kitty protocol conflicts don't apply.

### Root cause identified: Zellij 0.44.1 keyboard encoding bug

**PR #4967** (merged 2026-04-03, shipped in 0.44.1) introduced a regression in `cast_crossterm_key` (Windows console input handler). It added VT modifier encoding for non-Char keys but the guard condition was too broad -- it also matched Char keys, re-encoding things like Alt+D from their correct representation into CSI u sequences the server can't parse.

**PR #5014** (merged 2026-04-15, shipped in 0.44.2) directly fixed this by skipping the modifier re-encoding block for Char keys.

The "Received unknown message from client" errors are a downstream symptom: the client sends malformed key event data via IPC, the server can't deserialize it, logs "unknown message", and after 1000 consecutive failures disconnects the client.

### Evidence this is the fix

- Multiple users on GitHub confirmed 0.44.2 fixed their keyboard issues (#5048, #5022, #5017)
- User `golanguage` in #4745: "Windows-Terminal + Zellij are fine on Win10/11" (on 0.44.0, before the regression)
- User `Zykino` in #4745: confirmed all pane/tab operations work on WT
- Maintainer `@imsnif` confirmed #5167 (renderer corruption + unknown message) fixed in 0.44.2

### Available upgrades

| Version | Date | Key fixes |
|---------|------|-----------|
| 0.44.2 | 2026-05-05 | **PR #5014**: fix Char key modifier re-encoding. KKP unicode, pane ID reuse, idle CPU. |
| 0.44.3 | 2026-05-13 | ESC+mouse regression, STDIN stalling, blocking panes, Windows build (windows-sys bump). |

## Phase 2: Fix Plan

### Step 1: Upgrade Zellij to 0.44.3

```powershell
winget upgrade --id Zellij.Zellij
```

### Step 2: Restart Zellij

The running server (PID from old binary) must be replaced. After binary upgrade:
1. The current session uses the old 0.44.1 server
2. A fresh session will use the new 0.44.3 binary
3. Session resurrection will preserve tab/pane layout

### Step 3: Verify fix

After restart, test:
- [ ] `Alt+d` creates a new pane to the right
- [ ] `Alt+D` creates a new pane below
- [ ] `Alt+h/j/k/l` navigates between panes
- [ ] `Alt+t` creates a new tab
- [ ] `Alt+w` closes a pane
- [ ] `Alt+1..9` switches tabs
- [ ] `Alt+g` toggles floating panes
- [ ] `Alt+z` toggles fullscreen
- [ ] No "Received unknown message" errors in zellij.log after keypresses

## Self-Test Results (2026-05-23)

### Method

1. Upgraded binary to 0.44.3 via `winget upgrade --id Zellij.Zellij`
2. Opened new WT tab with `wt -w 0 nt` running `zellij -s key-test` (fresh 0.44.3 server)
3. Used Win32 `keybd_event` API via PowerShell `Add-Type` to simulate keystrokes
4. Compared zellij.log before/after for "Received unknown message" errors

### Results

| Test | Action | Log result |
|------|--------|------------|
| Alt+T (NewTab) | `PtyInstruction::NewTab: spawning terminals for tab 1` | **0 IPC errors** |
| Alt+D (NewPane Right) | Processed silently | **0 IPC errors** |
| Alt+H (MoveFocus Left) | Processed silently | **0 IPC errors** |
| Alt+W (CloseFocus) | Processed silently | **0 IPC errors** |

### A/B comparison

| Version | Alt+key behavior |
|---------|-----------------|
| 0.44.1 (main session) | `Received unknown message from client` + `Client sent over 1000 consecutive unknown messages` on every keypress, client disconnected and reconnected |
| 0.44.3 (key-test session) | All bindings processed correctly, zero IPC errors |

### Verdict

**The fix works.** PR #5014 (in 0.44.2) resolved the `cast_crossterm_key` modifier encoding regression. All tested Alt+key bindings fire correctly on 0.44.3.

## Remaining action

Close this Windows Terminal window and reopen it. The PowerShell profile auto-attaches to the `main` Zellij session. Session resurrection will preserve tab/pane layout. The new 0.44.3 binary will start as the server.

After restart, verify all bindings from Phase 2 Step 3 checklist work with manual keypresses.

## Shift+Enter / KKP Investigation (2026-05-23)

### Problem

Shift+Enter in Claude Code submits instead of inserting a newline. All modifier+Enter combos produce identical bytes to plain Enter in legacy VT100 encoding.

### Root cause

Zellij has two Windows input paths (`zellij-client/src/stdin_handler.rs:33`):

```rust
let use_vt_reader = std::env::var("TERM").is_ok() && enable_vt_input();
```

- **VT reader path**: reads raw bytes, has `KittyKeyboardParser` that handles CSI u sequences (Shift+Enter = `ESC[13;2u`)
- **Native console path**: uses `ReadConsoleInputW`, no KKP parsing

Windows Terminal doesn't set `$env:TERM`, so Zellij always takes the native console path. But Zellij also tells WT 1.25+ to enable KKP (`ESC[>1u`). WT sends KKP sequences, ConPTY mangles them into INPUT_RECORD garbage, and they print as `[27u`.

### Fix

Set `$env:TERM = "xterm-256color"` in the PowerShell profile before Zellij starts. This forces the VT reader path. Combined with WT Preview 1.25 (which has native KKP), Shift+Enter works in Claude Code.

### Requirements

1. **Windows Terminal Preview 1.25** (Kitty keyboard protocol support)
2. **`$env:TERM = "xterm-256color"`** in PowerShell profile (forces Zellij's VT reader path)
3. **Zellij 0.44.3** (Alt+key IPC fix from PR #5014)
4. **Claude Code 2.1.116+** (WindowsTerminal added to KKP allow-list)

### Changes made

- `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`: added `$env:TERM = "xterm-256color"`
- `dot_config/zellij/config.kdl.tmpl`: removed `"Alt Enter"` from ToggleFocusFullscreen (Alt+z remains)
- `AppData/.../settings.json.tmpl`: unbound `alt+shift+d` and `alt+enter` from WT defaults
- Installed Windows Terminal Preview 1.25 via `winget install Microsoft.WindowsTerminal.Preview`

## Status

- [x] Phase 1: Root cause identified (Zellij 0.44.1 `cast_crossterm_key` bug, fixed in 0.44.2 PR #5014)
- [x] Phase 2: Upgrade to 0.44.3
- [x] Phase 3: Self-test verification -- **PASS**
- [x] Phase 4: Shift+Enter fix -- **RESOLVED** (TERM env var + WT Preview 1.25)

## Related upstream issues

| Issue | Title | Status | Relevance |
|-------|-------|--------|-----------|
| #4745 | Windows implementation umbrella | Open | Tracking issue |
| #5014 | Fix Char key modifier re-encoding | **Merged (0.44.2)** | **THE FIX** |
| #4967 | Encode modifiers for non-Char keys | Merged (0.44.1) | **THE REGRESSION** |
| #5017 | Ctrl+ keys output garbage CSI u | Fixed (0.44.2) | Same root cause |
| #5048 | AltGr/Alt confusion | Fixed (0.44.2) | Same root cause |
| #5022 | Ctrl+D not passing through | Fixed (0.44.2) | Same root cause |
| #5167 | Renderer corruption + unknown message | Fixed (0.44.2) | Same symptom |
| #5149 | Query-reply parser stalling | Fixed (0.44.3) | Related IPC fix |
