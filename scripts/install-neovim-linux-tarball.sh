#!/usr/bin/env sh
set -eu

# Install or update the latest stable Neovim Linux tarball from the official
# GitHub release channel. This avoids old distro packages on Ubuntu/Debian.

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "install-neovim-linux-tarball: sudo is required for: $*" >&2
    return 1
  fi
}

case "$(uname -s)" in
  Linux) ;;
  *)
    echo "install-neovim-linux-tarball: this installer only supports Linux" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64)
    package_name="nvim-linux-x86_64"
    ;;
  aarch64|arm64)
    package_name="nvim-linux-arm64"
    ;;
  *)
    echo "install-neovim-linux-tarball: unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "install-neovim-linux-tarball: curl is required" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "install-neovim-linux-tarball: tar is required" >&2
  exit 1
fi

archive_name="$package_name.tar.gz"
download_url="https://github.com/neovim/neovim/releases/latest/download/$archive_name"
tmp_dir=$(mktemp -d)

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

echo "install-neovim-linux-tarball: downloading $download_url"
curl -fsSL "$download_url" -o "$tmp_dir/$archive_name"
tar -C "$tmp_dir" -xzf "$tmp_dir/$archive_name"

if [ ! -x "$tmp_dir/$package_name/bin/nvim" ]; then
  echo "install-neovim-linux-tarball: downloaded archive did not contain $package_name/bin/nvim" >&2
  exit 1
fi

run_root mkdir -p /opt /usr/local/bin
run_root rm -rf "/opt/$package_name"
run_root tar -C /opt -xzf "$tmp_dir/$archive_name"
run_root ln -sfn "/opt/$package_name/bin/nvim" /usr/local/bin/nvim

echo "install-neovim-linux-tarball: installed /usr/local/bin/nvim"
/usr/local/bin/nvim --version | sed -n '1p'
