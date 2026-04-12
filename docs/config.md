# Configuration

Zellij uses KDL (KDL Document Language) for configuration. KDL is node-based -- not YAML, not TOML. The config file is live-reloaded: changes apply to running sessions without restart (since 0.41).

Default location: `~/.config/zellij/config.kdl` (Linux/macOS) or `%APPDATA%\zellij\config.kdl` (Windows).

## Key Facts

- KDL uses nodes, not key-value pairs: `node_name argument { child_node; }`
- Comments: `//` for single-line
- Strings are quoted: `"value"`. Booleans are bare: `true` / `false`
- Migrate old YAML configs: `zellij convert-config /path/to/config.yaml`
- Migrate old YAML themes: `zellij convert-theme /path/to/theme.yaml > theme.kdl`
- Dump the full default config: `zellij setup --dump-config`
- Dump the default layout: `zellij setup --dump-layout`
- Validate your environment: `zellij setup --check`

## Options Block

All top-level settings go inside `options { }`. Here is a complete reference of commonly used options:

```kdl
options {
    // Shell and layout
    default_shell "zsh"
    default_layout "compact"          // "compact" uses the one-line status bar
    default_mode "normal"             // "locked" for non-colliding preset

    // UI
    pane_frames false                 // hide pane borders (more vertical space)
    simplified_ui true                // disable arrow/powerline fonts in UI
    theme "catppuccin-mocha"

    // Mouse
    mouse_mode true                   // mouse support (default: true)
    focus_follows_mouse false         // (0.44+)
    mouse_click_through false         // (0.44+)
    mouse_hover_effects true          // hover highlights and tooltips (0.44+)

    // Clipboard
    copy_command "xclip -selection clipboard"   // or "pbcopy" on macOS
    copy_on_select false              // copy to clipboard on mouse release

    // Scrollback
    scroll_buffer_size 10000
    scrollback_editor "/usr/bin/nvim" // editor for scroll-mode "E" action

    // Session persistence
    on_force_close "detach"           // detach instead of kill on terminal close
    session_serialization true        // enable resurrection (default: true)
    serialize_pane_viewport true      // also restore visible pane content
    scrollback_lines_to_serialize 1000

    // Misc
    stacked_resize true               // auto-stack panes on resize (0.42+)
    show_startup_tips true            // random tip on startup (0.42+)
    show_release_notes true           // release notes on first run of new version
}
```

## Plugin Aliases Block

Plugin aliases map short names to plugin URLs. Zellij depends on the default aliases -- do not remove them entirely.

```kdl
plugins {
    tab-bar         location="zellij:tab-bar"
    status-bar      location="zellij:status-bar"
    compact-bar     location="zellij:compact-bar"
    strider         location="zellij:strider" { cwd "/"; }
    session-manager location="zellij:session-manager"
    welcome-screen  location="zellij:session-manager" { welcome_screen true; }
    filepicker      location="zellij:strider" { cwd "/"; }
    about           location="zellij:about"
}
```

- `compact-bar` supports an optional tooltip: add `{ tooltip "F1"; }` to show keybinding hints on keypress
- Replace built-in plugins with custom WASM implementations by changing the `location` URL
- Load plugins at session start with the `load_plugins { }` block

## Theme System

Built-in themes include: `catppuccin-mocha`, `dracula`, `nord`, `one-dark`, `gruvbox-dark`, `ao`, `ayu_dark`, `ayu_light`, `vesper`, `night-owl`, `iceberg-dark`, `iceberg-light`, `onedark`, `ansi`, `lucario`.

Set the active theme in the options block:

```kdl
options {
    theme "catppuccin-mocha"
}
```

Custom themes use the new component-based spec (0.42+):

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
        // other UI components...
    }
}
```

## Examples

### Minimal config for a clean setup

```kdl
options {
    pane_frames false
    simplified_ui true
    default_layout "compact"
    theme "catppuccin-mocha"
    on_force_close "detach"
    copy_on_select true
}
```

### Non-colliding preset (starts locked)

```kdl
options {
    default_mode "locked"
}
```

All keys pass to the terminal by default. Press `Ctrl g` to unlock before using any Zellij keybinding. Avoids all conflicts with terminal apps.

## Gotchas

- KDL is not widely known. Error messages for syntax mistakes can be cryptic -- validate with `zellij setup --check`
- `clear-defaults=true` on the `keybinds` block removes ALL default bindings, including quit and lock mode. You must re-add everything you need. Only override specific modes if you want partial customization
- `simplified_ui true` is required if your font lacks Nerd Font or Powerline glyphs -- otherwise the status bar shows broken characters
- Config changes reload live, but keybinding changes in some contexts may need a session restart to take effect
- The `plugins { }` block defines aliases only. To load plugins at session start, use `load_plugins { }` separately
