# Work-specific config (Eclipse S-CORE / ETAS). Opt in per machine via ~/.zshrc.local:
#   source "$DOTFILES_DIR/zsh/work.zsh"

if command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "tcpdump"; then
    echo "[INFO] Setting tcpdump AppArmor profile to complain mode (allows writing to Bazel sandbox)..."
    aa-complain /usr/bin/tcpdump 2>/dev/null || echo "[WARNING] Could not modify AppArmor profile"
fi

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

docs() {
    local repo="${1:-.}"
    [[ "$repo" == "." ]] && repo=$(basename "$(pwd)")
    wslview "https://eclipse-score.github.io/$repo/main/"
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

# QNX SDP 8.0
export QNX_SDP_PATH="$HOME/qnx800"
export QNX_LICENSE_PATH="$HOME/.qnx/license"

# CDPATH breaks scripts using $(cd ... && pwd) command substitution
# export CDPATH=".:$HOME/repos/eclipse/score"
alias refresh-cc='bazel-compile-commands --targets //... && ~/bin/fix-compile-commands.sh'
