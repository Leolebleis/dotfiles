# Gotchas

A consolidated list of things that break, confuse, or behave unexpectedly in Zellij. Each item includes the symptom, cause, and fix (or workaround). Sourced from GitHub issues and community reports.

## Copy and Paste

### Mouse selection grabs pane borders
**Symptom**: Clicking to select text selects the border character instead.
**Fix**: Set `pane_frames false` in config. This is the recommended default for mouse-heavy workflows.

### Gnome Terminal adds spaces at end of lines
**Symptom**: Copied text has trailing spaces on every line.
**Cause**: Gnome Terminal's handling of OSC52 clipboard passthrough.
**Workaround**: Use a different terminal emulator, or pipe output through `sed 's/ *$//'` after pasting.

### Copy doesn't work in Tabby
**Symptom**: No text reaches the clipboard when selecting in Zellij inside Tabby.
**Cause**: Tabby blocks OSC52 passthrough.
**Workaround**: Use a terminal emulator that supports OSC52 (Alacritty, WezTerm, Kitty, Windows Terminal).

### Keyboard-only copy requires scroll mode
**Symptom**: No obvious way to select text without a mouse.
**Fix**: Enter scroll mode (`Ctrl s`), then press `E` to open the scrollback in `$EDITOR`. Select and copy from there.

### `copy_on_select` behavior
When `copy_on_select true` is set (default), mouse release copies the selection to the clipboard. Set `copy_command` to match your system:
- Linux X11: `"xclip -selection clipboard"`
- Linux Wayland: `"wl-copy"`
- macOS: `"pbcopy"`

## Scroll Mode

### PgUp/PgDown don't work without entering scroll mode
**Symptom**: Pressing PgUp or PgDown does nothing.
**Cause**: Keyboard scrolling requires explicitly entering scroll mode with `Ctrl s` first. Mouse scrolling works without this step.
**Status**: Open issue, no current fix.

### Mouse scroll works, keyboard scroll doesn't
**Symptom**: Mouse wheel scrolls the pane, but keyboard shortcuts don't.
**Cause**: Same as above -- keyboard navigation requires scroll mode. This is a common source of confusion for new users.

## Keybinding Conflicts

### Ctrl+R / Ctrl+A / Ctrl+E stop working in zsh
**Symptom**: Shell history search (Ctrl+R), go-to-line-start (Ctrl+A), go-to-line-end (Ctrl+E) produce escape sequences.
**Cause**: `$EDITOR=vi` causes zsh to enter vi-mode, disabling readline/emacs bindings. This is a zsh issue, not a Zellij issue, but it surfaces most often inside Zellij.
**Fix**: Add `bindkey -e` to `.zshrc` to force emacs/readline mode.

### `clear-defaults=true` removes everything
**Symptom**: After adding `clear-defaults=true`, basic functions like quit and lock mode stop working.
**Cause**: The flag removes ALL default bindings. You must re-add every binding you need.
**Fix**: Only override specific modes if you want partial customization. Use `clear-defaults=true` only when building a complete custom keybinding set.

## Session Resurrection

### Sessions lost after Zellij version update
**Symptom**: After upgrading Zellij, old sessions don't appear in the session manager.
**Cause**: The cache directory is version-specific under `~/.cache/zellij/`.
**Fix**: Copy session files from `~/.cache/zellij/<old-version>/` to the new version directory before upgrading. Back up the cache directory before any Zellij update.

### Environment variables not restored
**Symptom**: After resurrecting a session, tools like direnv or nvm don't have their expected env vars.
**Cause**: Resurrection replays commands in a fresh shell environment. Custom environment variables from the original shell session are not serialized.
**Workaround**: Use `.envrc` (direnv) or shell hooks that re-initialize on new shell start.

### Quoted commands break on resurrection
**Symptom**: Commands like `nvim +'lua ...'` lose their quoting after resurrection.
**Cause**: The serialization format strips some quote styles.
**Workaround**: Wrap complex commands in a shell script and run the script instead.

### Stale environment after OS crash
**Symptom**: After an OS crash and reattach, environment variables are stale or missing.
**Cause**: The session was serialized before the crash with the old environment state.
**Workaround**: Detach and reattach to get a fresh environment, or restart the affected panes.

## Windows Cross-Platform Quirks (0.44+)

### Windows Terminal 1.25+ keyboard conflicts
**Symptom**: All Ctrl+ combinations output garbage sequences.
**Cause**: Windows Terminal 1.25+ changed its keyboard protocol handling, conflicting with Zellij.
**Workaround**: Use WSL for stability, or downgrade Windows Terminal if possible. This is a known issue being tracked.

### Session visibility limited to same login
**Symptom**: Sessions started in one login session are not visible from another.
**Cause**: Windows session isolation. Sessions are scoped to the login context.
**Workaround**: Use a single login session, or use WSL where this limitation does not apply.

### Renaming sessions breaks reattach on Windows
**Symptom**: After renaming a session, trying to attach by the old name fails.
**Cause**: Windows-specific bug in session name resolution.
**Note**: This works correctly on Linux/macOS.

### Mouse pane resizing less reliable
**Symptom**: Dragging pane borders with the mouse is inconsistent on Windows native.
**Recommendation**: Use WSL for the most stable experience on Windows until these issues are resolved.

## Alt+Click File Opening (0.44+)

### Alt+Click opens unexpected files
**Symptom**: Hovering over text highlights it as a file path and Alt+Click tries to open it.
**Cause**: The built-in `link` plugin aggressively detects file paths in terminal output, including false positives.
**Fix**: Disable the `link` plugin by commenting it out in the plugin config if this is disruptive.

### Alt+Click not discovered
This feature exists but almost no one finds it without being told. Zellij detects file paths (relative and absolute) in terminal output. Hovering highlights them. Alt+Click opens the file in a floating pane using `$EDITOR`.

## Other Known Issues

### Memory usage spikes on long-running sessions
**Symptom**: Memory usage reaches 500MB+ after days of uptime.
**Cause**: Scrollback buffers and plugin state accumulate. The Rust allocator eventually returns memory, but peaks can be high.
**Workaround**: Periodic detach/reattach resets memory. Consider lowering `scroll_buffer_size` on constrained systems.

### Image rendering (sixel, kitty protocol) not supported
Zellij does not pass through image rendering protocols. Tools like yazi (image previews), image.nvim, and sixel-based viewers will not render images. This is an architectural limitation with no current workaround inside Zellij.

### Input lag on macOS
**Symptom**: Noticeable input delay, particularly with Alacritty on macOS.
**Cause**: Terminal emulator interaction with Zellij's rendering pipeline.
**Workaround**: Try a different terminal emulator (WezTerm, Kitty) or adjust the `repaint_delay` if available.

### Terminal BEL forwarding
Since 0.44, Zellij forwards BEL (bell) characters from background panes with a visual indication on unfocused tabs. This can be surprising if a background process generates frequent bells.
