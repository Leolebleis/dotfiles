# Zellij Community Research

Sources: GitHub Issues/Discussions (zellij-org/zellij), Hacker News threads (hn/39258823, hn/26902430),
blog posts (bulimov.me, vadosware.io, mauriciopoppe.com, marceloborges.dev, haseebmajid.dev,
typecraft.dev, tmpdir.org), dotfiles repos (omerxx, fresh2dev), official FAQ, awesome-zellij.

---

## Top Beginner Questions

Ranked by frequency/comment count across GitHub Issues and community posts.

1. **How do I copy and paste?**
   Copy/paste has multiple open issues and frequent confusion. The core problem: Zellij intercepts
   mouse selection in some terminal setups. `copy_on_select true` (default) copies on mouse release;
   OSC52 clipboard passthrough can break with some terminals (Tabby, Gnome Terminal adds spaces,
   Kitty has Alt+Shift conflicts). Keyboard-only copy requires entering scroll mode first.
   - GitHub: #671, #1288, #1330, #1998, #2989, #4898

2. **How do I get back to my previous session? / Sessions disappeared after reboot**
   Session resurrection was only added in 0.39.0. Before that, sessions were lost. Even now,
   many users don't know it exists or how to configure it. Entry point: the session manager
   (Ctrl+O → W, or just run `zellij attach`).
   - GitHub: #575 (103 comments: most-requested feature for years)

3. **Why are Ctrl+R / Ctrl+A / Ctrl+E not working?**
   Zellij's default bindings intercept common readline shortcuts. Ctrl+R was originally bound to
   Zellij's resize mode (now changed), but the conflict pattern persists. Root cause is often
   EDITOR=vi causing zsh to switch to vi mode. Fix: add `bindkey -e` to .zshrc.
   - GitHub: #3890 (8 confirmations, still open as of May 2025)
   - HN: "This makes me think I can't use this tool at all" -- common first reaction

4. **How do I navigate to neovim splits without Zellij intercepting keys?**
   The most-discussed integration problem. Zellij grabs Ctrl+H/J/K/L before neovim sees them.
   Solutions in order of popularity:
   a. `zellij-autolock` plugin -- auto-locks Zellij when nvim is focused
   b. `zellij.vim` plugin (combines with autolock for transparent navigation)
   c. "Unlock-First" preset (Ctrl+G to unlock before any Zellij command)
   d. Remap Zellij to Alt-based bindings (sidesteps conflict entirely)
   - GitHub: #967, #2434

5. **How do I scroll? / PgUp/PgDown not working**
   Scroll mode is not automatic. Users expect terminal scrolling to just work. Must press Ctrl+S
   to enter scroll mode first, then use PgUp/PgDown or arrow keys. Mouse scroll works in normal
   mode. This is an open issue with no current fix.
   - Source: bulimov.me, multiple blog posts

6. **How do I create a layout for my project?**
   Layout files use KDL syntax. Most beginners don't know layouts exist until they've been using
   Zellij for a while. Common starter question: "how do I make each tab start in a different
   directory?"
   - GitHub discussions: #1701, FAQ item #5

7. **How do I switch between sessions?**
   Ctrl+O opens the session manager. `zellij attach <name>` from outside. No native "last session"
   toggle (tmux has `switch-client -l`). Third-party: zellij-sessionizer plugin or custom fzf
   scripts.
   - GitHub: #884 (20 comments)

8. **How do I move a tab to a different position?**
   Not obvious from the UI. Alt+I / Alt+O reorder tabs left/right. In Pane mode, there are
   move commands. GitHub has a dedicated issue with 28 comments because it's hard to discover.
   - GitHub: #1656

9. **How do I make floating panes work?**
   Alt+F toggles floating pane visibility. First press creates one if none exist. Many users
   don't discover this until they see a demo. The persistent background behavior (hidden but
   still running) surprises people.

10. **Can I use Zellij on Windows?**
    Native Windows support added in 0.44.0. Before that: WSL only. Still some rough edges
    (session visibility across logins, Ctrl+ key garbage sequences in Windows Terminal 1.25+).
    - GitHub: #316 (94 comments), #4930, #5017

