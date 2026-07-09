# Interactive zle keybindings.

# Some terminals send xterm-style escape sequences for Ctrl-Left/Ctrl-Right.
# Bind the common variants so they move by shell word instead of printing
# fragments such as ";5D" or ";5C".
if [[ -o interactive ]]; then
  for keymap in emacs viins vicmd; do
    bindkey -M "$keymap" $'\e[1;5D' backward-word
    bindkey -M "$keymap" $'\e[1;5C' forward-word
    bindkey -M "$keymap" $'\e[5D' backward-word
    bindkey -M "$keymap" $'\e[5C' forward-word
  done
fi
