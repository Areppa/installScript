#!/usr/bin/env bash
set -euo pipefail

# Ensure we run as root for package management (use sudo from a normal user)
if [[ $EUID -ne 0 ]]; then
    echo "Switching to root for privileged operations..."
    exec sudo "$0" "$@"
fi

SOFTWARE_DIR="software"
AUR_DIR="aur"
FLATPAK_REMOTE="flathub"

# Determine original non-root user to run yay as
NONROOT_USER="${SUDO_USER:-$(logname 2>/dev/null || '')}"
# If NONROOT_USER is empty or root, abort with actionable message
if [[ -z "$NONROOT_USER" || "$NONROOT_USER" == "root" ]]; then
    echo "Error: cannot determine a non-root user to run 'yay'."
    echo "Please invoke this script from a normal user account (so sudo sets SUDO_USER),"
    echo "or set up and run the AUR step manually as a non-root user."
    exit 1
fi

# Helper: install pacman packages only if missing
install_pacman_pkgs() {
    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qs "^${pkg}\$" > /dev/null 2>&1; then
            to_install+=("$pkg")
        else
            echo "✔ $pkg already installed"
        fi
    done
    if (( ${#to_install[@]} )); then
        echo "Installing (pacman): ${to_install[*]}"
        pacman -S --noconfirm "${to_install[@]}"
    fi
}

# Helper: install AUR packages with yay only if missing — run yay as the original non-root user
install_aur_pkgs() {
    local pkgs=("$@")
    # Verify yay exists for the non-root user
    if ! sudo -u "$NONROOT_USER" -H bash -lc 'command -v yay >/dev/null 2>&1'; then
        echo "Error: 'yay' not found for user $NONROOT_USER. Please install an AUR helper (e.g. yay) as that user."
        exit 1
    fi
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qs "^${pkg}\$" > /dev/null 2>&1; then
            to_install+=("$pkg")
        else
            echo "✔ $pkg already installed (system)"
        fi
    done
    if (( ${#to_install[@]} )); then
        echo "Installing (AUR via yay as $NONROOT_USER): ${to_install[*]}"
        # Run yay as the non-root user; --noconfirm and --needed for unattended install
        sudo -u "$NONROOT_USER" -H bash -lc "yay -S --noconfirm --needed ${to_install[*]}"
    fi
}

# Helper: install flatpak apps only if missing
install_flatpak_apps() {
    local apps=("$@")
    # Ensure remote exists
    if ! flatpak remote-list | grep -q "^${FLATPAK_REMOTE}\$"; then
        echo "Adding Flatpak remote '${FLATPAK_REMOTE}'..."
        flatpak remote-add --if-not-exists "${FLATPAK_REMOTE}" "https://flathub.org/repo/flathub.flatpakrepo"
    fi
    for app in "${apps[@]}"; do
        if flatpak info "${app}" > /dev/null 2>&1; then
            echo "✔ ${app} already installed via Flatpak"
        else
            echo "Installing Flatpak app: ${app}"
            flatpak install -y "${FLATPAK_REMOTE}" "${app}"
        fi
    done
}

# Read software lists from files under software/*
# Files named exactly "flatpak" -> flatpak apps (one per line)
# Files named exactly "aur"     -> AUR packages (one per line, installed via yay as non-root)
# All other files -> pacman packages (one per line)
pacman_pkgs=()
aur_pkgs=()
flatpak_apps=()

if [[ ! -d "$SOFTWARE_DIR" ]]; then
    echo "No '${SOFTWARE_DIR}' directory found; skipping package installs."
else
    while IFS= read -r -d '' file; do
        name="$(basename "$file")"
        # Read lines, skip empty and comments
        mapfile -t lines < <(grep -E -v '^\s*(#|$)' "$file" || true)
        if [[ "$name" == "flatpak" ]]; then
            for l in "${lines[@]}"; do flatpak_apps+=("$l"); done
        elif [[ "$name" == "aur" ]]; then
            for l in "${lines[@]}"; do aur_pkgs+=("$l"); done
        else
            for l in "${lines[@]}"; do pacman_pkgs+=("$l"); done
        fi
    done < <(find "$SOFTWARE_DIR" -type f -print0)
fi

# Deduplicate arrays while preserving order
unique_array() {
    local -n in=$1 out=$2
    declare -A seen=()
    out=()
    for i in "${in[@]}"; do
        if [[ -n "${i}" && -z "${seen[$i]:-}" ]]; then
            seen[$i]=1
            out+=("$i")
        fi
    done
}

unique_array pacman_pkgs pacman_pkgs_uniq
unique_array aur_pkgs aur_pkgs_uniq
unique_array flatpak_apps flatpak_apps_uniq

# Install pacman packages
if (( ${#pacman_pkgs_uniq[@]} )); then
    echo -e "\n--------- Installing pacman pkgs. ---------"
    install_pacman_pkgs "${pacman_pkgs_uniq[@]}"
fi

# Install AUR packages via yay (as non-root user)
if (( ${#aur_pkgs_uniq[@]} )); then
    echo -e "\n--------- Installing AUR pkgs via yay (non-root). ---------"
    install_aur_pkgs "${aur_pkgs_uniq[@]}"
fi

# Install flatpak apps
if (( ${#flatpak_apps_uniq[@]} )); then
    echo -e "\n--------- Installing flatpaks. ---------"
    install_flatpak_apps "${flatpak_apps_uniq[@]}"
fi

echo -e "\n--------- All tasks completed. ---------"
