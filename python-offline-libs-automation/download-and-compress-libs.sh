#!/usr/bin/env bash

set -euo pipefail

REQUIREMENTS_FILE="${1:-}"

if [[ -z "$REQUIREMENTS_FILE" || ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "========================================"
  echo "ERRO"
  echo "========================================"
  echo "Uso: $0 <requirements.txt>"
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

section "Preparando arquivos"

info "Copiando requirements"
cp "$REQUIREMENTS_FILE" "${OUTPUT_DIR}/requirements.txt"

success "Requirements copiado"

section "Download de dependências"

info "Baixando wheels (somente binários)"

pip download \
  --requirement "$REQUIREMENTS_FILE" \
  --dest "$WHEELS_DIR" \
  --only-binary=:all:

success "Download concluído"

section "Empacotamento"

info "Gerando arquivo: $ARCHIVE_NAME"
tar -czf "$ARCHIVE_NAME" "$OUTPUT_DIR"

success "Pacote gerado com sucesso"

section "Limpeza"

info "Removendo diretório temporário: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"

success "Diretório removido"

section "Finalizado"

echo "Arquivo gerado:"
echo "→ $ARCHIVE_NAME"
echo ""
