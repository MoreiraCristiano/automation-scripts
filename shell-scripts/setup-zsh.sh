#!/bin/bash

set -e

# =========================
# HELPERS
# =========================

step() {
    echo
    echo "=================================================="
    echo "🚀 $1"
    echo "=================================================="
    echo
}

info() {
    echo "🔹 $1"
}

# =========================
# CONFIG
# =========================

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSHRC="$HOME/.zshrc"

ZSH_PATH="$(which zsh)"

# =========================
# RESET (DETERMINÍSTICO)
# =========================

step "Resetando ambiente Zsh (modo idempotente total)"

rm -rf "$OH_MY_ZSH_DIR"
rm -f "$ZSHRC"

# remove plugins customizados também
rm -rf "$HOME/.oh-my-zsh-custom"

info "Estado anterior removido"

# =========================
# SISTEMA
# =========================

step "Atualizando sistema"

sudo apt update -y
sudo apt upgrade -y

step "Instalando dependências"

sudo apt install -y zsh curl git

info "Zsh: $ZSH_PATH"

# =========================
# SHELL PADRÃO
# =========================

step "Definindo Zsh como shell padrão (seguro)"

for user in $(cut -d: -f1 /etc/passwd); do
    if getent passwd "$user" | grep -q "$ZSH_PATH"; then
        continue
    fi

    sudo chsh -s "$ZSH_PATH" "$user" 2>/dev/null || true
done

# =========================
# OH MY ZSH (FORÇADO LIMPO)
# =========================

step "Instalando Oh My Zsh (fresh install)"

export RUNZSH=no
export CHSH=no

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# =========================
# PLUGINS (DETACHED DIR PADRÃO)
# =========================

step "Instalando plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGIN_DIR="$ZSH_CUSTOM/plugins"

mkdir -p "$PLUGIN_DIR"

install_plugin () {
    local name=$1
    local repo=$2
    local path="$PLUGIN_DIR/$name"

    rm -rf "$path"
    git clone --depth=1 "$repo" "$path"
}

install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"

# =========================
# TEMA (FORÇADO LIMPO)
# =========================

step "Criando tema customizado"

THEME_DIR="$HOME/.oh-my-zsh/custom/themes"
THEME_FILE="$THEME_DIR/meutema.zsh-theme"

mkdir -p "$THEME_DIR"

cat > "$THEME_FILE" << 'EOF'
# =========================
# VIRTUALENV
# =========================

virtualenv_prompt() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "($(basename "$VIRTUAL_ENV")) "
  fi
}

# =========================
# PROMPT
# =========================

PROMPT=$'\n$(virtualenv_prompt)« %1~ »\nλ '
EOF

# =========================
# .ZSHRC (100% DETERMINÍSTICO)
# =========================

step "Criando .zshrc"

cat > "$ZSHRC" << 'EOF'
# =========================
# OH MY ZSH
# =========================

export ZSH="$HOME/.oh-my-zsh"

export VIRTUAL_ENV_DISABLE_PROMPT=1

ZSH_THEME="meutema"

plugins=(zsh-autosuggestions zsh-syntax-highlighting)

alias k=kubectl

source $ZSH/oh-my-zsh.sh
EOF

# =========================
# GIT CONFIG (FORÇADO)
# =========================

step "Configurando git aliases (reset)"

git config --global alias.a "add -A"
git config --global alias.l "log"
git config --global alias.s "status"
git config --global alias.c "commit -m"
git config --global alias.pm "push -uf origin main"

# =========================
# FINAL
# =========================

step "Finalizado"

echo "Ambiente Zsh resetado e recriado com sucesso!"
