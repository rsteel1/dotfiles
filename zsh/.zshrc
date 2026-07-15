export PATH="$HOME/go/bin:/snap/bin:$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
# Auto-detect dotfiles dir (handles devcontainers + symlinks + copied files)
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    # Try sourced script location first (works even if copied)
    local zshrc_path="${(%):-%x}"
    if [[ -n "$zshrc_path" ]] && [[ -f "$zshrc_path" ]]; then
        export DOTFILES_DIR="$(cd "$(dirname "$zshrc_path")/.." && pwd)"
    # Fallback: try symlink resolution
    elif [[ -L "$HOME/.zshrc" ]]; then
        export DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$HOME/.zshrc")")/.." && pwd)"
    # Last resort: default location
    else
        export DOTFILES_DIR="$HOME/dotfiles"
    fi
fi
ZSH_THEME=""
plugins=(
  git
  bazel
  z
  sudo
  extract
  copypath
  aliases
  docker
  docker-compose
  python
  rust
  tmux
  git-auto-fetch
  web-search
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  zsh-fzf-history-search
)

# Keep init idempotent so `source ~/.zshrc` does not re-wrap ZLE widgets.
# Imported env can contain stale "loaded" flags without OMZ/OMP functions.
if [[ -n "${DOTFILES_OMZ_LOADED:-}" ]] && [[ -z "${functions[omz]:-}" ]]; then
    unset DOTFILES_OMZ_LOADED
fi

if [[ -z "${DOTFILES_OMZ_LOADED:-}" ]]; then
    source "$ZSH/oh-my-zsh.sh"
    typeset -g DOTFILES_OMZ_LOADED=1
fi

if [[ -n "${commands[bazelisk]:-}" ]] && [[ -n "${functions[_bazel]:-}" ]]; then
    compdef _bazel bazelisk
fi

if [[ -n "${DOTFILES_OMP_LOADED:-}" ]] && [[ -z "${functions[set_poshcontext]:-}" ]]; then
    unset DOTFILES_OMP_LOADED
fi

if [[ -z "${DOTFILES_OMP_LOADED:-}" ]] && command -v oh-my-posh >/dev/null 2>&1; then
    export POSH_CONFIG_FILE="${DOTFILES_DIR:-.}/zsh/config.omp.json"
    eval "$(oh-my-posh init zsh --config "$POSH_CONFIG_FILE")"
    typeset -g DOTFILES_OMP_LOADED=1
fi

if command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "tcpdump"; then
    echo "[INFO] Setting tcpdump AppArmor profile to complain mode (allows writing to Bazel sandbox)..."
    aa-complain /usr/bin/tcpdump 2>/dev/null || echo "[WARNING] Could not modify AppArmor profile"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
