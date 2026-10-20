#!/usr/bin/env bash
# Установка Docker Engine + Compose v2 на Ubuntu 22.04 (по официальной инструкции docs.docker.com).
# Пакет docker.io из apt НЕ подходит: в нём нет compose-плагина v2.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; else SUDO=""; fi

if docker compose version >/dev/null 2>&1; then
  echo "Docker Compose уже установлен: $(docker compose version --short)"
  exit 0
fi

. /etc/os-release
[ "$ID" = "ubuntu" ] || { echo "Скрипт рассчитан на Ubuntu (найдено: $ID)"; exit 1; }

$SUDO apt-get update
$SUDO apt-get install -y ca-certificates curl gnupg openssl
$SUDO install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
$SUDO chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
$SUDO apt-get update
$SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

$SUDO systemctl enable --now docker
if [ -n "${SUDO_USER:-$USER}" ] && [ "${SUDO_USER:-$USER}" != "root" ]; then
  $SUDO usermod -aG docker "${SUDO_USER:-$USER}"
  echo "Пользователь добавлен в группу docker: перелогиньтесь или выполните 'newgrp docker'."
fi
docker --version
