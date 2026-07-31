#!/usr/bin/env bash
#
# Nerves systems setup
#
# OS: Debian/Ubuntu

set -euo pipefail

# Print headings
echo_heading() { echo -e "\n\033[34m$1\033[0m"; }

# Print success message
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }

# Print failure message
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

main() {
  PROJECTS_DIR="$HOME/Projects"
  REPO_URL="https://github.com/nerves-project/nerves_systems.git"
  REPO_DIR="$PROJECTS_DIR/nerves_systems"

  case "$(uname -m)" in
    x86_64 | aarch64 | arm64) ;;
    *)
      echo_failure "nerves_systems builds require an x86_64 or aarch64 Linux host."
      exit 1
      ;;
  esac

  echo_heading "Preparing workspace..."
  mkdir -p "$PROJECTS_DIR"
  echo_success "Created $PROJECTS_DIR (or already existed)."

  # https://hexdocs.pm/nerves/installation.html
  echo_heading "Installing base system packages…"
  if sudo apt update &&
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
      pkg-config \
      python3 \
      python3-aiohttp \
      python3-flake8 \
      python3-ijson \
      python3-nose2 \
      python3-pexpect \
      python3-requests \
      rsync \
      squashfs-tools \
      ssh-askpass \
      subversion \
      unzip \
      wget; then
    echo_success "System packages installed."
  else
    echo_failure "Failed to install system packages."
    exit 1
  fi

  # It is important to update the versions of hex and rebar used by Elixir, even
  # if you already had Elixir installed.
  echo_heading "Bootstrapping Elixir tooling for Nerves…"
  if mix local.hex --force &&
    mix local.rebar --force &&
    mix archive.install hex nerves_bootstrap --force; then
    echo_success "Elixir tools ready (hex, rebar, nerves_bootstrap)."
  else
    echo_failure "Elixir bootstrap failed."
    exit 1
  fi

  echo_heading "Verifying Python imports…"
  if python3 - <<'PY'; then
import importlib
for m in ("aiohttp","flake8","ijson","nose2","pexpect","requests"):
    importlib.import_module(m)
print("ok")
PY
    echo_success "All required Python modules import correctly."
  else
    echo_failure "One or more Python modules failed to import."
    exit 1
  fi

  echo_heading "Preparing nerves_systems repository…"
  if [ -d "$REPO_DIR/.git" ]; then
    echo_heading "Repository already present"
    echo_success "$REPO_DIR exists; leaving the working tree unchanged."
  elif [ -e "$REPO_DIR" ]; then
    echo_failure "$REPO_DIR exists but is not a Git repository."
    exit 1
  elif git -C "$PROJECTS_DIR" clone "$REPO_URL"; then
    echo_success "Cloned into $REPO_DIR."
  else
    echo_failure "Failed to clone nerves_systems."
    exit 1
  fi

  echo_heading "All done."
  echo_success "You can now explore: $REPO_DIR"
}

main "$@"
