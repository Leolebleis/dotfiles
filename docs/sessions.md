# Sessions

A Zellij session is an isolated workspace with its own tabs and panes. Sessions survive terminal closure, can be shared between multiple clients, and are serialized for resurrection after quit or crash.

## Key Facts

- Multiple sessions can run simultaneously, each with a unique name
- Sessions keep running after you close the terminal window (if `on_force_close "detach"` is set) or detach
- Sessions can be shared between multiple terminal windows ("multiplayer") -- all clients see the same view
- The session manager (`Ctrl o`) provides a single-screen UI to create, attach, and resurrect sessions (0.44+)
- Session names are auto-generated (memorable words) unless you specify one

## Attach and Detach

**Attach to a session:**

```bash
zellij attach [session-name]     # attach by name (auto-selects if only one running)
zellij attach                    # auto-attach if only one session exists
zellij a                         # short alias
```

**Detach from a session:**
- Keybinding: `Ctrl o` then `d` (session mode, then detach)
- CLI: `zellij detach` (0.44+)
- Detaching leaves the session running. Processes continue in the background

**List sessions:**

```bash
zellij list-sessions             # or: zellij ls
```

**Start a named session:**

```bash
zellij --session my-project
```

## Session Resurrection

Sessions are serialized to `~/.cache/zellij/` by default. On quit or crash, the session can be resurrected from the session manager.

**What gets saved:**
- Pane/tab layout structure
- Commands running in each pane
- Optionally: visible pane content (viewport) and scrollback lines

**Enable full content restoration:**

```kdl
options {
    session_serialization true              // on by default
    serialize_pane_viewport true            // also save visible pane text
    scrollback_lines_to_serialize 1000      // how many scrollback lines to keep
}
```

**Resurrect a session:**
1. Open session manager (`Ctrl o`, or `zellij attach`)
2. Exited sessions appear with an "EXITED" label
3. Select one to resurrect

Resurrected command panes show "Press ENTER to run..." -- you must confirm before re-execution. Skip the confirmation with:

```bash
zellij attach <name> --force-run-commands
```

### Post-Command Discovery Hook (0.43+)

Apply edits to serialized commands before resurrection saves them. Useful for nix wrappers, pipeline commands, or fixing paths:

```kdl
options {
    post_command_discovery_hook "my-script"
}
```

## Survive Terminal Close

By default, closing the terminal window kills the Zellij session. Change this:

```kdl
options {
    on_force_close "detach"
}
```

Now closing the terminal detaches instead. Reattach later with `zellij attach`.

## Multiplayer Mode

Open the same session in multiple terminal windows. Each window can view different tabs. All clients share the same session state.

Start a session in one terminal, then attach to it from another:

```bash
# Terminal 1
zellij --session shared-project

# Terminal 2
zellij attach shared-project
```

## CLI Commands

### `zellij run`

Run a command in a new pane from inside a session:

```bash
zellij run -- <command> [args]
  -f, --floating                open in floating pane
  -d, --direction up|down|left|right
  -n, --name <NAME>            pane title
  -c, --close-on-exit          close pane when command exits
  -s, --start-suspended        open suspended, run on Enter
  -i, --in-place               replace current pane
      --blocking                block CLI until pane closes
      --cwd <DIR>
      --x <X> --y <Y> --width <W> --height <H>   (floating position)
```

Returns the new pane_id on stdout.

### `zellij action`

Programmatically control a running session:

```bash
# Pane actions
zellij action new-pane [--floating] [--direction up|...] [--name N]
zellij action close-pane
zellij action rename-pane <NAME>
zellij action focus-next-pane
zellij action move-pane [--direction up|...]
zellij action dump-screen [--pane-id <ID>] [--include-scrollback]
zellij action send-keys "Enter" "Ctrl c" "a" "b"
zellij action list-panes [--json]
zellij action focus-pane-with-id <ID>      # 0.44.1+

# Tab actions
zellij action new-tab [--layout F] [--name N] [--cwd D]
zellij action close-tab
zellij action go-to-tab <N>
zellij action rename-tab <NAME>

# Session actions
zellij action switch-session [session-name]
zellij action switch-mode <mode>

# Misc
zellij action toggle-fullscreen
zellij action toggle-floating-panes
zellij action are-floating-panes-visible   # 0.44.1+
```

### Scripting Example: Project Setup

```bash
#!/usr/bin/env bash
# Open a dev workspace with named tabs
zellij action new-tab --name "editor" --cwd ~/project
zellij action new-tab --name "tests" --cwd ~/project
zellij run --floating -- cargo watch -x test
```

### Sessionizer Pattern

Combine zoxide + fzf + zellij for project-based session management:

```bash
#!/usr/bin/env bash
ZOXIDE_RESULT=$(zoxide query --interactive 2>/dev/null)
SESSION_NAME=$(basename "$ZOXIDE_RESULT")
zellij attach "$SESSION_NAME" 2>/dev/null || \
    zellij --session "$SESSION_NAME" --layout ~/.config/zellij/layouts/dev.kdl \
    options --default-cwd "$ZOXIDE_RESULT"
```

## Web / Remote Sessions (0.43+)

Share sessions over HTTPS for browser-based access:

```bash
zellij web                                    # start HTTPS web server
zellij web --create-read-only-token           # generate read-only access token
zellij attach https://example.com/session     # remote terminal attach (0.44+)
```

Authentication tokens are enforced by default. A `zellij-no-web` binary exists for users who want no web capability.

## Forwards Compatibility (0.44+)

A protobuf-based client/server contract means future Zellij versions can connect to existing 0.44+ sessions without killing them. Before 0.44, every upgrade orphaned running sessions.

## Gotchas

- Sessions are lost after Zellij version updates. The cache directory is version-specific under `~/.cache/zellij/`. Workaround: copy session files from the old version directory to the new one before updating
- Resurrected sessions do not restore environment variables. If your shell relied on direnv or custom env vars, those are gone after resurrection. Commands rerun in a fresh environment
- Session resurrection strips quotes from some commands (e.g., `nvim +'...'`). Complex command-line arguments may not survive the round-trip
- No "last session" toggle like tmux's `switch-client -l`. Use the session manager UI or a third-party sessionizer plugin
- Renaming sessions on Windows can break reattach by old name. This works correctly on Linux/macOS
- `on_force_close "detach"` is not set by default. Without it, closing the terminal kills the session and all running processes
