#!/usr/bin/env bash
set -euo pipefail

# Set repository URL here:
REPO_URL="https://github.com/areppa/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    echo "Updating existing dotfiles repository..."
    git -C "$DOTFILES_DIR" pull
else
    echo "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi
