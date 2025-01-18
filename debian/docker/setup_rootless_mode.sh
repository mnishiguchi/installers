#!/bin/bash
set -e

# Run the Docker daemon as a non-root user (Rootless mode)
# https://docs.docker.com/engine/security/rootless

if docker context inspect | grep -iq "rootless"; then
  echo 'warning: already rootless mode -- nothing to do'
  docker context inspect
  exit 0
fi

if ! command -v docker &>/dev/null; then
  echo 'error: docker is not installed'
  exit 1
fi

setuptool="/usr/bin/dockerd-rootless-setuptool.sh"
if [ ! -f "$setuptool" ]; then
  echo "error: $setuptool is not installed"
  exit 1
fi

# Disable the system-wide Docker daemon
# https://docs.docker.com/engine/security/rootless/#install
(sudo systemctl disable --now docker.service docker.socket)

# Install necessary packages
# https://docs.docker.com/engine/security/rootless/
sudo apt install --yes \
  dbus-user-session \
  docker-ce-rootless-extras \
  fuse-overlayfs \
  slirp4netns \
  uidmap

# Make sure id mapping is enabled
# https://docs.docker.com/engine/security/rootless/#prerequisites
echo "user: $(whoami)"
echo "uid: $(id -u)"
echo "gid: $(id -g)"
echo "subuid: $(grep "^$(whoami):" /etc/subuid)"
echo "subgid: $(grep "^$(whoami):" /etc/subgid)"

# Uninstall conflicting packages
# https://docs.docker.com/engine/install/debian/#uninstall-old-versions
sudo apt purge --yes \
  docker.io \
  docker-doc \
  docker-compose \
  podman-docker \
  containerd \
  runc

# Run the Docker daemon as a non-root user (Rootless mode)
# https://docs.docker.com/engine/security/rootless/#install
/usr/bin/dockerd-rootless-setuptool.sh install --force

# To launch the daemon on system startup, enable the systemd service and lingering
systemctl --user enable docker
sudo loginctl enable-linger "$(whoami)"

# Print current context
docker context inspect
