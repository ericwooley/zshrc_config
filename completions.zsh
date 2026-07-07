# Package manager completions.

_zshrc_completion_dir="$ZSHRC_CONFIG_DIR/generated-completions"
mkdir -p "$_zshrc_completion_dir" 2>/dev/null

_zshrc_source_generated_completion() {
  local name="$1"
  local generator="$2"
  local cache_file="$_zshrc_completion_dir/$name.zsh"

  if [[ ! -s "$cache_file" ]] && command -v "$name" >/dev/null 2>&1; then
    eval "$generator" >| "$cache_file" 2>/dev/null || rm -f "$cache_file"
  fi

  if [[ -s "$cache_file" ]]; then
    source "$cache_file"
  fi
}

if command -v npm >/dev/null 2>&1; then
  _zshrc_source_generated_completion npm "npm completion"
fi

if command -v pnpm >/dev/null 2>&1; then
  _zshrc_source_generated_completion pnpm "pnpm completion zsh"
fi

if command -v yarn >/dev/null 2>&1; then
  if (( $+functions[_yarn] )); then
    compdef _yarn yarn
  else
    for _zshrc_completion_fpath_dir in $fpath; do
      if [[ -r "$_zshrc_completion_fpath_dir/_yarn" ]]; then
        autoload -Uz _yarn
        compdef _yarn yarn
        break
      fi
    done
  fi
fi

if command -v bun >/dev/null 2>&1; then
  _zshrc_source_generated_completion bun "bun completions zsh || bun completions"
fi

unset -f _zshrc_source_generated_completion
unset _zshrc_completion_dir _zshrc_completion_fpath_dir
