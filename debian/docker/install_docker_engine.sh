#!/bin/bash
set -e

# Docker Engine and Docker CLI
# * document: https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
# * source: https://github.com/docker/docker-install

if command -v docker &>/dev/null; then
  echo 'warning: docker is already installed -- skipping'
  exit 0
fi

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
rm ./get-docker.sh

docker --version
