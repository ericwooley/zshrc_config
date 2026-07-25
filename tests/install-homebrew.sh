#!/usr/bin/env sh
set -eu

test_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_tmp_dir=$(mktemp -d)
trap 'rm -rf "$test_tmp_dir"' EXIT HUP INT TERM

export ZSHRC_INSTALL_SOURCE_ONLY=1
. "$test_repo_dir/install.sh"

fail() {
  echo "install-homebrew test: $*" >&2
  exit 1
}

write_fake_curl() {
  fake_bin_dir="$1"

  cat > "$fake_bin_dir/curl" <<'FAKE_CURL'
#!/usr/bin/env sh
set -eu

output_file=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_file="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[ -n "$output_file" ]

cat > "$output_file" <<'FAKE_INSTALLER'
#!/usr/bin/env bash
set -eu

cat > "$TEST_BIN_DIR/brew" <<'FAKE_BREW'
#!/usr/bin/env sh
set -eu

case "${1:-}" in
  shellenv)
    printf '%s\n' \
      "export HOMEBREW_TEST_ACTIVATED=1" \
      "export PATH=\"$TEST_BIN_DIR:\$PATH\""
    ;;
  --prefix)
    printf '%s\n' "$TEST_BIN_DIR"
    ;;
  *)
    printf '%s\n' "$*" >> "$TEST_BREW_LOG"
    ;;
esac
FAKE_BREW

chmod +x "$TEST_BIN_DIR/brew"
printf '%s\n' installed >> "$TEST_INSTALL_LOG"
FAKE_INSTALLER
FAKE_CURL

  chmod +x "$fake_bin_dir/curl"
}

run_install_case() {
  TEST_OS="$1"
  case_dir="$test_tmp_dir/$TEST_OS"
  TEST_BIN_DIR="$case_dir/bin"
  TEST_BREW_LOG="$case_dir/brew.log"
  TEST_INSTALL_LOG="$case_dir/install.log"
  export TEST_BIN_DIR TEST_BREW_LOG TEST_INSTALL_LOG

  mkdir -p "$TEST_BIN_DIR"
  : > "$TEST_BREW_LOG"
  : > "$TEST_INSTALL_LOG"
  write_fake_curl "$TEST_BIN_DIR"

  PATH="$TEST_BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
  export PATH
  unset HOMEBREW_TEST_ACTIVATED

  uname() {
    printf '%s\n' "$TEST_OS"
  }

  find_homebrew() {
    command -v brew
  }

  install_homebrew

  [ "${HOMEBREW_TEST_ACTIVATED:-}" = "1" ] \
    || fail "$TEST_OS did not activate Homebrew"
  [ "$(wc -l < "$TEST_INSTALL_LOG" | tr -d ' ')" = "1" ] \
    || fail "$TEST_OS did not run the installer exactly once"

  install_homebrew
  [ "$(wc -l < "$TEST_INSTALL_LOG" | tr -d ' ')" = "1" ] \
    || fail "$TEST_OS reinstalled an existing Homebrew"
}

run_install_case Darwin
run_install_case Linux

install_fastai
grep -Fx 'install ericwooley/apps/fastai' "$TEST_BREW_LOG" >/dev/null \
  || fail "fastAI did not use the Homebrew formula"

ZSHRC_CONFIG_DIR="$test_repo_dir"
export ZSHRC_CONFIG_DIR
unset HOMEBREW_TEST_ACTIVATED
zsh -f -c '
  source "$ZSHRC_CONFIG_DIR/homebrew.zsh"
  [[ "$HOMEBREW_TEST_ACTIVATED" == "1" ]]
' || fail "managed zsh startup did not activate Homebrew"

echo "install-homebrew test: passed"
