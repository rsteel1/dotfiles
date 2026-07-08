export PATH="$HOME/go/bin:/snap/bin:$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git bazel zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-fzf-history-search)

# Keep init idempotent so `source ~/.zshrc` does not re-wrap ZLE widgets.
if [[ -z "${DOTFILES_OMZ_LOADED:-}" ]]; then
    source "$ZSH/oh-my-zsh.sh"
    export DOTFILES_OMZ_LOADED=1
fi

if [[ -n "${commands[bazelisk]:-}" ]] && [[ -n "${functions[_bazel]:-}" ]]; then
    compdef _bazel bazelisk
fi

if [[ -z "${DOTFILES_OMP_LOADED:-}" ]] && command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init zsh)"
    export DOTFILES_OMP_LOADED=1
fi

if command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "tcpdump"; then
    echo "[INFO] Setting tcpdump AppArmor profile to complain mode (allows writing to Bazel sandbox)..."
    aa-complain /usr/bin/tcpdump 2>/dev/null || echo "[WARNING] Could not modify AppArmor profile"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
