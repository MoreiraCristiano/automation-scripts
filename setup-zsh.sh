#!/bin/bash

set -e

# =========================
# HELPERS VISUAIS
# =========================

step() {
    echo
    echo "=================================================="
    echo "👉 $1"
    echo "=================================================="
    echo
}

info() {
    echo "🔹 $1"
}

success() {
    echo "✅ $1"
}

# =========================
# UPDATE SISTEMA
# =========================

step "Atualizando sistema"

sudo apt update -y
sudo apt upgrade -y

# =========================
# DEPENDÊNCIAS
# =========================

step "Instalando dependências"

sudo apt install -y zsh curl git

ZSH_PATH=$(which zsh)
info "Zsh: $ZSH_PATH"

# =========================
# DEFINIR SHELL PADRÃO
# =========================

step "Definindo Zsh como shell padrão"

for user in $(cut -d: -f1 /etc/passwd); do
    sudo chsh -s "$ZSH_PATH" "$user" 2>/dev/null || true
done

success "Shell padrão configurado"

# =========================
# OH MY ZSH
# =========================

step "Oh My Zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Instalando Oh My Zsh..."
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    success "Oh My Zsh já instalado"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGIN_DIR="$ZSH_CUSTOM/plugins"

mkdir -p "$PLUGIN_DIR"

# =========================
# PLUGINS
# =========================

step "Instalando plugins"

install_plugin () {
    local name=$1
    local repo=$2
    local path="$PLUGIN_DIR/$name"

    if [ ! -d "$path" ]; then
        info "Instalando $name..."
        git clone "$repo" "$path"
    else
        info "Atualizando $name..."
        git -C "$path" pull --quiet || true
    fi
}

install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"

# =========================
# TEMA CUSTOMIZADO
# =========================

step "Criando tema customizado"

THEME_NAME="meutema"
THEME_DIR="$HOME/.oh-my-zsh/custom/themes"
THEME_FILE="$THEME_DIR/$THEME_NAME.zsh-theme"

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

success "Tema criado"

# =========================
# ZSHRC
# =========================

step "Configurando .zshrc"

ZSHRC="$HOME/.zshrc"

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

success ".zshrc configurado"

# =========================
# GIT CONFIG
# =========================

step "Configurando git aliases"

git config --global alias.a "add -A"
git config --global alias.l "log"
git config --global alias.s "status"
git config --global alias.c "commit -m"
git config --global alias.pm "push -uf origin main"

# =========================
# FINAL
# =========================

step "Finalizado"

echo "🎉 Tudo pronto!"
echo "👉 Rode: exec zsh"
