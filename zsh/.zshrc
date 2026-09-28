# Homebrew (macOS: Apple Silicon or Intel; Linux: linuxbrew)
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$_brew" ]] && { eval "$("$_brew" shellenv)"; break; }
done
unset _brew

typeset -U path
path=("$HOME/go/bin" "$HOME/.local/bin" $path)
[[ -d /snap/bin ]] && path+=(/snap/bin)
export PATH

export ZSH="$HOME/.oh-my-zsh"
# Auto-detect dotfiles dir. Only accept a dir that actually contains the repo,
# so a stale inherited DOTFILES_DIR or a copied ~/.zshrc can't point elsewhere.
for _d in \
    "${DOTFILES_DIR:-}" \
    "${${:-$HOME/.zshrc}:A:h:h}" \
    "${${(%):-%x}:A:h:h}" \
    "$HOME/dotfiles"; do
    [[ -n "$_d" && -f "$_d/zsh/.zshrc" ]] && { export DOTFILES_DIR="$_d"; break; }
done
unset _d
ZSH_THEME=""
plugins=(
  git
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
(( $+commands[bazel] || $+commands[bazelisk] )) && plugins+=(bazel)

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
    unset POSH_CONFIG_FILE
    for _cfg in "${DOTFILES_DIR:-}/zsh/config.omp.json" "$HOME/.config/oh-my-posh/config.json"; do
        [[ -f "$_cfg" ]] && { export POSH_CONFIG_FILE="$_cfg"; break; }
    done
    unset _cfg
    if [[ -n "${POSH_CONFIG_FILE:-}" ]]; then
        eval "$(oh-my-posh init zsh --config "$POSH_CONFIG_FILE")"
    else
        eval "$(oh-my-posh init zsh)"
    fi
    typeset -g DOTFILES_OMP_LOADED=1
fi

# Terminal tab title = cwd
precmd_wt_title() {
    print -Pn "\e]0;%~\a"
}
# Only add once
[[ -z ${precmd_functions[(r)precmd_wt_title]} ]] && precmd_functions+=(precmd_wt_title)

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Persistent history (devcontainers may mount /commandhistory)
if [[ -d /commandhistory ]]; then
    export HISTFILE=/commandhistory/.zsh_history
else
    export HISTFILE="$HOME/.zsh_history"
fi
export HISTSIZE=50000
export SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Functions

update-repos() {
    local updated=()
    local skipped_dirty=()
    local skipped_conflict=()

    echo "Scanning for repos (maxdepth 3)..."

    find . -maxdepth 3 -name .git -type d | while read gitdir; do
    repo=$(dirname "$gitdir")
    echo "\nChecking $repo"

    if git -C "$repo" diff-index --quiet HEAD 2>/dev/null; then
        if git -C "$repo" pull --ff-only 2>&1; then
        echo "  ✓ Updated"
        updated+=("$repo")
        else
        echo "  ⚠️  Can't fast-forward"
        skipped_conflict+=("$repo")
        fi
    else
        echo "  ⚠️  Uncommitted changes, skipped"
        skipped_dirty+=("$repo")
    fi
    done

    echo "\n--- Summary ---"
    echo "Updated: ${#updated[@]}"
    echo "Skipped (dirty): ${#skipped_dirty[@]}"
    [ ${#skipped_dirty[@]} -gt 0 ] && printf '  %s\n' "${skipped_dirty[@]}"
    echo "Skipped (conflict): ${#skipped_conflict[@]}"
    [ ${#skipped_conflict[@]} -gt 0 ] && printf '  %s\n' "${skipped_conflict[@]}"
}

alias gho='gh browse'

retrigger-ci() {
    echo "Retriggering CI..."

    # Check if we're in a git repo
    if ! git status &>/dev/null; then
        echo "Error: Not in a git repository"
        return 1
    fi

    # Get current branch
    local current_branch=$(git branch --show-current)

    # Store current HEAD
    local original_head=$(git rev-parse HEAD)

    # Create empty commit
    git commit --allow-empty -m "Retrigger CI"

    # Push to trigger CI
    echo "Pushing empty commit..."
    if ! git push; then
        echo "Error: Failed to push"
        git reset --hard "$original_head"
        return 1
    fi

    # Revert to original state
    echo "Reverting to original state..."
    git reset --hard "$original_head"

    # Force push to remove the empty commit from history
    if ! git push --force; then
        echo "Error: Failed to force push. Empty commit remains in remote history."
        return 1
    fi

    echo "✓ CI retriggered successfully, no trace left in history"
}

# pyenv
if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi

# Machine-local overrides (untracked). Work machines: source "$DOTFILES_DIR/zsh/work.zsh" here.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
