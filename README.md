# Simple script that install software.

This script will:
- Clone dotfiles repository
- Install `pacman` pkgs
- Install `AUR` packages using `paru`
- Install flatpaks

# Configuration
All files in the `software` directory are treated as software lists, with the following exceptions:

- `flatpak`: installed as Flatpak packages
- `aur`: installed as AUR packages
- All other files: installed via Pacman

# Usage
```bash
git clone https://github.com/Areppa/installScript

cd installScript

# Give permissions to execute install script and run it
chmod +x install.sh
./install.sh
```
