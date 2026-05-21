# dotfiles

Terminal configuration managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- **Zellij** — terminal multiplexer config, keybindings, plugins
- **Ghostty** — terminal emulator config (macOS settings templated, works on Linux too)
- **Plugins** — auto-downloaded via `.chezmoiexternal.toml` (room, autolock, zj-quit, zellij-forgot)

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

## Auto-attach to Zellij

Add this to your `.zshrc` or `.bashrc` to auto-attach to a named session when opening Ghostty:

```sh
if [ -z "$ZELLIJ_SESSION_NAME" ] && [ "$TERM_PROGRAM" = "ghostty" ]; then
    zellij attach -c main
fi
```

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
