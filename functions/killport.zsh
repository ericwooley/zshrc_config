# Kill the process listening on a TCP port.
killport() {
  emulate -L zsh

  if (( $# != 1 )); then
    echo "usage: killport <port>" >&2
    return 2
  fi

  local port="$1"
  if [[ "$port" != <-> ]] || (( port < 1 || port > 65535 )); then
    echo "killport: port must be a number from 1 to 65535" >&2
    return 2
  fi

  if ! command -v lsof >/dev/null 2>&1; then
    echo "killport: lsof is required to find the process using port $port" >&2
    return 1
  fi

  local -a pids alive
  pids=("${(@f)$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null)}")
  pids=("${(@)pids:#}")

  if (( ${#pids[@]} == 0 )); then
    echo "killport: no process is listening on port $port"
    return 0
  fi

  echo "killport: process listening on port $port:"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true

  command kill -TERM "${pids[@]}" 2>/dev/null || true
  sleep 1

  alive=()
  local pid
  for pid in "${pids[@]}"; do
    if command kill -0 "$pid" 2>/dev/null; then
      alive+=("$pid")
    fi
  done

  if (( ${#alive[@]} > 0 )); then
    echo "killport: forcing still-running pid(s): ${alive[*]}"
    command kill -KILL "${alive[@]}" 2>/dev/null || true
  fi

  echo "killport: cleared port $port"
}
