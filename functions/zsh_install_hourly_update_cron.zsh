# Install an hourly cron job that updates this zsh config repo.
zsh_install_hourly_update_cron() {
  if (( $# != 0 )); then
    echo "usage: zsh_install_hourly_update_cron" >&2
    return 2
  fi

  if ! command -v crontab >/dev/null 2>&1; then
    echo "zsh_install_hourly_update_cron: crontab is not installed or not on PATH" >&2
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "zsh_install_hourly_update_cron: git is not installed or not on PATH" >&2
    return 1
  fi

  local zsh_bin
  zsh_bin="$(command -v zsh)"
  if [[ -z "$zsh_bin" ]]; then
    echo "zsh_install_hourly_update_cron: zsh is not installed or not on PATH" >&2
    return 1
  fi

  local begin_marker="# zsh_install_hourly_update_cron begin"
  local end_marker="# zsh_install_hourly_update_cron end"
  local old_begin_marker="# zsh_install_nightly_update_cron begin"
  local old_end_marker="# zsh_install_nightly_update_cron end"
  local older_begin_marker="# zsh_update_nightly begin"
  local older_end_marker="# zsh_update_nightly end"
  local older_line_marker="# zsh_update_nightly"
  local log_file='$HOME/.zsh_install_hourly_update_cron.log'
  local cron_line="0 * * * * $zsh_bin -lc 'git -C \"\${ZSHRC_CONFIG_DIR:-\$HOME/.zshrc_config}\" pull --ff-only' >> \"$log_file\" 2>&1"
  local tmp_file
  tmp_file="$(mktemp -t zsh_install_hourly_update_cron.XXXXXX)" || return

  {
    crontab -l 2>/dev/null \
      | awk \
          -v begin="$begin_marker" \
          -v end="$end_marker" \
          -v old_begin="$old_begin_marker" \
          -v old_end="$old_end_marker" \
          -v older_begin="$older_begin_marker" \
          -v older_end="$older_end_marker" '
          $0 == begin || $0 == old_begin || $0 == older_begin { skip = 1; next }
          $0 == end || $0 == old_end || $0 == older_end { skip = 0; next }
          !skip { print }
        ' \
      | grep -vF "$older_line_marker" || true
    printf '%s\n%s\n%s\n' "$begin_marker" "$cron_line" "$end_marker"
  } > "$tmp_file"

  if crontab "$tmp_file"; then
    rm -f "$tmp_file"
    echo "zsh_install_hourly_update_cron: installed hourly cron update"
    echo "zsh_install_hourly_update_cron: schedule: minute 00 every hour"
    echo "zsh_install_hourly_update_cron: log: ~/.zsh_install_hourly_update_cron.log"
  else
    local command_status=$?
    rm -f "$tmp_file"
    return "$command_status"
  fi
}
