# Environment variables and local machine overrides.

if [[ -f "$HOME/.zsh_local" ]]; then
  source "$HOME/.zsh_local"
fi

# fastAI.
export FASTAI_DEFAULT_PROVIDER="openrouter"
export FASTAI_DEFAULT_MODEL="deepseek/deepseek-v4-flash"
export FASTAI_DEFAULT_PERMISSIONS="read"

# User Options
export EDITOR=nvim
