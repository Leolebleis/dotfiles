# Zellij Official Docs -- Research Notes

Sources: https://zellij.dev/documentation/ (context7, high-rep, 1123 snippets), GitHub releases API (zellij-org/zellij).

---

## Core Concepts

### Sessions
- A Zellij session is an isolated workspace with its own set of tabs and panes.
- Multiple sessions can run simultaneously; each has a name (auto-generated or user-supplied).
- Sessions survive terminal closure (they keep running in the background).
- Sessions can be shared between multiple clients ("multiplayer") -- all clients see the same view.
- Sessions are serialized to the cache folder for resurrection after quit or crash (configurable).

### Tabs
- Tabs are the top-level organizational unit inside a session.
- Each tab has its own pane layout.
- Tabs can be named, reordered, and navigated with keybindings.
- Tabs can have swap layouts -- alternate arrangements that cycle through as you add panes.

### Panes
- Panes are the individual terminal regions inside a tab.
- Two types: **tiled** (fixed in the grid) and **floating** (overlay windows).
- Panes can run a shell, a specific command, or a plugin.
- Command panes (started with `command`/`args`) restart or resume on demand.
- Panes can be renamed, resized, moved, fullscreened, embedded, or floated at any time.
- **Borderless panes**: individual panes can have their frame/border hidden (0.44+).
- **Stacked panes**: panes can be stacked with their neighbors (title visible but body hidden) to reclaim screen space; navigate by click or keyboard. Stacked resize (0.42+) makes this automatic on resize.
- **Pinned floating panes** (0.42+): a floating pane can be pinned to stay on top even when unfocused.

### Floating Panes
- Floating panes are overlay panes that sit above the tiled layout in the current tab.
- Toggled as a group with a keybind (default `Alt f`).
- Can be opened at specific x/y coordinates and with explicit width/height.
- Can be embedded (converted to tiled) and vice versa.
- A tab can have `hide_floating_panes=true` so they start hidden.
- Can be pinned to always stay visible (0.42+).

### Modes
Zellij is modal. The active mode determines what keystrokes do.

| Mode | Purpose |
|------|---------|
| `normal` | Default; passes most keys to the terminal |
| `locked` | All keys pass to terminal; Zellij captures nothing (Ctrl g to toggle) |
| `pane` | Manage/navigate panes (move focus, open, close, resize, float, fullscreen) |
| `tab` | Manage tabs (new, close, rename, go-to, reorder) |
| `resize` | Resize focused pane with arrow keys |
| `move` | Move pane position within the grid |
| `scroll` | Scroll pane output; enter search within scroll buffer |
| `search` | Text search in the current pane's scrollback |
| `session` | Session management actions (detach, switch, resurrect) |
| `tmux` | tmux-compatibility mode for muscle-memory migration |

- Modes are entered via keybinds (e.g., `Ctrl p` enters Pane mode).
- Two keybinding presets: **default** (Ctrl-leader) and **non-colliding** (starts locked, unlock first).
- The non-colliding preset avoids Ctrl conflicts with terminal apps; introduced in 0.41.

---

## Configuration

### File Location
- Default: `~/.config/zellij/config.kdl` (Linux/macOS) or `%APPDATA%\zellij\config.kdl` (Windows).
- Config is live-reloaded -- changes apply to running sessions (since 0.41).
- The user's config is at: `~/Documents/code/dotfiles/zellij/config.kdl`.

### KDL Syntax Basics
- KDL (KDL Document Language) uses node-based syntax, not TOML or YAML.
- Comments: `//` single-line.
- Nodes: `node_name argument { child_node; ... }`.
- String values quoted: `"value"`, bare identifiers unquoted.
- Boolean: `true` / `false`.
- Migrate old YAML config with: `zellij convert-config /path/to/config.yaml`.
- Migrate old YAML themes with: `zellij convert-theme /path/to/theme.yaml > theme.kdl`.

