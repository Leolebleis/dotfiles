# Zellij session restore on Windows with Claude auto-resume

_Research record, 2026-09-19. Serves as the spec for `docs/superpowers/plans/2026-09-19-zellij-restore.md`._

## Goal

After a reboot, starting a Windows Terminal window brings back the `main` Zellij session with the same tabs, panes and working directories, and every pane that was running Claude Code resumes its conversation instead of starting fresh.

## Symptom (2026-09-19)

Resurrected panes launched `uv tool uvx workspace-mcp --tools tasks` (Claude's Google Workspace MCP server) directly, waiting on stdin forever. The serialized layout in `%LOCALAPPDATA%\zellij\cache\contract_version_1\session_info\main\session-layout.kdl` recorded that as the pane command for two of three panes.

## Root cause (confirmed in Zellij 0.44.3 source)

- `zellij-server/src/os_input_output.rs`, non-unix `get_all_cmds_by_ppid`: scans every process, builds `HashMap<parent-pid, argv>` with `insert`, so for a parent with several children the last one iterated wins.
- `zellij-server/src/pty.rs`, `populate_session_layout_metadata`: looks up the pane's own pid in that map (a child of the pane process) and prefers it over the pane process's own argv.
- Resurrected panes and `attach -f` panes are shell-less command panes: the pane pid *is* `claude.exe`. Its children are MCP servers, so one of them is serialized. A plain pwsh pane with claude launched from the prompt serializes correctly (claude is the shell's only child).
- Net effect: resurrection works once, then poisons the next save. Shell-less panes also die when claude exits (zellij-org/zellij#5073).
- Upstream: PR #5324 (0.45.0) fixed Unix via `tcgetpgrp` and explicitly kept the ppid path on Windows; 0.45.1 and main are byte-identical. Exact bug is issue #4873 (not #4796).
- Independent gap: the `post_command_discovery_hook` that would turn `claude` into `claude --continue` is disabled on Windows (wedges the serializer, see memory `zellij-resurrect-hook-wedge`), so even a correctly recorded pane relaunches as a fresh session.

## Prior art (none works on native Windows)

| Tool | Notes |
|------|-------|
| Shengfeng233/zellij-claude-enhance (8 stars) | Documents the same MCP-child bug. Bash 4, uuidgen, long-lived Python PTY wrapper in the pane. WSL only. No license. |
| dchersey/claude-zellij-restore (MIT + Commons Clause) | Design we port: snapshot layout, rewrite claude panes to `--resume`, relaunch with `--layout`. macOS bash, jq, fzf. |
| ThaiG2Pro/zellij-claude-restore (MIT) | SessionStart hook writes id per cwd, WASM plugin injects `--resume`. Linux `/tmp`, plugin pinned to 0.44.2. |
| timvw/tmux-assistant-resurrect (94 stars) | Reference design, tmux only. |
| saaranshM/unsnooze (142 stars) | Zellij plus Windows, but resumes after usage-limit resets, not reboots. |
| Quil | Replacement multiplexer, no community validation. |

## Learnings

- Trust Zellij's serialized layout for tabs, panes and cwd. Never trust its `command=` on Windows.
- `claude --continue` is per working directory. One claude per directory makes it deterministic and needs no hooks.
- `claude --session-id <existing>` errors; `--resume` is the replay flag. Session ids rotate on `/clear`, `/resume`, compaction.
- Launch claude under `pwsh -NoExit -Command` so the pane keeps a shell (survives claude exiting) and claude is the shell's only child (discovery records it correctly next time).
- After an unclean shutdown a stale PID marker in `%TEMP%\zellij\contract_version_1\<session>` can make `attach` hang forever (zellij-org/zellij#5580). The marker holds the server PID; if no zellij process has that PID, delete the marker.
- `zellij delete-session` deletes the resurrection layout too, so copy the layout before deleting.

## Decision

Build a small pwsh restore step (`~/.config/zellij/plugins/zellij-restore.ps1`), called from the PowerShell profile instead of `zellij attach -f -c main`:

1. Clear a stale session marker if its PID is not a zellij process.
2. If `main` is alive, attach.
3. If `main` is dead, rewrite its cached layout: claude panes become `pwsh.exe -NoExit -Command "claude <original args minus resume flags> --continue"`, every other command pane becomes a plain shell pane with the same cwd and size, plugin panes and tabs are untouched. Delete the dead session and start `main` from the rewritten layout.
4. If `main` does not exist, start it with the default layout.

Deferred (YAGNI): per-pane session ids via a Claude SessionStart hook, only needed when two claude panes share a directory.
