#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
  echo -e "${GREEN}✔ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
  echo -e "${RED}✖ $1${NC}"
}

check_venv() {
  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    return 0
  fi
  return 1
}

confirm_venv() {
  warn "Você NÃO está em um virtualenv"
  warn "Isso pode afetar o Python global do sistema"
  echo ""
  read -p "Deseja continuar mesmo assim? (s/n): " confirm1
  if [[ ! "$confirm1" =~ ^[Ss]$ ]]; then
    info "Operação cancelada."
    exit 0
  fi
  echo ""
  read -p "Digite 'CONFIRMAR' para confirmar: " confirm2
  if [[ "$confirm2" != "CONFIRMAR" ]]; then
    error "Confirmação inválida. Abortando."
    exit 1
  fi
  success "Confirmação aceita"
}

cmd_download() {
  local target_platform="manylinux2014_x86_64"
  local python_version="312"
  local implementation="cp"
  local abi=""

  require_value() {
    [[ -n "${2:-}" ]] || { echo "Valor ausente para $1"; exit 1; }
  }

  usage() {
    echo "Uso: $0 download <requirements.txt> [opções]"
    echo ""
    echo "Opções:"
    echo "  --platform           Plataforma alvo"
    echo "  --python-version     Versão do Python (ex: 312, 311)"
    echo "  --implementation     Implementação (default: cp)"
    echo "  --abi                ABI (default: auto)"
    echo "  -h, --help           Exibe ajuda"
    exit 1
  }

  if [[ $# -lt 1 ]]; then
    usage
  fi

  local requirements_file="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        require_value "$1" "${2:-}"
        target_platform="$2"
        shift 2
        ;;
      --python-version)
        require_value "$1" "${2:-}"
        python_version="$2"
        shift 2
        ;;
      --implementation)
        require_value "$1" "${2:-}"
        implementation="$2"
        shift 2
        ;;
      --abi)
        require_value "$1" "${2:-}"
        abi="$2"
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

  abi="${abi:-cp${python_version}}"

  if [[ ! -f "$requirements_file" ]]; then
    error "Arquivo não encontrado: $requirements_file"
    exit 1
  fi

  if [[ ! "$python_version" =~ ^[0-9]{3}$ ]]; then
    error "PYTHON_VERSION inválido: $python_version"
    exit 1
  fi

  local output_dir="offline-packages"
  local wheels_dir="${output_dir}/wheels"
  local archive_name="offline-packages.tar.gz"

  section "Preparando diretórios"
  info "Removendo diretório anterior: $output_dir"
  rm -rf "$output_dir"
  info "Criando estrutura: $wheels_dir"
  mkdir -p "$wheels_dir"
  success "Diretórios prontos"

  section "Configuração do ambiente alvo"
  info "Platform: $target_platform"
  info "Python: $python_version"
  info "Implementation: $implementation"
  info "ABI: $abi"

  section "Preparando arquivos"
  info "Copiando requirements"
  cp "$requirements_file" "${output_dir}/requirements.txt"
  success "Requirements copiado"

  section "Download de dependências"
  info "Baixando wheels compatíveis com o ambiente alvo"

  pip download \
    --requirement "$requirements_file" \
    --dest "$wheels_dir" \
    --only-binary=:all: \
    --platform "$target_platform" \
    --python-version "$python_version" \
    --implementation "$implementation" \
    --abi "$abi"

  success "Download concluído"

  section "Empacotamento"
  info "Gerando arquivo: $archive_name"
  tar -czf "$archive_name" "$output_dir"

  if [[ ! -s "$archive_name" ]]; then
    error "Falha ao gerar o arquivo $archive_name"
    exit 1
  fi

  success "Pacote gerado com sucesso"

  section "Limpeza"
  info "Removendo diretório temporário: $output_dir"
  rm -rf "$output_dir"
  success "Diretório removido"

  section "Finalizado"
  info "Arquivo gerado:"
  echo "→ $archive_name"
}

