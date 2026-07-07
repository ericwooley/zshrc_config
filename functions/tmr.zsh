# Attach to a tmux session, creating it when it does not exist.
# Usage: tmr [session-name]. With no name, use the current directory name.
tmr() {
  if (( $# > 1 )); then
    echo "usage: tmr [session-name]" >&2
    return 2
  fi

  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmr: tmux is not installed" >&2
    return 1
  fi

  local session="${1:-${PWD:t}}"
  session="${session:-main}"
  session="${session//:/_}"

  if [[ -n "$TMUX" ]]; then
    tmux has-session -t "=$session" 2>/dev/null || tmux new-session -d -s "$session"
    tmux switch-client -t "=$session"
  else
    tmux new-session -A -s "$session"
  fi
}
