#!/bin/bash

set -e

# =========================
# HELPERS
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

# =========================
# CHECK WSL
# =========================

step "Verificando ambiente WSL"

if ! grep -qi microsoft /proc/version; then
    echo "❌ Este script foi feito para WSL."
    exit 1
fi

info "WSL detectado"

# =========================
# SYSTEMD (WSL2)
# =========================

step "Ativando systemd (se necessário)"

WSL_CONF="/etc/wsl.conf"

if ! grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
    sudo bash -c "cat > $WSL_CONF <<EOF
[boot]
systemd=true
EOF"

    info "systemd habilitado (reinicie o WSL depois se necessário)"
else
    info "systemd já habilitado"
fi

# =========================
# DEPENDÊNCIAS
# =========================

step "Atualizando sistema"

sudo apt-get update -y

step "Instalando dependências base"

sudo apt-get install -y ca-certificates curl gnupg

# =========================
# DOCKER INSTALL CHECK
# =========================

step "Verificando Docker"

if command -v docker >/dev/null 2>&1; then
    info "Docker já instalado"
else
    info "Instalando Docker..."

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh

    rm -f /tmp/get-docker.sh
fi

# =========================
# USER PERMISSIONS
# =========================

step "Configurando permissões do Docker"

if ! groups "$USER" | grep -q docker; then
    sudo usermod -aG docker "$USER"
    info "Usuário adicionado ao grupo docker (relogin necessário)"
else
    info "Usuário já está no grupo docker"
fi

# =========================
# START DOCKER
# =========================

step "Iniciando Docker"

sudo systemctl enable docker >/dev/null 2>&1 || true
sudo systemctl start docker >/dev/null 2>&1 || true

# =========================
# TESTE FINAL
# =========================

step "Testando instalação"

if docker info >/dev/null 2>&1; then
    info "Docker funcionando"
else
    echo "⚠️ Docker pode precisar de reinício do WSL"
fi

echo
echo "Rodando hello-world (opcional)..."

docker run hello-world || true

# =========================
# FINAL
# =========================

step "Finalizado"

echo "🎉 Docker instalado no WSL"
echo "👉 Se necessário, reinicie o WSL: wsl --shutdown"
