#!/usr/bin/env bash
# Reproducible Debian/LMDE workstation restore orchestrator.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly MANIFEST_DIR="$SCRIPT_DIR/manifests"
readonly APT_MANIFEST="$MANIFEST_DIR/apt-packages.txt"
readonly FLATPAK_MANIFEST="$MANIFEST_DIR/flatpak-apps.txt"
readonly MISE_MANIFEST="$MANIFEST_DIR/mise.toml"
readonly MISE_FWUP_PLUGIN_URL="https://github.com/fwup-home/asdf-fwup.git"
readonly DOTFILES_DIR="$SCRIPT_DIR/../dotfiles"

readonly -a ALL_SECTIONS=(directories apt dotfiles extras mise flatpak desktop docker shell)

CHECK=false
RUN_UPGRADE=false
CHANGE_SHELL=true
ONLY_SECTIONS=""
CHECK_DRIFT=0

export PATH="$HOME/.local/bin:$PATH"
APT_FLAGS=(-y -o Dpkg::Use-Pty=0 -o Acquire::Retries=3 -qq)

say() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*" >&2; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*" >&2
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }

sudo_apt_get() {
  sudo env DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

usage() {
  cat <<'EOF'
Usage: lm-bootstrap.sh [options]

Restore this workstation's managed applications, tools, and dotfiles.

Options:
  --check                 Report restore drift without changing the machine.
                          Exits 1 when managed state is missing.
  --only <sections>       Run comma-separated sections only.
                          Available: directories,apt,dotfiles,extras,mise,
                          flatpak,desktop,docker,shell
  --upgrade               Upgrade installed APT packages before restoring.
  --skip-upgrade          Do not upgrade installed APT packages (default).
  --skip-shell-change     Do not set Fish as the login shell.
  -h, --help              Show this help.

Examples:
  ./lm-bootstrap.sh --check
  ./lm-bootstrap.sh
  ./lm-bootstrap.sh --only dotfiles,mise
  ./lm-bootstrap.sh --upgrade
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        CHECK=true
        shift
        ;;
      --only)
        [[ $# -ge 2 ]] || fail "--only requires a comma-separated section list"
        [[ -n "$2" ]] || fail "--only requires a non-empty section list"
        ONLY_SECTIONS="$2"
        shift 2
        ;;
      --upgrade)
        RUN_UPGRADE=true
        shift
        ;;
      --skip-upgrade)
        RUN_UPGRADE=false
        shift
        ;;
      --skip-shell-change)
        CHANGE_SHELL=false
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
  done
}

section_is_known() {
  local requested="$1"
  local section

  for section in "${ALL_SECTIONS[@]}"; do
    [[ "$requested" == "$section" ]] && return 0
  done
  return 1
}

validate_sections() {
  local section
  local -a selected=()

  [[ -n "$ONLY_SECTIONS" ]] || return 0
  IFS=',' read -r -a selected <<<"$ONLY_SECTIONS"

  for section in "${selected[@]}"; do
    [[ -n "$section" ]] || fail "--only contains an empty section"
    section_is_known "$section" || fail "unknown section: $section"
  done
}

section_enabled() {
  local requested="$1"
  local section
  local -a selected=()

  [[ -n "$ONLY_SECTIONS" ]] || return 0
  IFS=',' read -r -a selected <<<"$ONLY_SECTIONS"

  for section in "${selected[@]}"; do
    [[ "$requested" == "$section" ]] && return 0
  done
  return 1
}

