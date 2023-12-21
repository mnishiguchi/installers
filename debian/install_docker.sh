#!/bin/bash
set -e

## Docker Engine and Docker CLI

if command -v docker &>/dev/null; then
  echo "warning: already installed -- skipping"
  exit 0
fi

sudo apt install --yes uidmap

# Install Docker Engine
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
rm ./get-docker.sh

# Run the Docker daemon as a non-root user (Rootless mode)
# https://docs.docker.com/engine/security/rootless
/usr/bin/dockerd-rootless-setuptool.sh install

# Verify that Docker is installed
docker --version

## Docker Compose

if ! command -v docker compose &>/dev/null; then
  echo "warning: already installed -- skipping"
  exit 0
fi

sudo apt-get install docker-compose-plugin

# Verify that Docker Compose is installed
docker compose version
