#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    echo "Run this script as your normal user, without sudo."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/areppa/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"
SOFTWARE_DIR="${SCRIPT_DIR}/software"
FLATPAK_REMOTE="flathub"

# Authenticate once, then keep the sudo ticket fresh during long installs.
sudo -v
(
    while :; do
        sleep 50
        sudo -n -v || exit
    done
) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# Clone or update the dotfiles as the normal user.
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    echo "Updating existing dotfiles repository..."
    git -C "$DOTFILES_DIR" pull --ff-only
else
    echo "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi

install_pacman_pkgs() {
    local to_install=()
    local pkg

    for pkg in "$@"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            echo "✔ $pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done

    if (( ${#to_install[@]} )); then
        echo "Installing (pacman): ${to_install[*]}"
        sudo -n pacman -S --needed --noconfirm "${to_install[@]}"
    fi
}

install_aur_pkgs() {
    local to_install=()
    local pkg

    if ! command -v paru >/dev/null 2>&1; then
        echo "Error: paru is not installed for user $USER."
        echo "Install paru as your normal user, then run this script again."
        exit 1
    fi

    for pkg in "$@"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            echo "✔ $pkg already installed"
        else
            to_install+=("$pkg")
        fi
    done

    if (( ${#to_install[@]} )); then
        echo "Installing (AUR via paru): ${to_install[*]}"
        paru -S --needed --noconfirm "${to_install[@]}"
    fi
}

install_flatpak_apps() {
    local app

    if ! sudo -n flatpak remote-list --system --columns=name |
        grep -Fxq "$FLATPAK_REMOTE"; then
        echo "Adding system Flatpak remote '$FLATPAK_REMOTE'..."
        sudo -n flatpak remote-add --system --if-not-exists \
            "$FLATPAK_REMOTE" \
            "https://flathub.org/repo/flathub.flatpakrepo"
    fi

    for app in "$@"; do
        if sudo -n flatpak info --system "$app" >/dev/null 2>&1; then
            echo "✔ $app already installed via Flatpak"
        else
            echo "Installing Flatpak app: $app"
            sudo -n flatpak install --system -y "$FLATPAK_REMOTE" "$app"
        fi
    done
}

# Read package lists. Files named "aur" and "flatpak" use those installers;
# all other files are treated as pacman package lists.
pacman_pkgs=()
aur_pkgs=()
flatpak_apps=()

if [[ -d "$SOFTWARE_DIR" ]]; then
    while IFS= read -r -d '' file; do
        name="$(basename "$file")"

        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%$'\r'}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            [[ -z "$line" || "$line" == \#* ]] && continue

            case "$name" in
                aur)     aur_pkgs+=("$line") ;;
                flatpak) flatpak_apps+=("$line") ;;
                *)       pacman_pkgs+=("$line") ;;
            esac
        done < "$file"
    done < <(find "$SOFTWARE_DIR" -type f -print0)
else
    echo "No software directory found at '$SOFTWARE_DIR'; skipping package installs."
fi

# Deduplicate arrays while preserving order.
unique_array() {
    local -n input=$1 output=$2
    local item
    local -A seen=()

    output=()
    for item in "${input[@]}"; do
        if [[ -z "${seen[$item]+present}" ]]; then
            seen["$item"]=1
            output+=("$item")
        fi
    done
}

unique_array pacman_pkgs pacman_pkgs_uniq
unique_array aur_pkgs aur_pkgs_uniq
unique_array flatpak_apps flatpak_apps_uniq

if (( ${#pacman_pkgs_uniq[@]} )); then
    echo -e "\n--------- Installing pacman packages ---------"
    install_pacman_pkgs "${pacman_pkgs_uniq[@]}"
fi

if (( ${#aur_pkgs_uniq[@]} )); then
    echo -e "\n--------- Installing AUR packages ---------"
    install_aur_pkgs "${aur_pkgs_uniq[@]}"
fi

if (( ${#flatpak_apps_uniq[@]} )); then
    echo -e "\n--------- Installing Flatpaks ---------"
    install_flatpak_apps "${flatpak_apps_uniq[@]}"
fi

echo -e "\n--------- Setting Up Memory ---------"
if [[ -f "$SCRIPT_DIR/software_config/setup-memory.sh" ]]; then
    sudo -n bash "$SCRIPT_DIR/software_config/setup-memory.sh"
else
    echo "Memory setup script not found; skipping."
fi


echo -e "\n--------- Installing Docker ---------"
if [[ -f "$SCRIPT_DIR/software_config/docker.sh" ]]; then
    bash "$SCRIPT_DIR/software_config/docker.sh"
else
    echo "Docker install script not found; skipping."
fi

echo -e "\n--------- Debloating Brave ---------"
if [[ -f "$SCRIPT_DIR/software_config/brave-debloat.sh" ]]; then
    sudo -n bash "$SCRIPT_DIR/software_config/brave-debloat.sh"
else
    echo "Brave debloat script not found; skipping."
fi

echo -e "\n--------- Installing Spotify & Spicetify ---------"
if [[ -f "$SCRIPT_DIR/software_config/spotify.sh" ]]; then
    bash "$SCRIPT_DIR/software_config/spotify.sh"
else
    echo "Spotify install script not found; skipping."
fi

echo -e "\n--------- All tasks completed ---------"
