#!/usr/bin/env sh
set -eu

repo_url="${ZSHSETUP_REPO_URL:-https://github.com/ericwooley/zshrc_config.git}"
install_dir="$HOME/.zshrc_config"
config_dir="$HOME/.zshrc_config"

backup_config_dir() {
  backup_path="$HOME/.zsh_config.bak"

  if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
    backup_path="$HOME/.zsh_config.bak_$(date +%Y%m%d_%H%M%S)"
  fi

  echo "bootstrap.sh: moving existing $config_dir to $backup_path"
  mv "$config_dir" "$backup_path"
}

if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap.sh: git is required before this installer can clone the repo" >&2
  exit 1
fi

if [ -e "$config_dir" ] || [ -L "$config_dir" ]; then
  backup_config_dir
fi

mkdir -p "$(dirname "$install_dir")"

echo "bootstrap.sh: cloning $repo_url into $install_dir"
git clone "$repo_url" "$install_dir"

sh "$install_dir/install.sh"
