# Connect to a managed Multipass VM as the configured VM user.
vmconnect() {
  if (( $# != 1 )); then
    echo "usage: vmconnect <name>" >&2
    return 2
  fi

  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmconnect: Multipass needs to be installed first" >&2
    return 1
  fi

  local name="$1"
  local vm_user="${VM_USER:-$USER}"

  multipass exec "$name" -- sudo -iu "$vm_user"
}
