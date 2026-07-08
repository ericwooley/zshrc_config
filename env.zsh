# Environment variables and local machine overrides.

typeset -U path PATH
path=("$ZSHRC_CONFIG_DIR/bin" "$N_PREFIX/bin" "$HOME/.local/go/bin" "$HOME/.local/bin" $path)
export PATH

if [[ -f "$HOME/.zshrc_local" ]]; then
  source "$HOME/.zshrc_local"
elif [[ -f "$HOME/.zsh_local" ]]; then
  source "$HOME/.zsh_local"
fi

# Send GUI apps launched from SSH to the TigerVNC session by default.
if [[ -z "$DISPLAY" ]] && pgrep -u "$USER" -f 'Xvnc.*:1' >/dev/null 2>&1; then
  export DISPLAY=:1
fi

# fastAI.
export FASTAI_DEFAULT_PROVIDER="openrouter"
export FASTAI_DEFAULT_MODEL="deepseek/deepseek-v4-flash"
export FASTAI_DEFAULT_PERMISSIONS="read"

# User Options
export EDITOR=nvim