### Keybind Structure
```kdl
keybinds {
    normal {
        bind "Ctrl g" { SwitchToMode "locked"; }
        bind "Alt n" { NewPane; }
        bind "Alt h" "Alt Left" { MoveFocusOrTab "Left"; }
    }
    pane {
        bind "h" "Left" { MoveFocus "Left"; }
        bind "s" { NewPane "stacked"; SwitchToMode "normal"; }
        bind "i" { TogglePaneFrames; SwitchToMode "normal"; }
    }
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
    }
}
```
- Each `bind` can take multiple keys (all bound separately) and multiple actions (all run together).
- Key names: `"Ctrl a"`, `"Alt f"`, `"F1"`, `"Enter"`, `"Space"`, `"Tab"`, bare chars like `"h"`.
- `keybinds clear-defaults=true { ... }` to start from scratch (no inherited defaults).

### Important Actions (keybind targets)
- `SwitchToMode "modename"` -- enter a mode
- `NewPane`, `NewPane "stacked"`, `NewPane "floating"` -- open panes
- `MoveFocus "Left|Right|Up|Down"`, `MoveFocusOrTab "Left|Right"` -- navigate
- `Resize "Increase|Decrease|Left|Right|Up|Down"` -- resize pane
- `ToggleFocusFullscreen` -- fullscreen current pane
- `ToggleFloatingPanes` -- show/hide floating panes
- `TogglePaneEmbedOrFloating` -- convert pane between tiled and floating
- `TogglePaneFrames` -- show/hide pane borders globally
- `PreviousSwapLayout`, `NextSwapLayout` -- cycle tab swap layouts
- `GoToPreviousTab`, `GoToNextTab`, `GoToTab N` -- tab navigation
- `Detach` -- detach from session
- `Quit` -- quit session

### Common Options (in `options { ... }` block)
```kdl
options {
    default_shell "zsh"
    default_layout "compact"
    default_mode "normal"         // or "locked" for non-colliding preset
    pane_frames false              // hide pane borders globally
    simplified_ui true             // disable arrow fonts in UI
    theme "catppuccin-mocha"
    mouse_mode true                // enable mouse support (default true)
    scroll_buffer_size 10000
    copy_command "xclip -selection clipboard"
    copy_on_select false
    scrollback_editor "/usr/bin/nvim"
    session_serialization true     // enable resurrection (default true)
    stacked_resize true            // auto-stack on resize (0.42+, default true)
    focus_follows_mouse false      // (0.44+)
    mouse_click_through false      // (0.44+)
    mouse_hover_effects true       // hover highlights/tooltips (0.44+)
    show_startup_tips true         // random tip on startup (0.42+)
    show_release_notes true        // show release notes on first run of new version (0.42+)
}
```

### Theme System
- Old spec: map palette keys to RGB values.
- New spec (0.42+): named UI components (ribbons, backgrounds, emphasis levels).

```kdl
themes {
    my-theme {
        ribbon_unselected {
            base 0 0 0
            background 255 153 0
            emphasis_0 255 53 94
            emphasis_1 255 255 255
            emphasis_2 0 217 227
            emphasis_3 255 0 255
        }
        // other components...
    }
}
```
- Built-in themes include: `catppuccin-mocha`, `dracula`, `nord`, `one-dark`, `gruvbox-dark`, `ao`, `ayu_dark`, `ayu_light`, `vesper`, `night-owl`, `iceberg-dark`, `iceberg-light`, `onedark`, `ansi`, `lucario`, and more.
- Set active theme: `theme "theme-name"` in `options { }`.

### Plugin Aliases Block
```kdl
plugins {
    tab-bar    location="zellij:tab-bar"
    status-bar location="zellij:status-bar"
    strider    location="zellij:strider" { cwd "/"; }
    compact-bar location="zellij:compact-bar"
    // compact-bar with tooltip:
    // compact-bar location="zellij:compact-bar" { tooltip "F1"; }
    session-manager location="zellij:session-manager"
    welcome-screen location="zellij:session-manager" { welcome_screen true; }
    filepicker location="zellij:strider" { cwd "/"; }
    about location="zellij:about"
}
```
- Aliases map short names to plugin URLs with optional config.
- Can swap built-in plugins for custom implementations.
- Do not remove default aliases entirely -- Zellij depends on them.

### Load Plugins on Startup
```kdl
load_plugins {
    // background plugins loaded on session start (since 0.41)
    // example: myplugin location="file:/path/to/plugin.wasm"
}
```

---

## Layouts

