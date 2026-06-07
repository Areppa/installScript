#!/usr/bin/env bash
set -euo pipefail

PACMAN_CMD="sudo pacman -S --noconfirm --needed"
USER_SYSTEMCTL="systemctl --user"
SERVICE_NAME="syncthing.service"

# Ensure systemd user instance is available
if ! systemctl --user >/dev/null 2>&1; then
  echo "Error: systemd user instance not available. Ensure you have a user session (login, systemd --user supported)." >&2
  exit 1
fi

# Install syncthing if not present
if ! command -v syncthing >/dev/null 2>&1; then
  echo "Installing syncthing (requires sudo)..."
  $PACMAN_CMD syncthing
else
  echo "syncthing already installed."
fi

# Reload user units, enable and start syncthing
echo "Reloading user systemd daemon..."
$USER_SYSTEMCTL daemon-reload

echo "Enabling and starting ${SERVICE_NAME} for current user..."
# Enable (creates symlink to default.target.wants) and start now
$USER_SYSTEMCTL enable --now "${SERVICE_NAME}"

# Provide brief status
echo
echo "Service status:"
$USER_SYSTEMCTL status "${SERVICE_NAME}" --no-pager
