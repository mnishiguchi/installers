#!/bin/bash
set -e

# Uninstall Rootless mode
# * See https://docs.docker.com/engine/security/rootless/#uninstall

# remove the systemd service of the Docker daemon
dockerd-rootless-setuptool.sh uninstall --force

# remove the data directory
rootlesskit rm -rf "$HOME/.local/share/docker"

# remove the binary files
sudo apt purge --yes docker-ce-rootless-extras

if [ -d "$HOME/bin" ]; then
  (
    cd "$HOME/bin"
    rm -f containerd \
      containerd-shim \
      containerd-shim-runc-v2 \
      ctr \
      docker \
      docker-init \
      docker-proxy \
      dockerd \
      dockerd-rootless-setuptool.sh \
      dockerd-rootless.sh \
      rootlesskit \
      rootlesskit-docker-proxy \
      runc \
      vpnkit
  )
fi
