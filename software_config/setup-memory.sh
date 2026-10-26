#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root: sudo bash $0" >&2
  exit 1
fi

packages=(zram-generator earlyoom)
missing=()

for package in "${packages[@]}"; do
  if pacman -Q "$package" &>/dev/null; then
    echo "$package is already installed."
  else
    missing+=("$package")
  fi
done

if ((${#missing[@]})); then
  echo "Installing missing packages: ${missing[*]}"
  pacman -S --needed "${missing[@]}"
else
  echo "All required packages are already installed."
fi

config="/etc/systemd/zram-generator.conf"

if [[ -e "$config" ]]; then
  backup="${config}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$config" "$backup"
  echo "Backed up existing config to: $backup"
fi

cat > "$config" <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

systemctl daemon-reload
systemctl enable --now earlyoom.service

echo
echo "Done. Reboot to activate zram, then check it with:"
echo "  zramctl"
echo "  swapon --show"
