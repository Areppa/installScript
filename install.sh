#!/usr/bin/env bash
set -euo pipefail

# Ensure we run as root for package management
if [[ $EUID -ne 0 ]]; then
    echo "Switching to root for privileged operations..."
    exec sudo "$0" "$@"
fi

SOFTWARE_DIR="software"
FLATPAK_REMOTE="flathub"

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
# All other files -> pacman packages (one per line)
pacman_pkgs=()
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
unique_array flatpak_apps flatpak_apps_uniq

# Install pacman packages
if (( ${#pacman_pkgs_uniq[@]} )); then
    echo -e "\n--------- Installing pacman pkgs. ---------"
    install_pacman_pkgs "${pacman_pkgs_uniq[@]}"
fi

# Install flatpak apps
if (( ${#flatpak_apps_uniq[@]} )); then
    echo -e "\n--------- Installing flatpaks. ---------"
    install_flatpak_apps "${flatpak_apps_uniq[@]}"
fi

echo -e "\n--------- All tasks completed. ---------"