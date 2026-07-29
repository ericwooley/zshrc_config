#!/usr/bin/env sh
set -eu

test_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_tmp_dir=$(mktemp -d)
trap 'rm -rf "$test_tmp_dir"' EXIT HUP INT TERM

export HOME="$test_tmp_dir/home"
export ZSHRC_CONFIG_DIR="$test_repo_dir"
export ZSHRC_INSTALL_SOURCE_ONLY=1
mkdir -p "$HOME"

. "$test_repo_dir/install.sh"

fail() {
  echo "install-crontab test: $*" >&2
  exit 1
}

install_log="$test_tmp_dir/install.log"

install_deps() {
  :
}

configure_timezone() {
  :
}

install_configs() {
  :
}

install_zsh_update_cron() {
  printf '%s\n' installed >> "$install_log"
}

accepted_output=$(
  main <<'EOF'
n
n
n
y
EOF
)

grep -F "Install the 10-minute zsh config update cron?" <<EOF >/dev/null \
  || fail "installer did not ask about the zsh update cron"
$accepted_output
EOF

[ "$(wc -l < "$install_log" | tr -d ' ')" = "1" ] \
  || fail "installer did not install the accepted zsh update cron exactly once"

rm -f "$install_log"

declined_output=$(
  main <<'EOF'
n
n
n
n
EOF
)

[ ! -e "$install_log" ] \
  || fail "installer installed the declined zsh update cron"

grep -F "install.sh: skipped 10-minute zsh config update cron" <<EOF >/dev/null \
  || fail "installer did not report the skipped zsh update cron"
$declined_output
EOF

fake_bin_dir="$test_tmp_dir/bin"
zsh_log="$test_tmp_dir/zsh.log"
mkdir -p "$fake_bin_dir"

cat > "$fake_bin_dir/zsh" <<'EOF'
#!/usr/bin/env sh
set -eu

printf 'config=%s\n' "$ZSHRC_CONFIG_DIR" > "$INSTALL_CRONTAB_ZSH_LOG"
printf 'arg=%s\n' "$@" >> "$INSTALL_CRONTAB_ZSH_LOG"
EOF
chmod +x "$fake_bin_dir/zsh"

INSTALL_CRONTAB_ZSH_LOG="$zsh_log"
export INSTALL_CRONTAB_ZSH_LOG
PATH="$fake_bin_dir:/usr/bin:/bin"
export PATH

sh -c '. "$0"; install_zsh_update_cron' "$test_repo_dir/install.sh"

grep -Fx "config=$test_repo_dir" "$zsh_log" >/dev/null \
  || fail "cron installer did not pass the managed config directory to zsh"
grep -Fx 'arg=-f' "$zsh_log" >/dev/null \
  || fail "cron installer did not isolate zsh startup files"
grep -F 'zsh_install_hourly_update_cron' "$zsh_log" >/dev/null \
  || fail "cron installer did not invoke the zsh update cron helper"

if grep -F "install 10-minute zshupdate cron on this remote?" \
  "$test_repo_dir/functions/zshsetup.zsh" >/dev/null; then
  fail "zshsetup still contains a duplicate zsh update cron prompt"
fi

echo "install-crontab test: passed"
