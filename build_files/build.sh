#!/bin/bash

set -ouex pipefail

rpm-ostree install \
    gnome-tweaks \
    tailscale

systemctl enable podman.socket


# === nix Setup ===

# Step 0: Make a /nix directory
mkdir -p /nix

# Step 1: Create the placeholder directory for the Nix store's actual data.
# Determinate Systems installer for OSTree often defaults to /var/lib/nix.
# This directory will be part of the OS image's /var content.
# On the live system, the user can replace this with a Btrfs subvolume of the same name.
STORE_DATA_PATH="/var/lib/nix" # Using the common path for OSTree Nix setups
echo "Creating placeholder directory for Nix store data at ${STORE_DATA_PATH}..."
mkdir -p "${STORE_DATA_PATH}"
# Set basic ownership/permissions; Nix installer might adjust later.
chown root:root "${STORE_DATA_PATH}"
chmod 0755 "${STORE_DATA_PATH}"

# Step 2: Create the systemd mount unit to bind-mount the store data path to /nix.
# This unit will run on the live system.
# We do NOT create /nix in the image. Systemd will create it as a mount point if it doesn't exist.
SYSTEMD_UNIT_DIR="/etc/systemd/system"
echo "Creating systemd mount unit for /nix..."
mkdir -p "${SYSTEMD_UNIT_DIR}"
cat <<EOF > "${SYSTEMD_UNIT_DIR}/nix.mount"
[Unit]
Description=Nix Package Manager Store (bind mount from ${STORE_DATA_PATH})
Documentation=https://nixos.org/
DefaultDependencies=no
Before=local-fs.target
# ConditionPathExists ensures we only try if the source directory exists
ConditionPathExists=${STORE_DATA_PATH}

[Mount]
What=${STORE_DATA_PATH}
Where=/nix
Type=none
Options=bind,rw

[Install]
WantedBy=local-fs.target
EOF

# Step 3: Enable the systemd mount unit.
# rpm-ostree's build process intercepts systemctl enable and configures the service
# to be enabled by default on the deployed system.
echo "Enabling nix.mount systemd unit..."
systemctl enable nix.mount



echo "Installing Zsh..."
rpm-ostree install zsh util-linux-user # util-linux-user for chsh

# Optionally set zsh as default for new users (careful with this system-wide)
echo "Setting Zsh as default shell for new users..."
sed -i 's#SHELL=/bin/bash#SHELL=/bin/zsh#' /etc/default/useradd


# --- Final Cleanups / Other Customizations ---
# Example: Remove unnecessary cached files from package manager
rpm-ostree cleanup -m
rm -rf /var/cache/*
