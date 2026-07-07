# Zsh

The zsh setup is split into small files so each area has one job.

## Entrypoint

`~/.zshrc` should only load the managed config:

```zsh
# zshsetup-managed
source "${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}/init.zsh"
```

The config root is:

```text
~/.zshrc_config/init.zsh
```

## Load Order

`init.zsh` loads files in this order:

```text
options.zsh
plugins.zsh
completions.zsh
tools.zsh
env.zsh
aliases.zsh
scripts/init.zsh
functions/init.zsh
```

## Options

`options.zsh` contains shell behavior such as history, completion behavior, and
directory navigation options.

One notable behavior is directory navigation without typing `cd` first. Typing a
directory name, `..`, or similar directory path changes into it.

## Plugins

Antidote plugin source lists live in:

```text
plugins_pre.txt
plugins_post.txt
```

Generated Antidote loaders live in:

```text
plugins_pre.zsh
plugins_post.zsh
```

`plugins.zsh` locates Antidote from Homebrew or `~/.antidote`, loads generated
plugin files when present, and warns when generated files are missing.

## Completions

`completions.zsh` sets up command completion and generated completions for:

```text
npm
pnpm
yarn
bun
```

Generated completion files are written under:

```text
~/.zshrc_config/generated-completions/
```

That directory is ignored by Git.

## Tools

`tools.zsh` initializes command-line tools when available:

- `zoxide`
- `starship`

Missing optional tools are skipped rather than failing shell startup.

## Environment

`env.zsh` de-duplicates `PATH` and prepends:

```text
~/.zshrc_config/bin
~/.local/n/bin
~/.local/go/bin
~/.local/bin
```

It also sets defaults for `fastAI`, sets `EDITOR=nvim`, and sources:

```text
~/.zshrc_local
```

Use `~/.zshrc_local` for machine-specific environment variables or secrets. Do not
commit that file.

Example local secret for `aiCommit` through
[`ericwooley/fastAI`](https://github.com/ericwooley/fastAI):

```zsh
export OPENROUTER_API_KEY='<openrouter key>'
```

## Aliases

Aliases live in:

```text
~/.zshrc_config/aliases.zsh
```

Current aliases:

| Alias | Expands to | Purpose |
| --- | --- | --- |
| `ll` | `ls -alF` | detailed directory listing |
| `la` | `ls -A` | include dotfiles except `.` and `..` |
| `l` | `ls -CF` | compact column listing with file type markers |
| `ports` | `lsof -i -P -n \| grep LISTEN` | show processes listening on ports |

## Functions

Function files live in:

```text
~/.zshrc_config/functions/
```

`functions/init.zsh` loads:

- `mkcd.zsh`
- `resetmouse.zsh`
- `tmr.zsh`
- `dstop.zsh`
- `dclean.zsh`
- `dnuke.zsh`
- `zshupdate.zsh`
- `zsh_install_nightly_update_cron.zsh`
- `zshsetup.zsh`

Each file should define one public function.

### `functions/init.zsh`

Purpose:

- bootstrap all sourced shell functions
- keep function load order in one place
- avoid loading executable helper commands as shell functions

Loaded by:

```text
~/.zshrc_config/init.zsh
```

Current load order:

```zsh
source "$ZSHRC_CONFIG_DIR/functions/mkcd.zsh"
source "$ZSHRC_CONFIG_DIR/functions/resetmouse.zsh"
source "$ZSHRC_CONFIG_DIR/functions/tmr.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dstop.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dclean.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dnuke.zsh"
source "$ZSHRC_CONFIG_DIR/functions/zshupdate.zsh"
source "$ZSHRC_CONFIG_DIR/functions/zsh_install_nightly_update_cron.zsh"
source "$ZSHRC_CONFIG_DIR/functions/zshsetup.zsh"
```

### `functions/mkcd.zsh`

Public function:

```zsh
mkcd <directory>
```

Purpose:

- create a directory with parents as needed
- immediately change into that directory
- print usage when no directory is provided

Example:

```sh
mkcd scratch/new-api
```

### `functions/resetmouse.zsh`

Public function:

```zsh
resetmouse
```

Purpose:

- reset terminal mouse reporting when a full-screen app exits badly
- disable common xterm mouse, focus, and bracketed-paste modes
- run `stty sane` to restore normal terminal line behavior

Example:

```sh
resetmouse
```

### `functions/tmr.zsh`

Public function:

```zsh
tmr [session-name]
```

Purpose:

- attach to a tmux session
- create the session if it does not exist
- default the session name to the current directory name
- use `main` if no name can be inferred
- replace `:` with `_` in session names so tmux accepts them

Behavior:

- outside tmux, runs `tmux new-session -A -s <session>`
- inside tmux, creates the session in the background when needed and switches the current client to it
- returns an error if tmux is not installed

Examples:

```sh
tmr
tmr work
tmr api
```

### `functions/dstop.zsh`

Public function:

```zsh
dstop
```

Purpose:

- stop every Docker container returned by `docker ps -a -q`
- print a friendly message when there are no containers
- return an error if Docker is not installed

### `functions/dclean.zsh`

Public function:

```zsh
dclean
```

Purpose:

- run `docker system prune -a -f --volumes`
- remove stopped containers, unused networks, dangling images, and volumes
- return an error if Docker is not installed

This is intentionally non-interactive and can delete Docker data.

### `functions/dnuke.zsh`

Public function:

```zsh
dnuke
```

Purpose:

- remove all Docker containers
- remove all Docker images
- remove all Docker volumes
- return an error if Docker is not installed

This is destructive. It is meant for complete local Docker teardown.

### `functions/zshupdate.zsh`

Public function:

```zsh
zshupdate
```

Purpose:

- run `git pull --ff-only` in `${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}`
- reload the current shell with `source ~/.zshrc`
- return an error if the config directory is missing or is not inside a Git repository

This is a shell function rather than a bin script so the final `source ~/.zshrc`
applies to the current shell.

### `functions/zsh_install_nightly_update_cron.zsh`

Public function:

```zsh
zsh_install_nightly_update_cron
```

Purpose:

- install a marked daily cron job for this user
- ask for the timezone and daily hour interactively
- run `git -C ~/.zshrc_config pull --ff-only` every day at minute `00`
- write cron output to `~/.zsh_install_nightly_update_cron.log`
- replace an existing nightly zsh update cron entry when rerun

Example:

```sh
zsh_install_nightly_update_cron
```

### `functions/zshsetup.zsh`

Public function:

```zsh
zshsetup <host>
```

Purpose:

- bootstrap this zsh, tmux, and Neovim setup on an SSH host
- clone the published config repo on first run
- pull the remote clone on later runs
- run the repo `install.sh` on the remote
- use the same installer prompts, backups, and managed symlinks as local installs

Local requirements:

- `ssh`
- a local config repo with an `origin` remote, or `ZSHSETUP_REPO_URL`

Optional repo URL override:

```zsh
ZSHSETUP_REPO_URL=https://github.com/<you>/<repo>.git zshsetup <host>
```

See [Remote Sync](REMOTE_SYNC.md) for the full flow.

## Bin Commands

Executable helper commands live in:

```text
~/.zshrc_config/bin/
```

Current command:

- `aiCommit`
- `howdoi`

See [Helper Commands](HELPERS.md) for details.
