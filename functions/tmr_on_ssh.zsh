# Open the interactive tmux session picker once for each SSH login shell.
tmr_on_ssh() {
  [[ -o interactive ]] || return 0
  [[ -n "${SSH_TTY:-}" ]] || return 0
  [[ -z "${TMUX:-}" ]] || return 0
  [[ -z "${ZSHRC_SSH_TMUX_PROMPTED:-}" ]] || return 0

  typeset -gx ZSHRC_SSH_TMUX_PROMPTED=1
  tmr
}
