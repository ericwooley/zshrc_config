# Stop every Docker container if any containers exist.
dstop() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "dstop: docker is not installed" >&2
    return 1
  fi

  local -a containers
  containers=("${(@f)$(docker ps -a -q)}") || return
  containers=("${(@)containers:#}")

  if (( ${#containers[@]} == 0 )); then
    echo "dstop: no containers to stop"
    return 0
  fi

  docker stop "${containers[@]}"
}
