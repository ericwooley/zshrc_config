# Pull the managed zsh config repo and reload the current shell.
zshupdate() {
  if (( $# != 0 )); then
    echo "usage: zshupdate" >&2
    return 2
  fi

  local config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local zshrc_file="$HOME/.zshrc"

  if [[ ! -d "$config_dir" ]]; then
    echo "zshupdate: config directory not found: $config_dir" >&2
    return 1
  fi

  if [[ ! -f "$zshrc_file" ]]; then
    echo "zshupdate: zshrc not found: $zshrc_file" >&2
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "zshupdate: git is not installed or not on PATH" >&2
    return 1
  fi

  if ! git -C "$config_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "zshupdate: $config_dir is not a git repository" >&2
    echo "zshupdate: clone this setup into ~/.zshrc_config before using zshupdate" >&2
    return 1
  fi

  echo "zshupdate: pulling $config_dir"
  git -C "$config_dir" pull --ff-only || return

  if [[ -x "$config_dir/install.sh" || -r "$config_dir/install.sh" ]]; then
    local answer
    printf "zshupdate: run install.sh now? [y/N] "
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        echo "zshupdate: running $config_dir/install.sh"
        sh "$config_dir/install.sh" || return
        ;;
      *)
        echo "zshupdate: skipped install.sh"
        ;;
    esac
  else
    echo "zshupdate: install.sh not found at $config_dir/install.sh"
  fi

  echo "zshupdate: reloading $zshrc_file"
  source "$zshrc_file"
}
