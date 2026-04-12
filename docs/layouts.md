# Layouts

Layouts define the initial pane and tab arrangement when a session or tab opens. They are KDL files that specify what panes to create, where to place them, what commands to run, and which directories to use.

## Key Facts

- Load a layout: `zellij --layout /path/to/layout.kdl`
- Inside an existing session, `--layout` adds the layout as new tabs (since 0.41). Use `--new-session-with-layout` to force a new session
- Layouts can be loaded from URLs: `zellij --layout https://example.com/layout.kdl` (commands start suspended for safety)
- Inline layout: `zellij --layout-string '<KDL string>'` (0.44.1+)
- Dump the default layout: `zellij setup --dump-layout`
- The Layout Manager plugin (`Ctrl o` then `l`, 0.44+) lets you browse, apply, and record layouts visually

## Basic Structure

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

Each `tab` contains panes. Panes can nest to create splits. A bare `pane` opens a default shell.

## Pane Attributes

| Attribute | Example | Effect |
|-----------|---------|--------|
| `split_direction` | `"vertical"` or `"horizontal"` | How child panes are arranged |
| `command` | `"nvim"` | Run this command instead of default shell |
| `args` | `"watch" "-x" "test"` | Arguments to the command |
| `cwd` | `"/my/project"` | Working directory |
| `name` | `"editor"` | Pane title in the UI |
| `borderless` | `true` | Hide this pane's frame |
| `focus` | `true` | Start with keyboard focus |
| `size` | `1` or `"50%"` | Fixed rows/columns or percentage |
| `stacked` | `true` | Start as a stacked pane |

## CWD Composition

Working directories compose from outer to inner. Relative paths are joined; absolute paths override.

```kdl
layout {
    cwd "/projects"
    tab cwd="frontend" {
        pane cwd="src"        // opens in /projects/frontend/src
        pane cwd="/tmp"       // opens in /tmp (absolute overrides)
    }
    tab cwd="backend" {
        pane                  // opens in /projects/backend
    }
}
```

Resolution order: pane cwd -> tab cwd -> layout global cwd -> command execution directory.

## Floating Panes in Layouts

```kdl
layout {
    tab name="dev" hide_floating_panes=true {
        pane
        floating_panes {
            pane x="10%" y="10%" width="80%" height="80%" command="htop"
        }
    }
}
```

- `hide_floating_panes=true` starts the floating panes hidden. Toggle with `Alt f`
- Floating pane position uses absolute values or percentages

## Plugin Panes

```kdl
layout {
    pane {
        plugin location="zellij:status-bar"
    }
    pane {
        plugin location="file:/path/to/plugin.wasm" {
            config_key "value"
        }
    }
}
```

## Pane Templates

Templates define reusable pane configurations. The `children` node marks where the consumer's content goes.

```kdl
layout {
    pane_template name="editor" {
        command "nvim"
    }
    pane_template name="log-watcher" command="tail"

    pane_template name="dev-sandwich" split_direction="vertical" {
        pane
        children    // consumer content goes here
        pane
    }

    // Use templates:
    editor                             // pane running nvim
    dev-sandwich {
        pane command="htop"            // inserted at children position
    }
    log-watcher { args "-f" "/tmp/app.log"; }
}
```

Templates can be nested and composed.

## Tab Templates

Tab templates work like pane templates but define an entire tab structure. Common use: wrapping every tab with a status bar.

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
    my-tab name="logs" {
        pane command="tail" args="-f" "/var/log/syslog"
    }
}
```

## Swap Layouts

Swap layouts define alternate arrangements that apply as panes are added or removed. Cycle through them with `PreviousSwapLayout` / `NextSwapLayout`.

```kdl
layout {
    swap_tiled_layout name="horizontal-then-vertical" {
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

- `max_panes` / `min_panes` conditionally apply a layout template based on pane count
- Swap layouts for tiled and floating panes are defined separately

## Examples

### Minimal dev workspace

```kdl
layout {
    cwd "~/projects/myapp"
    tab name="code" {
        pane command="nvim" focus=true
    }
    tab name="term" {
        pane split_direction="horizontal" {
            pane
            pane command="cargo" args="watch" "-x" "test"
        }
    }
}
```

### Compact layout with status bar

```kdl
layout {
    tab_template name="tab" {
        pane size=1 borderless=true {
            plugin location="zellij:compact-bar"
        }
        children
    }

    tab name="editor" {
        pane command="nvim"
    }
    tab name="shell" {
        pane
    }
}
```

## Gotchas

- `--layout` inside a session adds tabs to the current session (since 0.41). This surprises users who expect a new session. Use `--new-session-with-layout` for a new session
- Layouts from URLs start commands suspended for safety. You must press Enter to run each command
- A bare `pane` with no attributes opens a default shell. If you omit `pane` entirely in a tab, you get nothing
- CWD composition means relative paths are relative to the parent, not to your current directory. Use absolute paths when in doubt
- Tab and pane templates require the `children` node to place consumer content. Forgetting `children` means the consumer's body is ignored silently
