# List Multipass VMs.
vmls() {
  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmls: multipass is not installed or not on PATH" >&2
    return 1
  fi

  multipass list "$@"
}
