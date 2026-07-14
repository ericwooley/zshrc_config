#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
zshrc_file="$HOME/.zshrc"
managed_marker="# zshsetup-managed"

export N_PREFIX="${N_PREFIX:-$HOME/.local/n}"
export PATH="$N_PREFIX/bin:$HOME/.local/go/bin:$HOME/.local/bin:$PATH"

confirm() {
  printf "%s [y/N] " "$1"
  read answer || answer=""
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "install.sh: sudo is required for: $*" >&2
    return 1
  fi
}

run_apt() {
  if [ "$(id -u)" -eq 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"
  else
    echo "install.sh: sudo is required for apt-get" >&2
    return 1
  fi
}

detect_timezone() {
  detected_timezone=""

  if command -v timedatectl >/dev/null 2>&1; then
    detected_timezone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  fi

  if [ -z "$detected_timezone" ] && [ -L /etc/localtime ]; then
    localtime_target=$(readlink /etc/localtime 2>/dev/null || true)
    case "$localtime_target" in
      */zoneinfo/*) detected_timezone=${localtime_target#*/zoneinfo/} ;;
    esac
  fi

  if [ -z "$detected_timezone" ] && [ "$(uname -s)" = "Darwin" ] && command -v systemsetup >/dev/null 2>&1; then
    detected_timezone=$(systemsetup -gettimezone 2>/dev/null | sed 's/^Time Zone: //' || true)
  fi

  if [ -z "$detected_timezone" ] && [ -r /etc/timezone ]; then
    detected_timezone=$(sed -n '1p' /etc/timezone 2>/dev/null || true)
  fi

  printf '%s\n' "$detected_timezone"
}