### What Layouts Do
- Layouts define the initial pane/tab arrangement when a session or tab opens.
- Written in KDL, loaded via `zellij --layout /path/to/layout.kdl`.
- Since 0.41, `--layout` inside an existing session adds the layout as new tabs (not a nested session). Use `--new-session-with-layout` for the old behavior.
- Layouts can be loaded from URLs: `zellij --layout https://example.com/my.kdl` (commands start suspended for safety).
- Layouts location: `~/Documents/code/dotfiles/zellij/layouts/`.

### Basic Structure
```kdl
layout {
    tab name="Editor" {
        pane split_direction="vertical" {
            pane command="nvim" cwd="/my/project"
            pane split_direction="horizontal" {
                pane command="cargo" args="watch" cwd="/my/project"
                pane
            }
        }
    }
    tab name="Logs" {
        pane command="tail" args="-f" "/var/log/app.log"
    }
}
```

### Pane Attributes
- `split_direction="vertical|horizontal"` -- how children split
- `command "cmd"` + `args "arg1" "arg2"` -- run a command
- `cwd "/path"` -- working directory (relative paths compose with parent)
- `name "title"` -- pane title
- `borderless true` -- hide frame
- `focus true` -- start with focus

### CWD Composition
```kdl
layout {
    cwd "/hi"
    tab cwd="there" {
        pane cwd="friend" // opens in /hi/there/friend
        pane cwd="/absolute" // opens in /absolute (overrides)
    }
}
```
CWD resolution order: pane -> tab -> layout global -> command execution dir.

### Floating Panes in Layouts
```kdl
tab name="Tab #1" hide_floating_panes=true {
    pane         // tiled
    floating_panes {   // start hidden due to hide_floating_panes=true
        pane x="10%" y="10%" width="80%" height="80%"
    }
}
```

### Pane Templates (Reusable Blocks)
```kdl
layout {
    pane_template name="editor" {
        command "nvim"
    }
    pane_template name="log-watcher" command="tail" // inline form

    pane_template name="dev-sandwich" split_direction="vertical" {
        pane
        children       // where the consumer's content goes
        pane
    }

    // Use templates:
    editor                        // becomes a pane running nvim
    dev-sandwich {
        pane command="htop"
    }
    log-watcher { args "-f" "/tmp/app.log"; }
}
```
- `children` is a special node inside a template that marks where the consumer's body goes.
- Templates can be nested and composed.

### Tab Templates
```kdl
layout {
    tab_template name="my-tab" {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    my-tab name="main" {
        pane
    }
}
```

### Swap Layouts
Swap layouts define alternate arrangements that get applied as panes are added/removed.
```kdl
layout {
    swap_tiled_layout name="h2v" {
        tab max_panes=2 {
            pane
            pane
        }
        tab {
            pane split_direction="vertical" {
                pane
                pane
                pane
            }
        }
    }
    swap_floating_layout name="spread" {
        tab max_panes=3 {
            pane
        }
        tab {
            pane
            pane
        }
    }
}
```
- `PreviousSwapLayout` / `NextSwapLayout` actions cycle through them.
- `max_panes` / `min_panes` conditionally apply a layout template.

### Plugin Panes in Layouts
```kdl
pane {
    plugin location="zellij:status-bar"
}
pane {
    plugin location="file:/path/to/plugin.wasm" {
        config_key "value"
    }
}
```

---

## Plugins

### Plugin URL Schemas
- `zellij:name` -- built-in plugins (e.g., `zellij:tab-bar`)
- `file:/absolute/path/to/plugin.wasm` -- local WASM file
- `https://example.com/plugin.wasm` -- remote URL
- Bare alias name (e.g., `filepicker`) -- resolved via `plugins { }` block

### Built-in Plugins

| Alias | URL | Purpose |
|-------|-----|---------|
| `tab-bar` | `zellij:tab-bar` | Tab navigation bar |
| `status-bar` | `zellij:status-bar` | Classic bottom status bar with keybinding hints |
| `compact-bar` | `zellij:compact-bar` | One-line status bar; optional tooltip on key toggle |
| `strider` / `filepicker` | `zellij:strider` | File tree / file picker |
| `session-manager` | `zellij:session-manager` | Session management UI (attach, detach, resurrect) |
| `welcome-screen` | `zellij:session-manager` (with flag) | Startup session picker |
| `about` | `zellij:about` | Release notes and startup tips browser (`Ctrl o` + `a`) |
| `plugin-manager` | `zellij:plugin-manager` | List, load, reload plugins (`Ctrl o` + `p`) |
| `configuration` | `zellij:configuration` | Change keybinding presets, leader keys (`Ctrl o` + `c`) |
| `layout-manager` | `zellij:layout-manager` | Open/apply/record layouts (`Ctrl o` + `l`, added 0.44) |
| `share` | `zellij:share` | Web session sharing + read-only tokens (`Ctrl o` + `s`, added 0.43) |
| `link` | built-in | Click-to-open file paths (Alt+Click, added 0.44; disable by commenting out) |

