#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
  echo "Run this as your regular user, not with sudo."
  exit 1
fi

for cmd in pacman setsid pgrep pkill; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
done

# Install only packages that are missing.
required_packages=(spotify-launcher spicetify-cli)
missing_packages=()

for package in "${required_packages[@]}"; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    echo "$package is already installed."
  else
    missing_packages+=("$package")
  fi
done

if ((${#missing_packages[@]})); then
  if ! command -v paru >/dev/null 2>&1; then
    echo "paru is required to install: ${missing_packages[*]}"
    exit 1
  fi

  echo "Installing missing packages: ${missing_packages[*]}"
  paru -Syu --needed --noconfirm "${missing_packages[@]}"
fi

if ! command -v spicetify >/dev/null 2>&1; then
  echo "The spicetify command wasn't found after package installation."
  exit 1
fi

SPOTIFY_PATH="$HOME/.local/share/spotify-launcher/install/usr/share/spotify"
PREFS_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs"
LOG_PATH="$HOME/.cache/spotify-spicetify-setup.log"
LAUNCH_PID=""

stop_spotify() {
  if pgrep -u "$UID" -x spotify >/dev/null 2>&1; then
    echo "Closing the running Spotify app..."
    pkill -TERM -u "$UID" -x spotify || true

    for _ in {1..15}; do
      if ! pgrep -u "$UID" -x spotify >/dev/null 2>&1; then
        return 0
      fi
      sleep 1
    done

    echo "Spotify didn't close within 15 seconds."
    return 1
  fi
}

stop_started_spotify() {
  local pid="$1"

  # Gracefully stop the process group started by this script.
  kill -TERM -- "-$pid" 2>/dev/null || true

  for _ in {1..10}; do
    if ! kill -0 -- "-$pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  # Ensure the temporary Spotify instance is gone.
  kill -KILL -- "-$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

cleanup() {
  if [[ -n "$LAUNCH_PID" ]]; then
    stop_started_spotify "$LAUNCH_PID"
  fi
}
trap cleanup EXIT

# Spicetify needs Spotify closed while it patches the client files.
stop_spotify

# Start Spotify if either its client files or preferences are missing.
if [[ ! -d "$SPOTIFY_PATH" || ! -f "$PREFS_PATH" ]]; then
  echo "Starting Spotify briefly to prepare its files..."
  mkdir -p "$(dirname "$LOG_PATH")"

  setsid spotify-launcher >"$LOG_PATH" 2>&1 &
  LAUNCH_PID=$!

  ready=false
  for _ in {1..120}; do
    if [[ -d "$SPOTIFY_PATH" && -f "$PREFS_PATH" ]]; then
      ready=true
      break
    fi
    sleep 1
  done

  stop_started_spotify "$LAUNCH_PID"
  LAUNCH_PID=""

  if [[ "$ready" != true ]]; then
    echo "Spotify's files weren't ready within two minutes."
    echo "Launcher output (last lines):"
    tail -n 20 "$LOG_PATH" 2>/dev/null || true
    exit 1
  fi
fi

if [[ ! -w "$SPOTIFY_PATH" ]]; then
  echo "Spotify's install directory isn't writable by your user:"
  echo "  $SPOTIFY_PATH"
  echo "Don't run Spicetify with sudo; check the directory's ownership instead."
  exit 1
fi

echo "Configuring and applying Spicetify..."
spicetify config spotify_path "$SPOTIFY_PATH"
spicetify config prefs_path "$PREFS_PATH"
spicetify apply

echo "Done. Start Spotify normally."
