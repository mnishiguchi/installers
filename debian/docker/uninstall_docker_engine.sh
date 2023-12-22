#!/bin/bash
set -e

# Uninstall Docker Engine
# https://docs.docker.com/engine/install/debian/#uninstall-docker-engine
sudo apt purge --yes \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

