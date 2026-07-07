# Remove all Docker containers, images, and volumes.
dnuke() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "dnuke: docker is not installed" >&2
    return 1
  fi

  local -a containers images volumes
  containers=("${(@f)$(docker ps -a -q)}") || return
  containers=("${(@)containers:#}")
  images=("${(@f)$(docker images -q)}") || return
  images=("${(@)images:#}")
  volumes=("${(@f)$(docker volume ls -q)}") || return
  volumes=("${(@)volumes:#}")

  (( ${#containers[@]} > 0 )) && docker rm -f "${containers[@]}" 2>/dev/null
  (( ${#images[@]} > 0 )) && docker rmi -f "${images[@]}" 2>/dev/null
  (( ${#volumes[@]} > 0 )) && docker volume rm "${volumes[@]}" 2>/dev/null
}
