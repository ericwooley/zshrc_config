# Remove a Multipass VM and optionally remove its host-backed home directory.
vmrm() {
  if (( $# != 1 )); then
    echo "usage: vmrm <name>" >&2
    return 2
  fi

  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmrm: multipass is not installed or not on PATH" >&2
    return 1
  fi

  local name="$1"
  local home_root="${VM_HOME_ROOT:-$HOME/vms/home}"
  local host_home="$home_root/$name"

  if ! multipass info "$name" >/dev/null 2>&1; then
    echo "vmrm: VM not found: $name" >&2
    return 1
  fi

  echo "vmrm: deleting Multipass VM: $name"
  multipass delete --purge "$name" || return

  if [[ -d "$host_home" ]]; then
    local answer
    printf "vmrm: remove host home folder %s? [y/N] " "$host_home"
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        rm -rf "$host_home"
        echo "vmrm: removed $host_home"
        ;;
      *)
        echo "vmrm: kept $host_home"
        ;;
    esac
  fi
}
