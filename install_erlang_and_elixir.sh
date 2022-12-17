#!/bin/sh
set -e

echo "==> Installing Erlang and Elixir"

# https://github.com/asdf-vm/asdf-erlang
sudo apt install \
  autoconf \
  build-essential \
  fop \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libncurses-dev \
  libncurses5-dev \
  libpng-dev \
  libssh-dev \
  libwxgtk-webview3.0-gtk3-dev \
  libwxgtk3.0-gtk3-dev \
  libxml2-utils \
  m4 \
  openjdk-11-jdk \
  unixodbc-dev \
  xsltproc \
  -y

asdf plugin-add erlang || true
asdf install erlang latest
asdf global erlang latest

asdf plugin-add elixir || true
asdf install elixir latest
asdf global elixir latest

asdf list