cmd_install() {
  if [[ $# -lt 1 ]]; then
    error "Uso: $0 install <caminho/do/pacote.tar.gz>"
    exit 1
  fi

  local package_file="$1"
  local work_dir="offline-install"

  cleanup() {
    if [[ -d "$work_dir" ]]; then
      rm -rf "$work_dir"
    fi
  }

  trap cleanup EXIT

  if [[ ! -f "$package_file" ]]; then
    error "Arquivo não encontrado: $package_file"
    exit 1
  fi

  section "Ambiente de execução"

  if check_venv; then
    success "Executando em virtualenv: $VIRTUAL_ENV"
  else
    warn "NÃO está em um virtualenv"
    warn "Isso irá instalar pacotes no Python global"
    confirm_venv
  fi

  section "Instalação offline"

  info "Usando pacote: $package_file"
  info "Preparando ambiente..."
  rm -rf "$work_dir"
  mkdir -p "$work_dir"

  info "Extraindo pacote..."
  tar -xzf "$package_file" -C "$work_dir"

  local base_dir="${work_dir}/offline-packages"
  local wheels_dir="${base_dir}/wheels"
  local req_file="${base_dir}/requirements.txt"

  if [[ ! -d "$wheels_dir" ]]; then
    error "Diretório de wheels não encontrado"
    exit 1
  fi

  if [[ ! -f "$req_file" ]]; then
    error "requirements.txt não encontrado"
    exit 1
  fi

  info "Instalando dependências offline..."

  if pip install \
    --no-index \
    --find-links="$wheels_dir" \
    --requirement "$req_file"; then

    success "Instalação concluída com sucesso"
  else
    error "Falha na instalação"
    exit 1
  fi

  section "Pacotes instalados"
  pip list
}

cmd_uninstall() {
  section "Ambiente"

  if check_venv; then
    success "Executando dentro de virtualenv"
    info "Path: $VIRTUAL_ENV"
  else
    confirm_venv
  fi

  section "Pacotes instalados"
  pip list
  echo ""

  warn "Todos os pacotes listados serão removidos"
  read -p "Deseja continuar? (s/n): " confirm

  if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    info "Operação cancelada."
    exit 0
  fi

  section "Remoção"

  info "Gerando lista de pacotes..."
  local packages
  packages=$(pip freeze | sed 's/@.*//' | sed 's/==.*//')

  if [[ -z "$packages" ]]; then
    warn "Nenhum pacote para remover"
    exit 0
  fi

  info "Removendo pacotes..."
  pip uninstall -y $packages

  success "Remoção concluída"

  section "Estado final"
  pip list

  success "Processo finalizado"
}

usage() {
  echo "Python Offline Libs Automation"
  echo ""
  echo "Uso: $0 <comando> [opções]"
  echo ""
  echo "Comandos:"
  echo "  download <requirements.txt> [opções]  Baixa e empacota dependências"
  echo "  install <pacote.tar.gz>               Instala pacotes offline"
  echo "  uninstall                              Remove todos os pacotes"
  echo ""
  echo "Opções de download:"
  echo "  --platform           Plataforma alvo (ex: manylinux2014_x86_64)"
  echo "  --python-version     Versão do Python (ex: 312, 311)"
  echo "  --implementation     Implementação (default: cp)"
  echo "  --abi                ABI (default: auto)"
  echo ""
  echo "Exemplos:"
  echo "  $0 download requirements.txt --platform manylinux2014_x86_64 --python-version 312"
  echo "  $0 install offline-packages.tar.gz"
  echo "  $0 uninstall"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    download)
      cmd_download "$@"
      ;;
    install)
      cmd_install "$@"
      ;;
    uninstall)
      cmd_uninstall
      ;;
    -h|--help)
      usage
      ;;
    *)
      error "Comando desconhecido: $command"
      echo ""
      usage
      exit 1
      ;;
  esac
}

main "$@"