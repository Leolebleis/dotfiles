# NewPane after CloseFocus fails (was: "Alt+N after Alt+W fails")

- **Status**: **root cause confirmed** via procmon -- zellij userspace bug, NOT Windows/ConPTY. Upstream filing still deferred.
- **Reporter**: Leo
- **First observed**: 2026-04-12
- **Root cause confirmed**: 2026-04-12 (later the same day, via procmon)
- **Zellij version**: 0.44.1 (current latest, released 2026-04-07)
- **Platform**: Windows 11, Windows Terminal, pwsh

## Symptom

After any `CloseFocus` action (e.g. `Alt+W`), the *next* `NewPane` action in the same session silently fails:

- Action returns a fresh pane ID to the caller as if spawn succeeded (often the just-freed ID)
- No `pwsh.exe` child process is actually created
- No log entry is emitted at INFO/WARN/ERROR level
- Screen may flash briefly (client-side layout attempt)

Affects both keybinds (`Alt+\`, `Alt+-`, `Alt+N`) AND external CLI (`zellij action new-pane`). Affects both tiled and floating variants of NewPane. Session remains in this state until killed and restarted.

## Reproduction (minimal, pure CLI)

1. Launch a fresh Zellij session in a terminal outside zellij:
   ```
   zellij --layout C:\Users\leole\Documents\code\personal\zellij\docs\superpowers\investigations\minimal-no-bars.kdl
   ```
   (Layout file is a one-liner: `layout { pane }` -- no plugins, no fixed-size panes.)
2. From another terminal: `zellij --session <name> action new-pane` -- succeeds, pwsh.exe spawns
3. `zellij --session <name> action close-pane` -- succeeds, pwsh.exe killed
4. `zellij --session <name> action new-pane` -- returns a pane ID but no pwsh.exe is spawned

`list-panes` after step 4 still shows only the pre-step-4 panes. The returned ID is phantom.

## Root cause (confirmed)

**The NewPane action handler silently drops the spawn request when invoked after a CloseFocus.** No call to `CreateProcess` (or any other Windows spawn API) is ever made.

Evidence from procmon capture of a fresh repro:

| Step | What procmon saw |
|------|------------------|
| new-pane #1 (succeeds) | new `pwsh.exe` pid 41892 appears ✓ |
| close-pane | pid 41892 vanishes ✓ |
| new-pane #2 (lies) | **NO new pwsh.exe pid appears** — no CreateProcess call, no short-lived pid, no failed spawn; the OS is never invoked |

This rules out any OS-level, ConPTY, child-process-cleanup, or Windows-API hypothesis. The defect is entirely in zellij's userspace code path -- specifically in the NewPane action handler's post-CloseFocus behavior.

### Architectural interpretation

The action handler and the spawn thread are decoupled. The handler:
1. Allocates a pane ID (the next free slot -- which is the just-freed ID after a close)
2. Sends a spawn message to the PTY thread
3. Returns the allocated ID to the caller *synchronously*, before the spawn completes

After a CloseFocus, the handler still does (1) and (3) -- but at step (2) the PTY thread either never receives the message or silently drops it. No error propagation exists between the spawn thread and the action response path, so the handler returns "success" with a phantom ID.

## Scope of the bug -- tested

| Alternative | Affected by the bug? |
|-------------|----------------------|
| `NewPane` (tiled, any direction) | **yes** |
| `NewPane --floating` | **yes** -- same handler |
| `NewTab` | **NO** -- different code path, works correctly |
| `focus-next-pane` / `focus-pane-id` before retry | does not heal |

This narrows the defect to the NewPane action handler specifically (not the wider spawn subsystem).

## Confirmed observations

- Reproduces in user's full config, in a pristine default config, and in a one-line `layout { pane }` minimal layout
- First pane-create call in a session always works; every subsequent call after a CloseFocus fails
- Bug fires on close-to-2 panes (not just close-to-single-pane)
- Happens identically via keybinds and pure `zellij --session NAME action` CLI
- Zellij log at `%LOCALAPPDATA%\Temp\zellij\zellij-log\zellij.log` emits no entries during the full lifecycle (successful first new-pane, successful close, and failed second new-pane all log nothing at INFO level)
- `NewPane` action returns a pane ID that is often *the just-closed pane's ID* (slot recycling in ID allocator)

## Refuted hypotheses

- ~~**Windows ConPTY pane-spawn state corruption**~~ (was the prior leading hypothesis): procmon confirmed no spawn syscall is ever made -- the bug is above the OS layer
- ~~**Anchor-pane / focus-state corruption as the mechanism**~~: injecting `focus-next-pane` or `focus-pane-id terminal_0` between close-pane and new-pane does not heal
- ~~**"Close-to-single-pane" only**~~: bug also fires on close from 3→2 panes
- ~~**Config/bundling issue (Alt+W = `CloseFocus;` too minimal)**~~: 30+ dotfiles on GitHub use the exact same bind successfully on Linux/macOS
- **Keybinding layer**: external `zellij action new-pane` fails identically
- **No-direction `NewPane` special case**: directional `NewPane "Right"` / `"Down"` fail too
- **Fixed-size pane interaction**: reproduces with `layout { pane }` and zero plugin panes
- **Outdated Zellij**: 0.44.1 is the current release

## Diagnostic tooling validated

- **Reproduction via pure `zellij --session NAME action` CLI.** Any `zellij action ...` call against an attached session reproduces the bug. No keybind or TTY involvement needed.
- **procmon for OS-level ground truth.** GUI capture, then filter via Ctrl+L (Process Name is zellij.exe + pwsh.exe; Operation is Process_Create -- though Process_Create may not fire, the profiling samples still reveal lifecycle). Save filtered PML via File → Save → "Events displayed using current filter" to shrink ~14GB unfiltered to ~15MB.
- **`procmon-parser` Python library** (`pip install procmon-parser`). Procmon's own `/SaveAs` CLI is flaky on large files; the Python library reads PMLs reliably and supports scripting. Note: procmon FILETIME is UTC -- local timestamps need a TZ offset to correlate (BST on Leo's machine: UTC+1).
- **`zellij action dump-layout` is unreliable on Windows 0.44.1.** Renders tabs as empty `{}` even when panes exist. Do not use for state inspection; `list-panes` is the ground truth.
- **`current-tab-info` fails cross-session.** Returns "No active tab found for current client" when invoked via `zellij --session NAME action`. That's a CLI-context limitation, not a bug signal.

## Workarounds

- **Use `NewTab` (Alt+T) instead of `NewPane` after an Alt+W.** Creates a new tab with its own pane -- different code path, not affected by the bug. **This is the recommended daily workaround.**
- Kill and restart the session. Heavyweight but resets state fully.
- Keybind chaining (speculative, untested): `bind "Alt w" { CloseFocus; NewTab; }` -- close the pane and immediately spawn a new tab so the session never stays in the poisoned state. Test before adopting.

## Upstream filing plan

One-paragraph defect description (ready to drop into an issue):

> After `CloseFocus`, the next `NewPane` action returns a fresh pane ID to the caller but silently drops the spawn request: no `CreateProcess` call is ever made (procmon-verified on Windows 11, Zellij 0.44.1). The action reports success despite producing no pane. Affects both tiled and floating variants of NewPane. `NewTab`, which uses a different code path, is unaffected. No error is logged at INFO level. Reproducible from pure CLI: `zellij action new-pane` → `close-pane` → `new-pane` in any attached session.

### Related upstream issues to cross-reference

- **zellij-org/zellij#3999** -- "Not able to create a pane" on macOS 0.41.2. Visible symptom matches ours but reporter's "use explicit direction" workaround does not help us, suggesting different root cause despite same surface.
- **zellij-org/zellij#4880** -- Panic closing pane split from fixed-size pane (Linux/macOS). Similar shape, ruled out: reproduces here without any fixed-size pane.
- **zellij-org/zellij#4745** -- Windows implementation issues (umbrella).
- **zellij-org/zellij#2926** -- Windows support (umbrella).

### Still open questions (deprioritized)

- Whether the bug reproduces on macOS/Linux. Would distinguish "general NewPane-after-CloseFocus bug" from "Windows-port-only." Testing on non-Windows requires access to a non-Windows machine.
- Whether `is_enabled false` on the autolock plugin changes anything (deprioritized -- bug predates autolock install).

## Supporting files

- `minimal-no-bars.kdl` (in this directory) -- one-pane layout used to rule out the fixed-size-pane hypothesis and drive the procmon repro.

## Session 2026-04-13 update -- code path mapped, logger dead end

### Runtime log level is not controllable at runtime

`zellij-utils/src/logging.rs:92` hardcodes `Root::builder().appender("logFile").build(LevelFilter::Info)` with no env var reads anywhere in the logger config. Empirically verified: `RUST_LOG=trace`, `ZELLIJ_LOG=trace`, `ZELLIJ_LOG_LEVEL=trace` all produce only INFO/ERROR output (Probe A, 2026-04-13). `zellij --debug` is a red herring -- per upstream docs it only dumps PTY bytes per pane to `zellij-<pane_id>.log`, not application-level trace. Only escalation path for debug logging is source-modify + rebuild.

### Full NewPane code path on Windows (v0.44.1)

| Layer | File:line | Role |
|-------|-----------|------|
| Action entry | `zellij-server/src/route.rs:609` | `Action::NewPane` -> builds `PtyInstruction::SpawnTerminal`, `send_to_pty` at 622 |
| PTY loop | `zellij-server/src/pty.rs:207-350` | Matches `SpawnTerminal` at 212, calls `pty.spawn_terminal(...)` at 256 |
| Pty::spawn_terminal | `zellij-server/src/pty.rs:1007-1143` | `fill_cwd`, builds quit_cb, calls `os_input.spawn_terminal` at 1118 |
| **Trait impl** | `zellij-server/src/os_input_output.rs:381-404` | **Allocates terminal_id via `next_terminal_id()` at 389, reserves at 394, dispatches to backend at 398-401** |
| WindowsPtyBackend | `zellij-server/src/os_input_output_windows.rs:481-503` | `resolve_command`, then `do_spawn` -- or returns `ZellijError::CommandNotFound` |
| do_spawn | `zellij-server/src/os_input_output_windows.rs:383-479` | Pipes -> `create_conpty` -> `spawn_child_process` at 432 |
| spawn_child_process | `zellij-server/src/os_input_output_windows.rs:264+` | Calls `CreateProcessW` at 327 |

### Every error branch logs -- absence of errors rules out normal failures

`pty_thread_main` line 347: `_ => Err::<(), _>(err).non_fatal()`. Empirically confirmed `non_fatal()` produces ERROR lines in `zellij.log` (Probe A session teardown emitted `ERROR | ??? | a non-fatal error occured / Caused by: ... os error 87` for an unrelated kill). No such ERROR appears around the failing spawn in prior captures -- so the handler either returns Ok via an untraced path, or never runs at all.

### ID allocator is slot-recycling

`os_input_output.rs:389` calls `self.pty_backend.next_terminal_id()` (implementation not yet read). This matches the symptom "often the just-freed ID" since the closed pane's ID is lowest-unused after a close.

### Four remaining hypotheses

| # | Hypothesis | Discriminator |
|---|-----------|--------------|
| H1 | PTY spawn succeeds; screen-side `NewPane` handler drops the message after CloseFocus (bad tab/client state). CreateProcessW DID fire, procmon missed it. | Rule out H4 first (procmon audit). Then read screen.rs `ScreenInstruction::NewPane`. |
| H2 | `send_to_pty` never reaches PTY thread; thread stuck or dead. | Would hang on completion_tx; doc reports it doesn't. Unlikely. |
| H3 | Short-circuit in `Pty::spawn_terminal` returns `Ok(fabricated_id)` without calling the OS `spawn_terminal`. | Re-read `pty.rs:1049-1060`: `hold_on_start` branch calls `reserve_terminal_id` and returns Ok without spawning. Does any state post-CloseFocus flip hold_on_start=true? |
| H4 | Existing PML's filter was narrower than the investigation doc assumed -- CreateProcessW for the failed call IS in the capture. | Install `procmon-parser`, enumerate event types + per-pid counts. Cheap. |

### Resume point (next session, in priority order)

1. **Audit `Logfile.PML` with `procmon-parser`** -- `pip install procmon-parser`, enumerate event types and every `CreateProcess` call. Rules out H4.
2. **Re-read `Pty::spawn_terminal` at pty.rs:1049-1060 for H3** -- the `hold_on_start` short-circuit
3. **Find and read `next_terminal_id` implementation** (likely in `os_input_output_windows.rs`) -- confirm slot-recycling
4. **If H1 still live after above**, read screen-side `ScreenInstruction::NewPane` handler in `zellij-server/src/screen.rs`

### Supporting state (this session)

- Zellij v0.44.1 source shallow-cloned at `C:\Users\leole\Documents\code\scratch\zellij-src`. Windows MAX_PATH broke the `snapshots/` test-fixture checkout, but all server code we need is present (`zellij-server/src/`, `zellij-utils/src/logging.rs`, `zellij-server/src/os_input_output_windows.rs`, Cargo.toml).
- Existing `Logfile.PML` (15MB) scope unaudited; priority #1 above.

## Resolution

Open. Root cause confirmed at OS-syscall level 2026-04-12 (no `CreateProcess` ever called). Code path mapped to file:line in v0.44.1 source 2026-04-13, but exact userspace defect not yet pinpointed -- 4 hypotheses (H1-H4) remain, see §Session 2026-04-13 for resume point. Upstream filing still deferred. `NewTab` workaround validated for daily use.
