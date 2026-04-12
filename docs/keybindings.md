# Keybindings

Zellij is modal. The active mode determines what keystrokes do. You enter a mode with a keybinding, perform actions, then return to normal mode. Two presets ship out of the box: the default (Ctrl-leader) and non-colliding (starts locked, unlock first).

## Modes

| Mode | Default Entry | Purpose |
|------|--------------|---------|
| `normal` | (default) | Passes most keys to the terminal. Alt shortcuts work here |
| `locked` | `Ctrl g` | All keys pass to terminal. Zellij captures nothing |
| `pane` | `Ctrl p` | Navigate, open, close, resize, float, fullscreen panes |
| `tab` | `Ctrl t` | New, close, rename, go-to, reorder tabs |
| `resize` | `Ctrl n` | Resize focused pane with arrow keys |
| `move` | `Ctrl h` | Move pane position within the grid |
| `scroll` | `Ctrl s` | Scroll pane output; press `E` to open scrollback in $EDITOR |
| `search` | (from scroll) | Text search in the pane's scrollback buffer |
| `session` | `Ctrl o` | Session management (detach, switch, resurrect) |
| `tmux` | (user-configured) | tmux-compatible prefix mode for muscle-memory migration |

**Workflow**: Press mode key (e.g., `Ctrl p`) to enter Pane mode. Press action key (e.g., `d` for split down). Zellij returns to normal mode automatically after the action.

## Bind Syntax

