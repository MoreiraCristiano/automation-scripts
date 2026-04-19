#!/usr/bin/env bash

set -euo pipefail

echo "=========================================="
echo "🧹 Remoção de pacotes Python"
echo "=========================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

section() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

info() {
  echo "→ $1"
}

success() {
  echo -e "${GREEN}✔ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
  echo -e "${RED}✖ $1${NC}"
}

# =========================
# Detecção de ambiente
# =========================
IN_VENV=false

if [[ -n "${VIRTUAL_ENV:-}" ]]; then
  IN_VENV=true
fi

section "Ambiente"

if $IN_VENV; then
  success "Executando dentro de virtualenv"
  info "Path: $VIRTUAL_ENV"
else
  warn "Você NÃO está em um virtualenv"
  warn "Isso pode afetar o Python global do sistema"

  echo ""
  read -p "Deseja continuar mesmo assim? (s/n): " confirm1

  if [[ ! "$confirm1" =~ ^[Ss]$ ]]; then
    echo "Operação cancelada."
    exit 0
  fi

  echo ""
  read -p "Digite 'REMOVER GLOBAL' para confirmar: " confirm2

  if [[ "$confirm2" != "REMOVER GLOBAL" ]]; then
    error "Confirmação inválida. Abortando."
    exit 1
  fi

  success "Confirmação avançada aceita"
fi

# =========================
# Listagem
# =========================
section "Pacotes instalados"

pip list
echo ""

# =========================
# Confirmação final
# =========================
warn "Todos os pacotes listados serão removidos"

read -p "Deseja continuar? (s/n): " confirm

if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
  echo "Operação cancelada."
  exit 0
fi

# =========================
# Remoção
# =========================
section "Remoção"

info "Gerando lista de pacotes..."

PACKAGES=$(pip freeze | sed 's/@.*//' | sed 's/==.*//')

if [[ -z "$PACKAGES" ]]; then
  warn "Nenhum pacote para remover"
  exit 0
fi

info "Removendo pacotes..."

# shellcheck disable=SC2086
pip uninstall -y $PACKAGES

success "Remoção concluída"

# =========================
# Resultado
# =========================
section "Estado final"

pip list

success "Processo finalizado"