timezone_exists() {
  timezone_name="$1"

  case "$timezone_name" in
    ""|/*|*..*) return 1 ;;
  esac

  [ -f "/usr/share/zoneinfo/$timezone_name" ] && return 0
  [ -f "/var/db/timezone/zoneinfo/$timezone_name" ] && return 0

  if [ "$(uname -s)" = "Darwin" ] && command -v systemsetup >/dev/null 2>&1; then
    systemsetup -listtimezones 2>/dev/null | sed '1d' | grep -Fx "$timezone_name" >/dev/null 2>&1 && return 0
  fi

  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl list-timezones 2>/dev/null | grep -Fx "$timezone_name" >/dev/null 2>&1 && return 0
  fi

  [ -f "/usr/share/zoneinfo/$timezone_name" ]
}

set_system_timezone() {
  timezone_name="$1"

  if ! timezone_exists "$timezone_name"; then
    echo "install.sh: warning: unknown timezone: $timezone_name" >&2
    echo "install.sh: examples: America/Denver, America/New_York, Europe/London, UTC" >&2
    return 1
  fi

  case "$(uname -s)" in
    Darwin)
      if command -v systemsetup >/dev/null 2>&1; then
        run_root systemsetup -settimezone "$timezone_name"
      else
        echo "install.sh: warning: systemsetup is required to set timezone on macOS" >&2
        return 1
      fi
      ;;
    Linux)
      if command -v timedatectl >/dev/null 2>&1; then
        run_root timedatectl set-timezone "$timezone_name"
      elif [ -f "/usr/share/zoneinfo/$timezone_name" ]; then
        run_root ln -sf "/usr/share/zoneinfo/$timezone_name" /etc/localtime
        printf '%s\n' "$timezone_name" | run_root tee /etc/timezone >/dev/null
      else
        echo "install.sh: warning: no supported timezone setter found on this Linux system" >&2
        return 1
      fi
      ;;
    *)
      echo "install.sh: warning: unsupported OS for automatic timezone setup" >&2
      return 1
      ;;
  esac

  echo "install.sh: timezone set to $timezone_name"
}

configure_timezone() {
  current_timezone=$(detect_timezone)
  default_timezone="${current_timezone:-America/Denver}"

  echo "install.sh: current timezone: ${current_timezone:-unknown}"
  echo "install.sh: common choices: America/Denver, America/New_York, America/Los_Angeles, UTC"
  if command -v timedatectl >/dev/null 2>&1; then
    echo "install.sh: search with: timedatectl list-timezones | grep -i denver"
  elif [ "$(uname -s)" = "Darwin" ] && command -v systemsetup >/dev/null 2>&1; then
    echo "install.sh: search with: find /usr/share/zoneinfo -type f | sed 's#^/usr/share/zoneinfo/##' | grep -i denver"
  fi

  while :; do
    printf "Timezone to set [%s]: " "$default_timezone"
    read timezone_answer || timezone_answer=""
    timezone_name="${timezone_answer:-$default_timezone}"

    if set_system_timezone "$timezone_name"; then
      return 0
    fi

    if ! confirm "Try another timezone?"; then
      echo "install.sh: skipped timezone setup"
      return 0
    fi
  done
}

install_starship() {
  if ! command -v starship >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
}

install_zoxide() {
  if ! command -v zoxide >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi
}

install_n() {
  export N_PREFIX="${N_PREFIX:-$HOME/.local/n}"
  export PATH="$N_PREFIX/bin:$PATH"

  if ! command -v n >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    mkdir -p "$N_PREFIX/bin"
    curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$N_PREFIX/bin/n"
    chmod +x "$N_PREFIX/bin/n"
  fi

  if command -v n >/dev/null 2>&1; then
    N_PREFIX="$N_PREFIX" n install lts
  fi
}

go_at_least_1_24() {
  if ! command -v go >/dev/null 2>&1; then
    return 1
  fi

  go_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
  go_major=${go_version%%.*}
  go_rest=${go_version#*.}
  go_minor=${go_rest%%.*}

  case "$go_major" in
    ""|*[!0-9]*) return 1 ;;
  esac

  case "$go_minor" in
    ""|*[!0-9]*) return 1 ;;
  esac

  [ "$go_major" -gt 1 ] || { [ "$go_major" -eq 1 ] && [ "$go_minor" -ge 24 ]; }
}

install_go_linux_user() {
  if go_at_least_1_24; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo "install.sh: warning: curl and tar are required to install Go 1.24 for Go-built tools" >&2
    return 1
  fi

  go_arch=""
  case "$(uname -m)" in
    x86_64|amd64) go_arch="amd64" ;;
    aarch64|arm64) go_arch="arm64" ;;
  esac

  if [ -z "$go_arch" ]; then
    echo "install.sh: warning: unsupported Go architecture: $(uname -m)" >&2
    return 1
  fi

  go_version="${GO_VERSION:-1.24.4}"
  go_archive="go${go_version}.linux-${go_arch}.tar.gz"
  tmp_dir=$(mktemp -d)

  if curl -fsSL "https://go.dev/dl/$go_archive" -o "$tmp_dir/$go_archive" \
    && mkdir -p "$HOME/.local" \
    && rm -rf "$HOME/.local/go" \
    && tar -C "$HOME/.local" -xzf "$tmp_dir/$go_archive"; then
    export PATH="$HOME/.local/go/bin:$PATH"
  else
    echo "install.sh: warning: Go $go_version install failed; install Go 1.24.x manually for Go-built tools" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"
  go_at_least_1_24
}

ensure_go_for_tools() {
  if go_at_least_1_24; then
    return 0
  fi

  if [ "$(uname -s)" = "Linux" ]; then
    install_go_linux_user
  else
    echo "install.sh: warning: Go 1.24.x is required for Go-built tools; install or upgrade Go manually" >&2
    return 1
  fi
}

ensure_go_for_fastai() {
  ensure_go_for_tools
}

install_go_binary() {
  binary_name="$1"
  module_path="$2"
  purpose="$3"

  if command -v "$binary_name" >/dev/null 2>&1; then
    return 0
  fi

  if ! ensure_go_for_tools; then
    echo "install.sh: warning: skipped $binary_name install because Go 1.24.x is unavailable; install it manually for $purpose" >&2
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  echo "install.sh: installing $binary_name into $HOME/.local/bin"
  if ! GOBIN="$HOME/.local/bin" go install "$module_path"; then
    echo "install.sh: warning: $binary_name install failed; install it manually for $purpose" >&2
  fi
}

install_fastai() {
  if ! ensure_go_for_fastai; then
    echo "install.sh: warning: skipped fastAI install because Go 1.24.x is unavailable" >&2
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "install.sh: warning: git is required to install fastAI from the latest source" >&2
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  fastai_repo_url="${FASTAI_REPO_URL:-https://github.com/ericwooley/fastAI.git}"
  fastai_source_dir="${FASTAI_SOURCE_DIR:-$HOME/.local/src/fastAI}"

  echo "install.sh: installing fastAI into $HOME/.local/bin"
  echo "install.sh: fastAI source: $fastai_repo_url"

  if [ -d "$fastai_source_dir/.git" ]; then
    echo "install.sh: updating fastAI source at $fastai_source_dir"
    git -C "$fastai_source_dir" pull --ff-only
  else
    if [ -e "$fastai_source_dir" ] || [ -L "$fastai_source_dir" ]; then
      echo "install.sh: warning: $fastai_source_dir exists but is not a git repo; skipping fastAI install" >&2
      return 0
    fi

    mkdir -p "$(dirname "$fastai_source_dir")"
    echo "install.sh: cloning fastAI into $fastai_source_dir"
    git clone "$fastai_repo_url" "$fastai_source_dir"
  fi

  if [ -x "$fastai_source_dir/scripts/install.sh" ]; then
    (cd "$fastai_source_dir" && FASTAI_INSTALL_DIR="$HOME/.local/bin" ./scripts/install.sh)
  elif [ -r "$fastai_source_dir/scripts/install.sh" ] && command -v bash >/dev/null 2>&1; then
    (cd "$fastai_source_dir" && FASTAI_INSTALL_DIR="$HOME/.local/bin" bash ./scripts/install.sh)
  else
    echo "install.sh: warning: fastAI installer not found; falling back to go install @latest" >&2
    GOBIN="$HOME/.local/bin" go install github.com/ericwooley/fastAI/cmd/fastAI@latest
  fi
}

install_antidote() {
  if [ -r "$HOME/.antidote/antidote.zsh" ]; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix 2>/dev/null || true)
    if [ -n "$brew_prefix" ] && [ -r "$brew_prefix/opt/antidote/share/antidote/antidote.zsh" ]; then
      return 0
    fi
  fi

  if command -v git >/dev/null 2>&1; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
}

install_eza_apt() {
  if command -v eza >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
    return 0
  fi

  tmp_dir=$(mktemp -d)
  if curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc -o "$tmp_dir/eza.asc" \
    && gpg --batch --yes --dearmor -o "$tmp_dir/gierens.gpg" "$tmp_dir/eza.asc" \
    && printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' > "$tmp_dir/gierens.list" \
    && run_root mkdir -p /etc/apt/keyrings \
    && run_root cp "$tmp_dir/gierens.gpg" /etc/apt/keyrings/gierens.gpg \
    && run_root cp "$tmp_dir/gierens.list" /etc/apt/sources.list.d/gierens.list \
    && run_root chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list; then
    run_apt update
    run_apt install -y eza
  else
    echo "install.sh: warning: eza repo setup failed" >&2
  fi

  rm -rf "$tmp_dir"
}

install_neovim_linux_tarball() {
  if [ "$(uname -s)" != "Linux" ]; then
    return 0
  fi

  installer="$repo_dir/scripts/install-neovim-linux-tarball.sh"
  if [ ! -r "$installer" ]; then
    echo "install.sh: warning: missing Neovim tarball installer at $installer" >&2
    return 1
  fi

  sh "$installer"
}

install_glow() {
  if command -v glow >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-cache >/dev/null 2>&1 && apt-cache show glow >/dev/null 2>&1; then
    run_apt install -y glow
  else
    install_go_binary glow github.com/charmbracelet/glow@latest "zshow Markdown rendering"
  fi
}

install_lazygit() {
  install_go_binary lazygit github.com/jesseduffield/lazygit@latest "Neovim <leader>lg"
}

install_multipass() {
  if command -v multipass >/dev/null 2>&1; then
    return 0
  fi

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install --cask multipass
      else
        echo "install.sh: warning: Homebrew is required to install Multipass on macOS" >&2
      fi
      ;;
    Linux)
      if ! command -v snap >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
          run_apt install -y snapd
        else
          echo "install.sh: warning: snap is required to install Multipass on Linux" >&2
          return 0
        fi
      fi

      if command -v snap >/dev/null 2>&1; then
        run_root snap install multipass || echo "install.sh: warning: Multipass snap install failed; install it manually" >&2
      fi
      ;;
    *)
      echo "install.sh: warning: unsupported OS for automatic Multipass install" >&2
      ;;
  esac
}

maybe_install_multipass() {
  if command -v multipass >/dev/null 2>&1; then
    return 0
  fi

  if confirm "Install Multipass for vm* helpers?"; then
    install_multipass
  else
    echo "install.sh: skipped Multipass install; vm* helpers will ask for Multipass when used"
  fi
}

set_default_shell_to_zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "install.sh: warning: zsh is not installed; cannot set it as the default shell" >&2
    return 0
  fi

  target_user=$(id -un)
  zsh_path=$(command -v zsh)
  current_shell=""

  if command -v getent >/dev/null 2>&1; then
    current_shell=$(getent passwd "$target_user" 2>/dev/null | awk -F: '{print $7}' || true)
  fi

  if [ -z "$current_shell" ] && [ "$(uname -s)" = "Darwin" ] && command -v dscl >/dev/null 2>&1; then
    current_shell=$(dscl . -read "/Users/$target_user" UserShell 2>/dev/null | awk '{print $2}' || true)
  fi

  if [ -z "$current_shell" ]; then
    current_shell="${SHELL:-}"
  fi

  if [ "$current_shell" = "$zsh_path" ]; then
    echo "install.sh: default shell is already $zsh_path"
    return 0
  fi

  if [ -r /etc/shells ] && ! grep -Fx "$zsh_path" /etc/shells >/dev/null 2>&1; then
    echo "install.sh: adding $zsh_path to /etc/shells"
    if ! printf '%s\n' "$zsh_path" | run_root tee -a /etc/shells >/dev/null; then
      echo "install.sh: warning: could not add $zsh_path to /etc/shells" >&2
      return 0
    fi
  fi

  if command -v chsh >/dev/null 2>&1; then
    echo "install.sh: setting default shell for $target_user to $zsh_path"
    if run_root chsh -s "$zsh_path" "$target_user"; then
      echo "install.sh: default shell updated; log out and back in for it to take effect"
    else
      echo "install.sh: warning: failed to set default shell to $zsh_path" >&2
    fi
  else
    echo "install.sh: warning: chsh is not available; set your shell to $zsh_path manually" >&2
  fi
}

install_deps() {
  uname_s=$(uname -s)

  if [ "$uname_s" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "install.sh: Homebrew is required on macOS" >&2
      return 1
    fi

    brew install antidote eza fzf git glow go lazygit lsof neovim ripgrep starship tmux zoxide zsh
  elif [ "$uname_s" = "Linux" ]; then
    if command -v apt-get >/dev/null 2>&1; then
      run_apt update
      run_apt install -y bash ca-certificates curl fzf git golang-go gpg gzip lsof ripgrep tar tmux zsh
      install_neovim_linux_tarball
      install_eza_apt
      install_glow
      install_lazygit
    else
      echo "install.sh: unsupported Linux package manager for automatic dependency install" >&2
      echo "install.sh: install zsh git curl go tmux fzf ripgrep lsof zoxide eza starship glow lazygit fastAI multipass manually" >&2
      if ! install_neovim_linux_tarball; then
        echo "install.sh: warning: Neovim tarball install failed; install Neovim manually" >&2
      fi
    fi
  else
    echo "install.sh: unsupported OS for automatic dependency install" >&2
    echo "install.sh: install zsh git curl go nvim tmux fzf ripgrep lsof zoxide eza starship glow lazygit fastAI multipass manually" >&2
  fi

  install_zoxide
  install_starship
  install_n
  install_fastai
  install_antidote
  set_default_shell_to_zsh
  maybe_install_multipass
}

regenerate_antidote_files() {
  antidote_source=""

  if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix 2>/dev/null || true)
    if [ -n "$brew_prefix" ] && [ -r "$brew_prefix/opt/antidote/share/antidote/antidote.zsh" ]; then
      antidote_source="$brew_prefix/opt/antidote/share/antidote/antidote.zsh"
    fi
  fi

  if [ -z "$antidote_source" ] && [ -r "$HOME/.antidote/antidote.zsh" ]; then
    antidote_source="$HOME/.antidote/antidote.zsh"
  fi

  if [ -n "$antidote_source" ] && command -v zsh >/dev/null 2>&1; then
    ANTIDOTE_SOURCE="$antidote_source" ZSHRC_CONFIG_DIR="$config_dir" zsh -lc '
      source "$ANTIDOTE_SOURCE"
      antidote bundle < "$ZSHRC_CONFIG_DIR/plugins_pre.txt" > "$ZSHRC_CONFIG_DIR/plugins_pre.zsh"
      antidote bundle < "$ZSHRC_CONFIG_DIR/plugins_post.txt" > "$ZSHRC_CONFIG_DIR/plugins_post.zsh"
    '
  fi
}

backup_existing_path() {
  target_path="$1"

  if [ "$target_path" = "$HOME/.zshrc_config" ]; then
    backup_path="$HOME/.zsh_config.bak"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
      backup_path="$HOME/.zsh_config.bak_$(date +%Y%m%d_%H%M%S)"
    fi
  else
    backup_path="${target_path}_backup_$(date +%Y%m%d_%H%M%S).bak"
  fi

  echo "install.sh: backing up existing $target_path to $backup_path"
  mv "$target_path" "$backup_path"
}

link_managed_path() {
  source_path="$1"
  target_path="$2"
  label="$3"

  if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    echo "install.sh: warning: missing $label source at $source_path" >&2
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"

  if [ -d "$source_path" ] && [ -d "$target_path" ]; then
    source_real=$(CDPATH= cd -- "$source_path" && pwd -P)
    target_real=$(CDPATH= cd -- "$target_path" && pwd -P)
    if [ "$source_real" = "$target_real" ]; then
      echo "install.sh: $label already lives at $target_path"
      return 0
    fi
  fi

  if [ -L "$target_path" ]; then
    current_target=$(readlink "$target_path" || true)
    if [ "$current_target" = "$source_path" ]; then
      echo "install.sh: $label already linked at $target_path"
      return 0
    fi
    backup_existing_path "$target_path"
  elif [ -e "$target_path" ]; then
    backup_existing_path "$target_path"
  fi

  ln -s "$source_path" "$target_path"
  echo "install.sh: linked $label to $target_path"
}

hardlink_managed_file() {
  source_path="$1"
  target_path="$2"
  label="$3"

  if [ ! -f "$source_path" ]; then
    echo "install.sh: warning: missing $label source at $source_path" >&2
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    if [ "$source_path" -ef "$target_path" ] 2>/dev/null; then
      echo "install.sh: $label already hard linked at $target_path"
      return 0
    fi
    backup_existing_path "$target_path"
  fi

  if ln "$source_path" "$target_path" 2>/dev/null; then
    echo "install.sh: hard linked $label to $target_path"
  else
    echo "install.sh: warning: hard link failed for $label; using symlink" >&2
    ln -s "$source_path" "$target_path"
    echo "install.sh: linked $label to $target_path"
  fi
}

install_configs() {
  mkdir -p "$HOME/.config"
  link_managed_path "$repo_dir" "$config_dir" "zsh config"

  if [ -d "$repo_dir/.config/nvim" ]; then
    link_managed_path "$repo_dir/.config/nvim" "$HOME/.config/nvim" "Neovim config"
  fi

  if [ -f "$repo_dir/.config/starship.toml" ]; then
    hardlink_managed_file "$repo_dir/.config/starship.toml" "$HOME/.config/starship.toml" "Starship config"
  fi

  if [ -f "$repo_dir/.codex/AGENTS.md" ]; then
    hardlink_managed_file "$repo_dir/.codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "Codex global AGENTS.md"
  fi

  if [ -f "$repo_dir/.tmux.conf" ]; then
    link_managed_path "$repo_dir/.tmux.conf" "$HOME/.tmux.conf" "tmux config"
  fi

  if [ -f "$zshrc_file" ] && ! grep -q '^# zshsetup-managed$' "$zshrc_file" 2>/dev/null; then
    backup="$HOME/.zshrc_backup_$(date +%Y%m%d_%H%M%S).bak"
    echo "install.sh: backing up existing .zshrc to $backup"
    mv "$zshrc_file" "$backup"
  fi

  printf '%s\n%s\n' \
    "$managed_marker" \
    'source "${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}/init.zsh"' \
    > "$zshrc_file"

  regenerate_antidote_files
}

if confirm "Install dependencies for this machine?"; then
  install_deps
fi

if confirm "Configure system timezone?"; then
  configure_timezone
fi

if confirm "Install shell, tmux, Starship, and Neovim config into your home directory?"; then
  install_configs
  echo "install.sh: installed. Open a new shell or run: source ~/.zshrc"
else
  echo "install.sh: skipped config install"
fi
