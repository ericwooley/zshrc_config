# Environment variables and local machine overrides.

typeset -U path PATH
path=("$ZSHRC_CONFIG_DIR/bin" "$N_PREFIX/bin" "$HOME/.local/go/bin" "$HOME/.local/bin" $path)
export PATH

if [[ -f "$HOME/.zshrc_local" ]]; then
  source "$HOME/.zshrc_local"
elif [[ -f "$HOME/.zsh_local" ]]; then
  source "$HOME/.zsh_local"
fi

# fastAI.
export FASTAI_DEFAULT_PROVIDER="openrouter"
export FASTAI_DEFAULT_MODEL="deepseek/deepseek-v4-flash"
export FASTAI_DEFAULT_PERMISSIONS="read"

# User Options
export EDITOR=nvim
