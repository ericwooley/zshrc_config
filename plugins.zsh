# Plugin loading.

_zshrc_antidote_file=""

if command -v brew >/dev/null 2>&1; then
  _zshrc_brew_prefix="$(brew --prefix 2>/dev/null)"
  if [[ -r "$_zshrc_brew_prefix/opt/antidote/share/antidote/antidote.zsh" ]]; then
    _zshrc_antidote_file="$_zshrc_brew_prefix/opt/antidote/share/antidote/antidote.zsh"
  fi
fi

if [[ -z "$_zshrc_antidote_file" && -r "$HOME/.antidote/antidote.zsh" ]]; then
  _zshrc_antidote_file="$HOME/.antidote/antidote.zsh"
fi

if [[ -z "$_zshrc_antidote_file" ]]; then
  echo "zsh: antidote is not installed; run zshsetup from a configured machine or install antidote" >&2
  return 1
fi

source "$_zshrc_antidote_file"
unset _zshrc_antidote_file _zshrc_brew_prefix

# Load zsh completion paths before compinit, then load fzf-tab after compinit.
# fzf-tab wraps zsh's Tab completion widgets and will break if compinit has not run.
zshrc_has_n() {
  command -v n >/dev/null 2>&1
}

_zshrc_antidote_bundle_needs_regen() {
  local source_list="$1"
  local bundle_file="$2"

  [[ ! -s "$bundle_file" ]] && return 0
  [[ "$source_list" -nt "$bundle_file" ]] && return 0

  # Antidote bundles contain absolute cache paths, so rebuild bundles copied
  # from another OS or home-directory layout before sourcing them.
  if grep -q '/Library/Caches/antidote' "$bundle_file" 2>/dev/null \
    && [[ ! -d "$HOME/Library/Caches/antidote" ]]; then
    return 0
  fi

  local line source_path
  while IFS= read -r line; do
    case "$line" in
      *'source "'*'"'*)
        source_path="${line#*source \"}"
        source_path="${source_path%%\"*}"
        source_path="${source_path//\$HOME/$HOME}"

        if [[ ! -e "$source_path" ]]; then
          return 0
        fi
        ;;
    esac
  done < "$bundle_file"

  return 1
}

_zshrc_regenerate_antidote_bundle() {
  local source_list="$1"
  local bundle_file="$2"
  local tmp_file="${bundle_file}.tmp.$$"

  if [[ ! -r "$source_list" ]]; then
    echo "zsh: missing Antidote plugin list: $source_list" >&2
    return 1
  fi

  if antidote bundle < "$source_list" >| "$tmp_file"; then
    mv "$tmp_file" "$bundle_file"
  else
    rm -f "$tmp_file"
    echo "zsh: failed to regenerate Antidote bundle: $bundle_file" >&2
    return 1
  fi
}

_zshrc_ensure_antidote_bundle() {
  local source_list="$1"
  local bundle_file="$2"

  if _zshrc_antidote_bundle_needs_regen "$source_list" "$bundle_file"; then
    _zshrc_regenerate_antidote_bundle "$source_list" "$bundle_file" || return
  fi
}

_zshrc_ensure_antidote_bundle "$ZSHRC_CONFIG_DIR/plugins_pre.txt" "$ZSHRC_CONFIG_DIR/plugins_pre.zsh"
_zshrc_ensure_antidote_bundle "$ZSHRC_CONFIG_DIR/plugins_post.txt" "$ZSHRC_CONFIG_DIR/plugins_post.zsh"

source "$ZSHRC_CONFIG_DIR/plugins_pre.zsh"
autoload -Uz compinit
compinit
source "$ZSHRC_CONFIG_DIR/plugins_post.zsh"

unset -f _zshrc_antidote_bundle_needs_regen
unset -f _zshrc_regenerate_antidote_bundle
unset -f _zshrc_ensure_antidote_bundle
