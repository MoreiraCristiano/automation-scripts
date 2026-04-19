#!/usr/bin/env bash

set -euo pipefail

echo "=========================================="
echo "Instalação offline de pacotes Python"
echo "=========================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =========================
# Validação de argumento
# =========================
if [[ $# -lt 1 ]]; then
  echo -e "${RED}Uso: $0 <caminho/do/pacote.tar.gz>${NC}"
  exit 1
fi

PACKAGE_FILE="$1"
WORK_DIR="offline-install"

cleanup() {
  if [[ -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

trap cleanup EXIT

# =========================
# Validações
# =========================
if [[ ! -f "$PACKAGE_FILE" ]]; then
  echo -e "${RED}Arquivo não encontrado: $PACKAGE_FILE${NC}"
  exit 1
fi

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  echo -e "${RED}Erro: você não está em um virtualenv.${NC}"
  echo "Ative um ambiente virtual antes de continuar."
  exit 1
fi

# =========================
# Execução
# =========================
echo -e "${YELLOW}[INFO] Usando pacote: $PACKAGE_FILE${NC}"

echo -e "${YELLOW}[INFO] Preparando ambiente...${NC}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo -e "${YELLOW}[INFO] Extraindo pacote...${NC}"
tar -xzf "$PACKAGE_FILE" -C "$WORK_DIR"

BASE_DIR="${WORK_DIR}/offline-packages"
WHEELS_DIR="${BASE_DIR}/wheels"
REQ_FILE="${BASE_DIR}/requirements.txt"

if [[ ! -d "$WHEELS_DIR" ]]; then
  echo -e "${RED}Diretório de wheels não encontrado${NC}"
  exit 1
fi

if [[ ! -f "$REQ_FILE" ]]; then
  echo -e "${RED}requirements.txt não encontrado${NC}"
  exit 1
fi

echo -e "${YELLOW}[INFO] Instalando dependências offline...${NC}"

if pip install \
  --no-index \
  --find-links="$WHEELS_DIR" \
  --requirement "$REQ_FILE"; then

  echo -e "${GREEN}Instalação concluída com sucesso${NC}"
else
  echo -e "${RED}Falha na instalação${NC}"
  exit 1
fi

echo ""
echo "=========================================="
echo "Pacotes instalados:"
pip list
echo "=========================================="

exit 0