### Permission System (since 0.38)
- Plugins must declare required permissions and request them at load time.
- Users see a prompt to grant/deny.
- Key permissions: `ReadApplicationState`, `ChangeApplicationState`, `WriteToStdin`, `InterceptInput`, `OpenFiles`, `RunCommands`, `WebAccess`.

### Plugin Development
- Plugins are compiled to WASM (Rust SDK: `zellij-tile`).
- WASM runtime: migrated from `wasmtime` to `wasmi` in 0.44 (no explicit compile/cache step needed).
  - Performance tip: add `lto=true`, `strip=true`, `codegen-units=1` to `[profile.release]`.
- Plugins have access to `/host` (host filesystem access), `/tmp`, and `/cache` (persistent per-plugin cache, since 0.41.2).
- Plugin APIs (partial list): open panes, send keys, scroll, manage tabs, read pane scrollback, highlight viewport text, set pane colors, load/reload plugins, intercept input, pipe messages between plugins.
- Config propagation: plugin config changes propagate to running plugins (since 0.44).

### Plugin Pipes
- Plugins communicate via `pipe_message_to_plugin` API.
- CLI pipes: `zellij pipe --plugin <url> -- message` sends a message to a running or new plugin instance.

---

## CLI Commands

### Top-level Subcommands
```
zellij [OPTIONS] [SUBCOMMAND]
  --layout <FILE|URL>            Start with this layout
  --new-session-with-layout <F>  Start a NEW session even if inside Zellij (vs. --layout)
  --session <NAME>               Target a named session
  --config <FILE>                Custom config file
  --config-dir <DIR>             Custom config directory
  --layout-string <KDL>          Provide layout inline as a string (0.44.1+)
```

### attach / a
```bash
zellij attach [session-name]          # attach to session (auto if only one)
zellij attach <name> --force-run-commands  # resurrect and immediately run commands
zellij attach https://host/session    # attach over HTTPS (remote, 0.44+)
```

### run
```bash
zellij run -- <command> [args]
  -f, --floating               open in floating pane
  -d, --direction up|down|left|right
  -n, --name <NAME>            pane title
  -c, --close-on-exit          close pane when command exits
  -s, --start-suspended        open suspended, run on Enter
  -i, --in-place               open in place of current pane
      --blocking               block CLI until pane closes
      --block-until-exit-success  block CLI only if command succeeds
      --block-until-exit-failure  block CLI only if command fails
      --cwd <DIR>
      --x <X> --y <Y> --width <W> --height <H>   (for floating)
      --tab-id <N>             open in specific tab (0.44.1+)
```
- Returns the new pane_id on stdout.

### action
```bash
zellij action <ACTION> [flags]

# Pane actions
zellij action new-pane [--floating] [--direction up|...] [--name N]
zellij action close-pane
zellij action focus-next-pane / focus-previous-pane
zellij action move-pane [--direction up|...]
zellij action rename-pane <NAME>
zellij action dump-screen [--pane-id <ID>] [--include-scrollback]
zellij action send-keys "Enter" "Ctrl c" "a" "b"   # send human-readable keys
zellij action list-panes [--json] [--session <NAME>]
zellij action focus-pane-with-id <ID>   (0.44.1+)

# Tab actions
zellij action new-tab [--layout F] [--name N] [--cwd D]  # returns tab index
zellij action close-tab
zellij action go-to-tab <N>
zellij action rename-tab <NAME>

# Session actions
zellij action switch-session [session-name]
zellij action switch-mode <mode>

# Misc
zellij action toggle-fullscreen
zellij action toggle-floating-panes
zellij action toggle-pane-embed-or-floating
zellij action are-floating-panes-visible  (0.44.1+)
```

