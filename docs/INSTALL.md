# Install

The repo installs zsh, Starship, tmux, and Neovim config into a home directory.

## Copy/Paste Install

```sh
curl -fsSL https://raw.githubusercontent.com/ericwooley/zshrc_config/main/bootstrap.sh | sh
```

This backs up any existing `~/.zshrc_config`, then clones the repo at:

```text
~/.zshrc_config
```

Before linking managed config, the bootstrap script moves an existing
`~/.zshrc_config` to:

```text
~/.zsh_config.bak
```

If that backup already exists, it uses a dated backup path instead.

## Local Repo Install

From the repo root:

```sh
./install.sh
```

The installer asks before installing dependencies, configuring the system
timezone, and linking config into the home directory.

## What Gets Installed

When config installation is accepted, these paths are managed:

```text
~/.zshrc
~/.zshrc_config/
~/.tmux.conf
~/.config/starship.toml
~/.config/nvim/
~/.codex/AGENTS.md
```

`~/.zshrc_config` is the repo checkout. `~/.tmux.conf` and `~/.config/nvim`
are symlinked from that repo when their source files are present.
`~/.config/starship.toml` and `~/.codex/AGENTS.md` are hard linked from the repo
when the filesystem allows it, with a symlink fallback.

The managed `~/.zshrc` stays intentionally small:

```zsh
# zshsetup-managed
source "${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}/init.zsh"
```

## Backups

If `~/.zshrc` already exists and does not contain the managed marker, it is
renamed before the new entrypoint is written:

```text
~/.zshrc_backup_<date>.bak
```

Managed `.zshrc` files are overwritten in place so the installer can be rerun.

If `~/.zshrc_config` already exists before bootstrap, it is renamed to
`~/.zsh_config.bak` before the repo is cloned. If that backup already exists, a
dated backup name is used instead.

## Dependency Install

On macOS, the installer expects Homebrew and can install:

```text
antidote eza fzf git glow go lazygit neovim ripgrep starship tmux zoxide zsh
```

On Ubuntu/Debian, the installer uses apt for stable dependencies:

```text
bash ca-certificates curl fzf git golang-go gpg gzip ripgrep tar tmux zsh
```

It also handles Neovim from the official stable Linux tarball, eza, zoxide,
starship, `glow` when available from apt, Go 1.24.x when the packaged Go is too
old, `fastAI` into `~/.local/bin`, `n`, Node LTS, and Antidote. On
Ubuntu/Debian, `lazygit` is reported as a warning if it is missing so the Neovim
`<leader>lg` binding has a clear next step.

Linux Neovim installs use:

```text
https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz
```

The archive is extracted under `/opt`, and `/usr/local/bin/nvim` is symlinked to
the installed binary. On non-apt Linux systems, the installer still attempts this
Neovim tarball path when `curl` and `tar` are already available, while the rest
of the dependency bundle remains manual.

To keep that tarball current on Linux, run:

```sh
nvim_install_stable_update_cron
```

That installs a marked root cron job that reruns the tarball installer daily.

`fastAI` is installed with:

```sh
GOBIN="$HOME/.local/bin" go install github.com/ericwooley/fastAI/cmd/fastAI@latest
```

Unsupported operating systems get warnings with the tools to install manually.

## Timezone Setup

The installer can configure the system timezone interactively. It shows the
current detected timezone, defaults to that value or `America/Denver`, and lets
you type any valid timezone such as:

```text
America/Denver
America/New_York
America/Los_Angeles
UTC
```

On Linux, it uses `timedatectl set-timezone` when available and falls back to
`/etc/localtime` plus `/etc/timezone` on minimal systems. On macOS, it uses
`systemsetup -settimezone`.

## Antidote Regeneration

After linking config, the installer regenerates:

```text
~/.zshrc_config/plugins_pre.zsh
~/.zshrc_config/plugins_post.zsh
```

Those are generated from:

```text
~/.zshrc_config/plugins_pre.txt
~/.zshrc_config/plugins_post.txt
```

## After Install

Open a new shell, or run:

```sh
source ~/.zshrc
```

Then verify:

```sh
command -v zshsetup
command -v aiCommit
command -v howdoi
tmux -V
nvim --version
```

## Reinstalling

The install script is intended to be rerunnable. It refreshes managed links,
backs up unmanaged paths that are in the way, and regenerates Antidote files.

## Manual Uninstall

Remove the managed files:

```sh
rm -rf ~/.zshrc_config ~/.config/nvim ~/.config/starship.toml ~/.tmux.conf ~/.codex/AGENTS.md
```

Then restore a previous `.zshrc` backup if desired.
