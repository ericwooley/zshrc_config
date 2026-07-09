# Create a Multipass VM with a host-backed home directory and this zsh setup.
vmcreate() {
  if (( $# < 1 || $# > 2 )); then
    echo "usage: vmcreate <name> [image]" >&2
    echo "env: VM_USER VM_HOME_ROOT VM_IMAGE VM_CPUS VM_MEMORY VM_DISK" >&2
    return 2
  fi

  if ! command -v multipass >/dev/null 2>&1; then
    echo "vmcreate: multipass is not installed or not on PATH" >&2
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "vmcreate: git is not installed or not on PATH" >&2
    return 1
  fi

  local name="$1"
  local image="${2:-${VM_IMAGE:-lts}}"
  local vm_user="${VM_USER:-$USER}"
  local cpus="${VM_CPUS:-2}"
  local memory="${VM_MEMORY:-4G}"
  local disk="${VM_DISK:-20G}"
  local home_root="${VM_HOME_ROOT:-$HOME/vms/home}"
  local cloud_init_root="${VM_CLOUD_INIT_ROOT:-$HOME/vms/cloud-init}"
  local host_home="$home_root/$name"
  local cloud_init="$cloud_init_root/$name.yaml"
  local config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local repo_url="${ZSHSETUP_REPO_URL:-}"
  local vm_exists=0
  local yaml_key

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

  mkdir -p "$host_home/.ssh" "$cloud_init_root"
  chmod 700 "$host_home/.ssh"

  local explicit_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHllsKDjX0HDWubAMR/F0xW6UM2g2g8NqX5LcK8QI29j ericwooley@gmail.com'
  local key_file key_line
  {
    print -r -- "$explicit_key"
    for key_file in "$HOME"/.ssh/*.pub(N); do
      while IFS= read -r key_line; do
        [[ -n "$key_line" ]] && print -r -- "$key_line"
      done < "$key_file"
    done
  } | awk '!seen[$0]++' > "$host_home/.ssh/authorized_keys"
  chmod 600 "$host_home/.ssh/authorized_keys"

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
  esac

  if [[ -d "$host_home/.zshrc_config/.git" ]]; then
    echo "vmcreate: updating $host_home/.zshrc_config"
    git -C "$host_home/.zshrc_config" pull --ff-only || return
  elif [[ -e "$host_home/.zshrc_config" ]]; then
    echo "vmcreate: $host_home/.zshrc_config exists but is not a git checkout" >&2
    return 1
  else
    echo "vmcreate: cloning $repo_url into $host_home/.zshrc_config"
    git clone "$repo_url" "$host_home/.zshrc_config" || return
  fi

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
    done < "$host_home/.ssh/authorized_keys"
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

  echo "vmcreate: mounting $host_home to /home/$vm_user"
  multipass exec "$name" -- sudo mkdir -p "/home/$vm_user" || return
  if multipass info "$name" 2>/dev/null | grep -F -- "$host_home" >/dev/null 2>&1; then
    echo "vmcreate: $host_home is already mounted"
  else
    multipass mount "$host_home" "$name:/home/$vm_user" || return
  fi
  multipass exec "$name" -- sudo chown -R "$vm_user:$vm_user" "/home/$vm_user" >/dev/null 2>&1 || true

  echo "vmcreate: installing zsh setup inside $name"
  multipass exec "$name" -- sudo -H -u "$vm_user" sh -lc 'printf "y\nn\ny\n" | sh "$HOME/.zshrc_config/install.sh"' || return

  echo "vmcreate: ready"
  echo "vmcreate: connect with: vmconnect $name"
  echo "vmcreate: host home: $host_home"
}
