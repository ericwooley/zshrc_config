# Shell behavior.

export N_PREFIX="${N_PREFIX:-$HOME/.local/n}"

# Let directory names, including `..`, act like `cd <directory>`.
setopt AUTO_CD
alias ..='cd ..'
