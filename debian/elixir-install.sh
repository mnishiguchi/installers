#!/usr/bin/env bash
set -eu

# Bootstrap asdf PATH for non-interactive runs
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
export ASDF_DATA_DIR
export PATH="$ASDF_DATA_DIR/bin:$PATH"

if ! command -v asdf &>/dev/null; then
  echo "error: asdf must be installed --aborting"
  exit 1
fi

# https://github.com/asdf-vm/asdf-erlang
sudo apt install --yes \
  autoconf \
  build-essential \
  fop \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libncurses-dev \
  libncurses5-dev \
  libpng-dev \
  libssh-dev \
  libwxgtk-webview3.2-dev \
  libwxgtk3.2-dev \
  libxml2-utils \
  m4 \
  openjdk-17-jdk \
  unixodbc-dev \
  xsltproc

ASDF_PLUGINS=(
  erlang
  elixir
)

for plugin in "${ASDF_PLUGINS[@]}"; do
  asdf plugin add "$plugin" || true
  asdf install "$plugin" latest
  asdf set --home "$plugin" latest
done

asdf list
