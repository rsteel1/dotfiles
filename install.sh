#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_apt() {
  if need_cmd sudo; then
    sudo apt-get update
    sudo apt-get install -y "$@"
  else
    apt-get update
    apt-get install -y "$@"
  fi
}

echo "[1/6] Ensure base packages"
need_cmd zsh  || install_apt zsh
need_cmd git  || install_apt git
need_cmd curl || install_apt curl
need_cmd fzf  || install_apt fzf

echo "[2/6] Install Oh My Zsh (once)"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=yes KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

echo "[3/6] Install oh-my-posh (once)"
mkdir -p "$HOME/.local/bin"
if ! need_cmd oh-my-posh; then
  curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
fi

echo "[4/6] Link zsh dotfiles"
ln -snf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
[[ -f "$DOTFILES_DIR/zsh/.zprofile" ]] && ln -snf "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"

echo "[5/6] Install Oh My Zsh plugins (once)"
mkdir -p "$ZSH_CUSTOM/plugins"

[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-fzf-history-search" ]] || \
  git clone --depth=1 https://github.com/joshskidmore/zsh-fzf-history-search \
    "$ZSH_CUSTOM/plugins/zsh-fzf-history-search"

echo "[6/6] Done"
echo "Open new terminal."