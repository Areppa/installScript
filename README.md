# Simple arch install script

This script will:
- Clone dotfiles repository
- Install pacman pkgs
- Install flatpaks

# Configuration
All files under the software directory are treated as software lists. Packages listed in a flatpak file inside software are installed via Flatpak. All other packages in the software directory are installed using Pacman.

# Usage
```bash
git clone https://github.com/Areppa/installScript

# Give permissions to execute install script and run it
chmod +x install.sh
./install.sh

# Give permissions to execute dotfiles script and run it
chmox +x dotfiles.sh
./dotfiles.sh
```