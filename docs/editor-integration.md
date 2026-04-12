# Editor Integration

The most-cited reason experienced users don't adopt Zellij is keybinding conflicts with neovim and other terminal editors. This file covers the problem, the solutions, and the known limitations.

## The Problem

Zellij's default keybindings intercept keys before your editor sees them:

| Zellij Default | Conflicts With |
|---------------|---------------|
| `Ctrl p` (pane mode) | Vim's Ctrl+P (completion, file finder) |
| `Ctrl o` (session mode) | Vim's Ctrl+O (jump list back) |
| `Ctrl s` (scroll mode) | Shell's Ctrl+S (XOFF/suspend output) |
| `Ctrl n` (resize mode) | Vim's Ctrl+N (completion next) |
| `Alt h/j/k/l` (navigation) | Some terminal emulator shortcuts |

## Solutions (Ranked by Popularity)

### 1. Alt-Based Keybindings

Remap all Zellij bindings to Alt. Alt is rarely used by terminal applications, so conflicts disappear. See `keybindings.md` for the full Alt-based config pattern.

**Pros**: No extra keypresses. No plugins needed. Works everywhere.
**Cons**: Some terminal emulators (Kitty, WezTerm) may consume certain Alt combinations.

### 2. zellij-autolock Plugin

Auto-locks Zellij when an editor is focused. All keys pass to the editor. When you leave the editor pane, Zellij unlocks.

Install: download the WASM file and add to your plugin config.

```kdl
plugins {
    autolock location="file:~/.config/zellij/plugins/zellij-autolock.wasm" {
        triggers "nvim|vim|helix"   // regex of commands that trigger lock
        watch_triggers "fzf|zoxide" // also lock for these interactive tools
    }
}
load_plugins {
    autolock
}
```

**Pros**: Transparent -- you never think about modes. Works with default keybindings.
**Cons**: Requires a third-party plugin. Must configure the trigger list for each editor/tool you use.

### 3. zellij.vim Plugin

A neovim plugin that integrates Zellij pane navigation with vim split navigation. Combined with autolock, you get transparent `Ctrl+H/J/K/L` navigation across both vim splits and Zellij panes.

**Pros**: Seamless vim-to-Zellij navigation.
**Cons**: Neovim only. Requires both the vim plugin and autolock.

### 4. Non-Colliding (Unlock-First) Preset

Set `default_mode "locked"` in config. All keys pass to the terminal. Press `Ctrl g` to unlock Zellij before any action.

```kdl
options {
    default_mode "locked"
}
```

**Pros**: Zero conflicts. Built-in, no plugins.
**Cons**: Adds 2-4 extra keypresses to every Zellij action. Feels heavy compared to tmux's single prefix.

## Scrollback Editor Integration

In scroll mode (`Ctrl s`), press `E` to open the entire pane scrollback in `$EDITOR`. Search, copy, or save from there. Configure the editor:

```kdl
options {
    scrollback_editor "/usr/bin/nvim"
}
```

This replaces the common workflow of piping output to a file just to search it.

## Known Limitations

### Image Protocols Do Not Work

Zellij does not pass through sixel or kitty image protocol escape sequences. This means:

- `yazi` image previews do not render inside Zellij
- `image.nvim` in neovim shows nothing
- Any tool relying on sixel graphics fails

This is an architectural limitation with no workaround. Run image-dependent tools outside Zellij, or use the Zellij web client (which has separate rendering).

### OSC52 Clipboard Passthrough

Neovim's OSC52 clipboard integration (copying to system clipboard via escape sequences) is blocked or unreliable through Zellij. Workarounds:

- Use `copy_on_select true` with mouse-based copy
- Use a neovim clipboard plugin that works through Zellij's clipboard integration
- Use the scrollback editor (`E` in scroll mode) to copy from the editor instead

### Slow Scrolling in Large Buffers

Scrolling through large neovim buffers inside Zellij can be noticeably slower than in a bare terminal. Fullscreen apps on large monitors are most affected.

### Unicode/CJK Rendering

Unicode and CJK characters can cause rendering artifacts in editors running inside Zellij. Wide characters may misalign or leave ghost characters after cursor movement. CJK IME cursor positioning was improved in 0.44.1 but some issues remain.

## Gotchas

- The autolock plugin needs to know which commands are editors. If you use `nvim` via an alias or wrapper (e.g., `vi -> nvim`), add all variants to the trigger list
- `Ctrl j` was not bindable before 0.40.1. If you see old guides suggesting workarounds, that limitation no longer applies
- Key forwarding behavior changed in 0.41 -- it's now based on `default_mode`, not just locked/normal. Old config advice may be outdated
- The non-colliding preset works best with the default keybindings. Combining it with `clear-defaults=true` requires careful manual setup
