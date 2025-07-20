#!/bin/bash

set -e

PACKAGES=(sudo htop tree nano net-tools)

echo "=== Basic tools installer ==="
echo ""

# Обновляем индекс пакетов
echo "[*] Updating package lists..."
sudo apt update

echo ""

# Функция установки одного пакета с проверкой
install_package() {
  local pkg=$1
  echo "[*] Installing package: $pkg"
  if dpkg -s "$pkg" &>/dev/null; then
    echo "  - Package '$pkg' is already installed."
  else
    sudo apt install -y "$pkg"
    echo "  - Package '$pkg' installed successfully."
  fi
  echo ""
}

# Устанавливаем все пакеты по очереди
for pkg in "${PACKAGES[@]}"; do
  install_package "$pkg"
done

echo "=== All packages installed successfully! ==="
