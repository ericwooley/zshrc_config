# Interactive zle keybindings.

# Some terminals send xterm-style escape sequences for Ctrl-Left/Ctrl-Right.
# Bind the common variants so they move by shell word instead of printing
# fragments such as ";5D" or ";5C".
if [[ -o interactive ]]; then
  # Use zsh's emacs keymap, which matches standard bash/readline-style editing.
  bindkey -e

  _zshrc_bind_word_key() {
    local sequence="$1"
    local widget="$2"

    bindkey -M emacs "$sequence" "$widget"
  }

  _zshrc_bind_word_key $'\e[1;5D' backward-word
  _zshrc_bind_word_key $'\e[1;5C' forward-word
  _zshrc_bind_word_key $'\e[5D' backward-word
  _zshrc_bind_word_key $'\e[5C' forward-word

  _zshrc_bind_word_key $'\C-a' beginning-of-line
  _zshrc_bind_word_key $'\C-e' end-of-line

  unfunction _zshrc_bind_word_key
fi
