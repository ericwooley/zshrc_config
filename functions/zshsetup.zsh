# Sync this terminal setup to an SSH host.
# Copies zsh, tmux, and Neovim config, then runs the remote helper script for
# dependency bootstrap, Antidote/Lazy.nvim setup, and remote health checks.
zshsetup() {
  if (( $# != 1 )); then
    echo "usage: zshsetup <host>" >&2
    return 2
  fi

  local host="$1"
  local config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local remote_helper="${ZSHSETUP_REMOTE_SCRIPT:-$config_dir/scripts/zshsetup-remote.sh}"
  local setup_status=0

  for cmd in ssh scp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "zshsetup: missing local command: $cmd" >&2
      return 1
    fi
  done

  if [[ ! -f "$HOME/.zshrc" ]]; then
    echo "zshsetup: missing $HOME/.zshrc" >&2
    return 1
  fi

  if [[ ! -d "$config_dir" ]]; then
    echo "zshsetup: missing $config_dir" >&2
    return 1
  fi

  if [[ ! -f "$remote_helper" ]]; then
    echo "zshsetup: missing remote helper script: $remote_helper" >&2
    return 1
  fi

  echo "zshsetup: preparing $host"
  scp "$remote_helper" "$host:~/.zshsetup-remote.sh" || return
  ssh -tt "$host" 'sh "$HOME/.zshsetup-remote.sh" prepare; setup_rc=$?; rm -f "$HOME/.zshsetup-remote.sh"; exit "$setup_rc"'
  local prep_status=$?
  if (( prep_status != 0 )); then
    setup_status=$prep_status
  fi

  echo "zshsetup: syncing zsh config"
  scp "$HOME/.zshrc" "$host:~/.zshrc" || return
  scp -r "$config_dir"/. "$host:~/.zshrc_config/" || return

  if [[ -d "$HOME/.config/nvim" ]]; then
    echo "zshsetup: syncing nvim config"
    scp -r "$HOME/.config/nvim" "$host:~/.config/" || return
  else
    echo "zshsetup: local nvim config not found at $HOME/.config/nvim" >&2
    setup_status=1
  fi

  if [[ -f "$HOME/.tmux.conf" ]]; then
    echo "zshsetup: syncing tmux config"
    scp "$HOME/.tmux.conf" "$host:~/.tmux.conf" || return
  fi

  echo "zshsetup: checking remote tools and regenerating antidote plugin files"
  ssh -tt "$host" 'sh "$HOME/.zshrc_config/scripts/zshsetup-remote.sh" finalize'
  local check_status=$?
  if (( check_status != 0 )); then
    setup_status=$check_status
  fi

  if (( setup_status == 0 )); then
    echo "zshsetup: complete"
  else
    echo "zshsetup: copied config, but one or more remote checks failed" >&2
  fi

  return "$setup_status"
}
