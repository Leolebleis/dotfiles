# Panes

Panes are the individual terminal regions inside a tab. Zellij has three pane types: tiled (fixed in a grid), floating (overlay windows), and stacked (collapsed into a shared space). Each pane runs a shell, a specific command, or a plugin.

## Key Facts

- Panes can be renamed, resized, moved, fullscreened, embedded, or floated at any time
- Command panes (`zellij run -- <cmd>`) show "Press ENTER to run" on first open and after the command exits. Press Enter to rerun, Ctrl+C to close
- Mouse resize: drag pane borders, or Ctrl+scroll while hovering a border (0.44+)
- `pane_frames false` in config hides all pane borders globally. Individual panes can also be set `borderless true` in layouts (0.44+)
- Borderless toggling at runtime is available since 0.44

## Tiled Panes

Tiled panes fill the tab in a grid. Zellij auto-places new tiled panes by splitting the focused pane.

**Open a tiled pane:**
- `Alt n` (normal mode) -- auto-places a new pane
- `Ctrl p` then `d` -- split down
- `Ctrl p` then `r` -- split right
- `zellij run -- <command>` from CLI

**Navigate:**
- `Alt h/j/k/l` or `Alt+arrows` -- move focus between panes
- `MoveFocusOrTab "Left"/"Right"` -- at the edge of the tab, switches to adjacent tab instead

**Resize:**
- Enter resize mode (`Ctrl n`), then use arrow keys
- Mouse: drag borders or Ctrl+scroll on a border

**Fullscreen:**
- `ToggleFocusFullscreen` -- expand current pane to fill the tab. Press again to restore

## Floating Panes

Floating panes sit above the tiled layout as overlay windows. They persist while hidden.

**Lifecycle:**
1. `Alt f` toggles floating pane visibility for the current tab
2. First press creates a floating pane if none exist
3. Hiding floating panes (`Alt f` again) does NOT kill them. Commands keep running in the background
4. Show them again to see current output

**Open a floating pane:**
- `Alt f` -- toggle visibility (creates one if none exist)
- `Ctrl p` then `w` -- new floating pane (from pane mode)
- `zellij run --floating -- <command>` from CLI

**Position and size:**
- Floating panes can be opened at specific x/y coordinates with explicit width/height via CLI or layouts
- In layouts: `pane x="10%" y="10%" width="80%" height="80%"` inside a `floating_panes { }` block

**Convert between types:**
- `TogglePaneEmbedOrFloating` -- convert a floating pane to tiled (embed it) or a tiled pane to floating

**Hide on tab creation:**
- In layouts, `hide_floating_panes=true` on a tab starts floating panes hidden

## Stacked Panes

Stacked panes share the same screen space. Only the focused pane's body is visible; the others show just their title bar. Navigate between stacked panes by clicking their title or with keyboard focus.

**Open a stacked pane:**
- `Ctrl p` then `s` -- new stacked pane (0.42+)
- `NewPane "stacked"` action in keybindings

**Stacked resize (0.42+):**
- When `stacked_resize true` (default), resizing panes automatically stacks neighbors that would become too small
- Disable with `stacked_resize false` in options

**When to use stacked panes:**
- Group related panes (e.g., test runner + build watcher) in the same area
- Maximize visible space on small screens while keeping multiple panes accessible

## Pinned Floating Panes (0.42+)

A floating pane can be pinned to stay visible even when floating panes are toggled off or when switching focus.

**Pin/unpin:** `Ctrl p` then `i` (from pane mode).

**Use cases:**
- Keep a monitoring pane (logs, tests) always visible while working in tiled panes
- Reference material that should stay on screen across tab switches

## Examples

### Open a floating command pane from CLI

```bash
zellij run --floating -- cargo test
```

The test output appears in a floating overlay. When the command exits, press Enter to rerun or Ctrl+C to close.

### Auto-close on success

```bash
zellij run --floating --close-on-exit -- make build
```

The pane closes automatically when the command succeeds.

### Run in place of current pane

```bash
zellij run --in-place -- htop
```

### Floating pane at specific position

```bash
zellij run --floating --x 5 --y 5 --width 80 --height 20 -- tail -f /var/log/app.log
```

## Gotchas

- Hiding floating panes does NOT kill them. New users often assume hide means close. The process keeps running
- `pane_frames false` is recommended for mouse-heavy workflows. With frames enabled, clicking to select text can accidentally select the border instead
- Auto-placement of new tiled panes can feel unpredictable. Zellij splits the focused pane, not always where you expect. Use directional splits (`NewPane "Down"` / `"Right"`) for control
- `zellij run` behaves differently inside vs outside a session: inside opens a new pane, outside starts a new session
- The `--close-on-exit` and `--floating` flags on `zellij run` only work inside an existing session
