#!/usr/bin/env bash
set -euo pipefail

echo "Installing docker, docker-compose and adding ${USER} to docker group"

pkgs=()

pacman -Q docker >/dev/null 2>&1 || pkgs+=(docker)
pacman -Q docker-compose >/dev/null 2>&1 || pkgs+=(docker-compose)

if ((${#pkgs[@]})); then
    sudo pacman -Syu --noconfirm "${pkgs[@]}"
fi

sudo systemctl enable --now docker.service

if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "Log out and back in to use docker without sudo."
fi

docker --version
