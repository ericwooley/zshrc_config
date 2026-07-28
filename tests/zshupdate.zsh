#!/usr/bin/env zsh

set -eu

repo_root="${0:A:h:h}"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/zshupdate-test.XXXXXX")"
trap 'rm -rf -- "$fixture_root"' EXIT

export HOME="$fixture_root/home"
export ZSHRC_CONFIG_DIR="$fixture_root/config"
export ZSHUPDATE_GIT_LOG="$fixture_root/git.log"
export ZSHUPDATE_INSTALL_LOG="$fixture_root/install.log"
export ZSHUPDATE_SOURCE_LOG="$fixture_root/source.log"

mkdir -p \
  "$HOME" \
  "$ZSHRC_CONFIG_DIR/.git" \
  "$ZSHRC_CONFIG_DIR/.config" \
  "$ZSHRC_CONFIG_DIR/.codex" \
  "$fixture_root/bin"

printf '%s\n' 'starship' > "$ZSHRC_CONFIG_DIR/.config/starship.toml"
printf '%s\n' 'agents' > "$ZSHRC_CONFIG_DIR/.codex/AGENTS.md"
printf '%s\n' 'printf "%s\n" installed > "$ZSHUPDATE_INSTALL_LOG"' \
  > "$ZSHRC_CONFIG_DIR/install.sh"
printf '%s\n' 'printf "%s\n" sourced >> "$ZSHUPDATE_SOURCE_LOG"' \
  > "$HOME/.zshrc"
printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s\n" "$*" >> "$ZSHUPDATE_GIT_LOG"' \
  'exit 0' \
  > "$fixture_root/bin/git"
chmod +x "$fixture_root/bin/git"
export PATH="$fixture_root/bin:$PATH"

source "$repo_root/functions/zshupdate.zsh"

fail() {
  print -u2 -r -- "FAIL: $1"
  return 1
}

assert_file_missing() {
  [[ ! -e "$1" ]] || fail "expected $1 to be absent"
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  grep -F -- "$expected" "$file" >/dev/null ||
    fail "expected $file to contain: $expected"
}

fast_output="$fixture_root/fast-output.log"
if zshupdate --fast </dev/null >"$fast_output" 2>&1; then
  fast_status=0
else
  fast_status=$?
fi

[[ "$fast_status" == 0 ]] ||
  fail "zshupdate --fast exited with $fast_status"
assert_file_missing "$ZSHUPDATE_INSTALL_LOG"
assert_file_contains "$ZSHUPDATE_GIT_LOG" "pull --ff-only"
assert_file_contains "$ZSHUPDATE_SOURCE_LOG" "sourced"
if grep -F -- "run install.sh now?" "$fast_output" >/dev/null; then
  fail "zshupdate --fast asked whether to run install.sh"
fi

rm -f -- "$ZSHUPDATE_SOURCE_LOG"
interactive_output="$fixture_root/interactive-output.log"
zshupdate <<< "y" >"$interactive_output" 2>&1

assert_file_contains "$ZSHUPDATE_INSTALL_LOG" "installed"
assert_file_contains "$ZSHUPDATE_SOURCE_LOG" "sourced"
assert_file_contains "$interactive_output" "run install.sh now?"

invalid_output="$fixture_root/invalid-output.log"
if zshupdate --unexpected >"$invalid_output" 2>&1; then
  invalid_status=0
else
  invalid_status=$?
fi

[[ "$invalid_status" == 2 ]] ||
  fail "invalid option exited with $invalid_status instead of 2"
assert_file_contains "$invalid_output" "usage: zshupdate [--fast]"

print -r -- "PASS: zshupdate"
