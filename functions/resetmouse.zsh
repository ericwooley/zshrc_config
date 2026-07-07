# Reset terminal mouse reporting when an app exits without cleaning up.
resetmouse() {
  # Disable the common xterm mouse/focus/bracketed-paste modes that can leak
  # after tmux, Neovim, SSH, or full-screen terminal apps exit badly.
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1004l\033[?1005l\033[?1006l\033[?1015l\033[?1016l\033[?2004l'
  stty sane 2>/dev/null || true
}
