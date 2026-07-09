# Shared shell aliases.

# Core utility aliases.
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Find processes listening on ports.
alias ports='lsof -i -P -n | grep LISTEN'

# Reload the managed zsh config in the current shell.
alias rzsh='source ~/.zshrc'
