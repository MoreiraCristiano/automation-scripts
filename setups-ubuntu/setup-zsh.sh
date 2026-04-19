#!/usr/bin/env bash

set -Eeuo pipefail

# =========================
# GLOBALS
# =========================

DRY_RUN=false
LOG_FILE="/tmp/bootstrap-zsh.log"

# =========================
# COLORS (TTY SAFE)
# =========================

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# =========================
# LOGGING
# =========================

log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp
  timestamp="$(date +'%Y-%m-%d %H:%M:%S')"

  echo -e "[$timestamp] [$level] $msg" >> "$LOG_FILE"

  case "$level" in
    INFO)  echo -e "${BLUE}ℹ${NC}  $msg" ;;
    OK)    echo -e "${GREEN}✔${NC}  $msg" ;;
    WARN)  echo -e "${YELLOW}⚠${NC}  $msg" ;;
    ERROR) echo -e "${RED}✖${NC}  $msg" ;;
    *)     echo -e "$msg" ;;
  esac
}

info()  { log INFO "$@"; }
ok()    { log OK "$@"; }
warn()  { log WARN "$@"; }
error() { log ERROR "$@"; }

# =========================
# SECTIONS (UX IMPORTANTE)
# =========================

section() {
  local title="$1"

  echo
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $title${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
}

# =========================
# ERROR HANDLING
# =========================

trap 'error "Erro na linha $LINENO: $BASH_COMMAND"' ERR

# =========================
# DRY RUN
# =========================

run() {
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$@"
  fi
}

# =========================
# RETRY
# =========================

retry() {
  local retries=3
  local delay=2
  local count=0

  until "$@"; do
    exit_code=$?
    count=$((count + 1))

    if [ $count -ge $retries ]; then
      error "Falhou após $count tentativas: $*"
      return $exit_code
    fi

    warn "Tentativa $count falhou. Retry em ${delay}s..."
    sleep $delay
    delay=$((delay * 2))
  done
}

# =========================
# DETECT OS
# =========================

detect_os() {
  section "Detectando sistema operacional"

  source /etc/os-release
  OS_ID="$ID"
  OS_VERSION="$VERSION_ID"

  info "OS: $OS_ID"
  info "Versão: $OS_VERSION"
}

# =========================
# APT
# =========================

configure_apt_mirror() {
  section "Configurando APT"

  if [[ "$OS_ID" == "ubuntu" && "$OS_VERSION" == "24.04" ]]; then
    info "Aplicando mirror UFPR"

    run "sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null << 'EOF'
Types: deb
URIs: http://ubuntu.c3sl.ufpr.br/ubuntu/
Suites: noble noble-updates noble-backports noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF"

    ok "Mirror configurado"
  else
    warn "Mirror ignorado (incompatível)"
  fi
}

force_ipv4() {
  info "Forçando IPv4"
  run "echo 'Acquire::ForceIPv4 \"true\";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 > /dev/null"
}

install_base_packages() {
  section "Instalação de pacotes"

  info "apt update"
  retry sudo apt update

  info "Instalando zsh, curl, git"
  retry sudo apt install -y zsh curl git

  ok "Dependências instaladas"
}

# =========================
# ZSH
# =========================

set_default_shell() {
  section "Configuração do Zsh"

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ -z "$zsh_path" ]]; then
    error "zsh não encontrado"
    exit 1
  fi

  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  if [[ "$current_shell" == "$zsh_path" ]]; then
    ok "Zsh já é padrão"
    return
  fi

  info "Alterando shell para $USER"
  run "chsh -s $zsh_path $USER"

  ok "Shell atualizado"
}

# =========================
# OH MY ZSH
# =========================

install_oh_my_zsh() {
  section "Oh My Zsh"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    warn "Removendo instalação anterior"
    run "rm -rf $HOME/.oh-my-zsh"
  fi

  info "Instalando Oh My Zsh"

  run "export RUNZSH=no CHSH=no; \
  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""

  ok "Oh My Zsh instalado"
}

# =========================
# PLUGINS
# =========================

install_plugin() {
  local name="$1"
  local repo="$2"
  local dir="$HOME/.oh-my-zsh/custom/plugins/$name"

  info "Plugin: $name"

  run "rm -rf $dir"
  retry git clone --depth=1 "$repo" "$dir"
}

setup_plugins() {
  section "Plugins"

  install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
  install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"

  ok "Plugins instalados"
}

# =========================
# THEME
# =========================

setup_theme() {
  section "Tema"

  local dir="$HOME/.oh-my-zsh/custom/themes"
  local file="$dir/meutema.zsh-theme"

  run "mkdir -p $dir"

  run "cat > $file << 'EOF'
virtualenv_prompt() {
  if [[ -n \"\$VIRTUAL_ENV\" ]]; then
    echo \"(\$(basename \"\$VIRTUAL_ENV\")) \"
  fi
}

PROMPT=\$'\\n\$(virtualenv_prompt)« %1~ »\\nλ '
EOF"

  ok "Tema criado"
}

# =========================
# ZSHRC
# =========================

setup_zshrc() {
  section ".zshrc"

  run "cat > $HOME/.zshrc << 'EOF'
export ZSH=\"$HOME/.oh-my-zsh\"
export VIRTUAL_ENV_DISABLE_PROMPT=1

ZSH_THEME=\"meutema\"
plugins=(zsh-autosuggestions zsh-syntax-highlighting)

alias k=kubectl

source \$ZSH/oh-my-zsh.sh
EOF"

  ok ".zshrc configurado"
}

# =========================
# GIT
# =========================

setup_git() {
  section "Git"

  run "git config --global alias.a 'add -A'"
  run "git config --global alias.s 'status'"
  run "git config --global alias.l 'log'"
  run "git config --global alias.c 'commit -m'"
  run "git config --global alias.pm 'push -uf origin main'"

  ok "Git configurado"
}

# =========================
# ARGS
# =========================

parse_args() {
  for arg in "$@"; do
    case $arg in
      --dry-run) DRY_RUN=true ;;
    esac
  done
}

# =========================
# MAIN
# =========================

main() {
  parse_args "$@"

  section "Bootstrap Zsh"

  info "Dry-run: $DRY_RUN"
  info "Log: $LOG_FILE"

  detect_os
  configure_apt_mirror
  force_ipv4
  install_base_packages
  set_default_shell
  install_oh_my_zsh
  setup_plugins
  setup_theme
  setup_zshrc
  setup_git

  section "Finalizado"
  ok "Ambiente pronto 🚀"
}

main "$@"
