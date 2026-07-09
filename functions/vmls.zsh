# List Multipass VMs.
vmls() {
  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmls: Multipass needs to be installed first" >&2
    return 1
  fi

  multipass list "$@"
}
