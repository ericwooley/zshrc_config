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

  local detected_tz="${TZ:-}"
  if [[ -z "$detected_tz" && -r /etc/timezone ]]; then
    detected_tz="$(</etc/timezone)"
  fi
  if [[ -z "$detected_tz" && -L /etc/localtime ]]; then
    detected_tz="$(readlink /etc/localtime)"
    detected_tz="${detected_tz##*/zoneinfo/}"
  fi
  if [[ -z "$detected_tz" ]]; then
    detected_tz="America/Denver"
  fi

  local -a tz_choices=(
    "$detected_tz"
    America/Denver
    America/Los_Angeles
    America/Chicago
    America/New_York
    UTC
  )
  local -a unique_tz_choices=()
  local choice
  for choice in "${tz_choices[@]}"; do
    if (( ${unique_tz_choices[(Ie)$choice]} == 0 )); then
      unique_tz_choices+=("$choice")
    fi
  done

  echo "Choose the timezone for the daily update:"
  local idx now_label
  for idx in {1..${#unique_tz_choices[@]}}; do
    choice="${unique_tz_choices[$idx]}"
    printf '  %d) %s' "$idx" "$choice"
    now_label="$(TZ="$choice" date '+%Z, now %H:%M' 2>/dev/null)" || now_label=""
    if [[ -n "$now_label" ]]; then
      printf ' (%s)\n' "$now_label"
    else
      printf '\n'
    fi
  done

  local tz_answer selected_tz
  printf 'Timezone [1]: '
  read -r tz_answer
  if [[ -z "$tz_answer" ]]; then
    selected_tz="${unique_tz_choices[1]}"
  elif [[ "$tz_answer" == <-> && "$tz_answer" -ge 1 && "$tz_answer" -le ${#unique_tz_choices[@]} ]]; then
    selected_tz="${unique_tz_choices[$tz_answer]}"
  else
    selected_tz="$tz_answer"
  fi

  if ! TZ="$selected_tz" date +%Z >/dev/null 2>&1; then
    echo "zsh_update_nightly: invalid timezone: $selected_tz" >&2
    return 1
  fi

  local selected_hour
  while true; do
    printf 'Daily update hour in %s (0-23) [4]: ' "$selected_tz"
    read -r selected_hour
    selected_hour="${selected_hour:-4}"

    if [[ "$selected_hour" == <-> && "$selected_hour" -ge 0 && "$selected_hour" -le 23 ]]; then
      break
    fi

    echo "zsh_update_nightly: use an hour from 0 to 23" >&2
  done

  local hour="$selected_hour"
  local minute=0
  local begin_marker="# zsh_update_nightly begin"
  local end_marker="# zsh_update_nightly end"
  local old_marker="# zsh_update_nightly"
  local log_file='$HOME/.zsh_update_nightly.log'
  local cron_line="$minute $hour * * * $zsh_bin -lc 'git -C \"\${ZSHRC_CONFIG_DIR:-\$HOME/.zshrc_config}\" pull --ff-only' >> \"$log_file\" 2>&1"
  local tmp_file
  tmp_file="$(mktemp -t zsh_update_nightly.XXXXXX)" || return

  {
    crontab -l 2>/dev/null \
      | awk -v begin="$begin_marker" -v end="$end_marker" '
          $0 == begin { skip = 1; next }
          $0 == end { skip = 0; next }
          !skip { print }
        ' \
      | grep -vF "$old_marker" || true
    printf '%s\nCRON_TZ=%s\n%s\n%s\n' "$begin_marker" "$selected_tz" "$cron_line" "$end_marker"
  } > "$tmp_file"

  if crontab "$tmp_file"; then
    rm -f "$tmp_file"
    echo "zsh_update_nightly: installed daily cron update"
    echo "zsh_update_nightly: timezone: $selected_tz"
    echo "zsh_update_nightly: time: ${hour}:00"
    echo "zsh_update_nightly: log: ~/.zsh_update_nightly.log"
  else
    local status=$?
    rm -f "$tmp_file"
    return "$status"
  fi
}