mark_drift() {
  warn "$*"
  CHECK_DRIFT=1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

load_manifest() {
  local manifest="$1"
  local output_name="$2"
  local line
  local -n output="$output_name"

  require_file "$manifest"
  output=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && output+=("$line")
  done <"$manifest"
}

run_script() {
  local script="$1"
  shift
  [[ -f "$script" ]] || fail "missing script: $script"
  bash "$script" "$@"
}

section_directories() {
  local directory
  local -a directories=(
    "${XDG_CONFIG_HOME:-$HOME/.config}"
    "${XDG_CACHE_HOME:-$HOME/.cache}"
    "${XDG_DATA_HOME:-$HOME/.local/share}"
    "${XDG_STATE_HOME:-$HOME/.local/state}"
    "$HOME/.local/bin"
  )

  say "XDG and user directories"
  for directory in "${directories[@]}"; do
    if [[ -d "$directory" ]]; then
      ok "$directory"
    elif [[ "$CHECK" == true ]]; then
      mark_drift "missing directory: $directory"
    else
      mkdir -p -- "$directory"
      ok "created $directory"
    fi
  done
}

section_apt() {
  local package
  local -a packages=()
  local -a missing=()

  load_manifest "$APT_MANIFEST" packages
  say "APT packages (${#packages[@]} managed)"

  if [[ "$CHECK" == true ]]; then
    for package in "${packages[@]}"; do
      dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii ' \
        || missing+=("$package")
    done

    if ((${#missing[@]} == 0)); then
      ok "all managed APT packages are installed"
    else
      mark_drift "missing APT packages (${#missing[@]}): ${missing[*]}"
    fi
    return
  fi

  has sudo || fail "sudo is required for APT restoration"
  sudo_apt_get update -qq

  if [[ "$RUN_UPGRADE" == true ]]; then
    say "Upgrading installed APT packages"
    sudo_apt_get upgrade "${APT_FLAGS[@]}"
  else
    ok "skipping full APT upgrade (use --upgrade to enable)"
  fi

  say "Installing managed APT packages"
  sudo_apt_get install "${APT_FLAGS[@]}" "${packages[@]}"
  ok "managed APT packages restored"
}

section_dotfiles() {
  local install_output=""

  say "Dotfiles"

  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if [[ -e "$DOTFILES_DIR" ]]; then
      fail "$DOTFILES_DIR exists but is not a Git repository"
    elif [[ "$CHECK" == true ]]; then
      mark_drift "dotfiles repository is not cloned at $DOTFILES_DIR"
      return
    else
      git clone https://github.com/mnishiguchi/dotfiles.git "$DOTFILES_DIR" \
        || fail "dotfiles clone failed over HTTPS"
      ok "dotfiles repository cloned"
    fi
  fi

  if [[ -n "$(git -C "$DOTFILES_DIR" status --short)" ]]; then
    warn "dotfiles repository contains local changes; they are being preserved"
  fi

  if [[ "$CHECK" == true ]]; then
    if ! install_output="$(run_script "$DOTFILES_DIR/install.sh" --force --check 2>&1)"; then
      printf '%s\n' "$install_output" >&2
      mark_drift "dotfiles check failed"
    elif grep -Eq ': (backup|link)[[:space:]]' <<<"$install_output"; then
      printf '%s\n' "$install_output"
      mark_drift "dotfile links differ from $DOTFILES_DIR"
    else
      ok "dotfile links match $DOTFILES_DIR"
    fi
    return
  fi

  run_script "$DOTFILES_DIR/install.sh" --force
  ok "dotfiles processed with conflict backups enabled"
}

section_extras() {
  local font_installed=false

  say "User-level extras"

  if has fc-list && fc-list | grep -F 'FiraCode Nerd Font' >/dev/null; then
    font_installed=true
  fi

  if [[ "$CHECK" == true ]]; then
    has diff-so-fancy || mark_drift "diff-so-fancy is not installed"
    [[ "$font_installed" == true ]] || mark_drift "FiraCode Nerd Font is not installed"
    if has diff-so-fancy && [[ "$font_installed" == true ]]; then
      ok "diff-so-fancy and FiraCode Nerd Font are installed"
    fi
    return
  fi

  run_script "$SCRIPT_DIR/shared/diff-so-fancy-install.sh"
  run_script "$SCRIPT_DIR/shared/nerd-fonts-install.sh"
  ok "user-level extras restored"
}

install_mise_cli() {
  if has mise; then
    ok "mise available: $(mise --version 2>/dev/null || printf present)"
    return
  fi

  if [[ "$CHECK" == true ]]; then
    mark_drift "mise is not installed"
    return 1
  fi

  has curl || fail "curl is required to install mise"
  curl -fsSL https://mise.run | sh || fail "mise installation failed"
  has mise || fail "mise was installed but is not available on PATH"
  ok "mise installed"
}

link_mise_config() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local target_dir="$config_home/mise"
  local target="$target_dir/config.toml"
  local current_target=""
  local backup

  require_file "$MISE_MANIFEST"

  if [[ -L "$target" ]]; then
    current_target="$(readlink -f -- "$target" 2>/dev/null || true)"
  fi

  if [[ "$current_target" == "$(readlink -f -- "$MISE_MANIFEST")" ]]; then
    ok "mise global config is linked to the managed manifest"
    return
  fi

  if [[ "$CHECK" == true ]]; then
    if [[ -f "$target" ]] && cmp -s -- "$MISE_MANIFEST" "$target"; then
      mark_drift "mise config content matches but is not linked to $MISE_MANIFEST"
    else
      mark_drift "mise global config is not managed by $MISE_MANIFEST"
    fi
    return
  fi

  mkdir -p -- "$target_dir"
  if [[ -e "$target" || -L "$target" ]]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$target" "$backup"
    warn "backed up existing mise config to $backup"
  fi
  ln -s -- "$MISE_MANIFEST" "$target"
  ok "linked $target -> $MISE_MANIFEST"
}

ensure_mise_fwup_plugin() {
  local plugin_url=""

  plugin_url="$(mise plugins ls --urls | awk '$1 == "fwup" { print $2; exit }')"
  if [[ "$plugin_url" == "$MISE_FWUP_PLUGIN_URL" ]]; then
    ok "mise fwup plugin is installed"
    return
  fi

  if [[ -n "$plugin_url" ]]; then
    fail "mise fwup plugin uses unexpected source: $plugin_url"
  elif [[ "$CHECK" == true ]]; then
    mark_drift "mise fwup plugin is not installed"
    return 1
  fi

  mise plugins install fwup "$MISE_FWUP_PLUGIN_URL" \
    || fail "mise fwup plugin installation failed"
  ok "mise fwup plugin installed"
}

section_mise() {
  local mise_check_state

  say "mise-managed development tools"
  if ! install_mise_cli; then
    return 0
  fi
  link_mise_config
  if ! ensure_mise_fwup_plugin; then
    return 0
  fi

  if [[ "$CHECK" == true ]]; then
    mise_check_state="$(mktemp -d)"
    if MISE_STATE_DIR="$mise_check_state" mise install -C "$MANIFEST_DIR" --dry-run-code; then
      ok "all mise tools from the managed manifest are installed"
    else
      mark_drift "one or more managed mise tools need installation"
    fi
    rm -rf -- "$mise_check_state"
    return
  fi

  mise install -C "$MANIFEST_DIR" --yes
  ok "mise tools restored from $MISE_MANIFEST"
}

section_flatpak() {
  local app
  local -a apps=()
  local -a missing=()

  load_manifest "$FLATPAK_MANIFEST" apps
  say "Flatpak applications (${#apps[@]} managed)"

  if ! has flatpak; then
    if [[ "$CHECK" == true ]]; then
      mark_drift "flatpak is not installed"
      return
    fi
    fail "flatpak is unavailable; run the apt section first"
  fi

  if [[ "$CHECK" == true ]]; then
    for app in "${apps[@]}"; do
      flatpak info --system "$app" >/dev/null 2>&1 || missing+=("$app")
    done

    if ((${#missing[@]} == 0)); then
      ok "all managed Flatpak applications are installed"
    else
      mark_drift "missing Flatpak applications (${#missing[@]}): ${missing[*]}"
    fi
    return
  fi

  has sudo || fail "sudo is required for system Flatpak restoration"
  sudo flatpak remote-add --system --if-not-exists \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  for app in "${apps[@]}"; do
    sudo flatpak install --system --noninteractive --assumeyes --or-update flathub "$app"
    ok "Flatpak ready: $app"
  done
}

install_brave() {
  if dpkg-query -W -f='${db:Status-Abbrev}' brave-browser 2>/dev/null | grep -q '^ii '; then
    ok "Brave Browser is installed"
    return
  fi

  if [[ "$CHECK" == true ]]; then
    mark_drift "Brave Browser is not installed"
    return
  fi

  has curl || fail "curl is required to install Brave Browser"
  has sudo || fail "sudo is required to install Brave Browser"
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
  sudo_apt_get update -qq
  sudo_apt_get install "${APT_FLAGS[@]}" brave-browser
  ok "Brave Browser installed from its official APT repository"
}

install_1password() {
  if dpkg-query -W -f='${db:Status-Abbrev}' 1password 2>/dev/null | grep -q '^ii '; then
    ok "1Password is installed"
  elif [[ "$CHECK" == true ]]; then
    mark_drift "1Password is not installed"
  else
    run_script "$SCRIPT_DIR/shared/1password-install.sh"
  fi
}

install_vscode() {
  if dpkg-query -W -f='${db:Status-Abbrev}' code 2>/dev/null | grep -q '^ii '; then
    ok "Visual Studio Code is installed"
  elif [[ "$CHECK" == true ]]; then
    mark_drift "Visual Studio Code is not installed"
  else
    run_script "$SCRIPT_DIR/debian/vscode-install.sh"
  fi
}

section_desktop() {
  say "Native desktop applications and settings"
  install_brave
  install_1password
  install_vscode

  if [[ "$CHECK" == true ]]; then
    if ! run_script "$SCRIPT_DIR/lm-desktop-settings.sh" check; then
      mark_drift "desktop settings differ from the managed snapshot"
    fi
  else
    run_script "$SCRIPT_DIR/lm-desktop-settings.sh" restore
  fi
}

section_docker() {
  say "Docker Engine and Compose"

  if [[ "$CHECK" == true ]]; then
    has docker || mark_drift "Docker is not installed"
    if has docker && docker compose version >/dev/null 2>&1; then
      ok "Docker Engine and Compose are available"
    elif has docker; then
      mark_drift "Docker Compose plugin is unavailable"
    fi
    return
  fi

  run_script "$SCRIPT_DIR/debian/docker-install.sh"
  ok "Docker ready"
}

section_shell() {
  local fish_path
  local current_shell

  say "Login shell"

  if [[ "$CHANGE_SHELL" != true ]]; then
    ok "login shell change skipped by request"
    return
  fi

  fish_path="$(command -v fish 2>/dev/null || true)"
  [[ -n "$fish_path" ]] || {
    if [[ "$CHECK" == true ]]; then
      mark_drift "Fish is not installed"
      return
    fi
    fail "Fish is unavailable; run the apt section first"
  }

  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" == "$fish_path" ]]; then
    ok "Fish is already the login shell"
    return
  fi

  if [[ "$CHECK" == true ]]; then
    mark_drift "login shell is $current_shell; expected $fish_path"
    return
  fi

  grep -Fxq "$fish_path" /etc/shells || fail "$fish_path is not listed in /etc/shells"
  has sudo || fail "sudo is required to change the login shell"
  sudo chsh -s "$fish_path" "$USER"
  ok "login shell changed to $fish_path"
}

run_sections() {
  local section

  for section in "${ALL_SECTIONS[@]}"; do
    if section_enabled "$section"; then
      "section_$section"
    fi
  done
}

main() {
  parse_args "$@"
  validate_sections
  require_file "$APT_MANIFEST"
  require_file "$FLATPAK_MANIFEST"
  require_file "$MISE_MANIFEST"

  [[ $EUID -ne 0 ]] || fail "run this script as your normal user, not with sudo"

  if [[ "$CHECK" == true ]]; then
    say "Checking managed workstation state"
  else
    say "Restoring managed workstation state"
  fi

  run_sections

  if [[ "$CHECK" == true ]]; then
    if ((CHECK_DRIFT != 0)); then
      warn "restore drift detected"
      exit 1
    fi
    ok "managed workstation state is complete"
  else
    echo
    ok "Restore complete. Log out and back in for shell and group changes."
  fi
}

main "$@"
