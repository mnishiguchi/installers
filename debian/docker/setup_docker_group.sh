#!/bin/bash
set -e

# Use Docker as a non-privileged user
# * Log out and log back in so that your group membership is re-evaluated.
# * On Debian and Ubuntu, the Docker service starts on boot by default.
# * See https://docs.docker.com/engine/install/linux-postinstall

if ! command -v docker &>/dev/null; then
  echo 'error: docker is not installed -- aborting'
  exit 1
fi

if groups "$USER" | grep -wq docker; then
  echo "warning: $USER already belongs to docker group -- skipping"
  exit 0
fi

# Create the new group named "docker" on the system
sudo groupadd -f docker

# Add the active user to the "docker" group
sudo usermod -aG docker "$USER"

# List groups
groups
