#!/bin/sh
# Remote helper for zshsetup.
# This script only runs when the zshsetup function copies it to an SSH host and
# invokes a phase explicitly. Sourcing local zsh config or opening files never
# runs this bootstrap logic.

set -eu

phase="${1:-}"
if [ "$phase" != "prepare" ] && [ "$phase" != "finalize" ]; then
  echo "usage: zshsetup-remote.sh prepare|finalize" >&2
  exit 2
fi

export N_PREFIX="${N_PREFIX:-$HOME/.local/n}"
export PATH="$N_PREFIX/bin:$HOME/.local/bin:$PATH"

setup_status=0

apt_command_preview() {
  if [ "$(id -u)" -eq 0 ]; then
    printf 'DEBIAN_FRONTEND=noninteractive apt-get %s\n' "$*"
  elif command -v sudo >/dev/null 2>&1; then
    printf 'sudo env DEBIAN_FRONTEND=noninteractive apt-get %s\n' "$*"
  else
    printf 'apt-get %s # requires root or sudo\n' "$*"
  fi
}

root_command_preview() {
  if [ "$(id -u)" -eq 0 ]; then
    printf '%s\n' "$*"
  elif command -v sudo >/dev/null 2>&1; then
    printf 'sudo %s\n' "$*"
  else
    printf '%s # requires root or sudo\n' "$*"
  fi
}

confirm_commands() {
  label="$1"
  shift

  echo
  echo "zshsetup: $label"
  echo "zshsetup: commands to run:"
  for command_preview in "$@"; do
    printf '  %s\n' "$command_preview"
  done

  printf 'Run this step? [y/N] '
  if ! read answer; then
    answer=""
  fi

  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      echo "zshsetup: skipped $label"
      return 1
      ;;
  esac
}

