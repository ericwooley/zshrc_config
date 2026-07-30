# Attach to a tmux session, creating it when it does not exist.
# Usage: tmr [session-name]. With no name, choose interactively.
tmr() {
  if (( $# > 1 )); then
    echo "usage: tmr [session-name]" >&2
    return 2
  fi

  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmr: tmux is not installed" >&2
    return 1
  fi

  local session

  if (( $# == 1 )); then
    session="${1:-main}"
  else
    if ! command -v fzf >/dev/null 2>&1; then
      echo "tmr: fzf is required for interactive session selection" >&2
      return 1
    fi

    local sessions_output selected existing picker_status
    local -a sessions choices

    if sessions_output="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"; then
      sessions=("${(@f)sessions_output}")
    else
      sessions=()
    fi

    choices=()
    for existing in "${sessions[@]}"; do
      choices+=("Attach: $existing")
    done
    choices+=("Create a new session")

    if selected="$(
      printf '%s\n' "${choices[@]}" |
        fzf \
          --height=40% \
          --layout=reverse \
          --border \
          --cycle \
          --no-multi \
          --prompt='tmux session> ' \
          --header='Up/Down: move | Enter: choose | Ctrl-C: cancel'
    )"; then
      :
    else
      picker_status=$?
      return "$picker_status"
    fi

    if [[ "$selected" == "Create a new session" ]]; then
      if ! IFS= read -r "session?New tmux session name: "; then
        return 1
      fi

      if [[ -z "$session" ]]; then
        echo "tmr: session name cannot be empty" >&2
        return 1
      fi
    elif [[ "$selected" == "Attach: "* ]]; then
      session="${selected#Attach: }"
    else
      echo "tmr: no session selected" >&2
      return 1
    fi
  fi

  session="${session//:/_}"

  if [[ -n "${TMUX:-}" ]]; then
    tmux has-session -t "=$session" 2>/dev/null || tmux new-session -d -s "$session"
    tmux switch-client -t "=$session"
  else
    tmux new-session -A -s "$session"
  fi
}
