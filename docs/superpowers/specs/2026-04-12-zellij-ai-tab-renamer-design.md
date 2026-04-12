# Zellij AI Tab Renamer — Design (Work in Progress)

**Status:** Parked mid-brainstorm after Section 2a. Resume at Section 2b.

## Problem

Zellij tabs auto-name based on the running command (`pwsh`, `nvim`, etc.) which is
useless when you have five `pwsh` tabs. `Alt r` opens manual rename, but you have
to read the pane and type a name yourself.

Goal: press a keybind, have Claude Haiku read the current pane and pick a short
descriptive name, auto-apply it. Zero typing, two-second roundtrip.

## Decisions made

| Decision | Choice | Why |
|----------|--------|-----|
| Implementation | **Rust WASM Zellij plugin (Option F)** | Cross-platform native, no shell dispatch, first-class Zellij integration |
| Claude invocation | **`claude` CLI via `run_command`** (not direct API) | Reuses existing CLI auth; WASM plugins can't do HTTPS anyway |
| Trigger | **Keybind → `MessagePlugin` payload** | Sends payload to already-loaded plugin instance, no duplicate spawns |
| Hosting | **Headless via `load_plugins` block + `set_selectable(false)`** | Never consumes pane real-estate |
| Repo layout | **Git submodule at `leolebleis/zellij-tab-renamer`**, mounted under this repo | Clean separation, but co-located with the Zellij assistant that references it |
| Reference implementation | **zellij-attention** (KiryuuLight) | Near-identical architecture: headless, `rename_tab`, pipe-triggered, Claude-Code-adjacent |

## Open questions (to resolve on resume)

- **Keybind**: `Alt m` vs `Alt x` — both are free (verified from defaults dump + user config). Pick one.
- **`run_command` result event shape** in zellij-tile 0.43+ — stdout/stderr/exit in one event or separate? Determines FSM state count. Verify before writing 2b.
- **Multi-pane tabs**: if the focused tab has multiple panes, capture only focused pane, or all?
- **Context window default**: how many lines of scrollback by default? (config-driven, but need a default — probably 200)
- **Max tab name length**: 24 chars? 32?
- **Claude model**: default `haiku`, but config-overridable
- **Cooldown / debounce**: opencode-zellij-namer has logic to prevent rapid-fire renames — do we need similar? (Probably yes, at least a 1-second guard.)

## Approach: Option F in detail

### High-level architecture

```
┌──────────────┐ MessagePlugin  ┌──────────────────┐ run_command ┌────────────────┐
│ user presses │──────────────▶ │ tab-renamer      │───────────▶ │ zellij action  │
│  Alt m/x     │   payload      │ plugin (wasm,    │             │  dump-screen   │
└──────────────┘                │ headless, loaded │ ◀───────────│                │
                                │ at startup)      │  pane text  └────────────────┘
                                │                  │
                                │                  │ run_command ┌────────────────┐
                                │                  │───────────▶ │ claude -p      │
                                │                  │             │  --model haiku │
                                │                  │ ◀───────────│                │
                                │                  │   new name  └────────────────┘
                                │                  │
                                │                  │ rename_tab
                                │                  │───────────▶  Zellij core
                                └──────────────────┘
```

### Dependencies (final)

```toml
[dependencies]
zellij-tile = "0.43"             # plugin API (match Zellij 0.44.1)
serde_json = "1"                 # parse Claude JSON output
strip-ansi-escapes = "0.2"       # clean pane capture
anyhow = "1"                     # ergonomic Result chain
```

Rejected: tokio/async-std (no runtime in WASM), reqwest/HTTP clients (no network from
plugin sandbox), anthropic-sdk (same reason), clap (no CLI args), FSM crates
(overkill for 4 states), tracing (`eprintln!` goes to zellij log).

### Section 2a: Crate structure (APPROVED)

```
zellij-tab-renamer/
├── Cargo.toml
├── README.md
└── src/
    ├── main.rs       register_plugin!(State);  — ~3 lines
    ├── lib.rs        ZellijPlugin impl: load/update/pipe/render    (~200 LOC)
    ├── state.rs      State struct + FsmState enum + transitions    (~80 LOC)
    ├── config.rs     Parse + validate plugin config                (~60 LOC)
    ├── capture.rs    Spawn dump-screen, strip ANSI, truncate       (~70 LOC)
    ├── claude.rs     Prompt template + claude CLI + parse output   (~80 LOC)
    └── tests.rs      Unit tests (pure logic, no zellij runtime)    (~150 LOC)
```

Total ~650 LOC hand-written Rust. zellij-attention is ~400 for simpler scope.

`capture.rs`, `claude.rs`, `config.rs` have no zellij-tile runtime dependency —
unit-testable on native target without a Zellij mock.

`Cargo.toml` release profile matches zellij-attention: `opt-level = "z"`, `lto = true`,
`codegen-units = 1`, `panic = "abort"` — optimizes for WASM binary size.

## Still to write

- **Section 2b** — State machine (`Idle → Capturing → Querying → Renaming → Idle`),
  transitions, failure edges, re-entry guard
