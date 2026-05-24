# dotfiles

Terminal configuration managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- **Zellij** — terminal multiplexer config, keybindings, plugins
- **Ghostty** — terminal emulator config (macOS settings templated, works on Linux too)
- **Plugins** — auto-downloaded via `.chezmoiexternal.toml` (room, autolock, zj-quit, zellij-forgot)
- **zsh** — `.zshrc` with Ghostty → Zellij auto-attach
- **ccstatusline** — config for the [ccstatusline](https://www.npmjs.com/package/ccstatusline) Claude Code status bar

## Install on a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Leolebleis
```

This will:
1. Install chezmoi
2. Clone this repo
3. Install zellij + ghostty (macOS via brew, Linux prints install links)
4. Download Zellij plugins
5. Deploy all configs to `~/.config/`

### Clone over SSH instead of HTTPS

If HTTPS auth fails (or you'd just rather use your SSH key), pass `--ssh`:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh Leolebleis
```

Requires an SSH key registered with GitHub — verify with `ssh -T git@github.com`.

## Auto-attach to Zellij

Auto-attach to a named `main` Zellij session when opening Ghostty (Linux/macOS) or Windows Terminal (Windows) is set up automatically:

- **zsh** (Linux/macOS): handled by `dot_zshrc.tmpl` — guards on `$TERM_PROGRAM = ghostty` and `$ZELLIJ` not set.
- **pwsh** (Windows): handled by `Microsoft.PowerShell_profile.ps1` — guards on `$env:WT_SESSION` and `$env:ZELLIJ` not set.

Both `exec` into `zellij attach -c main` so the terminal closes when Zellij detaches.

## ccstatusline

The status bar config lives at `dot_config/ccstatusline/settings.json` and deploys to `~/.config/ccstatusline/settings.json` via chezmoi. `bun` is checked by the install script and must be installed for ccstatusline to run.

To wire it into Claude Code, add to `~/.claude/settings.json` (one-time, per machine):

```json
"statusLine": {
  "type": "command",
  "command": "bunx -y ccstatusline@latest",
  "padding": 0
}
```

This is not chezmoi-managed because `~/.claude/settings.json` is heavily entangled with per-machine plugin/hook state.

## Keybindings

| Action | Shortcut |
|--------|----------|
| Split right / down | Alt+D / Alt+Shift+D |
| Close pane | Alt+W |
| Navigate panes | Alt+H/J/K/L or Alt+Arrows |
| Fullscreen pane | Alt+Z or Alt+Enter |
| Floating panes | Alt+G |
| Resize | Alt+= / Alt+_ |
| New tab | Alt+T |
| Tab 1-9 | Alt+1-9 |
| Rename tab | Alt+R |
| Tab switcher | Alt+S |
| Claude sessions | Alt+C |
| Cheatsheet | Alt+E |
| Quit | Ctrl+Q |
| Lock/unlock | Ctrl+G |

## Update configs

```sh
chezmoi update -v
```

## Edit locally then push

```sh
chezmoi edit ~/.config/zellij/config.kdl
chezmoi cd  # enters the source repo
git add -A && git commit -m "update" && git push
exit
```