### detach
```bash
zellij detach    # detach from current session (added as explicit CLI command in 0.44)
```

### list-sessions / ls
```bash
zellij list-sessions   # list running sessions
zellij ls              # alias
```

### list-aliases
```bash
zellij list-aliases    # show resolved plugin aliases
```

### setup
```bash
zellij setup --dump-config    # print default config to stdout
zellij setup --dump-layout    # print default layout to stdout
zellij setup --generate-completion <shell>   # generate shell completion
zellij setup --check          # validate environment
```

### subscribe (0.44+)
```bash
zellij subscribe [--pane-id <ID>] [--json] [--ansi]
# Continuously stream pane viewport/scrollback updates
```

### pipe
```bash
zellij pipe --plugin <URL> -- <message>
```

### convert-config / convert-theme
```bash
zellij convert-config /path/to/config.yaml
zellij convert-theme  /path/to/theme.yaml > theme.kdl
```

---

## Session Management

### Attach/Detach
- `zellij attach [name]` -- attach; auto-selects if only one session running.
- `zellij detach` (CLI, 0.44+) or `Detach` keybind action inside a session.
- Detaching leaves the session running; processes continue in background.

### Session Naming
- Sessions get auto-generated memorable names by default.
- `zellij --session my-name` starts with a specific name.
- Session names must be unique.

### Session Resurrection
- Sessions are serialized to the cache directory by default (`session_serialization true`).
- Serializes: pane/tab layout, commands running in each pane.
- Optional: also serialize viewport/scrollback (`serialize_pane_viewport true`, `serialize_scrollback_lines N`).
- Resurrected command panes show "Press ENTER to run..." -- user must confirm before re-execution.
- `zellij attach <name> --force-run-commands` skips the confirmation prompt.
- Exited sessions appear in the session manager under "EXITED".
- `post_command_discovery_hook` (0.43+): apply edits to serialized commands before they're saved (helps with nix wrappers, pipeline commands, etc.).

### New Session Manager UI (0.44)
- Single-screen UI: create new, attach existing, resurrect exited -- all from one screen.
- Specify session name and it auto-decides what to do.
- Old multi-screen experience available with `multi_screen true` in session-manager config.

### Web / Remote Attach (0.43-0.44)
- `zellij web` starts a built-in HTTPS web server to share sessions in the browser.
- Authentication tokens are required (enforced by default).
- Read-only tokens: `zellij web --create-read-only-token` or via share plugin.
- Remote terminal attach: `zellij attach https://example.com/session-name`.
- A `zellij-no-web` binary is provided for users who want no web capability.

### Forwards Compatibility (0.44+)
- A protobuf-based client/server contract was introduced in 0.44.
- Future versions will be able to connect to existing 0.44+ sessions without killing them.
- Prior to 0.44, every upgrade orphaned existing sessions.

---

## Recent Changes (0.40 to 0.44.1)

### v0.40.0 -- Major Features
- Welcome screen (session manager on startup).
- New filepicker (strider plugin).
- Plugin pipes (inter-plugin and CLI-to-plugin messaging).
- Open floating panes at specific x/y coordinates.
- Rearrange/reorder tabs.
- Disconnect other clients.
- Plugin aliases block in config.
- Start Zellij session in the background from CLI.
- New bindable keys added.
- **Note**: Users with custom configs must update their `plugins` block to get welcome screen and filepicker.

### v0.40.1 -- Patch
- `Ctrl j` is now bindable (was previously intercepted by terminal).
- `zellij action list-clients` command added.

### v0.41.0 -- Breaking + Major
- **BREAKING**: `--layout` inside a Zellij session now adds tabs to current session (not nested). Use `--new-session-with-layout` for old behavior.
- **BREAKING**: `ENTER` key changed in plugin events (sent explicitly, not as `Char('\n')`).
- **BREAKING**: `zellij-tile` API changed to support multi-modifier keybindings.
- **BREAKING**: Key forwarding now based on `default_mode`, not just `locked`/`normal`.
- Non-colliding keybinding preset (unlock-first workflow).
- New Configuration screen (`Ctrl o` + `c`).
- First-run Setup Wizard.
- Kitty Keyboard Protocol support (multi-modifier keys, Super key).
- Config live reloading.
- WASM runtime: switched to `wasmtime`.
- New Plugin Manager (`Ctrl o` + `p`).
- `--layout` supports URLs (commands start suspended for safety).
- New status-bar design (single line, chord-aware). Old bar: `zellij --layout classic`.
- `load_plugins` section in config for background startup plugins.
- Many new themes: `ao`, `ayu_mirage`, `ayu_dark`, `ayu_light`, `vesper`, `night-owl`, `iceberg-dark`, `iceberg-light`, `onedark`, `ansi`, `lucario`.

