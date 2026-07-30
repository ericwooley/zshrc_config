#!/usr/bin/env zsh

set -eu

repo_root="${0:A:h:h}"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/tmr-test.XXXXXX")"
trap 'rm -rf -- "$fixture_root"' EXIT

export TMR_TEST_LOG="$fixture_root/tmux.log"
export TMR_FZF_LOG="$fixture_root/fzf.log"
export TMR_FZF_CHOICE="Attach: beta"
export TMUX=""

mkdir -p "$fixture_root/bin"

printf '%s\n' \
  '#!/bin/sh' \
  'set -eu' \
  'printf "%s\n" "$*" >> "$TMR_TEST_LOG"' \
  'if [ "${1:-}" = "list-sessions" ]; then' \
  '  printf "%s\n" alpha beta' \
  'fi' \
  > "$fixture_root/bin/tmux"

printf '%s\n' \
  '#!/bin/sh' \
  'set -eu' \
  'sed -n "p" > "$TMR_FZF_LOG"' \
  'printf "%s\n" "$TMR_FZF_CHOICE"' \
  > "$fixture_root/bin/fzf"

chmod +x "$fixture_root/bin/tmux" "$fixture_root/bin/fzf"
export PATH="$fixture_root/bin:$PATH"

source "$repo_root/functions/tmr.zsh"

fail() {
  print -u2 -r -- "FAIL: $1"
  return 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  grep -Fx -- "$expected" "$file" >/dev/null ||
    fail "expected $file to contain: $expected"
}

assert_file_missing_line() {
  local file="$1"
  local unexpected="$2"

  if grep -Fx -- "$unexpected" "$file" >/dev/null 2>&1; then
    fail "expected $file not to contain: $unexpected"
  fi
}

assert_file_line_count() {
  local file="$1"
  local expected="$2"
  local line="$3"
  local actual

  actual="$(grep -Fxc -- "$line" "$file" || true)"
  [[ "$actual" == "$expected" ]] ||
    fail "expected $file to contain $expected copies of '$line', found $actual"
}

tmr
assert_file_contains "$TMR_FZF_LOG" "Attach: alpha"
assert_file_contains "$TMR_FZF_LOG" "Attach: beta"
assert_file_contains "$TMR_FZF_LOG" "Create a new session"
assert_file_contains "$TMR_TEST_LOG" "new-session -A -s beta"

: > "$TMR_TEST_LOG"
: > "$TMR_FZF_LOG"
export TMR_FZF_CHOICE="Create a new session"
tmr <<< "feature:work"
assert_file_contains "$TMR_TEST_LOG" "new-session -A -s feature_work"

: > "$TMR_TEST_LOG"
: > "$TMR_FZF_LOG"
tmr explicit
assert_file_contains "$TMR_TEST_LOG" "new-session -A -s explicit"
[[ ! -s "$TMR_FZF_LOG" ]] ||
  fail "tmr with an explicit session unexpectedly opened the picker"

: > "$TMR_TEST_LOG"
export TMR_FZF_CHOICE="Attach: alpha"
TMUX="/tmp/tmux-test" tmr
assert_file_contains "$TMR_TEST_LOG" "has-session -t =alpha"
assert_file_contains "$TMR_TEST_LOG" "switch-client -t =alpha"
assert_file_missing_line "$TMR_TEST_LOG" "new-session -A -s alpha"

: > "$TMR_TEST_LOG"
export ZSHRC_CONFIG_DIR="$repo_root"
export SSH_TTY="/dev/pts/test"
unset TMUX
unset ZSHRC_SSH_TMUX_PROMPTED
zsh -fic '
  source "$ZSHRC_CONFIG_DIR/functions/init.zsh"
  zsh -fic "source \"$ZSHRC_CONFIG_DIR/functions/init.zsh\""
  source "$ZSHRC_CONFIG_DIR/functions/init.zsh"
'
assert_file_line_count "$TMR_TEST_LOG" 1 "new-session -A -s alpha"

print -r -- "PASS: tmr"
