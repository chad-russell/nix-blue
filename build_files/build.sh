#!/bin/bash

set -ouex pipefail

systemctl enable podman.socket

# mkdir /nix

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

# Step 4: Set up shell profile for Nix.
# This will source the Nix environment once Nix is fully installed by the user.
PROFILE_D_DIR="/etc/profile.d"
echo "Creating Nix shell environment setup script in ${PROFILE_D_DIR}/nix.sh..."
mkdir -p "${PROFILE_D_DIR}"
cat <<EOF > "${PROFILE_D_DIR}/nix.sh"
# Source Nix environment if available (after user installs Nix into the store)
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
EOF
