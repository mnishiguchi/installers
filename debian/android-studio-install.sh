#!/usr/bin/env bash
#
# Install or update Android Studio on LMDE7 (Debian-based)
# - Installs from official .tar.gz into /opt/android-studio
# - Creates /usr/local/bin/android-studio launcher
# - Creates /usr/share/applications/android-studio.desktop
# - Idempotent: safe to re-run (backs up previous /opt/android-studio)
#
set -euo pipefail

# Fallback: stable as of 2025-12-03 (Android Studio Otter | 2025.2.1.8)
# Used only if auto-detection and ANDROID_STUDIO_TAR_URL both fail.
ANDROID_STUDIO_TAR_URL_FALLBACK="https://dl.google.com/dl/android/studio/ide-zips/2025.2.1.8/android-studio-2025.2.1.8-linux.tar.gz"

INSTALL_DIR="/opt/android-studio"
LAUNCHER_SCRIPT="/usr/local/bin/android-studio"
DESKTOP_FILE="/usr/share/applications/android-studio.desktop"

SUDO=""
TAR_PATH=""
DOWNLOAD_TMP=""

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn() { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

require_sudo() {
  if [ "${EUID}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      echo_failure "This script needs root privileges (sudo or run as root)."
      exit 1
    fi
  else
    SUDO=""
  fi
}

ensure_prereqs() {
  echo_heading "Preparing prerequisites (curl, tar)..."
  $SUDO apt-get update -yqq
  $SUDO apt-get install -y curl tar >/dev/null
  echo_success "Prerequisites installed."
}

# Resolve the download URL:
# 1. If ANDROID_STUDIO_TAR_URL is set, use that.
# 2. Otherwise, try Flathub's manifest (tracks stable Android Studio).
# 3. If that fails, fall back to the pinned URL.
detect_latest_url() {
  # Explicit override wins
  if [ -n "${ANDROID_STUDIO_TAR_URL:-}" ]; then
    echo_heading "Using ANDROID_STUDIO_TAR_URL from environment..."
    echo "  $ANDROID_STUDIO_TAR_URL"
    echo "$ANDROID_STUDIO_TAR_URL"
    return 0
  fi

  echo_heading "Trying to auto-detect latest Android Studio tarball (Flathub)..."

  # Flathub manifest for com.google.AndroidStudio (stable)
  local flathub_manifest
  flathub_manifest="$(
    curl -fsSL "https://raw.githubusercontent.com/flathub/com.google.AndroidStudio/master/com.google.AndroidStudio.json" 2>/dev/null || true
  )"

  if [ -n "$flathub_manifest" ]; then
    local detected
    detected="$(
      printf '%s\n' "$flathub_manifest" |
        grep -Eo 'https://dl\.google\.com/dl/android/studio/ide-zips/[0-9.]+/android-studio-[0-9.]+-linux\.tar\.gz' |
        head -n1 || true
    )"

    if [ -n "$detected" ]; then
      echo_success "Detected latest URL from Flathub:"
      echo "  $detected"
      echo "$detected"
      return 0
    fi
  fi

  echo_warn "Auto-detection failed. Falling back to pinned URL:"
  echo "  $ANDROID_STUDIO_TAR_URL_FALLBACK"
  echo "$ANDROID_STUDIO_TAR_URL_FALLBACK"
}

pick_archive() {
  local local_file="${1:-}"

  if [ -n "$local_file" ]; then
    if [ -f "$local_file" ]; then
      TAR_PATH="$local_file"
      DOWNLOAD_TMP=""
      echo_heading "Using local Android Studio archive..."
      echo_success "Archive: $TAR_PATH"
    else
      echo_failure "Specified archive not found: $local_file"
      exit 1
    fi
  else
    local url
    url="$(detect_latest_url)"

    echo_heading "Downloading Android Studio from:"
    echo "  $url"

    DOWNLOAD_TMP="$(mktemp -t android-studio-XXXXXX.tar.gz)"
    curl -fsSL "$url" -o "$DOWNLOAD_TMP"
    TAR_PATH="$DOWNLOAD_TMP"

    echo_success "Downloaded archive to: $TAR_PATH"
  fi
}

