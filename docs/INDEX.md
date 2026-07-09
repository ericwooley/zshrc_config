# Documentation Index

This directory contains the longer-form docs for the dotfiles repo.

## Start Here

- [Install](INSTALL.md): one-line bootstrap, local install flow, backups, dependency setup, Neovim tarball updates, and uninstall notes
- [Zsh](ZSH.md): shell load order, plugins, completions, functions, Multipass VM helpers, and local overrides
- [Neovim](NEOVIM.md): plugin set, safety model, keymaps, formatting, linting, and sessions
- [Tmux](TMUX.md): prefix, windows, panes, mouse, copy mode, and clipboard behavior
- [Remote Sync](REMOTE_SYNC.md): `zshsetup <host>`, remote clone setup, and rerunnable installs
- [Helper Commands](HELPERS.md): commands in `.zshrc_config/bin`
- [Maintenance](MAINTENANCE.md): documentation, secret scanning, generated files, and release checks

## Quick References

- Neovim user cheat sheet: `docs/nvim-quick-reference.md`
- Main repo overview: `README.md`
- Agent maintenance instructions: `AGENTS.md`

## Config Map

```text
bootstrap.sh                    one-line installer target
install.sh                      local installer
init.zsh                        zsh config root
aliases.zsh                     shared aliases
keybindings.zsh                 shell keybindings
bin/                            executable helper commands
docs/                           installed reference docs
functions/                      sourced zsh functions
scripts/                        executable support scripts
.config/nvim/                   Neovim config
.config/starship.toml           Starship prompt config
.codex/AGENTS.md                global Codex instructions
.tmux.conf                      tmux config
```
