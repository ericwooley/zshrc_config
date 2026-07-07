# Script bootstrapper.
# Exposes helper scripts on PATH without running any install or sync logic.

export ZSHRC_SCRIPTS_DIR="$ZSHRC_CONFIG_DIR/scripts"
export ZSHSETUP_REMOTE_SCRIPT="$ZSHRC_SCRIPTS_DIR/zshsetup-remote.sh"

path=("$ZSHRC_SCRIPTS_DIR" $path)
