export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-fzf-history-search)
source "$ZSH/oh-my-zsh.sh"
eval "$(oh-my-posh init zsh)"