# Remove stopped containers, unused networks, dangling images, and volumes.
dclean() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "dclean: docker is not installed" >&2
    return 1
  fi

  docker system prune -a -f --volumes
}
