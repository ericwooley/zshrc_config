_vmcreate_run_with_heartbeat() {
  local label="$1"
  local timeout_seconds="$2"
  shift 2

  echo "vmcreate: $label"
  "$@" &

  local command_pid=$!
  local started_at=$SECONDS
  local elapsed=0
  local command_status=0
  local next_heartbeat=5

  while kill -0 "$command_pid" >/dev/null 2>&1; do
    elapsed=$((SECONDS - started_at))
    if (( elapsed >= timeout_seconds )); then
      echo "vmcreate: timed out while $label after ${timeout_seconds}s" >&2
      kill "$command_pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$command_pid" >/dev/null 2>&1 || true
      wait "$command_pid" >/dev/null 2>&1 || true
      return 124
    fi

    sleep 1
    elapsed=$((SECONDS - started_at))
    if (( elapsed >= next_heartbeat )) && kill -0 "$command_pid" >/dev/null 2>&1; then
      next_heartbeat=$((next_heartbeat + 5))
      elapsed=$((SECONDS - started_at))
      echo "vmcreate: still $label (${elapsed}s elapsed)"
    fi
  done

  wait "$command_pid"
  command_status=$?

  if (( command_status == 0 )); then
    echo "vmcreate: finished $label"
  else
    echo "vmcreate: failed while $label (exit $command_status)" >&2
  fi

  return "$command_status"
}

