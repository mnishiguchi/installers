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
  PY_PKGS=(aiohttp flake8 ijson nose2 pexpect requests)

  echo_heading "Preparing workspace..."
  mkdir -p "$PROJECTS_DIR"
  echo_success "Created $PROJECTS_DIR (or already existed)."

  if [ -d "$REPO_DIR" ]; then
    echo_heading "Repository already present"
    echo_success "$REPO_DIR exists. Skipping installation steps."
    exit 0
  fi

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

  echo_heading "Checking for python3 on PATH…"
  if command -v python3 >/dev/null 2>&1; then
    PY_BIN="$(command -v python3)"
    echo_success "Found python3 at: $PY_BIN"
  else
    echo_heading "python3 not found; installing Debian python3 + pip…"
    if sudo apt install --yes python3 python3-pip; then
      echo_success "Installed python3 and pip from apt."
    else
      echo_failure "Failed to install python3."
      exit 1
    fi
  fi

  echo_heading "Ensuring pip is available for this python3…"
  if python3 -m pip --version >/dev/null 2>&1; then
    echo_success "pip is available."
  else
    if python3 -m ensurepip --upgrade >/dev/null 2>&1; then
      echo_success "Bootstrapped pip via ensurepip."
    else
      echo_heading "ensurepip failed; installing python3-pip from apt…"
      if sudo apt install --yes python3-pip; then
        echo_success "Installed python3-pip from apt."
      else
        echo_failure "Failed to ensure pip."
        exit 1
      fi
    fi
  fi

  # https://github.com/nerves-project/nerves_systems
  echo_heading "Installing required Python packages…"
  if python3 -m pip install --upgrade pip &&
    python3 -m pip install --upgrade "${PY_PKGS[@]}"; then
    echo_success "Python packages installed: ${PY_PKGS[*]}"
  else
    echo_failure "Failed to install Python packages."
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

  echo_heading "Cloning nerves_systems…"
  if git -C "$PROJECTS_DIR" clone "$REPO_URL"; then
    echo_success "Cloned into $REPO_DIR."
  else
    echo_failure "Failed to clone nerves_systems."
    exit 1
  fi

  echo_heading "All done."
  echo_success "You can now explore: $REPO_DIR"
}

main "$@"
