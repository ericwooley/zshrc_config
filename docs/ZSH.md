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
keybindings.zsh
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

These generated loader files are machine-local and ignored by Git because they
contain Antidote cache paths for the current home directory and OS. `plugins.zsh`
locates Antidote from Homebrew or `~/.antidote`, regenerates the loader files
when they are missing, older than the source lists, or copied from another OS
cache layout, then sources them.

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

## Keybindings

`keybindings.zsh` contains interactive zle keybindings. It uses zsh's emacs
keymap, which matches standard bash/readline-style line editing.

Current bindings:

| Key | Action |
| --- | --- |
| `Ctrl-A` | move to the beginning of the line |
| `Ctrl-E` | move to the end of the line |
| `Ctrl-Left` | move one shell word left |
| `Ctrl-Right` | move one shell word right |

The config binds common xterm-style Ctrl-arrow escape sequences so terminals
that send sequences like `^[[1;5D` do not print fragments such as `;5D`.

## Tools

`tools.zsh` initializes command-line tools when available:

- `zoxide`
- `starship`

Missing optional tools are skipped rather than failing shell startup.
The managed Starship prompt config enables the time module with local time;
Starship does not accept named timezones such as `America/Denver` for
`utc_time_offset`.

## Environment

`env.zsh` sources machine-local overrides first so `~/.zshrc_local` can set
values such as `N_PREFIX`. It defaults `N_PREFIX` to:

```text
~/.local/n
```

Then it de-duplicates `PATH` and prepends:

```text
~/.zshrc_config/bin
$N_PREFIX/bin
~/.local/go/bin
~/.local/bin
```

It also sets defaults for `fastAI` and sets `EDITOR=nvim`. Machine-local
overrides are sourced from:

```text
~/.zshrc_local
```

Use `~/.zshrc_local` for machine-specific environment variables or secrets. Do not
commit that file.

After local overrides, `env.zsh` detects an active TigerVNC display on `:1` and
sets `DISPLAY=:1` when `DISPLAY` is otherwise unset. This makes GUI commands
launched from SSH, such as headed Playwright browser runs, open in the VNC
desktop by default.

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
| `rzsh` | `source ~/.zshrc` | reload the managed zsh config in the current shell |
| `zh` | `zshow` | short alias for asking about this zsh setup |

## Functions

Function files live in:

```text
~/.zshrc_config/functions/
```

`functions/init.zsh` loads:

- `mkcd.zsh`
- `resetmouse.zsh`
- `tmr.zsh`
- `killport.zsh`
- `dstop.zsh`
- `dclean.zsh`
- `dnuke.zsh`
- `zshupdate.zsh`
- `zsh_install_hourly_update_cron.zsh`
- `nvim_install_stable_update_cron.zsh`
- `vmls.zsh`
- `vmcreate.zsh`
- `vmconnect.zsh`
- `vmrm.zsh`
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
source "$ZSHRC_CONFIG_DIR/functions/killport.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dstop.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dclean.zsh"
source "$ZSHRC_CONFIG_DIR/functions/dnuke.zsh"
source "$ZSHRC_CONFIG_DIR/functions/zshupdate.zsh"
source "$ZSHRC_CONFIG_DIR/functions/zsh_install_hourly_update_cron.zsh"
source "$ZSHRC_CONFIG_DIR/functions/nvim_install_stable_update_cron.zsh"
source "$ZSHRC_CONFIG_DIR/functions/vmls.zsh"
source "$ZSHRC_CONFIG_DIR/functions/vmcreate.zsh"
source "$ZSHRC_CONFIG_DIR/functions/vmconnect.zsh"
source "$ZSHRC_CONFIG_DIR/functions/vmrm.zsh"
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

### `functions/killport.zsh`

Public function:

```zsh
killport <port>
```

Purpose:

- find the process listening on a TCP port with `lsof`
- print the matching listener details
- send `TERM`, then `KILL` if the process is still alive after a short wait
- validate that the port is a number from `1` to `65535`

Example:

