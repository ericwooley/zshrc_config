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

darwin_candidates=$(homebrew_candidates_for_os Darwin)
[ "$darwin_candidates" = "$(printf '%s\n' /opt/homebrew/bin/brew /usr/local/bin/brew)" ] \
  || fail "Darwin Homebrew paths are incorrect"

linux_candidates=$(homebrew_candidates_for_os Linux)
[ "$linux_candidates" = "/home/linuxbrew/.linuxbrew/bin/brew" ] \
  || fail "Linux Homebrew path is incorrect"

for fallback_os in Darwin Linux; do
  fallback_root="$test_tmp_dir/fallback-$fallback_os"
  fallback_candidates=$(homebrew_candidates_for_os "$fallback_os" "$fallback_root")
  fallback_brew=$(printf '%s\n' "$fallback_candidates" | sed -n '1p')
  mkdir -p "$(dirname "$fallback_brew")"
  cp "$TEST_BIN_DIR/brew" "$fallback_brew"

  discovered_brew=$(find_homebrew_for_os "$fallback_os" "$fallback_root")
  [ "$discovered_brew" = "$fallback_brew" ] \
    || fail "$fallback_os Homebrew fallback path discovery failed"
done

intel_fallback_root="$test_tmp_dir/fallback-Darwin-intel"
intel_candidates=$(homebrew_candidates_for_os Darwin "$intel_fallback_root")
intel_brew=$(printf '%s\n' "$intel_candidates" | sed -n '2p')
mkdir -p "$(dirname "$intel_brew")"
cp "$TEST_BIN_DIR/brew" "$intel_brew"

discovered_intel_brew=$(find_homebrew_for_os Darwin "$intel_fallback_root")
[ "$discovered_intel_brew" = "$intel_brew" ] \
  || fail "Darwin fallback discovery did not skip a missing first candidate"

install_fastai
grep -Fx 'install ericwooley/apps/fastai' "$TEST_BREW_LOG" >/dev/null \
  || fail "fastAI did not use the Homebrew formula"

printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$TEST_BIN_DIR/apt-get"
chmod +x "$TEST_BIN_DIR/apt-get"

for dependency_os in Darwin Linux; do
  dependency_log="$test_tmp_dir/dependencies-after-homebrew-failure-$dependency_os.log"
  : > "$dependency_log"

  set +e
  (
    set -e

    uname() {
      printf '%s\n' "$dependency_os"
    }

    run_apt() {
      :
    }

    install_homebrew() {
      return 1
    }

    brew() {
      fail "dependency installation continued after Homebrew failed"
    }

    install_neovim_linux_tarball() {
      printf '%s\n' install_neovim_linux_tarball >> "$dependency_log"
    }

    install_eza_apt() {
      printf '%s\n' install_eza_apt >> "$dependency_log"
    }

    install_glow() {
      printf '%s\n' install_glow >> "$dependency_log"
    }

    install_lazygit() {
      printf '%s\n' install_lazygit >> "$dependency_log"
    }

    install_zoxide() {
      printf '%s\n' install_zoxide >> "$dependency_log"
    }

    install_starship() {
      printf '%s\n' install_starship >> "$dependency_log"
    }

    install_n() {
      printf '%s\n' install_n >> "$dependency_log"
    }

    install_fastai() {
      printf '%s\n' install_fastai >> "$dependency_log"
    }

    install_antidote() {
      printf '%s\n' install_antidote >> "$dependency_log"
    }

    set_default_shell_to_zsh() {
      printf '%s\n' set_default_shell_to_zsh >> "$dependency_log"
    }

    maybe_install_multipass() {
      printf '%s\n' maybe_install_multipass >> "$dependency_log"
    }

    install_deps
  )
  dependency_status=$?
  set -e

  [ "$dependency_status" -eq 0 ] \
    || fail "a Homebrew failure prevented later $dependency_os installer steps"

  expected_dependency_log=$(printf '%s\n' \
    install_zoxide \
    install_starship \
    install_n \
    install_fastai \
    install_antidote \
    set_default_shell_to_zsh \
    maybe_install_multipass)
  if [ "$dependency_os" = "Linux" ]; then
    expected_dependency_log=$(printf '%s\n%s\n' \
      "$expected_dependency_log" \
      "$(printf '%s\n' \
        install_neovim_linux_tarball \
        install_eza_apt \
        install_glow \
        install_lazygit)")
  fi

  actual_dependency_log=$(sort "$dependency_log")
  expected_dependency_log=$(printf '%s\n' "$expected_dependency_log" | sort)
  [ "$actual_dependency_log" = "$expected_dependency_log" ] \
    || fail "non-Homebrew $dependency_os dependency steps were skipped after Homebrew failed"
done

ZSHRC_CONFIG_DIR="$test_repo_dir"
export ZSHRC_CONFIG_DIR
unset HOMEBREW_TEST_ACTIVATED
zsh -f -c '
  source "$ZSHRC_CONFIG_DIR/homebrew.zsh"
  [[ "$HOMEBREW_TEST_ACTIVATED" == "1" ]]
' || fail "managed zsh startup did not activate Homebrew"

echo "install-homebrew test: passed"