---

## Common Pain Points

### Keybinding Conflicts (Most Frequent)

Default Zellij modes intercept keys from running applications. The problem has three layers:

1. **Ctrl-based mode shortcuts** (Ctrl+P, Ctrl+O, Ctrl+N, Ctrl+S, Ctrl+G) conflict with
   readline (Ctrl+A/E/R), vim jump list (Ctrl+O), shell suspend (Ctrl+Z).

2. **Alt-based quick shortcuts** (Alt+H/J/K/L for navigation) conflict with terminal emulators
   that use Alt for their own shortcuts (Kitty, WezTerm on some configs).

3. **Mode-locking overhead**: Users dislike needing to "unlock" before doing anything, adding
   "two to four extra keypresses" vs tmux's single prefix.

The 0.41.0 "Unlock-First (non-colliding)" preset addresses #1 and #2 but introduces the #3
frustration. Trade-off is unavoidable with current architecture.

### Copy/Paste Unreliability

Multiple independent issues across terminal emulators:
- Gnome Terminal: spaces added at end of lines (#1330)
- Tabby: doesn't work (#2928)
- OSC52 passthrough blocked (affects neovim's clipboard integration, #3951)
- Keyboard-only selection not native (requires entering scroll mode)
- Mouse selection with pane borders can be awkward

### Neovim/Editor Integration Friction

The most-cited reason experienced users don't adopt or leave Zellij:
- Navigation shortcuts collide unless using autolock or unlock-first
- Image protocols (sixel, kitty image protocol) don't work through Zellij (#371, #4336)
- Slow scrolling in large nvim buffers (#4306)
- Unicode/CJK characters cause rendering artifacts (#2592, #3783)
- OSC52 clipboard blocked (#3951)

### Session Resurrection Gaps

- Sessions lost on Zellij version update -- cache is version-specific in `~/.cache/zellij/`
  (workaround: copy session files from old version dir to new)
- Stale environment variables after OS crash reattach (#5002)
- Session resurrection strips quotes from commands like `nvim +'...'` (#4727)
- No "last session" toggle like tmux's `switch-client -l`

### KDL Configuration Learning Curve

- Not a widely-known config format (vs YAML/TOML)
- No inline comments allowed in some contexts
- Error messages for syntax errors are sometimes cryptic
- `clear-defaults=true` required to fully replace default bindings -- easy to forget

### Performance

- Memory usage spikes reported (500MB+ after extended use, though allocator eventually frees)
- Input lag on macOS with some terminal emulators (Alacritty, reported in HN thread)
- Slow scrolling in fullscreen apps on large monitors

---

## Late-Discovered Features

These are features that users consistently report not knowing about until significantly into
their Zellij usage, based on "TIL" posts, blog retrospectives, and discussion threads.

### Edit Scrollback in Editor (Ctrl+S, then E)
Opens the entire pane's scrollback buffer in $EDITOR. Search it, copy from it, save it.
This eliminates the common workflow of piping output to a file just to grep it.
Added in 0.30.0, still widely unknown. Most beginner content doesn't mention it.

### `zellij run` / `zellij run --floating`
Run a command in a new pane (or floating pane) from inside Zellij. When the command exits,
press Enter to rerun or Ctrl+C to close. Perfect for test runners, build commands, linters.
`--close-on-exit` closes the pane automatically on success.

Example: `zellij run --floating -- cargo test` opens test output in a floating overlay.

### Floating Panes Persist While Hidden
Hiding floating panes (Alt+F) does not kill them. The command keeps running. Show them again
to see current output. Discovered late by most users who assume hide = close.

### Session Manager Has a Layout Picker (0.44.0+)
The Layout Manager (accessible from session manager or `zellij --layout`) lets you visually
browse, apply, and create layouts. Most users don't know this exists.

### Pinned Floating Panes (0.44.0+)
A floating pane can be "pinned" to always stay visible across tab switches. Useful for keeping
a reference pane or monitoring output always in view.

### Alt+Click on File Paths Opens in Editor
Zellij detects file paths in terminal output (relative and absolute). Hovering highlights them;
Alt+Click opens the file in a new floating pane using $EDITOR. Discovered by almost no one
without being told explicitly.

### Stacked Panes
Multiple panes can be "stacked" in the same space and toggled between. Different from floating.
Useful for putting related panes in the same area and switching focus.

### `on_force_close "detach"` Config Option
Default behavior when closing the terminal window is to kill the Zellij session. Setting
`on_force_close "detach"` instead detaches, preserving the session for later reattach.
Many users don't discover this until they accidentally lose work.

### Multiple Windows Can Share a Session
Open the same Zellij session in multiple terminal windows. Each can display different tabs.
Mentioned in community notes (tmpdir.org) as surprising.

### `zellij action` CLI Commands
From inside a running session, you can issue commands to manipulate the workspace:
`zellij action new-tab`, `zellij action move-tab`, `zellij action go-to-tab-name`.
Enables scripting workspace setup from shell scripts or startup commands.

### `pane_viewport_serialization true` for Full Scrollback Resurrection
By default, resurrected sessions don't restore pane content -- only structure and commands.
Enable `pane_viewport_serialization true` (and optionally `scrollback_lines_to_serialize`)
to also restore visible text.

---

## Popular Config Patterns

### Pattern 1: Minimalist UI (Most Common)

Remove visual chrome, use compact-bar, disable frames:

```kdl
pane_frames false
simplified_ui true
default_layout "compact"
theme "catppuccin-mocha"
on_force_close "detach"
copy_on_select true
```

`simplified_ui true` is needed if your font doesn't have Nerd Font/Powerline glyphs.
`pane_frames false` removes the border around each pane, giving more vertical space.

### Pattern 2: Alt-Based Keybindings (For Neovim/Helix Users)

Replace Ctrl-based mode entry with Alt to avoid editor conflicts. The omerxx dotfiles and
the haseebmajid.dev setup both use this pattern:

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
    // mode entry via Alt+letter
    bind "Alt p" { SwitchToMode "Pane"; }
    bind "Alt t" { SwitchToMode "Tab"; }
    bind "Alt s" { SwitchToMode "Scroll"; }
    bind "Alt o" { SwitchToMode "Session"; }
}
```

### Pattern 3: Tmux-Mode Only (For Tmux Migrants)

Use Ctrl+B as the only Zellij prefix, clear everything else to avoid conflicts:

```kdl
default_layout "compact"
pane_frames false

keybinds clear-defaults=true {
    normal {
        bind "Ctrl b" { SwitchToMode "Tmux"; }
        bind "F12"    { SwitchToMode "Locked"; }
    }
    tmux {
        bind "Ctrl b" { Write 2; SwitchToMode "Normal"; }  // pass-through on double-press
        bind "\""     { NewPane "Down"; SwitchToMode "Normal"; }
        bind "%"      { NewPane "Right"; SwitchToMode "Normal"; }
        bind "1" "2" "3" "4" "5" "6" "7" "8" "9" {
            GoToTab 1; SwitchToMode "Normal"; // etc
        }
    }
}
```

Source: GitHub Discussion #3058 (dlintw)

### Pattern 4: Sessionizer Script (Power User)

Combine zoxide + fzf + zellij for project-based session management:

```bash
#!/usr/bin/env bash
# Fuzzy-find a project directory, attach to its session or create a new one
ZOXIDE_RESULT=$(zoxide query --interactive 2>/dev/null)
SESSION_NAME=$(basename "$ZOXIDE_RESULT")
zellij attach "$SESSION_NAME" 2>/dev/null || \
    zellij --session "$SESSION_NAME" --layout ~/.config/zellij/layouts/dev.kdl \
    options --default-cwd "$ZOXIDE_RESULT"
```

Source: haseebmajid.dev, also popular in dotfiles repos

### Pattern 5: zjstatus Status Bar

Replace default status bar with `zjstatus` WASM plugin for custom info display:

```kdl
plugins {
    status-bar location="zellij:compact-bar"
    // replace with:
    zjstatus location="file:~/.config/zellij/plugins/zjstatus.wasm" {
        format_left  "{mode} #[fg=#89B4FA,bold]{session}"
        format_right "{datetime}"
    }
}
```

Shows: current mode, session name, git branch, datetime. Catppuccin-compatible.

### Common Config Options Summary

| Option | Common Value | Why |
|--------|-------------|-----|
| `pane_frames` | `false` | Less visual noise |
| `simplified_ui` | `true` | Font compatibility |
| `theme` | `"catppuccin-mocha"` | Most popular theme |
| `on_force_close` | `"detach"` | Don't lose sessions |
| `default_layout` | `"compact"` | Smaller status bar |
| `copy_on_select` | `true` | System clipboard on selection |
| `default_mode` | `"locked"` | Avoid accidental Zellij commands |
| `mouse_mode` | `true` | Keep default (some disable it) |
| `session_serialization` | `true` | Keep default (enable resurrection) |
| `pane_viewport_serialization` | `true` | Restore visible content too |

---

## tmux Migration Gotchas

### "Where's my prefix key?"
Zellij doesn't use a prefix by default. Instead it uses modal editing (normal/pane/tab/scroll
modes). tmux users find this jarring. The Tmux mode preset (`Ctrl+B` prefix) exists but isn't
the default.

### "How do I split panes?"
tmux: `Ctrl+B "` (horizontal), `Ctrl+B %` (vertical).
Zellij: Ctrl+P then D (down) or R (right). Or in pane mode: `n` (auto-places).
The auto-placement behavior (Zellij decides where the new pane goes) surprises people.

### "Ctrl+B isn't working for tmux things"
The Tmux compatibility mode exists but must be explicitly enabled via config or runtime
selection. It's not on by default.

### "My session doesn't persist after reboot"
tmux had no session persistence without plugins (tmux-resurrect). Zellij has it built-in
since 0.39.0, but it's not always obvious. The session manager UI shows resurrectable sessions
with a different indicator.

### "Pane navigation feels wrong"
tmux: `Ctrl+B <arrow>` to move between panes.
Zellij: `Alt+H/J/K/L` or `Alt+<arrow>` from normal mode -- no mode switch needed.
This is actually easier, but muscle memory from tmux fights it.

### "I can't send commands to panes from scripts"
tmux: `tmux send-keys -t session:window.pane "command" Enter`
Zellij: `zellij action write-chars "command"` (must specify pane by number or focus).
The ergonomics are different; `send-keys` behavior is similar but targeting syntax differs.

### "No `respawn-pane -k` equivalent"
tmux has `respawn-pane -k` to force-restart a stuck pane. Zellij has no direct equivalent.
Workaround: close the pane and open a new one.

### "Session switching is clunkier"
tmux: `Ctrl+B (` / `)` to cycle sessions, `switch-client -l` for last session.
Zellij: Ctrl+O opens session manager (visual picker). No last-session hotkey.
Third-party plugin zellij-sessionizer adds fzf-based session switching.

### "Copy mode works differently"
tmux copy mode: Enter with `Ctrl+B [`, navigate with vi/emacs keys, select with `Space`,
copy with `Enter`. Native, keyboard-driven, no external tools needed.
Zellij scroll mode: Enter with `Ctrl+S`, mouse or arrow navigation, no direct vi-style
selection. The "open in editor" (E key in scroll mode) is the Zellij alternative but
requires an editor round-trip.

### Configuration Language (KDL vs conf)
tmux uses its own `.conf` syntax. Zellij uses KDL, which is less common.
Key differences that trip people up:
- Values are not quoted by default: `theme catppuccin-mocha` not `theme = "catppuccin-mocha"`
  (though both work in some contexts)
- `clear-defaults=true` on the keybinds block is essential to fully replace defaults
- Node-based nesting is different from tmux's line-by-line format

---

## Gotchas and Warnings

### Gotcha: Ctrl+R / Ctrl+A / Ctrl+E stop working
**Symptom**: Shell history search (Ctrl+R), go-to-line-start (Ctrl+A), go-to-line-end (Ctrl+E)
produce escape sequences instead of working.
**Cause**: $EDITOR=vi causes zsh to enter vi-mode, disabling readline bindings.
**Fix**: Add `bindkey -e` to .zshrc to force emacs/readline mode.
- GitHub #3890

### Gotcha: Pane borders block text selection with mouse
**Symptom**: Clicking to select text selects the border element instead.
**Fix**: `pane_frames false` in config removes borders. Consider this the default for
mouse-heavy workflows.

### Gotcha: Sessions lost after Zellij version update
**Symptom**: After updating Zellij, old sessions don't appear in session manager.
**Cause**: Cache is stored in version-specific subdirectory under `~/.cache/zellij/`.
**Fix**: Manually copy `~/.cache/zellij/<old-version>/` contents to new version directory.
Workaround: back up sessions before upgrading.
- Source: tmpdir.org community notes

### Gotcha: OSC52 clipboard doesn't work from neovim
**Symptom**: Neovim clipboard copy (using OSC52) doesn't reach system clipboard.
**Cause**: Zellij intercepts and sometimes blocks OSC52 escape sequences.
**Fix**: Enable `copy_on_select true` and use mouse-based copy, OR use a clipboard plugin
in neovim that works through Zellij's clipboard integration.
- GitHub #3951

### Gotcha: `clear-defaults=true` is all-or-nothing
If you use `keybinds clear-defaults=true`, ALL default bindings are removed including
ones you didn't think about (like quitting, lock mode). You must re-add everything you want.
Alternative: only override specific modes to avoid surprises.

### Gotcha: Image rendering (sixel, kitty protocol) doesn't work
Zellij doesn't pass through image rendering protocols. This means:
- `yazi` image previews don't work inside Zellij (#4336)
- `image.nvim` in neovim doesn't render images
- Any tool relying on sixel graphics fails (#371)
No workaround; this is an architectural limitation. Run image tools outside Zellij or
use the Zellij web client (which has separate rendering).

### Gotcha: Alt keybindings may not work in some terminals
Some terminal emulators consume Alt before Zellij sees it:
- Kitty: Alt+Shift+<key> stopped working in some versions (#4148)
- Windows Terminal 1.25+: All Ctrl+ combos output garbage sequences with new keyboard protocol (#5017)
Check terminal emulator compatibility when Alt-based config is used.

### Gotcha: Scroll mode doesn't activate on mouse scroll
You must explicitly press Ctrl+S to enter scroll mode before using keyboard navigation.
Mouse scrolling works without entering scroll mode, but PgUp/PgDown and keyboard search
require the explicit mode switch. This is an open issue with no current fix.

### Gotcha: Resurrected sessions don't restore environment variables
If the shell session was started with specific env vars (e.g., from direnv or shell hooks),
those are not restored on resurrection. The command reruns but in a fresh environment.
- GitHub #5002 (stale env vars after OS crash)

### Gotcha: `zellij run` inside a session vs outside
`zellij run <command>` behaves differently:
- **Outside session**: starts a new session, runs command
- **Inside session**: opens command in a new pane in current session
The `--floating` and `--close-on-exit` flags are inside-session features.

### Gotcha: Windows native support still has rough edges (as of 0.44.x)
- Session visibility only within same login (#4930)
- Windows Terminal 1.25+ keyboard protocol conflicts (#5017)
- Some Ctrl+ combinations produce garbage sequences
- Mouse pane resizing may be less reliable
Recommendation: use WSL for stability on Windows until these issues are resolved.

### Gotcha: Renaming sessions can break attach
On Windows, renaming a session and then trying to re-attach by old name fails (#4998).
On Linux/macOS this works correctly.

### Warning: Memory usage can spike
Extended sessions (days-long uptime) can accumulate significant memory usage. The Rust
allocator eventually returns it, but the peak can reach 500MB+. If running on a resource-
constrained system, consider periodic detach/reattach to reset.
- Source: HN thread #39258823
