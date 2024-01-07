#!/usr/bin/env bash

#
# Install Linux Driver for USB WiFi Adapters that are based on the RTL8812BU
# and RTL8822BU Chipsets
#

set -eu

sudo apt install -y \
  linux-headers-"$(uname -r)" \
  build-essential \
  bc \
  dkms \
  git \
  libelf-dev \
  rfkill \
  iw

(
  cd "$HOME/Downloads"
  git clone https://github.com/morrownr/88x2bu-20210702.git
  cd 88x2bu-20210702
  sudo ./install-driver.sh
  cd ..
  rm -rf 88x2bu-20210702
)
