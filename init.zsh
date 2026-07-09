# Main zsh config entrypoint.

export ZSHRC_CONFIG_DIR="${ZSHRC_CONFIG_DIR:-$HOME/.zshrc_config}"

source "$ZSHRC_CONFIG_DIR/options.zsh"
source "$ZSHRC_CONFIG_DIR/plugins.zsh"
source "$ZSHRC_CONFIG_DIR/completions.zsh"
source "$ZSHRC_CONFIG_DIR/keybindings.zsh"
source "$ZSHRC_CONFIG_DIR/tools.zsh"
source "$ZSHRC_CONFIG_DIR/env.zsh"
source "$ZSHRC_CONFIG_DIR/aliases.zsh"
source "$ZSHRC_CONFIG_DIR/scripts/init.zsh"
source "$ZSHRC_CONFIG_DIR/functions/init.zsh"