install_android_studio() {
  echo_heading "Extracting Android Studio archive..."

  local tmp_dir
  tmp_dir="$(mktemp -d -t android-studio-XXXXXX)"

  tar -xzf "$TAR_PATH" -C "$tmp_dir"

  if [ ! -d "$tmp_dir/android-studio" ]; then
    echo_failure "Expected directory 'android-studio' not found in archive."
    echo "Extracted contents:"
    ls -la "$tmp_dir"
    exit 1
  fi

  echo_heading "Installing to: $INSTALL_DIR"

  if [ -d "$INSTALL_DIR" ]; then
    local backup="${INSTALL_DIR}.bak.$(date +%s)"
    echo_warn "Existing installation detected. Moving to backup: $backup"
    $SUDO mv "$INSTALL_DIR" "$backup"
  fi

  $SUDO mv "$tmp_dir/android-studio" "$INSTALL_DIR"
  echo_success "Installed Android Studio under $INSTALL_DIR"

  rm -rf "$tmp_dir"

  if [ -n "$DOWNLOAD_TMP" ]; then
    rm -f "$DOWNLOAD_TMP"
  fi
}

create_launcher_script() {
  echo_heading "Creating launcher script: $LAUNCHER_SCRIPT"

  if [ -e "$LAUNCHER_SCRIPT" ]; then
    if [ -L "$LAUNCHER_SCRIPT" ]; then
      $SUDO rm -f "$LAUNCHER_SCRIPT"
    else
      local backup="${LAUNCHER_SCRIPT}.bak.$(date +%s)"
      echo_warn "Existing file at $LAUNCHER_SCRIPT. Moving to backup: $backup"
      $SUDO mv "$LAUNCHER_SCRIPT" "$backup"
    fi
  fi

  $SUDO mkdir -p "$(dirname "$LAUNCHER_SCRIPT")"

  $SUDO tee "$LAUNCHER_SCRIPT" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec /opt/android-studio/bin/studio "$@"
EOF

  $SUDO chmod +x "$LAUNCHER_SCRIPT"
  echo_success "Launcher script created."
}

create_desktop_entry() {
  echo_heading "Creating desktop entry: $DESKTOP_FILE"

  $SUDO tee "$DESKTOP_FILE" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=Android IDE for mobile development
Exec=$LAUNCHER_SCRIPT %f
Icon=/opt/android-studio/bin/studio.png
Terminal=false
Categories=Development;IDE;
StartupWMClass=jetbrains-studio
EOF

  $SUDO chmod 644 "$DESKTOP_FILE"
  echo_success "Desktop entry written."
}

post_install_message() {
  echo_heading "Installation summary"

  echo "  Android Studio: $INSTALL_DIR"
  echo "  Launcher:       $LAUNCHER_SCRIPT"
  echo "  Desktop entry:  $DESKTOP_FILE"
  echo
  echo "Default Android SDK path on Linux is usually:"
  echo "  \$HOME/Android/Sdk"
  echo
  echo "Suggested shell configuration (for ~/.bashrc or ~/.zshrc):"
  echo "  export ANDROID_HOME=\"\$HOME/Android/Sdk\""
  echo "  export PATH=\"\$PATH:\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools\""
  echo
  echo "You can start Android Studio by running:"
  echo "  android-studio"
  echo
  echo "Inside Android Studio, use the Setup Wizard to install SDK components and AVDs."
}

main() {
  require_sudo
  ensure_prereqs

  local archive_path="${1:-}"
  pick_archive "$archive_path"
  install_android_studio
  create_launcher_script
  create_desktop_entry
  post_install_message
}

main "$@"
