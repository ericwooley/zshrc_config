# Bootstrap this terminal setup on an SSH host from the published git repo.
# The remote host clones or pulls the repo, then runs install.sh there so the
# same dependency prompts, backups, and managed symlinks are used everywhere.
zshsetup() {
  if (( $# != 1 )); then
    echo "usage: zshsetup <host>" >&2
    return 2
  fi

  local host="$1"
  local config_dir="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"
  local repo_url="${ZSHSETUP_REPO_URL:-}"
  local repo_root=""

  if ! command -v ssh >/dev/null 2>&1; then
    echo "zshsetup: missing local command: ssh" >&2
    return 1
  fi

  if [[ -z "$repo_url" ]]; then
    if ! command -v git >/dev/null 2>&1; then
      echo "zshsetup: missing local command: git" >&2
      return 1
    fi

    repo_root="$(git -C "$config_dir" rev-parse --show-toplevel 2>/dev/null)" || repo_root=""
    if [[ -n "$repo_root" ]]; then
      repo_url="$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null)" || repo_url=""
    fi
  fi

  if [[ -z "$repo_url" ]]; then
    cat >&2 <<'EOF'
zshsetup: no git remote URL found for this setup.
zshsetup: add an origin remote, or run with:
zshsetup:   ZSHSETUP_REPO_URL=https://github.com/<you>/<repo>.git zshsetup <host>
EOF
    return 1
  fi

  local -a remote_steps=(
    'set -eu'
    'repo_url="$ZSHSETUP_REPO_URL"'
    'repo_dir="$HOME/.zshrc_config"'
    'run_apt() { if [ "$(id -u)" -eq 0 ]; then DEBIAN_FRONTEND=noninteractive apt-get "$@"; elif command -v sudo >/dev/null 2>&1; then sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"; else echo "zshsetup: sudo is required to install git with apt" >&2; return 1; fi; }'
    'ensure_git() { if command -v git >/dev/null 2>&1; then return 0; fi; if ! command -v apt-get >/dev/null 2>&1; then echo "zshsetup: git is required before cloning $repo_url" >&2; echo "zshsetup: install git manually, then rerun zshsetup" >&2; return 1; fi; echo "zshsetup: git is required before cloning $repo_url"; echo "zshsetup: commands:"; echo "  apt-get update"; echo "  apt-get install -y git ca-certificates"; printf "zshsetup: install git with apt now? [y/N] "; read answer || answer=""; case "$answer" in y|Y|yes|YES) ;; *) echo "zshsetup: skipped git install"; return 1 ;; esac; run_apt update; run_apt install -y git ca-certificates; }'
    'ensure_git'
    'mkdir -p "$(dirname "$repo_dir")"'
    'backup_config_dir() { backup_path="$HOME/.zsh_config.bak"; if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then backup_path="$HOME/.zsh_config.bak_$(date +%Y%m%d_%H%M%S)"; fi; echo "zshsetup: moving existing $repo_dir to $backup_path"; mv "$repo_dir" "$backup_path"; }'
    'stash_if_dirty() { if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then stash_name="zshsetup auto-stash $(date +%Y%m%d_%H%M%S)"; echo "zshsetup: stashing local changes in $repo_dir: $stash_name"; git -C "$repo_dir" stash push -u -m "$stash_name"; fi; }'
    'if [ -d "$repo_dir/.git" ]; then echo "zshsetup: updating $repo_dir"; stash_if_dirty; git -C "$repo_dir" pull --ff-only; else if [ -e "$repo_dir" ] || [ -L "$repo_dir" ]; then backup_config_dir; fi; echo "zshsetup: cloning $repo_url into $repo_dir"; git clone "$repo_url" "$repo_dir"; fi'
    'cd "$repo_dir"'
    'sh ./install.sh'
    'printf "zshsetup: install nightly update cron on this remote? [y/N] "; read cron_answer || cron_answer=""; case "$cron_answer" in y|Y|yes|YES) ZSHRC_CONFIG_DIR="$repo_dir" zsh -lc "source \"$repo_dir/functions/zsh_install_nightly_update_cron.zsh\"; zsh_install_nightly_update_cron" ;; *) echo "zshsetup: skipped nightly update cron" ;; esac'
    'printf "zshsetup: install Neovim stable tarball update cron on this remote? [y/N] "; read nvim_cron_answer || nvim_cron_answer=""; case "$nvim_cron_answer" in y|Y|yes|YES) ZSHRC_CONFIG_DIR="$repo_dir" zsh -lc "source \"$repo_dir/functions/nvim_install_stable_update_cron.zsh\"; nvim_install_stable_update_cron" ;; *) echo "zshsetup: skipped Neovim update cron" ;; esac'
  )
  local remote_script="${(j:; :)remote_steps}"

  echo "zshsetup: bootstrapping $host from $repo_url"
  ssh -tt "$host" "ZSHSETUP_REPO_URL=${(q)repo_url} sh -lc ${(q)remote_script}"
}
