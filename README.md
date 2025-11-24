# Marcos' Dotfiles

Welcome! This is my personal dotfiles repository. It contains configuration files and scripts for the programs I use daily and bootstrapping using [Dotbot](https://github.com/anishathalye/dotbot)

## Features

This repo includes configs for:

- **Shells:** zsh, readline, aliases, functions
- **Editors:** Neovim, VSCode, IdeaVim
- **Terminal:** Alacritty, Wezterm, Starship prompt
- **Window Manager:** AwesomeWM, Picom, Xorg
- **Multiplexer:** tmux
- **Launcher & Menus:** Rofi
- **File Managers:** lf
- **Other tools:** Dotbot, lazygit, systemd services, scripts for automation

## Structure

- `nvim/` — Neovim config and plugins
- `zsh/` — Zsh modules and main config
- `tmux/` — tmux config and plugins
- `awesome/` — AwesomeWM config
- `rofi/` — Rofi themes, launchers, scripts
- `alacritty/`, `wezterm/`, `starship/` — Terminal configs
- `dotbot/` — Dotbot submodule setup for managing symlinks
- `scripts/` — Utility scripts
- `picom/`, `xorg/` — Compositor and Xorg configs
- `lf/` — lf file manager config
- `systemd/` — User services
- `private/` — Example for private configs (not tracked)
- And more!

## Installation

**Warning:** Review all configs before using! These are tailored to my workflow and may override your existing setup.

Using [Dotbot](https://github.com/anishathalye/dotbot):

```sh
git clone https://github.com/<your-username>/new-dotfiles.git ~/new-dotfiles
cd ~/new-dotfiles
./install
```

This will symlink configs to your home directory.

## Updating

To update your dotfiles, pull the latest changes and re-run the install script if needed:

```sh
cd ~/new-dotfiles
git pull
./install
```

## Credits & Inspiration

Inspired by:
- [Dotbot](https://github.com/anishathalye/dotbot)
- [anishathalye's dotfiles](https://github.com/anishathalye/dotfiles)

## License

MIT

---

Feel free to fork, adapt, and use these configs for your own setup!
