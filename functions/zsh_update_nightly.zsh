# Install a daily cron job that updates this zsh config repo.
zsh_update_nightly() {
  if (( $# != 0 )); then
    echo "usage: zsh_update_nightly" >&2
    return 2
  fi

  if ! command -v crontab >/dev/null 2>&1; then
    echo "zsh_update_nightly: crontab is not installed or not on PATH" >&2
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "zsh_update_nightly: git is not installed or not on PATH" >&2
    return 1
  fi

  local zsh_bin
  zsh_bin="$(command -v zsh)"
  if [[ -z "$zsh_bin" ]]; then
    echo "zsh_update_nightly: zsh is not installed or not on PATH" >&2
    return 1
  fi

  local marker="# zsh_update_nightly"
  local log_file='$HOME/.zsh_update_nightly.log'
  local cron_line="17 4 * * * $zsh_bin -lc 'git -C \"\${ZSHRC_CONFIG_DIR:-\$HOME/.zshrc_config}\" pull --ff-only' >> \"$log_file\" 2>&1 $marker"
  local tmp_file
  tmp_file="$(mktemp -t zsh_update_nightly.XXXXXX)" || return

  {
    crontab -l 2>/dev/null | grep -vF "$marker" || true
    printf '%s\n' "$cron_line"
  } > "$tmp_file"

  if crontab "$tmp_file"; then
    rm -f "$tmp_file"
    echo "zsh_update_nightly: installed daily cron update"
    echo "zsh_update_nightly: $cron_line"
  else
    local status=$?
    rm -f "$tmp_file"
    return "$status"
  fi
}