run_apt() {
  if [ "$(id -u)" -eq 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"
  else
    return 1
  fi
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

backup_existing_zshrc() {
  if [ -f "$HOME/.zshrc" ] && ! grep -q '^# zshsetup-managed$' "$HOME/.zshrc" 2>/dev/null; then
    backup_path="$HOME/.zshrc_backup_$(date +%Y%m%d_%H%M%S).bak"
    echo "zshsetup: backing up existing remote .zshrc to $backup_path"
    mv "$HOME/.zshrc" "$backup_path"
  fi
}

prepare_remote() {
  can_use_apt=0
  if command -v apt-get >/dev/null 2>&1 && [ -r /etc/os-release ]; then
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *" debian "*|*" ubuntu "*) can_use_apt=1 ;;
    esac
  fi

  apt_packages=""
  add_missing_package() {
    command_name="$1"
    package_name="$2"

    if ! command -v "$command_name" >/dev/null 2>&1; then
      apt_packages="${apt_packages:+$apt_packages }$package_name"
    fi
  }

  if [ "$can_use_apt" -eq 1 ]; then
    add_missing_package zsh zsh
    add_missing_package bash bash
    add_missing_package git git
    add_missing_package curl curl
    add_missing_package gpg gpg
    add_missing_package tar tar
    add_missing_package tmux tmux
    add_missing_package fzf fzf
    add_missing_package rg ripgrep
    if [ "${ID:-}" = "ubuntu" ]; then
      add_missing_package add-apt-repository software-properties-common
    fi

    if [ -n "$apt_packages" ]; then
      apt_packages="$apt_packages ca-certificates"
      if confirm_commands \
        "install apt packages:$apt_packages" \
        "$(apt_command_preview update)" \
        "$(apt_command_preview install -y $apt_packages)"; then
        if run_apt update && run_apt install -y $apt_packages; then
          echo "zshsetup: apt package install complete"
        else
          echo "zshsetup: warning: could not install apt packages automatically; install manually:$apt_packages" >&2
          setup_status=1
        fi
      fi
    fi

    if ! command -v eza >/dev/null 2>&1; then
      if confirm_commands \
        "install eza from deb.gierens.de" \
        "rm -f \"$HOME/.eza-deb.asc\" \"$HOME/.eza-gierens.gpg\" \"$HOME/.eza-gierens.list\"" \
        "curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc -o \"$HOME/.eza-deb.asc\"" \
        "gpg --batch --yes --dearmor -o \"$HOME/.eza-gierens.gpg\" \"$HOME/.eza-deb.asc\"" \
        "printf '%s\\n' 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' > \"$HOME/.eza-gierens.list\"" \
        "$(root_command_preview mkdir -p /etc/apt/keyrings)" \
        "$(root_command_preview mv "$HOME/.eza-gierens.gpg" /etc/apt/keyrings/gierens.gpg)" \
        "$(root_command_preview mv "$HOME/.eza-gierens.list" /etc/apt/sources.list.d/gierens.list)" \
        "$(root_command_preview chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list)" \
        "$(apt_command_preview update)" \
        "$(apt_command_preview install -y eza)" \
        "rm -f \"$HOME/.eza-deb.asc\" \"$HOME/.eza-gierens.gpg\" \"$HOME/.eza-gierens.list\""; then
        rm -f "$HOME/.eza-deb.asc" "$HOME/.eza-gierens.gpg" "$HOME/.eza-gierens.list"
        if curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc -o "$HOME/.eza-deb.asc" \
          && gpg --batch --yes --dearmor -o "$HOME/.eza-gierens.gpg" "$HOME/.eza-deb.asc" \
          && printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' > "$HOME/.eza-gierens.list" \
          && run_root mkdir -p /etc/apt/keyrings \
          && run_root mv "$HOME/.eza-gierens.gpg" /etc/apt/keyrings/gierens.gpg \
          && run_root mv "$HOME/.eza-gierens.list" /etc/apt/sources.list.d/gierens.list \
          && run_root chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list \
          && run_apt update \
          && run_apt install -y eza; then
          echo "zshsetup: eza install complete"
        else
          echo "zshsetup: warning: could not install eza automatically; install it manually from https://github.com/eza-community/eza/blob/main/INSTALL.md" >&2
          setup_status=1
        fi
        rm -f "$HOME/.eza-deb.asc" "$HOME/.eza-gierens.gpg" "$HOME/.eza-gierens.list"
      fi
    fi
  else
    echo "zshsetup: warning: remote is not a Debian/Ubuntu apt host; install zsh bash git curl gpg tar tmux fzf ripgrep manually" >&2
    setup_status=1
  fi

  if command -v nvim >/dev/null 2>&1; then
    echo "zshsetup: Neovim already installed: $(nvim --version | sed -n '1p')"
  elif [ "${ID:-}" = "ubuntu" ]; then
    if grep -Rqs 'neovim-ppa' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      if confirm_commands \
        "install Neovim from existing apt sources" \
        "$(apt_command_preview update)" \
        "$(apt_command_preview install -y neovim)"; then
        if run_apt update && run_apt install -y neovim; then
          echo "zshsetup: Neovim install complete: $(nvim --version | sed -n '1p')"
        else
          echo "zshsetup: warning: Neovim apt install failed; install it manually" >&2
          setup_status=1
        fi
      fi
    else
      if confirm_commands \
        "install Neovim from ppa:neovim-ppa/stable" \
        "$(root_command_preview add-apt-repository -y ppa:neovim-ppa/stable)" \
        "$(apt_command_preview update)" \
        "$(apt_command_preview install -y neovim)"; then
        if run_root add-apt-repository -y ppa:neovim-ppa/stable && run_apt update && run_apt install -y neovim; then
          echo "zshsetup: Neovim install complete: $(nvim --version | sed -n '1p')"
        else
          echo "zshsetup: warning: Neovim PPA install failed; install it manually with add-apt-repository ppa:neovim-ppa/stable" >&2
          setup_status=1
        fi
      fi
    fi
  elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    nvim_arch=""
    case "$(uname -m)" in
      x86_64|amd64) nvim_arch="x86_64" ;;
      aarch64|arm64) nvim_arch="arm64" ;;
    esac

    if [ -n "$nvim_arch" ]; then
      nvim_tmp="$(mktemp -d)"
      nvim_asset="nvim-linux-${nvim_arch}.tar.gz"
      nvim_dir="nvim-linux-${nvim_arch}"

      if confirm_commands \
        "install latest Neovim release" \
        "curl -fsSL \"https://github.com/neovim/neovim/releases/latest/download/$nvim_asset\" -o \"$nvim_tmp/$nvim_asset\"" \
        "tar -xzf \"$nvim_tmp/$nvim_asset\" -C \"$nvim_tmp\"" \
        "mkdir -p \"$HOME/.local/bin\"" \
        "rm -rf \"$HOME/.local/nvim\"" \
        "mv \"$nvim_tmp/$nvim_dir\" \"$HOME/.local/nvim\"" \
        "ln -sfn \"$HOME/.local/nvim/bin/nvim\" \"$HOME/.local/bin/nvim\"" \
        "rm -rf \"$nvim_tmp\""; then
        if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$nvim_asset" -o "$nvim_tmp/$nvim_asset" \
          && tar -xzf "$nvim_tmp/$nvim_asset" -C "$nvim_tmp" \
          && mkdir -p "$HOME/.local/bin" \
          && rm -rf "$HOME/.local/nvim" \
          && mv "$nvim_tmp/$nvim_dir" "$HOME/.local/nvim" \
          && ln -sfn "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"; then
          export PATH="$HOME/.local/bin:$PATH"
          echo "zshsetup: Neovim install complete: $(nvim --version | sed -n '1p')"
        else
          echo "zshsetup: warning: latest Neovim install failed; install it manually from https://github.com/neovim/neovim/releases/latest" >&2
          setup_status=1
        fi
      fi

      rm -rf "$nvim_tmp"
    else
      echo "zshsetup: warning: unsupported Neovim release architecture: $(uname -m)" >&2
      setup_status=1
    fi
  else
    echo "zshsetup: warning: curl or tar is missing, so latest Neovim could not be installed" >&2
    setup_status=1
  fi

  if ! command -v n >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1 && command -v bash >/dev/null 2>&1; then
      if confirm_commands \
        "install n and Node LTS" \
        "mkdir -p \"$N_PREFIX/bin\"" \
        "curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o \"$N_PREFIX/bin/n\"" \
        "chmod +x \"$N_PREFIX/bin/n\"" \
        "N_PREFIX=\"$N_PREFIX\" \"$N_PREFIX/bin/n\" install lts"; then
        mkdir -p "$N_PREFIX/bin"
        if curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$N_PREFIX/bin/n" \
          && chmod +x "$N_PREFIX/bin/n" \
          && N_PREFIX="$N_PREFIX" "$N_PREFIX/bin/n" install lts; then
          export PATH="$N_PREFIX/bin:$PATH"
          if command -v n >/dev/null 2>&1; then
            echo "zshsetup: n install complete"
          else
            echo "zshsetup: warning: n installer finished, but n is not on PATH" >&2
            setup_status=1
          fi
        else
          echo "zshsetup: warning: n installer failed; install it manually with: curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s install lts" >&2
          setup_status=1
        fi
      fi
    else
      echo "zshsetup: warning: curl or bash is missing, so n could not be installed; install it manually" >&2
      setup_status=1
    fi
  fi

  if command -v n >/dev/null 2>&1; then
    n_path="$(command -v n)"
    n_realpath="$n_path"
    if command -v readlink >/dev/null 2>&1; then
      n_realpath="$(readlink -f "$n_path" 2>/dev/null || printf '%s' "$n_path")"
    fi

    n_needs_chown=0
    if [ -n "$n_realpath" ] && [ -e "$n_realpath" ] && [ ! -w "$n_realpath" ]; then
      n_needs_chown=1
    fi
    if [ "$n_path" != "$N_PREFIX/bin/n" ] && [ -d /usr/local/n ] && [ ! -w /usr/local/n ]; then
      n_needs_chown=1
    fi

  if [ "$n_needs_chown" -eq 1 ]; then
      if confirm_commands \
        "repair n ownership" \
        "$(root_command_preview chown -R "$(id -un)" "$n_realpath" /usr/local/lib/node_modules/n /usr/local/n /usr/local/bin/n)"; then
        n_chown_failed=0
        for n_owned_path in "$n_realpath" /usr/local/lib/node_modules/n /usr/local/n /usr/local/bin/n; do
          if [ -e "$n_owned_path" ] || [ -L "$n_owned_path" ]; then
            run_root chown -R "$(id -un)" "$n_owned_path" || n_chown_failed=1
          fi
        done

        if [ "$n_chown_failed" -eq 0 ]; then
          echo "zshsetup: n ownership repaired"
        else
          echo "zshsetup: warning: could not repair n ownership; try: sudo chown -R $(id -un) /usr/local/lib/node_modules/n /usr/local/n /usr/local/bin/n" >&2
          setup_status=1
        fi
      fi
    fi
  fi

  if ! command -v zoxide >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      if confirm_commands \
        "install zoxide" \
        "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"; then
        if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
          export PATH="$HOME/.local/bin:$PATH"
          if command -v zoxide >/dev/null 2>&1; then
            echo "zshsetup: zoxide install complete"
          else
            echo "zshsetup: warning: zoxide installer finished, but zoxide is not on PATH" >&2
            setup_status=1
          fi
        else
          echo "zshsetup: warning: zoxide installer failed; install it manually with: curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh" >&2
          setup_status=1
        fi
      fi
    else
      echo "zshsetup: warning: curl is missing, so zoxide could not be installed; install it manually" >&2
      setup_status=1
    fi
  fi

  if ! command -v starship >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      if confirm_commands \
        "install starship" \
        "curl -sS https://starship.rs/install.sh | sh -s -- -y"; then
        if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
          echo "zshsetup: starship install complete"
        else
          echo "zshsetup: warning: starship installer failed; install it manually with: curl -sS https://starship.rs/install.sh | sh -" >&2
          setup_status=1
        fi
      fi
    else
      echo "zshsetup: warning: curl is missing, so starship could not be installed; install it manually" >&2
      setup_status=1
    fi
  fi

  backup_existing_zshrc
  mkdir -p "$HOME/.zshrc_config" "$HOME/.config"
}

