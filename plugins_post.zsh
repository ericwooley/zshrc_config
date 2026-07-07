fpath+=( "$HOME/Library/Caches/antidote/github.com/Aloxaf/fzf-tab" )
source "$HOME/Library/Caches/antidote/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/zsh-users/zsh-autosuggestions" )
source "$HOME/Library/Caches/antidote/github.com/zsh-users/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
if ! (( $+functions[zsh-defer] )); then
  fpath+=( "$HOME/Library/Caches/antidote/github.com/romkatv/zsh-defer" )
  source "$HOME/Library/Caches/antidote/github.com/romkatv/zsh-defer/zsh-defer.plugin.zsh"
fi
fpath+=( "$HOME/Library/Caches/antidote/github.com/zdharma-continuum/fast-syntax-highlighting" )
zsh-defer source "$HOME/Library/Caches/antidote/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
if zshrc_has_n; then
  fpath+=( "$HOME/Library/Caches/antidote/github.com/torifat/nnvm" )
  zsh-defer source "$HOME/Library/Caches/antidote/github.com/torifat/nnvm/nnvm.plugin.zsh"
fi
fpath+=( "$HOME/Library/Caches/antidote/github.com/zsh-users/zsh-history-substring-search" )
source "$HOME/Library/Caches/antidote/github.com/zsh-users/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh"
