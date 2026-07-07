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
- connects to the remote with `ssh`
- installs `git` with apt when the remote is Debian/Ubuntu and `git` is missing
- clones the repo on first run
- stashes remote local changes before updating an existing clone
- runs `git pull --ff-only` on later runs
- runs the repo `install.sh` on the remote

The remote installer then handles dependency prompts, backups, and links for
zsh, tmux, and Neovim config.

## Local Function

The local zsh function lives at:

```text
.zshrc_config/functions/zshsetup.zsh
```

Local requirements:

- `ssh`
- a published git remote, or `ZSHSETUP_REPO_URL`

If the local clone does not have an `origin` remote yet, run:

```zsh
ZSHSETUP_REPO_URL=https://github.com/<you>/<repo>.git zshsetup <host>
```

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
~/.config/nvim -> ~/.zshrc_config/.config/nvim
```

If an unmanaged path already exists, the installer moves it aside first:

```text
<path>_backup_<date>.bak
```

## Interactive Prompts

`zshsetup` only auto-prompts for the minimum git bootstrap needed before the repo
can be cloned. After that, `install.sh` asks before installing dependencies and
before writing managed config links.

Answer `y` to run a step. Anything else skips it.

## Rerunning

`zshsetup` is intended to be rerunnable. On an existing remote clone it runs:

```sh
git -C ~/.zshrc_config stash push -u -m "zshsetup auto-stash <date>" # only when dirty
git -C ~/.zshrc_config pull --ff-only
sh ~/.zshrc_config/install.sh
```

## Supported Remote OS

Automatic dependency installation is focused on Ubuntu/Debian through the shared
`install.sh` script. Other systems get warnings for missing tools and should be
prepared manually.
