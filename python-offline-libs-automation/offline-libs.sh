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
  warn "You are NOT in a virtualenv"
  warn "This will install packages in the global Python"
  echo ""
  read -p "Continue anyway? (y/n): " confirm1
  if [[ ! "$confirm1" =~ ^[Yy]$ ]]; then
    info "Operation cancelled."
    exit 0
  fi
  echo ""
  read -p "Type 'CONFIRM' to confirm: " confirm2
  if [[ "$confirm2" != "CONFIRM" ]]; then
    error "Invalid confirmation. Aborting."
    exit 1
  fi
  success "Confirmation accepted"
}

cmd_download() {
  local target_platform="manylinux2014_x86_64"
  local python_version="312"
  local implementation="cp"
  local abi=""

  require_value() {
    [[ -n "${2:-}" ]] || { echo "Missing value for $1"; exit 1; }
  }

  usage() {
    echo "Usage: $0 download <requirements.txt> [options]"
    echo ""
    echo "Options:"
    echo "  --platform           Target platform"
    echo "  --python-version     Python version (e.g., 312, 311)"
    echo "  --implementation     Implementation (default: cp)"
    echo "  --abi                ABI (default: auto)"
    echo "  -h, --help           Show help"
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
        echo "Invalid argument: $1"
        usage
        ;;
    esac
  done

  abi="${abi:-cp${python_version}}"

  if [[ ! -f "$requirements_file" ]]; then
    error "File not found: $requirements_file"
    exit 1
  fi

  if [[ ! "$python_version" =~ ^[0-9]{3}$ ]]; then
    error "Invalid PYTHON_VERSION: $python_version"
    exit 1
  fi

  local output_dir="offline-packages"
  local wheels_dir="${output_dir}/wheels"
  local archive_name="offline-packages.tar.gz"

  section "Preparing directories"
  info "Removing previous directory: $output_dir"
  rm -rf "$output_dir"
  info "Creating structure: $wheels_dir"
  mkdir -p "$wheels_dir"
  success "Directories ready"

  section "Target environment config"
  info "Platform: $target_platform"
  info "Python: $python_version"
  info "Implementation: $implementation"
  info "ABI: $abi"

  section "Preparing files"
  info "Copying requirements"
  cp "$requirements_file" "${output_dir}/requirements.txt"
  success "Requirements copied"

  section "Downloading dependencies"
  info "Downloading wheels compatible with target environment"

  pip download \
    --requirement "$requirements_file" \
    --dest "$wheels_dir" \
    --only-binary=:all: \
    --platform "$target_platform" \
    --python-version "$python_version" \
    --implementation "$implementation" \
    --abi "$abi"

  success "Download completed"

  section "Packaging"
  info "Generating archive: $archive_name"
  tar -czf "$archive_name" "$output_dir"

  if [[ ! -s "$archive_name" ]]; then
    error "Failed to generate $archive_name"
    exit 1
  fi

  success "Package generated successfully"

  section "Cleanup"
  info "Removing temporary directory: $output_dir"
  rm -rf "$output_dir"
  success "Directory removed"

  section "Done"
  info "Generated file:"
  echo "→ $archive_name"
}

cmd_install() {
  if [[ $# -lt 1 ]]; then
    error "Usage: $0 install <path/to/package.tar.gz>"
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
    error "File not found: $package_file"
    exit 1
  fi

  section "Execution environment"

  if check_venv; then
    success "Running in virtualenv: $VIRTUAL_ENV"
  else
    warn "NOT in a virtualenv"
    warn "This will install packages in the global Python"
    confirm_venv
  fi

  section "Offline installation"

  info "Using package: $package_file"
  info "Preparing environment..."
  rm -rf "$work_dir"
  mkdir -p "$work_dir"

  info "Extracting package..."
  tar -xzf "$package_file" -C "$work_dir"

  local base_dir="${work_dir}/offline-packages"
  local wheels_dir="${base_dir}/wheels"
  local req_file="${base_dir}/requirements.txt"

  if [[ ! -d "$wheels_dir" ]]; then
    error "Wheels directory not found"
    exit 1
  fi

  if [[ ! -f "$req_file" ]]; then
    error "requirements.txt not found"
    exit 1
  fi

  info "Installing dependencies offline..."

  if pip install \
    --no-index \
    --find-links="$wheels_dir" \
    --requirement "$req_file"; then

    success "Installation completed successfully"
  else
    error "Installation failed"
    exit 1
  fi

  section "Installed packages"
  pip list
}

cmd_uninstall() {
  section "Environment"

  if check_venv; then
    success "Running in virtualenv"
    info "Path: $VIRTUAL_ENV"
  else
    confirm_venv
  fi

  section "Installed packages"
  pip list
  echo ""

  warn "All listed packages will be removed"
  read -p "Continue? (y/n): " confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "Operation cancelled."
    exit 0
  fi

  section "Uninstalling"

  info "Generating package list..."
  local packages
  packages=$(pip freeze | sed 's/@.*//' | sed 's/==.*//')

  if [[ -z "$packages" ]]; then
    warn "No packages to remove"
    exit 0
  fi

  info "Removing packages..."
  pip uninstall -y $packages

  success "Uninstall completed"

  section "Final state"
  pip list

  success "Process completed"
}

usage() {
  echo "Python Offline Libs Automation"
  echo ""
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  download <requirements.txt> [options]  Download and package dependencies"
  echo "  install <package.tar.gz>               Install packages offline"
  echo "  uninstall                                Remove all packages"
  echo ""
  echo "Download options:"
  echo "  --platform           Target platform (e.g., manylinux2014_x86_64)"
  echo "  --python-version     Python version (e.g., 312, 311)"
  echo "  --implementation     Implementation (default: cp)"
  echo "  --abi                ABI (default: auto)"
  echo ""
  echo "Examples:"
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
      error "Unknown command: $command"
      echo ""
      usage
      exit 1
      ;;
  esac
}

main "$@"