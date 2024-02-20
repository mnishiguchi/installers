#!/usr/bin/env bash
set -eu

CODE_DIR="$HOME/Code"
mkdir -p "$CODE_DIR"

if [ -d "$CODE_DIR/nerves_systems" ]; then
  echo "warning: already exists -- skipping"
  exit 0
fi

# https://hexdocs.pm/nerves/installation.html
sudo apt install --yes \
  autoconf \
  automake \
  build-essential \
  curl \
  git \
  pkg-config \
  squashfs-tools \
  ssh-askpass

# It is important to update the versions of hex and rebar used by Elixir, even
# if you already had Elixir installed.
mix local.hex --force
mix local.rebar --force
mix archive.install hex nerves_bootstrap --force

# https://github.com/nerves-project/nerves_systems
sudo apt install --yes \
  autoconf \
  automake \
  bc \
  build-essential \
  cmake \
  curl \
  cvs \
  gawk \
  git \
  jq \
  libncurses5-dev \
  libssl-dev \
  mercurial \
  python3 \
  python3-aiohttp \
  python3-flake8 \
  python3-ijson \
  python3-nose2 \
  python3-pexpect \
  python3-pip \
  python3-requests \
  rsync \
  squashfs-tools \
  subversion \
  unzip \
  wget

(
  cd "$CODE_DIR"
  git clone https://github.com/nerves-project/nerves_systems.git
)