Keybindings live inside `keybinds { }` in config. Each mode is a block. Each `bind` takes one or more keys and one or more actions:

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
    }
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
    }
}
```

**Key names**: `"Ctrl a"`, `"Alt f"`, `"F1"`, `"Enter"`, `"Space"`, `"Tab"`, bare characters like `"h"`.

**Multiple keys** on one `bind` line are each bound separately to the same actions.

**Multiple actions** in one `bind` block run together in sequence.

### Shared Bindings

Use `shared_except` or `shared_among` to bind keys across multiple modes without repetition:

```kdl
keybinds {
    shared_except "locked" "renametab" "renamepane" {
        bind "Alt h" { MoveFocusOrTab "Left"; }
        bind "Alt l" { MoveFocusOrTab "Right"; }
        bind "Alt j" { MoveFocus "Down"; }
        bind "Alt k" { MoveFocus "Up"; }
        bind "Alt f" { ToggleFloatingPanes; }
        bind "Alt n" { NewPane; }
    }
}
```

### Clearing Defaults

```kdl
keybinds clear-defaults=true {
    // ALL default bindings removed -- you must define everything
}
```

Without `clear-defaults=true`, your bindings add to or override the defaults.

## Common Actions Reference

| Action | What It Does |
|--------|-------------|
| `SwitchToMode "modename"` | Enter a mode |
| `NewPane` | Open pane (auto-placed) |
| `NewPane "Down"` / `"Right"` | Split in direction |
| `NewPane "stacked"` | Open stacked pane |
| `NewPane "floating"` | Open floating pane |
| `MoveFocus "Left\|Right\|Up\|Down"` | Navigate between panes |
| `MoveFocusOrTab "Left\|Right"` | Navigate panes or switch tabs at edge |
| `Resize "Increase\|Decrease\|Left\|Right\|Up\|Down"` | Resize focused pane |
| `ToggleFocusFullscreen` | Fullscreen current pane |
| `ToggleFloatingPanes` | Show/hide floating panes |
| `TogglePaneEmbedOrFloating` | Convert pane between tiled and floating |
| `TogglePaneFrames` | Show/hide pane borders globally |
| `PreviousSwapLayout` / `NextSwapLayout` | Cycle tab swap layouts |
| `GoToNextTab` / `GoToPreviousTab` | Tab navigation |
| `GoToTab N` | Go to tab by number |
| `Detach` | Detach from session |
| `Quit` | Quit session |

## Alt-Based Pattern (Recommended for Editor Users)

Alt-based bindings avoid Ctrl conflicts with neovim, helix, and readline. Navigation works from normal mode without entering a sub-mode:

```kdl
keybinds clear-defaults=true {
    shared_except "locked" "renametab" "renamepane" {
        bind "Alt h" { MoveFocusOrTab "Left"; }
        bind "Alt l" { MoveFocusOrTab "Right"; }
        bind "Alt j" { MoveFocus "Down"; }
        bind "Alt k" { MoveFocus "Up"; }
        bind "Alt f" { ToggleFloatingPanes; }
        bind "Alt n" { NewPane; }
    }
    normal {
        bind "Alt p" { SwitchToMode "pane"; }
        bind "Alt t" { SwitchToMode "tab"; }
        bind "Alt s" { SwitchToMode "scroll"; }
        bind "Alt o" { SwitchToMode "session"; }
    }
}
```

**Why Alt**: Alt is rarely intercepted by terminal apps. Ctrl conflicts with readline (Ctrl+A/E/R), vim (Ctrl+O), and shell signals (Ctrl+Z/C). Alt sidesteps all of these.

## Tmux-Mode Pattern (For tmux Migrants)

Use `Ctrl b` as a prefix key, just like tmux. Clear all other bindings to avoid conflicts:

```kdl
keybinds clear-defaults=true {
    normal {
        bind "Ctrl b" { SwitchToMode "tmux"; }
        bind "F12"    { SwitchToMode "locked"; }
    }
    tmux {
        bind "Ctrl b" { Write 2; SwitchToMode "normal"; }  // double-press passes Ctrl+B through
        bind "\"" { NewPane "Down"; SwitchToMode "normal"; }
        bind "%" { NewPane "Right"; SwitchToMode "normal"; }
        bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
        bind "c" { NewTab; SwitchToMode "normal"; }
        bind "," { SwitchToMode "renametab"; }
        bind "p" { GoToPreviousTab; SwitchToMode "normal"; }
        bind "n" { GoToNextTab; SwitchToMode "normal"; }
        bind "d" { Detach; }
    }
}
```

### tmux Migration Quick Reference

| tmux | Zellij (default) | Notes |
|------|------------------|-------|
| `Ctrl+B "` | `Ctrl+P` then `D` | Split horizontal |
| `Ctrl+B %` | `Ctrl+P` then `R` | Split vertical |
| `Ctrl+B <arrow>` | `Alt+H/J/K/L` | Pane navigation (no mode switch needed) |
| `Ctrl+B [` | `Ctrl+S` | Enter scroll/copy mode |
| `Ctrl+B d` | `Ctrl+O` then `D` | Detach |
| `Ctrl+B (` / `)` | `Ctrl+O` to session manager | No last-session hotkey |
| `Ctrl+B c` | `Ctrl+T` then `N` | New tab |
| `.tmux.conf` | KDL config file | Different syntax entirely |

## Non-Colliding Preset

Set `default_mode "locked"` in options. All keys pass to the terminal until you press `Ctrl g` to unlock. This eliminates all keybinding conflicts but adds keypresses to every Zellij action.

Best for users who rarely use Zellij features and primarily work in a single editor.

## Gotchas

- `clear-defaults=true` removes ALL bindings including `Ctrl g` (lock toggle) and `Quit`. Always re-add your escape bindings when clearing defaults
- Alt keybindings may not work in some terminal emulators. Kitty and WezTerm sometimes consume Alt before Zellij sees it. Test your Alt bindings after setup
- Ctrl+R / Ctrl+A / Ctrl+E stopping: usually caused by `$EDITOR=vi` putting zsh into vi-mode, not by Zellij. Fix with `bindkey -e` in `.zshrc`
- The non-colliding preset adds 2-4 extra keypresses per Zellij action compared to tmux's single prefix. This is a known trade-off
- No `switch-client -l` equivalent for toggling between last two sessions. Use the session manager or a third-party sessionizer plugin
