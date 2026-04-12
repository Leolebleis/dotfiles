# docs/ Structure Decision

## Topic Analysis

| Topic | Beginner Frequency | Depth Needed | KDL Examples | Verdict |
|-------|-------------------|--------------|--------------|---------|
| Keybindings & modes | high | deep | yes | own file: keybindings.md |
| Sessions (attach/detach/resurrection) | high | deep | yes | own file: sessions.md |
| Panes (tiled, floating, stacked) | high | medium | yes | own file: panes.md |
| Config / KDL syntax | high | medium | yes | own file: config.md |
| Layouts | medium | deep | yes | own file: layouts.md |
| Copy/paste | high | shallow | no | merge into gotchas.md |
| Neovim/editor integration | medium | medium | yes | own file: editor-integration.md |
| tmux migration | medium | shallow | yes | merge into keybindings.md (tmux section) |
| CLI automation (zellij run/action) | low | shallow | no | merge into sessions.md (CLI section) |
| Plugins (built-ins + custom) | low | deep | yes | skip (too advanced for beginner focus) |
| Gotchas & warnings | high | shallow | no | own file: gotchas.md |

## Chosen Structure

```
docs/
  config.md              -- KDL syntax basics, options block, common options reference
  keybindings.md         -- modes explained, bind syntax, alt-based pattern, tmux-mode pattern
  panes.md               -- tiled vs floating vs stacked, floating pane lifecycle, pinned panes
  sessions.md            -- attach/detach, resurrection, session naming, CLI (run/action) commands
  layouts.md             -- layout KDL structure, pane attributes, cwd composition, templates, swap layouts
  editor-integration.md  -- neovim conflicts, autolock plugin, alt-based rebind solution, known limits
  gotchas.md             -- copy/paste issues, scroll mode quirks, key conflicts, resurrection gaps, known bugs
```

## CLAUDE.md Cheat Sheet Priorities

Top items for the ~15-line cheat sheet (most-asked, most-useful):

1. Alt+F -- toggle floating panes (show/hide; hidden panes keep running)
2. Ctrl+S -- enter scroll mode; then E to open scrollback in $EDITOR
3. Alt+H/J/K/L -- navigate panes (normal mode, no mode switch needed)
4. Ctrl+O -- open session manager (attach, resurrect, switch sessions)
5. on_force_close "detach" -- survive terminal window close
6. pane_frames false + simplified_ui true -- standard minimal UI setup
7. keybinds clear-defaults=true -- required when fully replacing default bindings
8. zellij run --floating -- <cmd> -- run a command in a floating overlay pane
9. Ctrl+P then D/R -- split pane down/right (pane mode)
10. Modes: normal → pane (Ctrl+P), tab (Ctrl+T), scroll (Ctrl+S), session (Ctrl+O)
11. Alt+I / Alt+O -- reorder tabs left/right
12. session_serialization true -- resurrection is on by default; sessions survive reboot
13. zellij --layout <file.kdl> -- start with a layout (inside session: adds tabs, not new session)
14. Copy/paste: pane_frames false helps; copy_on_select true copies on mouse release
15. bindkey -e in .zshrc -- fix Ctrl+R/A/E if they stop working inside Zellij

## Rationale

**Own files** were given to topics that either (a) beginners hit in their first week and need dense
reference material or (b) have substantial KDL that needs to be copy-pasted:

- `config.md` and `keybindings.md` cover the two most common early customization needs. KDL is
  unfamiliar to most users, so having dedicated scannable references with real examples is high
  value. tmux-mode pattern was folded into keybindings rather than getting its own file because
  it's a subset of the keybinding topic, not a separate knowledge domain.

- `panes.md` covers the three pane types (tiled/floating/stacked) in one place. Floating pane
  lifecycle (hide != close) is a top-10 beginner confusion that benefits from its own callout.

- `sessions.md` is the second-most-asked beginner topic (resurrection, reboot persistence). CLI
  commands (`zellij run`, `zellij action`) were merged here rather than given a separate file
  because beginners encounter them in session/pane context, not as a standalone CLI topic.

- `layouts.md` earns its own file because the KDL syntax for layouts is distinct from config KDL
  and there is enough depth (templates, swap layouts, cwd composition) to warrant isolation.

- `editor-integration.md` targets the main reason experienced users abandon Zellij. It's a
  separate audience concern (neovim users) that doesn't fit naturally into any other file.

- `gotchas.md` consolidates high-frequency stumbling blocks (copy/paste quirks, scroll mode,
  resurrection version gap, image protocols, Windows rough edges) that cross topic boundaries.
  These are short actionable items, not deep topics, making consolidation the right call.

**Skipped**: The plugin development topic (WASM, zellij-tile SDK) is too advanced for a beginner
learning reference. Built-in plugin _usage_ is covered incidentally in config.md and sessions.md
where relevant (compact-bar, session-manager, autolock).