```sh
killport 18080
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
- ask whether to run the updated repo `install.sh`
- reload the current shell with `source ~/.zshrc`
- return an error if the config directory is missing or is not inside a Git repository

This is a shell function rather than a bin script so the final `source ~/.zshrc`
applies to the current shell. If accepted, `install.sh` runs before the reload
so newly pulled installer changes can apply immediately.

### `functions/zsh_install_hourly_update_cron.zsh`

Public function:

```zsh
zsh_install_hourly_update_cron
```

Purpose:

- install a marked hourly cron job for this user
- run `git -C ~/.zshrc_config pull --ff-only` at minute `00` every hour
- write cron output to `~/.zsh_install_hourly_update_cron.log`
- replace an existing hourly or older nightly zsh update cron entry when rerun

Example:

```sh
zsh_install_hourly_update_cron
```

### `functions/nvim_install_stable_update_cron.zsh`

Public function:

```zsh
nvim_install_stable_update_cron
```

Purpose:

- install a marked daily root cron job on Linux
- ask for the timezone and daily hour interactively
- run the official stable Neovim Linux tarball installer every day at minute `00`
- write cron output to `/var/log/nvim_install_stable_update_cron.log`
- replace an existing Neovim tarball update cron entry when rerun

Example:

```sh
nvim_install_stable_update_cron
```

### `functions/vmls.zsh`

Public function:

```zsh
vmls [multipass-list-args...]
```

Purpose:

- list Multipass instances with `multipass list`
- pass any extra arguments through to Multipass
- print that Multipass needs to be installed first when it is missing

Example:

```sh
vmls
```

### `functions/vmcreate.zsh`

Public function:

```zsh
vmcreate <name> [image]
```

Purpose:

- create a Multipass VM from the requested image, defaulting to `lts`
- print that Multipass needs to be installed first when it is missing
- create a shared host directory at `~/vms/shared`
- collect the pinned public SSH key plus public keys from `~/.ssh/*.pub`
- write a cloud-init file under `~/vms/cloud-init/<name>.yaml`
- create the configured user, defaulting to `$USER`
- install `zsh`, `git`, `curl`, `sudo`, `htop`, and certificates during cloud-init
- clone this dotfiles repo into `~/.zshrc_config` inside the VM
- continue setup when the VM already exists, which helps after a partial launch
- wait for Multipass SSH/exec readiness before checking cloud-init
- show heartbeat output while silent Multipass mount and install steps run
- remove the older `/home/<user>` mount when rerunning against a VM from the previous layout
- mount `~/vms/shared` to `~/shared` in the VM
- run the normal `install.sh` inside the VM

Useful environment overrides:

```zsh
VM_USER=ericwooley
VM_SHARED_DIR=$HOME/vms/shared
VM_IMAGE=lts
VM_CPUS=2
VM_MEMORY=4G
VM_DISK=20G
VM_SSH_WAIT_SECONDS=240
VM_MOUNT_WAIT_SECONDS=180
VM_INSTALL_WAIT_SECONDS=900
VM_CLOUD_INIT_ROOT=$HOME/vms/cloud-init
ZSHSETUP_REPO_URL=https://github.com/ericwooley/zshrc_config.git
```

Examples:

```sh
vmcreate test-thing
vmcreate test-thing 24.04
VM_MEMORY=8G VM_CPUS=4 vmcreate heavier-box
```

### `functions/vmconnect.zsh`

Public function:

```zsh
vmconnect <name>
```

Purpose:

- open a shell in a managed Multipass VM
- print that Multipass needs to be installed first when it is missing
- switch to the configured VM user with `sudo -iu`
- default the VM user to `$USER`

Example:

```sh
vmconnect test-thing
```

### `functions/vmrm.zsh`

Public function:

```zsh
vmrm <name>
```

Purpose:

- permanently delete a Multipass VM with `multipass delete --purge`
- print that Multipass needs to be installed first when it is missing
- leave the shared host directory at `~/vms/shared` alone

Example:

```sh
vmrm test-thing
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
- normalize GitHub SSH repo URLs to HTTPS before cloning or pulling
- run the repo `install.sh` on the remote
- ask whether to install the hourly zshupdate cron on the remote
- ask whether to install the Neovim stable tarball update cron on the remote
- use the same installer prompts, backups, and managed symlinks as local installs

Local requirements:

- `ssh`
- a local config repo with an `origin` remote, or `ZSHSETUP_REPO_URL`

If neither is set, it falls back to:

```text
https://github.com/ericwooley/zshrc_config.git
```

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
- `zshow`

See [Helper Commands](HELPERS.md) for details.
