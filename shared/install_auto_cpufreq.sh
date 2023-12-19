#!/bin/bash
set -e

DOWNLOADS_DIR="$HOME/Downloads"

if command -v auto-cpufreq >/dev/null 2>&1; then
  echo "warning: already installed -- skipping"
  exit 0
fi

(
  # Download  source code
  cd "$DOWNLOADS_DIR"
  git clone https://github.com/AdnanHodzic/auto-cpufreq.git

  # Install auto-cpufreq
  cd auto-cpufreq && sudo ./auto-cpufreq-installer

  # Install daemon via GUI for (permanent) automatic CPU optimizations
  sudo auto-cpufreq --install

  # Clean up
  cd - && rm -rf auto-cpufreq
)
