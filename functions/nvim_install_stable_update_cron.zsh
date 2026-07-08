# Install a nightly root cron job that refreshes the stable Neovim Linux tarball.
nvim_install_stable_update_cron() {
  if (( $# != 0 )); then
    echo "usage: nvim_install_stable_update_cron" >&2
    return 2
  fi

  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "nvim_install_stable_update_cron: only Linux uses the Neovim tarball installer" >&2
    return 1
  fi

  local repo_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local installer="$repo_dir/scripts/install-neovim-linux-tarball.sh"

  if [[ ! -r "$installer" ]]; then
    echo "nvim_install_stable_update_cron: missing installer: $installer" >&2
    return 1
  fi

  if ! command -v crontab >/dev/null 2>&1; then
    echo "nvim_install_stable_update_cron: crontab is not installed or not on PATH" >&2
    return 1
  fi

  local crontab_cmd="crontab"
  if (( EUID != 0 )); then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "nvim_install_stable_update_cron: sudo is required to install a root cron job" >&2
      return 1
    fi
    crontab_cmd="sudo crontab"
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

  echo "Choose the timezone for the Neovim tarball update cron job:"
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
    echo "nvim_install_stable_update_cron: invalid timezone: $selected_tz" >&2
    return 1
  fi

  local selected_hour
  while true; do
    printf 'Neovim update hour in %s (0-23) [4]: ' "$selected_tz"
    read -r selected_hour
    selected_hour="${selected_hour:-4}"

    if [[ "$selected_hour" == <-> && "$selected_hour" -ge 0 && "$selected_hour" -le 23 ]]; then
      break
    fi

    echo "nvim_install_stable_update_cron: use an hour from 0 to 23" >&2
  done

  local hour="$selected_hour"
  local minute=0
  local begin_marker="# nvim_install_stable_update_cron begin"
  local end_marker="# nvim_install_stable_update_cron end"
  local log_file="/var/log/nvim_install_stable_update_cron.log"
  local cron_line="$minute $hour * * * ZSHRC_CONFIG_DIR=${(q)repo_dir} sh ${(q)installer} >> ${(q)log_file} 2>&1"
  local tmp_file
  tmp_file="$(mktemp -t nvim_install_stable_update_cron.XXXXXX)" || return

  {
    $=crontab_cmd -l 2>/dev/null \
      | awk \
          -v begin="$begin_marker" \
          -v end="$end_marker" '
          $0 == begin { skip = 1; next }
          $0 == end { skip = 0; next }
          !skip { print }
        ' || true
    printf '%s\nCRON_TZ=%s\n%s\n%s\n' "$begin_marker" "$selected_tz" "$cron_line" "$end_marker"
  } > "$tmp_file"

  if $=crontab_cmd "$tmp_file"; then
    rm -f "$tmp_file"
    echo "nvim_install_stable_update_cron: installed root cron update"
    echo "nvim_install_stable_update_cron: timezone: $selected_tz"
    echo "nvim_install_stable_update_cron: time: ${hour}:00"
    echo "nvim_install_stable_update_cron: log: $log_file"
  else
    local status=$?
    rm -f "$tmp_file"
    return "$status"
  fi
}
