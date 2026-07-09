# Remove a Multipass VM.
vmrm() {
  if (( $# != 1 )); then
    echo "usage: vmrm <name>" >&2
    return 2
  fi

  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmrm: Multipass needs to be installed first" >&2
    return 1
  fi

  local name="$1"

  if ! multipass info "$name" >/dev/null 2>&1; then
    echo "vmrm: VM not found: $name" >&2
    return 1
  fi

  echo "vmrm: deleting Multipass VM: $name"
  multipass delete --purge "$name" || return
}
