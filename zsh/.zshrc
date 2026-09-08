export PATH="$HOME/go/bin:/snap/bin:$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
# Auto-detect dotfiles dir (handles devcontainers + symlinks + copied files)
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    local zshrc_path="${(%):-%x}"
    # Try symlink resolution first
    if [[ -L "$HOME/.zshrc" ]]; then
        export DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$HOME/.zshrc")")/.." && pwd)"
    # Fallback: Try sourced script location (works even if copied)
    elif [[ -n "$zshrc_path" ]] && [[ -f "$zshrc_path" ]]; then
        export DOTFILES_DIR="$(cd "$(dirname "$zshrc_path")/.." && pwd)"
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

# Windows Terminal tab title (WSL workaround)
precmd_wt_title() {
    print -Pn "\e]0;%~\a"
}
# Only add once
[[ -z ${precmd_functions[(r)precmd_wt_title]} ]] && precmd_functions+=(precmd_wt_title)

if command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "tcpdump"; then
    echo "[INFO] Setting tcpdump AppArmor profile to complain mode (allows writing to Bazel sandbox)..."
    aa-complain /usr/bin/tcpdump 2>/dev/null || echo "[WARNING] Could not modify AppArmor profile"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Persistent history (devcontainer s-core-local feature uses /commandhistory)
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

ghe() {
    local repo="${1:-.}"

    if [[ "$repo" == "." ]]; then
        # Use upstream if exists, else extract repo name from origin
        if git remote get-url upstream &>/dev/null; then
            gh browse --remote upstream
        else
            repo=$(basename "$(pwd)")
            gh browse --repo eclipse-score/"$repo"
        fi
    else
        gh browse --repo eclipse-score/"$repo"
    fi
}

ghea() {
    local repo="${1:-.}"

    if [[ "$repo" == "." ]]; then
        # Use origin, auto-detects etas-contrib or etas-eng
        gh browse --remote origin
    else
        # Manual name: check if it has underscore (full name) or needs score_ prefix
        [[ "$repo" != *"_"* ]] && repo="score_$repo"
        gh browse --repo etas-contrib/"$repo"
    fi
}

alias gho='gh browse'

docs() {
    local repo="${1:-.}"
    [[ "$repo" == "." ]] && repo=$(basename "$(pwd)")
    wslview "https://eclipse-score.github.io/$repo/main/"
}

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

# Open VS Code workspace from ~/repos (matched by dir basename, falling back to substring match).
# For score repos with no existing workspace file, auto-generate one that
# bundles module_template/score/process_description alongside the repo.
SCORE_ROOT="$HOME/repos/eclipse/score"
SCORE_EXTRA_REPOS=(module_template score process_description)
WORKSPACES_DIR="$HOME/repos"

ws() {
    local dir="${1:-.}"
    local abs base ws
    abs=$(realpath "$dir" 2>/dev/null) || abs="$dir"
    base=$(basename "$abs")

    if [[ -d "$WORKSPACES_DIR" ]]; then
        ws="$WORKSPACES_DIR/$base.code-workspace"
        [[ -f "$ws" ]] || ws=$(find "$WORKSPACES_DIR" -maxdepth 1 -iname "*$base*.code-workspace" -print -quit 2>/dev/null)
    fi

    if [[ -z "$ws" && "$abs" == "$SCORE_ROOT"/* ]]; then
        mkdir -p "$WORKSPACES_DIR"
        ws="$WORKSPACES_DIR/$base.code-workspace"
        # Paths relative to workspace file location
        local relpath=$(realpath --relative-to="$WORKSPACES_DIR" "$abs")
        local folders="{\"path\":\"$relpath\"}"
        for extra in "${SCORE_EXTRA_REPOS[@]}"; do
            [[ "$extra" == "$base" ]] && continue
            if [[ -d "$SCORE_ROOT/$extra" ]]; then
                local extra_rel=$(realpath --relative-to="$WORKSPACES_DIR" "$SCORE_ROOT/$extra")
                folders+=",{\"path\":\"$extra_rel\"}"
            fi
        done
        printf '{"folders":[%s],"settings":{}}\n' "$folders" > "$ws"
    fi

    if [[ -n "$ws" && -f "$ws" ]]; then
        command code "$ws" "${@:2}"
    else
        command code "$@"
    fi
}

# Build ETAS SDK and deploy to prod_mvp
build-sdk-prod() {
    local arch="${1:-linux-x86_64}"
    local ref_int="/home/str1yok/repos/etas/score/reference_integration"
    local prod_mvp="/home/str1yok/repos/etas/vsps/prod_mvp/sdk/etas_vsps_gp"

    echo "Building SDK for $arch..."
    (cd "$ref_int" && ./etas/sdk/build_sdk_local.sh "$arch") || return 1

    echo "Deploying to prod_mvp..."
    mkdir -p "$prod_mvp"
    # Remove SDK contents, preserve README.md and user files
    rm -rf "$prod_mvp"/{BUILD.bazel,MODULE.bazel,bzl,metadata,include,lib,rlib,bin,examples,linux-*,qnx-*}
    tar -xzf "$ref_int/artifacts/vsps_gp_sdk.tar.gz" -C "$prod_mvp"

    echo "SDK deployed: $prod_mvp"
}

# pyenv
if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi
export CDPATH=".:$HOME/repos/eclipse/score"
alias refresh-cc='bazel-compile-commands --targets //... && ~/bin/fix-compile-commands.sh'
