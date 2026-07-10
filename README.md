# Eric's Dotfiles

A fast, practical terminal setup for zsh, tmux, and Neovim. It is designed to be
easy to install on a new machine, safe to publish, and boring in the places
where dotfiles should be boring.

## Dependencies

The installer can install the common dependencies on macOS with Homebrew, on
Ubuntu/Debian with apt, and Multipass through the official macOS cask or Linux
snap path. Multipass is asked about separately because it is only needed for
the `vm*` helpers. Core tools include:

```text
zsh git curl tmux nvim fzf ripgrep zoxide eza starship antidote glow lazygit go fastAI n node multipass
```

### OpenRouter Key

AI helpers use [`ericwooley/fastAI`](https://github.com/ericwooley/fastAI) and
OpenRouter. To have `aiCommit` and `zshow` work automatically, put your key in
`~/.zshrc_local` before or after installing:

```zsh
export OPENROUTER_API_KEY='<openrouter key>'
```

`~/.zshrc_local` is loaded automatically by this setup and stays outside git.
The older `~/.zsh_local` filename is still supported as a fallback.

## Copy/Paste Install

```sh
curl -fsSL https://raw.githubusercontent.com/ericwooley/zshrc_config/main/bootstrap.sh | sh
```

The bootstrap installer clones this repo directly into `~/.zshrc_config`, then
runs `install.sh`. If `~/.zshrc_config` already exists, it is moved to:

```text
~/.zsh_config.bak
```

If that backup already exists, a dated backup name is used instead.

## What You Get

- **zsh**: Antidote-managed plugins, fast completions, flexible aliases, and one-function-per-file helpers.
- **Starship**: versioned prompt config hard linked into `~/.config/starship.toml`.
- **Codex instructions**: global `~/.codex/AGENTS.md` hard linked from this repo.
- **tmux**: mouse support, clipboard-friendly copy mode, current-directory windows/panes, and simple window movement.
- **Neovim**: lazy.nvim, Telescope, LSP, completion, file tree, statusline, Git signs, LazyGit, formatting, linting, sessions, and which-key. Linux installs use the official stable tarball.
- **Multipass VMs**: `vmcreate`, `vmconnect`, `vmls`, and `vmrm` create and manage disposable VMs with `~/vms/shared` mounted at `~/shared`.
- **AI helpers**: `aiCommit` for short commit messages and `zshow` for asking questions about this setup.
- **Remote setup**: `zshsetup <host>` clones or updates this repo on an SSH host and runs the same installer there.
- **TigerVNC helper**: `setup-tight-vnc.sh` configures an XFCE TigerVNC desktop for SSH-tunneled, localhost-only access.
- **Updates**: `zshupdate` pulls the managed config repo and reloads the current shell; `zsh_install_hourly_update_cron` can check for config updates hourly; `nvim_install_stable_update_cron` can keep the Linux Neovim tarball current.
- **Timezone setup**: `install.sh` can interactively set the system timezone on macOS and Linux.
- **Safety**: no Neovim project-open hooks that run repo-local scripts just because a file was opened.
- **Docs**: quick references and maintenance notes live in [`./docs`](docs/INDEX.md).

## Managed Paths

The installer keeps `~/.zshrc` tiny:

```zsh
# zshsetup-managed
source "${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}/init.zsh"
```

The zsh config repo lives at:

```text
~/.zshrc_config
```

These paths are linked from that repo when present:

```text
~/.tmux.conf -> ~/.zshrc_config/.tmux.conf
~/.config/starship.toml => ~/.zshrc_config/.config/starship.toml
~/.codex/AGENTS.md => ~/.zshrc_config/.codex/AGENTS.md
~/.config/nvim -> ~/.zshrc_config/.config/nvim
```

Machine-local secrets and overrides belong in `~/.zshrc_local`, which is not part
of this repo.

## Feature Tour

### Zsh

- plugin management through Antidote
- `~/.local/bin` and `~/.zshrc_config/bin` on `PATH`
- npm, pnpm, yarn, and bun completion setup
- Ctrl-Left/Ctrl-Right word movement in the shell
- directory jumping with zoxide
- Starship prompt support
- `mkcd`, `tmr`, `resetmouse`, `zshsetup`, `zshupdate`, `zsh_install_hourly_update_cron`, `nvim_install_stable_update_cron`, Multipass VM helpers, Docker cleanup helpers, and utility aliases

Read more in [docs/ZSH.md](docs/ZSH.md) and [docs/HELPERS.md](docs/HELPERS.md).

### Neovim

- leader key: `Space`
- fuzzy finding with Telescope
- file creation, deletion, rename, and browsing with nvim-tree
- LSP for TypeScript, Python, and Go
- formatting on save through conform.nvim
- linting through nvim-lint
- LazyGit inside Neovim with `<leader>lg`
- session restore through persistence.nvim
- key discovery through which-key.nvim

Read more in [docs/NEOVIM.md](docs/NEOVIM.md). The quick reference is at
`docs/nvim-quick-reference.md`.

### Tmux

- prefix: `Ctrl-b`
- `Ctrl-b c` creates a window
- `Ctrl-b ,` renames a window
- `Ctrl-b n` and `Ctrl-b m` move left/right between windows
- new windows and panes keep the current directory
- mouse and copy-mode bindings are enabled

Read more in [docs/TMUX.md](docs/TMUX.md).

### Remote Machines

After installing locally:

```zsh
zshsetup user@host
```

`zshsetup` uses `ZSHSETUP_REPO_URL` or the local git `origin`, normalizes GitHub
SSH remotes to HTTPS, and falls back to
`https://github.com/ericwooley/zshrc_config.git`. On the remote it clones into
`~/.zshrc_config`, pulls on later runs, and runs `install.sh`.

Read more in [docs/REMOTE_SYNC.md](docs/REMOTE_SYNC.md).

### TigerVNC

On a Linux host, `setup-tight-vnc.sh` installs XFCE plus TigerVNC and configures
display `:1` as a localhost-only service. Connect with an SSH tunnel:

```sh
ssh -L 5901:localhost:5901 user@host
```

Then point TigerVNC Viewer at `localhost:5901`.

Read more in [docs/INSTALL.md](docs/INSTALL.md#tigervnc-setup).

## Docs

- [Install](docs/INSTALL.md): bootstrap flow, local install, backups, dependencies, and uninstall
- [Zsh](docs/ZSH.md): load order, plugins, completions, aliases, functions, and local overrides
- [Neovim](docs/NEOVIM.md): plugins, safety model, keymaps, formatting, linting, and sessions
- [Tmux](docs/TMUX.md): prefix, windows, panes, mouse, copy mode, and clipboard behavior
- [Remote Sync](docs/REMOTE_SYNC.md): `zshsetup <host>` and remote clone installs
- [Helper Commands](docs/HELPERS.md): executable helpers in `.zshrc_config/bin`
- [Maintenance](docs/MAINTENANCE.md): docs policy, validation, gitleaks, and release checks

## Repo Layout

```text
bootstrap.sh                    one-line installer target
install.sh                      local installer
init.zsh                        zsh config entrypoint
aliases.zsh                     shared aliases
keybindings.zsh                 shell keybindings
bin/                            executable helper commands
docs/                           full documentation and quick references
functions/                      sourced zsh functions
scripts/                        executable support scripts
plugins*.txt                    Antidote plugin lists
.config/nvim/                   Neovim config
.config/starship.toml           Starship prompt config
.codex/AGENTS.md                global Codex instructions
.tmux.conf                      tmux config
.githooks/pre-commit            gitleaks pre-commit hook
```

## Publishing Safety

This repo is intended to be public. Keep secrets in `~/.zshrc_local`, not in git.
Before publishing or after sensitive edits, run:

```sh
gitleaks git . --redact --no-color --no-banner
gitleaks dir . --redact --no-color --no-banner
```

Enable the versioned pre-commit hook in a clone with:

```sh
git config core.hooksPath .githooks
```