finalize_remote() {
  missing_required=""
  missing_optional=""

  check_required() {
    if command -v "$1" >/dev/null 2>&1; then
      echo "zshsetup: remote $1 OK"
    else
      echo "zshsetup: warning: remote $1 is missing; install it manually" >&2
      missing_required="${missing_required:+$missing_required }$1"
      setup_status=1
    fi
  }

  check_optional() {
    if command -v "$1" >/dev/null 2>&1; then
      echo "zshsetup: remote $1 OK"
    else
      echo "zshsetup: warning: remote $1 is missing; install it manually if you want matching behavior" >&2
      missing_optional="${missing_optional:+$missing_optional }$1"
      setup_status=1
    fi
  }

  check_required zsh
  check_required bash
  check_required git
  check_required curl
  check_required nvim
  check_required tmux
  check_required fzf
  check_required rg
  check_required zoxide
  check_required eza
  check_required n
  check_required node

  if ! command -v zsh >/dev/null 2>&1; then
    echo "zshsetup: remote zsh is required before zshsetup can validate the copied config" >&2
    exit 1
  fi

  if command -v nvim >/dev/null 2>&1; then
    echo "zshsetup: remote nvim OK: $(nvim --version | sed -n '1p')"
  fi

  antidote_source=""
  if command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    if [ -n "$brew_prefix" ] && [ -r "$brew_prefix/opt/antidote/share/antidote/antidote.zsh" ]; then
      antidote_source="$brew_prefix/opt/antidote/share/antidote/antidote.zsh"
    fi
  fi

  if [ -z "$antidote_source" ] && [ -r "$HOME/.antidote/antidote.zsh" ]; then
    antidote_source="$HOME/.antidote/antidote.zsh"
  fi

  if [ -z "$antidote_source" ]; then
    if ! command -v git >/dev/null 2>&1; then
      echo "zshsetup: warning: remote antidote is missing, and git is missing; install git manually, then rerun zshsetup" >&2
      exit 1
    fi

    if confirm_commands \
      "install remote antidote into ~/.antidote" \
      "git clone --depth=1 https://github.com/mattmc3/antidote.git \"$HOME/.antidote\""; then
      git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
      antidote_source="$HOME/.antidote/antidote.zsh"
    else
      echo "zshsetup: warning: remote antidote is missing; skipped install" >&2
      setup_status=1
      return
    fi
  fi

  echo "zshsetup: remote antidote OK: $antidote_source"

  zsh -lc '
    set -e
    export ZSHRC_CONFIG_DIR="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"

    antidote_source=""
    if command -v brew >/dev/null 2>&1; then
      brew_prefix="$(brew --prefix 2>/dev/null || true)"
      if [[ -n "$brew_prefix" && -r "$brew_prefix/opt/antidote/share/antidote/antidote.zsh" ]]; then
        antidote_source="$brew_prefix/opt/antidote/share/antidote/antidote.zsh"
      fi
    fi

    if [[ -z "$antidote_source" && -r "$HOME/.antidote/antidote.zsh" ]]; then
      antidote_source="$HOME/.antidote/antidote.zsh"
    fi

    source "$antidote_source"
    antidote bundle < "$ZSHRC_CONFIG_DIR/plugins_pre.txt" > "$ZSHRC_CONFIG_DIR/plugins_pre.zsh"
    antidote bundle < "$ZSHRC_CONFIG_DIR/plugins_post.txt" > "$ZSHRC_CONFIG_DIR/plugins_post.zsh"
    source "$HOME/.zshrc"
  '

  if command -v nvim >/dev/null 2>&1; then
    if confirm_commands \
      "sync Neovim plugins" \
      "nvim --headless -i NONE '+Lazy! sync' +qa" \
      "nvim --headless -i NONE +qa"; then
      if nvim --headless -i NONE "+Lazy! sync" +qa; then
        echo "zshsetup: Neovim plugins synced"
      else
        echo "zshsetup: warning: Neovim plugin sync failed" >&2
        setup_status=1
      fi

      if ! nvim --headless -i NONE +qa; then
        echo "zshsetup: warning: Neovim failed to start cleanly after plugin sync" >&2
        setup_status=1
      fi
    fi
  fi

  if [ -n "$missing_required" ]; then
    echo "zshsetup: required remote tools missing: $missing_required" >&2
  fi

  if [ -n "$missing_optional" ]; then
    echo "zshsetup: optional remote tools missing: $missing_optional" >&2
  fi
}

case "$phase" in
  prepare) prepare_remote ;;
  finalize) finalize_remote ;;
esac

exit "$setup_status"
