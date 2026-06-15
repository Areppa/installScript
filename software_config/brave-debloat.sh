#!/usr/bin/env bash
# Brave policy installer – fetches policies.json and installs it for Brave

# Exit on any error
set -euo pipefail

# URL of the policies file
POLICIES_URL="https://raw.githubusercontent.com/Areppa/installScript/refs/heads/master/software_config/config/brave/policies.json"

# Temporary location for the download
TMP_FILE="$(mktemp)"

# Download the JSON file
echo "Downloading policies.json..."
curl -fsSL "$POLICIES_URL" -o "$TMP_FILE"

# Ensure the managed policies directory exists
echo "Creating /etc/brave/policies/managed/ (if needed)..."
sudo mkdir -p /etc/brave/policies/managed/

# Copy the file into the managed directory
echo "Installing policies.json..."
sudo cp "$TMP_FILE" /etc/brave/policies/managed/policies.json

# Clean up the temporary file
rm -f "$TMP_FILE"

# Inform the user how to verify
echo "Installation complete."
echo "Verify applied policies by opening: brave://policy/ in Brave."