### v0.41.2 -- Patch
- Kitty keyboard protocol fix for some terminals.
- Plugins now have a `/cache` folder that persists between runs.

### v0.42.0 -- New Features
- Stacked Resize: resizing panes auto-stacks neighbors (disable: `stacked_resize false`).
- Pinned floating panes: `Ctrl p` + `i` to pin/unpin.
- New theme definition spec (component-based, not palette-based).
- Double/triple click text selection in terminal panes.
- Stack keybinding: `Ctrl p` + `s` to open a new stacked pane.
- Release notes on startup (first run of new version) and random tips on subsequent runs.
- New `about` plugin (`Ctrl o` + `a`) to browse release notes and tips.
- Mouse: read motions in plugins; change `/host` folder, floating pane coordinates, stack panes via API.

### v0.42.2 -- Patch
- Rendering performance: consolidate renders, introduce `repaint_delay`.
- Fixed Rust 1.86 `--locked` build failure.

### v0.43.0 -- Web Client
- Web client: built-in HTTPS web server for browser-based terminal access.
- Multiple pane select (`Alt` + click or `Alt p`) for bulk operations.
- Keybinding tooltips for compact-bar (optional, configure with `tooltip "F1"`).
- Async rendering engine (smoother perceived performance).
- Stack keybinding in Pane mode (`Ctrl p` + `s`).
- Multiline hyperlink fix (OSC 8).
- `post_command_discovery_hook` for session resurrection command patching.
- `zellij-no-web` binary option introduced.

### v0.43.1 -- Patch
- Pane rename backspace regression fix.
- Terminal title regression fix.
- Resurrection listing fix.

### v0.44.0 -- Major Features
- **Native Windows support** (community contribution by @divens).
- **Layout Manager** built-in plugin (`Ctrl o` + `l`): open, apply, record layouts; `override-layout` command.
- **Terminal-to-terminal remote attach** over HTTPS: `zellij attach https://host/session`.
- **Read-only session sharing** with `zellij web --create-read-only-token`.
- **CLI automation expanded**: `zellij detach`, `zellij action switch-session`, `zellij action list-panes`, `zellij action send-keys`, `zellij subscribe`, `zellij action dump-screen --pane-id`.
- `zellij run` blocking flags: `--blocking`, `--block-until-exit-success`, `--block-until-exit-failure`.
- CLI commands that create panes now return pane_id; tab-creating commands return tab index.
- Pane resize with mouse: drag borders; Ctrl+scroll while hovering.
- Click-to-open file paths: Alt+Click opens file in floating pane (built-in `link` plugin).
- New Session Manager UI (single screen).
- Borderless panes toggle at runtime.
- Terminal BEL forwarding with visual indication from unfocused tabs.
- `focus_follows_mouse` and `mouse_click_through` config options.
- Line-wrapping/resize performance improvements.
- **WASM runtime migrated from `wasmtime` to `wasmi`**: no explicit compile/cache step; add LTO to Cargo profile for best plugin performance.
- **Protobuf client/server contract**: forwards compatibility from this version on.
- New plugin APIs: read pane scrollback with ANSI, config propagation, query env vars, highlight viewport text, change pane colors, explicit session save.
- `OSC-99` desktop notifications forwarded.

### v0.44.1 -- Patch
- Fixed tab-switching performance regression.
- Properly report OSC52 clipboard support in DA1 (helps Neovim clipboard discovery).
- Codex scrolling bug mitigation.
- Various Windows port fixes.
- Web client uses `base-url` when switching sessions.
- CJK IME cursor positioning fix.
- Added `focus-pane-with-id` and `are-floating-panes-visible` CLI actions.
- `zellij --layout-string` for inline layout provision.
- `--tab-id` flag on all pane-opening CLI actions.