# Create a Multipass VM with this zsh setup and a host shared directory.
vmcreate() {
  if (( $# < 1 || $# > 2 )); then
    echo "usage: vmcreate <name> [image]" >&2
    echo "env: VM_USER VM_SHARED_DIR VM_IMAGE VM_CPUS VM_MEMORY VM_DISK VM_SSH_WAIT_SECONDS VM_MOUNT_WAIT_SECONDS VM_INSTALL_WAIT_SECONDS" >&2
    return 2
  fi

  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmcreate: Multipass needs to be installed first" >&2
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "vmcreate: git is not installed or not on PATH" >&2
    return 1
  fi

  local name="$1"
  local image="${2:-${VM_IMAGE:-lts}}"
  local vm_user="${VM_USER:-$USER}"
  local cpus="${VM_CPUS:-}"
  local memory="${VM_MEMORY:-}"
  local disk="${VM_DISK:-20G}"
  local host_shared="${VM_SHARED_DIR:-$HOME/vms/shared}"
  local cloud_init_root="${VM_CLOUD_INIT_ROOT:-$HOME/vms/cloud-init}"
  local cloud_init="$cloud_init_root/$name.yaml"
  local authorized_keys="$cloud_init_root/$name-authorized_keys"
  local config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local repo_url="${ZSHSETUP_REPO_URL:-}"
  local vm_exists=0
  local yaml_key
  local mount_wait_seconds="${VM_MOUNT_WAIT_SECONDS:-180}"
  local install_wait_seconds="${VM_INSTALL_WAIT_SECONDS:-900}"

  if [[ ! "$name" =~ '^[A-Za-z0-9][A-Za-z0-9-]*$' ]]; then
    echo "vmcreate: VM name must use letters, numbers, and dashes, and must not start with a dash" >&2
    return 1
  fi

  if [[ ! "$vm_user" =~ '^[a-z_][a-z0-9_-]*[$]?$' ]]; then
    echo "vmcreate: VM_USER is not a valid Linux username: $vm_user" >&2
    return 1
  fi

  if multipass info "$name" >/dev/null 2>&1; then
    vm_exists=1
    echo "vmcreate: VM already exists; continuing setup: $name"
  fi

  if (( ! vm_exists )); then
    if [[ -z "$cpus" ]]; then
      read -r "cpus?vmcreate: vCPUs [2]: " || {
        echo "vmcreate: canceled while reading vCPUs" >&2
        return 1
      }
      cpus="${cpus:-2}"
    fi
    if [[ ! "$cpus" =~ '^[1-9][0-9]*$' ]]; then
      echo "vmcreate: vCPUs must be a positive whole number" >&2
      return 1
    fi

    if [[ -z "$memory" ]]; then
      local memory_gb
      read -r "memory_gb?vmcreate: RAM in GB [4]: " || {
        echo "vmcreate: canceled while reading RAM" >&2
        return 1
      }
      memory_gb="${memory_gb:-4}"
      if [[ ! "$memory_gb" =~ '^[1-9][0-9]*$' ]]; then
        echo "vmcreate: RAM must be a positive whole number of GB" >&2
        return 1
      fi
      memory="${memory_gb}G"
    fi
  fi

  mkdir -p "$host_shared" "$cloud_init_root"

  local explicit_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHllsKDjX0HDWubAMR/F0xW6UM2g2g8NqX5LcK8QI29j ericwooley@gmail.com'
  local key_file key_line
  {
    print -r -- "$explicit_key"
    for key_file in "$HOME"/.ssh/*.pub(N); do
      while IFS= read -r key_line; do
        [[ -n "$key_line" ]] && print -r -- "$key_line"
      done < "$key_file"
    done
  } | awk '!seen[$0]++' > "$authorized_keys"
  chmod 600 "$authorized_keys"

  if [[ -z "$repo_url" && -d "$config_dir/.git" ]]; then
    repo_url="$(git -C "$config_dir" config --get remote.origin.url 2>/dev/null)" || repo_url=""
  fi
  if [[ -z "$repo_url" ]]; then
    repo_url="https://github.com/ericwooley/zshrc_config.git"
  fi
  case "$repo_url" in
    git@github.com:*)
      repo_url="https://github.com/${repo_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      repo_url="https://github.com/${repo_url#ssh://git@github.com/}"
      ;;
  esac

  {
    print -r -- "#cloud-config"
    print -r -- "package_update: true"
    print -r -- "users:"
    print -r -- "  - default"
    print -r -- "  - name: $vm_user"
    print -r -- "    gecos: $vm_user"
    print -r -- "    groups: [adm, sudo]"
    print -r -- "    sudo: ALL=(ALL) NOPASSWD:ALL"
    print -r -- "    shell: /bin/bash"
    print -r -- "    lock_passwd: true"
    print -r -- "    ssh_authorized_keys:"
    while IFS= read -r key_line; do
      yaml_key="$(print -r -- "$key_line" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      print -r -- "      - \"$yaml_key\""
    done < "$authorized_keys"
    print -r -- "packages:"
    print -r -- "  - ca-certificates"
    print -r -- "  - curl"
    print -r -- "  - git"
    print -r -- "  - htop"
    print -r -- "  - sudo"
    print -r -- "  - zsh"
    print -r -- "runcmd:"
    print -r -- "  - mkdir -p /home/$vm_user"
    print -r -- "  - chown $vm_user:$vm_user /home/$vm_user"
    print -r -- "  - chsh -s /usr/bin/zsh $vm_user"
    print -r -- "  - echo 'VM initialized' > /tmp/init-status"
  } > "$cloud_init"

  if (( ! vm_exists )); then
    echo "vmcreate: launching $name from $image"
    multipass launch "$image" --name "$name" --cpus "$cpus" --memory "$memory" --disk "$disk" --cloud-init "$cloud_init" || return
  else
    echo "vmcreate: starting $name if needed"
    multipass start "$name" >/dev/null 2>&1 || true
  fi

  local wait_seconds="${VM_SSH_WAIT_SECONDS:-240}"
  local wait_deadline=$((SECONDS + wait_seconds))
  echo "vmcreate: waiting for Multipass SSH (${wait_seconds}s max)"
  until multipass exec "$name" -- true >/dev/null 2>&1; do
    if (( SECONDS >= wait_deadline )); then
      echo "vmcreate: timed out waiting for Multipass SSH for $name" >&2
      multipass info "$name" >&2 || true
      return 1
    fi
    sleep 3
  done

  echo "vmcreate: waiting for cloud-init"
  multipass exec "$name" -- cloud-init status --wait || return

  local sudoers_file="/etc/sudoers.d/90-vmcreate-$vm_user"
  local sudoers_rule="$vm_user ALL=(ALL) NOPASSWD:ALL"
  echo "vmcreate: configuring passwordless sudo for $vm_user"
  multipass exec "$name" -- sudo sh -c '
    set -eu
    rule="$1"
    sudoers_file="$2"
    printf "%s\n" "$rule" > "$sudoers_file"
    chmod 0440 "$sudoers_file"
    visudo -cf "$sudoers_file" >/dev/null
  ' sh "$sudoers_rule" "$sudoers_file" || return
  multipass exec "$name" -- sudo -n -u "$vm_user" sudo -n true || return

  echo "vmcreate: disabling IPv6"
  multipass exec "$name" -- sudo sh -c '
    set -eu
    sysctl_file=/etc/sysctl.d/99-vmcreate-disable-ipv6.conf
    printf "%s\n" \
      "net.ipv6.conf.all.disable_ipv6 = 1" \
      "net.ipv6.conf.default.disable_ipv6 = 1" \
      > "$sysctl_file"
    sysctl -p "$sysctl_file" >/dev/null
  ' || return

  if multipass info "$name" 2>/dev/null | grep -F -- "/home/$vm_user" | grep -Fv -- "/home/$vm_user/shared" >/dev/null 2>&1; then
    echo "vmcreate: removing old home mount at /home/$vm_user"
    multipass umount "$name:/home/$vm_user" || return
  fi

  echo "vmcreate: mounting $host_shared to /home/$vm_user/shared"
  multipass exec "$name" -- sudo -u "$vm_user" mkdir -p "/home/$vm_user/shared" || return
  if multipass info "$name" 2>/dev/null | grep -F -- "$host_shared" >/dev/null 2>&1; then
    echo "vmcreate: $host_shared is already mounted"
  else
    local host_uid host_gid vm_uid vm_gid
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    vm_uid="$(multipass exec "$name" -- id -u "$vm_user" 2>/dev/null)" || vm_uid=""
    vm_gid="$(multipass exec "$name" -- id -g "$vm_user" 2>/dev/null)" || vm_gid=""

    local mount_args=()
    if [[ -n "$vm_uid" && -n "$vm_gid" ]]; then
      mount_args+=(--uid-map "$host_uid:$vm_uid" --gid-map "$host_gid:$vm_gid")
    fi

    _vmcreate_run_with_heartbeat \
      "mounting shared directory (${mount_wait_seconds}s max)" \
      "$mount_wait_seconds" \
      multipass mount "${mount_args[@]}" "$host_shared" "$name:/home/$vm_user/shared" || return
  fi

  echo "vmcreate: preparing zsh setup inside $name"
  multipass exec "$name" -- sudo -H -u "$vm_user" env ZSHSETUP_REPO_URL="$repo_url" sh -lc '
    set -eu
    repo_url="$ZSHSETUP_REPO_URL"
    if [ -d "$HOME/.zshrc_config/.git" ]; then
      git -C "$HOME/.zshrc_config" remote set-url origin "$repo_url" 2>/dev/null || true
      git -C "$HOME/.zshrc_config" pull --ff-only
    elif [ -e "$HOME/.zshrc_config" ]; then
      echo "vmcreate: $HOME/.zshrc_config exists but is not a git checkout" >&2
      exit 1
    else
      git clone "$repo_url" "$HOME/.zshrc_config"
    fi
  ' || return

  _vmcreate_run_with_heartbeat \
    "installing zsh setup inside $name (${install_wait_seconds}s max)" \
    "$install_wait_seconds" \
    multipass exec "$name" -- sudo -H -u "$vm_user" sh -lc 'printf "y\nn\nn\ny\n" | NONINTERACTIVE=1 sh "$HOME/.zshrc_config/install.sh"' || return

  echo "vmcreate: ready"
  echo "vmcreate: connect with: vmconnect $name"
  echo "vmcreate: shared directory: $host_shared -> $name:/home/$vm_user/shared"
}
