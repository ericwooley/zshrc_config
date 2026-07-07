# Script bootstrapper.
# Exposes helper scripts on PATH without running any install or sync logic.

export ZSHRC_SCRIPTS_DIR="$ZSHRC_CONFIG_DIR/scripts"

path=("$ZSHRC_SCRIPTS_DIR" $path)
