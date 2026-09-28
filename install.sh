#!/usr/bin/env bash
# Usage: ./install.sh [--work]
#   --work  enable work-specific config (zsh/work.zsh) via ~/.zshrc.local
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
OS="$(uname -s)"

WORK=0
for arg in "$@"; do
  case "$arg" in
    --work) WORK=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

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

ensure_brew() {
  need_cmd brew && return
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { eval "$("$b" shellenv)"; return; }
  done
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { eval "$("$b" shellenv)"; return; }
  done
}

install_pkg() {
  case "$OS" in
    Darwin) brew install "$@" ;;
    Linux)  install_apt "$@" ;;
    *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
  esac
}

# Symlink, backing up any existing regular file
link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backed up existing $dst"
  fi
  ln -snf "$src" "$dst"
}

echo "[1/7] Ensure base packages"
[[ "$OS" == Darwin ]] && ensure_brew
need_cmd zsh  || install_pkg zsh
need_cmd git  || install_pkg git
need_cmd curl || install_pkg curl
need_cmd fzf  || install_pkg fzf
need_cmd tmux || install_pkg tmux
[[ "$OS" == Linux ]] && { need_cmd unzip || install_pkg unzip; }  # oh-my-posh installer needs it

echo "[2/7] Install Oh My Zsh (once)"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=yes KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

echo "[3/7] Install Oh My Zsh plugins (once)"
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

# Optional: a failure here shouldn't abort the rest of the setup
echo "[4/7] Install oh-my-posh (once)"
mkdir -p "$HOME/.local/bin"
if ! need_cmd oh-my-posh; then
  if [[ "$OS" == Darwin ]]; then
    brew install oh-my-posh || echo "  WARNING: oh-my-posh install failed"
  else
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" \
      || echo "  WARNING: oh-my-posh install failed"
  fi
fi

echo "[5/7] Link zsh dotfiles"
mkdir -p "$HOME/.config/oh-my-posh"
link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zsh/config.omp.json" "$HOME/.config/oh-my-posh/config.json"
[[ -f "$DOTFILES_DIR/zsh/.zprofile" ]] && link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"

echo "[6/7] Machine-local config"
touch "$HOME/.zshrc.local"
if [[ "$WORK" == 1 ]] && ! grep -q 'zsh/work.zsh' "$HOME/.zshrc.local"; then
  echo 'source "$DOTFILES_DIR/zsh/work.zsh"' >> "$HOME/.zshrc.local"
  echo "  enabled work config"
fi

echo "[7/7] Done"
echo "Open new terminal."
