#!/usr/bin/env bash

set -euo pipefail

# =========================
# Defaults
# =========================
TARGET_PLATFORM="manylinux2014_x86_64"
PYTHON_VERSION="312"
IMPLEMENTATION="cp"
ABI=""

# =========================
# Helpers
# =========================
require_value() {
  [[ -n "${2:-}" ]] || { echo "Valor ausente para $1"; exit 1; }
}

usage() {
  echo "========================================"
  echo "Uso:"
  echo "  $0 <requirements.txt> [opções]"
  echo ""
  echo "Opções:"
  echo "  --platform           Plataforma alvo"
  echo "  --python-version     Versão do Python (ex: 312, 311)"
  echo "  --implementation     Implementação (default: cp)"
  echo "  --abi                ABI (default: auto)"
  echo "  -h, --help           Exibe ajuda"
  echo "========================================"
  exit 1
}

# =========================
# Parse args
# =========================
if [[ $# -lt 1 ]]; then
  usage
fi

REQUIREMENTS_FILE="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      require_value "$1" "${2:-}"
      TARGET_PLATFORM="$2"
      shift 2
      ;;
    --python-version)
      require_value "$1" "${2:-}"
      PYTHON_VERSION="$2"
      shift 2
      ;;
    --implementation)
      require_value "$1" "${2:-}"
      IMPLEMENTATION="$2"
      shift 2
      ;;
    --abi)
      require_value "$1" "${2:-}"
      ABI="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Argumento inválido: $1"
      usage
      ;;
  esac
done

# ABI default derivado
ABI="${ABI:-cp${PYTHON_VERSION}}"

# =========================
# Validações
# =========================
if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "========================================"
  echo "ERRO"
  echo "========================================"
  echo "Arquivo não encontrado: $REQUIREMENTS_FILE"
  exit 1
fi

if [[ ! "$PYTHON_VERSION" =~ ^[0-9]{3}$ ]]; then
  echo "PYTHON_VERSION inválido: $PYTHON_VERSION"
  exit 1
fi

OUTPUT_DIR="offline-packages"
WHEELS_DIR="${OUTPUT_DIR}/wheels"
ARCHIVE_NAME="offline-packages.tar.gz"

section() {
  echo ""
  echo "========================================"
  echo "$1"
  echo "========================================"
}

info() {
  echo "$1"
}

success() {
  echo "$1"
}

# =========================
# Execução
# =========================

section "Preparando diretórios"

info "Removendo diretório anterior: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"

info "Criando estrutura: $WHEELS_DIR"
mkdir -p "$WHEELS_DIR"

success "Diretórios prontos"

section "Configuração do ambiente alvo"

info "Platform: $TARGET_PLATFORM"
info "Python: $PYTHON_VERSION"
info "Implementation: $IMPLEMENTATION"
info "ABI: $ABI"

section "Preparando arquivos"

info "Copiando requirements"
cp "$REQUIREMENTS_FILE" "${OUTPUT_DIR}/requirements.txt"

success "Requirements copiado"

section "Download de dependências"

info "Baixando wheels compatíveis com o ambiente alvo"

pip download \
  --requirement "$REQUIREMENTS_FILE" \
  --dest "$WHEELS_DIR" \
  --only-binary=:all: \
  --platform "$TARGET_PLATFORM" \
  --python-version "$PYTHON_VERSION" \
  --implementation "$IMPLEMENTATION" \
  --abi "$ABI"

success "Download concluído"

section "Empacotamento"

info "Gerando arquivo: $ARCHIVE_NAME"
tar -czf "$ARCHIVE_NAME" "$OUTPUT_DIR"

if [[ ! -s "$ARCHIVE_NAME" ]]; then
  echo "Falha ao gerar o arquivo $ARCHIVE_NAME"
  exit 1
fi

success "Pacote gerado com sucesso"

section "Limpeza"

info "Removendo diretório temporário: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"

success "Diretório removido"

section "Finalizado"

echo "Arquivo gerado:"
echo "→ $ARCHIVE_NAME"
echo ""
