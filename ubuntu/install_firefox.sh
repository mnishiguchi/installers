#!/bin/sh
set -e

echo "==> Installing Firefox"

# find the firefox command binary
command -v firefox
exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  echo "firefox is already installed"
else
  # https://fosspost.org/how-to-install-firefox-as-a-deb-package-on-ubuntu-22-04
  sudo snap remove firefox
  sudo add-apt-repository ppa:mozillateam/ppa
  echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox
  sudo apt install -y firefox
fi

firefox -v