- **Section 2c** — Permissions (five: `ReadApplicationState`, `ChangeApplicationState`,
  `MessageAndLaunchOtherPlugins`, `ReadCliPipes`, **`RunCommands`**) + event
  subscriptions (`PermissionRequestResult`, likely `TabUpdate`/`PaneUpdate` for
  focus tracking, `RunCommandResult` for async chain)
- **Section 2d** — Public interface: config keys schema, `MessagePlugin` payload
  schema for the keybind trigger
- **Section 3** — Data flow (happy path: keystroke to rename, with timing)
- **Section 4** — Error handling (claude missing, auth failure, timeout, rate limit,
  empty pane, non-UTF8 output)
- **Section 5** — Testing strategy (unit vs manual Zellij-session verification)

## Architecture reference: zellij-attention

Deep-dived its source. Relevant patterns we lift:

| Pattern | Our use |
|---------|---------|
| `load_plugins { "file:~/.config/zellij/plugins/X.wasm" { ... } }` | Identical |
| `request_permission(&[...])` on `load()` | Identical but add `RunCommands` |
| `set_selectable(false)` on permission grant | Identical |
| Config via `BTreeMap<String, String>::from_configuration()` | Identical shape |
| `rename_tab((pos + 1) as u32, &name)` | **1-indexed — don't forget** |
| Module split: `lib.rs` / `state.rs` / `config.rs` | Copy |
| Release profile: `opt-level = "z"`, lto, codegen-units=1, panic=abort | Copy verbatim |
| `#[cfg(debug_assertions)] eprintln!(...)` for log output | Copy |

### Key lessons from their code

1. **`rename_tab` is 1-indexed** while everything else uses 0-indexed positions.
   Bug factory if missed.
2. **Re-entry guards matter.** Their `updating_tabs: bool` + `pending_renames:
   HashSet<usize>` exists because calling `rename_tab` causes a bounced `TabUpdate`.
   We need at minimum a guard for double-pressing the keybind during an in-flight run.
3. **They use `--name` (broadcast pipe), we use `MessagePlugin`.** `MessagePlugin`
   from a keybind delivers payload to the already-loaded plugin — sidesteps the
   duplicate-instance problem they document with `zellij pipe --plugin`.
4. **Permissions asked**: 4 (no exec). We need 5 — add `RunCommands`.

## Appendix: awesome-zellij survey — highlights for us

Full survey run 2026-04-12 (agent-dispatched). Distilled relevance:

### Architectural kin (same load+pipe+headless pattern)

- **zellij-attention** — closest prior art (already covered above)
- **zellij-autolock** — self-describes as headless; worth copying its event
  subscription shape and `reaction_seconds` debounce pattern
- **zjswitcher** — background plugin, pipe-triggered from shell hooks
- **zellij-nvim-nav-plugin** — exactly the `MessagePlugin` keybind → payload →
  plugin chain we plan
- **multitask** — also uses `MessagePlugin` with payload string activation

### Potential tab-name conflicts

- Only **zellij-attention** also calls `rename_tab`. Last writer wins. If a user
  runs both, we'd need to coordinate (preserve their icon suffix). Document as
  known limitation; don't engineer around it in v0.1.
- Status bars (zjstatus, compact-bar, zj-status-bar) render whatever tab name
  the kernel reports. No contention.

### AI/LLM adjacent

- **zellaude** — Claude Code status bar with per-tab activity. Complementary, not
  overlapping.
- **opencode-zellij-namer** — AI-renames **sessions** (not tabs) via Gemini 3 Flash
  for OpenCode. Direct cousin. **Read its debouncing/cooldown logic before writing
  Section 4** — same failure modes transfer.
- No existing AI tab-renamer. We'd be the first.

### Nice-to-haves for user's personal setup (unrelated to this plugin)

- **zellij-forgot** — floating keybind cheatsheet (confirmed: NOT what we're
  building, despite surface similarity)
- **zellij-notepad** — floating notes pane in `$EDITOR`
- **zellij-worktree** — git worktree manager in floating pane

## Side-quests (parked)

These emerged during the brainstorm. Not part of the tab-renamer plugin.

### 1. Per-folder Zellij sessions via shell function

**Problem**: Zellij auto-generates session names ("random shitty names"). User
wants: `cd ~/code/foo; zj` → attach to or create the `foo` session, with
resurrection restoring tabs/layouts.

**Solution**: shell function, not a plugin. `zsm` is WASM-menu only and hard-depends
on zoxide.

```powershell
# ~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1
function zj {
    $name = (Split-Path -Leaf (Resolve-Path ($args[0] ?? $PWD)))
    zellij attach -c $name
}
```

`zellij attach -c <name>` = attach-or-create. `session_serialization true` (default
in 0.44) handles resurrection. Gotcha: two folders same basename collide.

### 2. `attach_to_session true` in `config.kdl`

Would auto-attach when `zellij` is run with no args. Deferred — we'll decide when
picking up the session-management thread.

### 3. zoxide + zsm install

Complementary to the shell function (in-Zellij session switcher). Deferred.

## Resume point

When picking this up:

1. Re-read this doc.
2. Read `zellij-attention` source again (src/lib.rs and src/state.rs) — it's the
   template for most of our code.
3. Verify `run_command` result event shape in `zellij-tile 0.43+` docs or source.
4. Resolve the "open questions" list above before writing Section 2b.
5. Continue with Section 2b (state machine).
