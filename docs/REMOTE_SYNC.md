# Remote Sync

Remote sync is handled by:

```zsh
zshsetup <host>
```

Examples:

```zsh
zshsetup dev
zshsetup user@example.com
```

## What It Does

`zshsetup` bootstraps the setup from this git repo on an SSH host:

- finds the repo URL from `ZSHSETUP_REPO_URL` or the local repo `origin`
- normalizes GitHub SSH URLs to HTTPS so remote hosts do not need GitHub SSH keys
- connects to the remote with `ssh`
- installs `git` with apt when the remote is Debian/Ubuntu and `git` is missing
- clones the repo on first run
- stashes remote local changes before updating an existing clone
- runs `git pull --ff-only` on later runs
- runs the repo `install.sh` on the remote
- asks whether to install the remote hourly zshupdate cron job
- asks whether to install the remote Neovim stable tarball update cron job

The remote installer then handles dependency prompts, optional timezone setup,
backups, and links for zsh, tmux, and Neovim config.

## Local Function

The local zsh function lives at:

```text
.zshrc_config/functions/zshsetup.zsh
```

Local requirements:

- `ssh`
- a published HTTPS git remote, or `ZSHSETUP_REPO_URL`

If the local clone does not have an `origin` remote yet, `zshsetup` falls back
to:

```text
https://github.com/ericwooley/zshrc_config.git
```

You can override it with:

```zsh
ZSHSETUP_REPO_URL=https://github.com/<you>/<repo>.git zshsetup <host>
```

When an existing remote checkout has an SSH origin, `zshsetup` resets that
remote `origin` URL to the HTTPS URL before pulling.

## Remote Clone Location

The default remote clone path is:

```text
~/.zshrc_config
```

## Remote Config Links

After `install.sh` runs, these remote paths are managed:

```text
~/.zshrc
~/.zshrc_config
~/.tmux.conf -> ~/.zshrc_config/.tmux.conf
~/.config/starship.toml => ~/.zshrc_config/.config/starship.toml
~/.codex/AGENTS.md => ~/.zshrc_config/.codex/AGENTS.md
~/.config/nvim -> ~/.zshrc_config/.config/nvim
```

If an unmanaged path already exists, the installer moves it aside first:

```text
<path>_backup_<date>.bak
```

## Interactive Prompts

`zshsetup` only auto-prompts for the minimum git bootstrap needed before the repo
can be cloned. After that, `install.sh` asks before installing dependencies,
configuring the system timezone, and writing managed config links. When install
finishes, `zshsetup` asks whether to run `zsh_install_hourly_update_cron` and
`nvim_install_stable_update_cron` on the remote.

Answer `y` to run a step. Anything else skips it.

## Rerunning

`zshsetup` is intended to be rerunnable. On an existing remote clone it runs:

```sh
git -C ~/.zshrc_config stash push -u -m "zshsetup auto-stash <date>" # only when dirty
git -C ~/.zshrc_config pull --ff-only
sh ~/.zshrc_config/install.sh
zsh_install_hourly_update_cron # only when accepted
nvim_install_stable_update_cron # only when accepted
```

## Supported Remote OS

Automatic dependency installation is focused on Ubuntu/Debian through the shared
`install.sh` script. Other systems get warnings for missing tools and should be
prepared manually.
