# Shell behavior.

export N_PREFIX="${N_PREFIX:-$HOME/.local/n}"

if [[ -d "$N_PREFIX/bin" ]]; then
  export PATH="$N_PREFIX/bin:$PATH"
fi

if [[ -d "$HOME/.local/bin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Let directory names, including `..`, act like `cd <directory>`.
setopt AUTO_CD
alias ..='cd ..'
