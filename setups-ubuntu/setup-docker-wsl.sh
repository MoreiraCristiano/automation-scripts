#!/bin/bash

set -e

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

step "Checking WSL environment"

if ! grep -qi microsoft /proc/version; then
    echo "❌ This script is designed for WSL."
    exit 1
fi

info "WSL detected"

step "Enabling systemd (if needed)"

WSL_CONF="/etc/wsl.conf"

if ! grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
    sudo bash -c "cat > $WSL_CONF <<EOF
[boot]
systemd=true
EOF"

    info "systemd enabled (restart WSL if needed)"
else
    info "systemd already enabled"
fi

step "Updating system"

sudo apt-get update -y

step "Installing base dependencies"

sudo apt-get install -y ca-certificates curl gnupg

step "Checking Docker"

if command -v docker >/dev/null 2>&1; then
    info "Docker already installed"
else
    info "Installing Docker..."

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh

    rm -f /tmp/get-docker.sh
fi

step "Configuring Docker permissions"

if ! groups "$USER" | grep -q docker; then
    sudo usermod -aG docker "$USER"
    info "User added to docker group (relogin required)"
else
    info "User already in docker group"
fi

step "Starting Docker"

sudo systemctl enable docker >/dev/null 2>&1 || true
sudo systemctl start docker >/dev/null 2>&1 || true

step "Testing installation"

if docker info >/dev/null 2>&1; then
    info "Docker is running"
else
    echo "⚠️ Docker may need WSL restart"
fi

echo
echo "Running hello-world (optional)..."

docker run hello-world || true

step "Done"

echo "🎉 Docker installed on WSL"
echo "👉 If needed, restart WSL: wsl --shutdown"