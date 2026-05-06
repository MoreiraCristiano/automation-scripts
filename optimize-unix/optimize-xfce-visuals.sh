#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
RESTART_WM=false

log() {
  printf "\n==== %s ====\n" "$1"
}

info() {
  printf "INFO: %s\n" "$1"
}

warn() {
  printf "WARN: %s\n" "$1"
}

error() {
  printf "ERRO: %s\n" "$1" >&2
}

usage() {
  cat <<'EOF'
Uso:
  ./optimize-xfce-visuals.sh [opções]

Opções:
  --dry-run       Mostra o que seria alterado, sem aplicar mudanças
  --restart-wm    Reinicia o xfwm4 após aplicar alterações
  -h, --help      Mostra esta ajuda

Exemplos:
  ./optimize-xfce-visuals.sh
  ./optimize-xfce-visuals.sh --dry-run
  ./optimize-xfce-visuals.sh --restart-wm
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --restart-wm)
        RESTART_WM=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Argumento inválido: $1"
        usage
        exit 1
        ;;
    esac
  done
}

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "comando não encontrado: $cmd"
    echo "Instale com:"
    echo "  sudo apt update"
    echo "  sudo apt install xfconf"
    exit 1
  fi
}

is_xfce_session() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *XFCE* ]] || [[ "${DESKTOP_SESSION:-}" == *xfce* ]]
}

property_exists() {
  local channel="$1"
  local property="$2"

  xfconf-query -c "$channel" -p "$property" >/dev/null 2>&1
}

get_xfce() {
  local channel="$1"
  local property="$2"

  xfconf-query -c "$channel" -p "$property" 2>/dev/null || true
}

set_xfce() {
  local channel="$1"
  local property="$2"
  local type="$3"
  local value="$4"
  local current_value

  if ! property_exists "$channel" "$property"; then
    warn "Ignorado: $channel $property não existe"
    return 0
  fi

  current_value="$(get_xfce "$channel" "$property")"

  if [[ "$current_value" == "$value" ]]; then
    info "Sem mudança: $channel $property já está em $value"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "DRY-RUN: $channel $property: $current_value -> $value"
    return 0
  fi

  xfconf-query \
    -c "$channel" \
    -p "$property" \
    --type "$type" \
    --set "$value"

  info "OK: $channel $property: $current_value -> $value"
}

restart_xfwm4() {
  if [[ "$RESTART_WM" != true ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "DRY-RUN: reiniciaria xfwm4"
    return 0
  fi

  if command -v xfwm4 >/dev/null 2>&1; then
    log "Reiniciando xfwm4"
    xfwm4 --replace >/dev/null 2>&1 &
    info "xfwm4 reiniciado"
  else
    warn "xfwm4 não encontrado; reinício ignorado"
  fi
}

main() {
  parse_args "$@"

  require_command xfconf-query

  if ! is_xfce_session; then
    warn "Sessão XFCE não detectada."
    warn "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-indefinido}"
    warn "DESKTOP_SESSION=${DESKTOP_SESSION:-indefinido}"
    warn "Continuando mesmo assim."
  fi

  log "Reduzindo efeitos visuais do XFCE"

  set_xfce xfwm4 /general/use_compositing bool false
  set_xfce xfwm4 /general/frame_opacity int 100
  set_xfce xfwm4 /general/inactive_opacity int 100
  set_xfce xfwm4 /general/move_opacity int 100
  set_xfce xfwm4 /general/resize_opacity int 100
  set_xfce xfwm4 /general/popup_opacity int 100

  log "Reduzindo efeitos do terminal XFCE"

  set_xfce xfce4-terminal /misc-background-mode string TERMINAL_BACKGROUND_SOLID
  set_xfce xfce4-terminal /misc-background-opacity int 100

  restart_xfwm4

  log "Finalizado"

  if [[ "$DRY_RUN" == true ]]; then
    echo "Nenhuma alteração foi aplicada."
  else
    echo "Reduções visuais aplicadas no XFCE/Kali."
    echo "Se o compositor estava ativo, as mudanças já devem ser perceptíveis."
  fi
}

main "$@"
