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

source "$ZSHRC_CONFIG_DIR/plugins_pre.zsh"
autoload -Uz compinit
compinit
source "$ZSHRC_CONFIG_DIR/plugins_post.zsh"
