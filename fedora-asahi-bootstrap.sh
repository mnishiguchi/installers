#!/usr/bin/env bash
# Restore the Fedora Asahi Remix ARM64 KDE workstation.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly MANIFEST_DIR="$SCRIPT_DIR/manifests"
readonly OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
readonly SHELLS_FILE="${SHELLS_FILE:-/etc/shells}"
readonly DOTFILES_OVERRIDE="${DOTFILES_DIR:-}"
DOTFILES_DIR=""
readonly PACKAGE_MANIFEST="$MANIFEST_DIR/fedora-asahi-packages.txt"
readonly DESKTOP_MANIFEST="$MANIFEST_DIR/fedora-asahi-desktop-packages.txt"
readonly BUILD_MANIFEST="$MANIFEST_DIR/fedora-asahi-build-packages.txt"
readonly -a DEFAULT_SECTIONS=(preflight directories packages desktop fonts dotfiles mise shell verify)
readonly -a ALL_SECTIONS=(preflight directories packages desktop fonts dotfiles mise build runtimes shell verify)
readonly -a MISE_TOOLS=(yazi@latest shfmt@latest github:linebender/resvg@0.50.0)
readonly -a MISE_RUNTIMES=(erlang@28 elixir@1.19.5-otp-28 node@24 python@3.12 ruby@latest go@latest rust@latest uv@latest)

export PATH="$HOME/.local/bin:$PATH"

CHECK=false
CHANGE_SHELL=true
ONLY=""
DRIFT=0

say() { printf '\n%s\n' "$*"; }
ok() { printf '  [ok] %s\n' "$*"; }
warn() { printf '  [review] %s\n' "$*" >&2; }
fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}
mark_drift() {
  warn "$*"
  DRIFT=1
}
has() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'USAGE'
Usage: fedora-asahi-bootstrap.sh [options]

Restore the Fedora Asahi Remix ARM64 KDE workstation.

Options:
  --check                 Report managed-state drift without changing the system.
  --only <sections>       Run comma-separated sections in dependency order:
                          preflight,directories,packages,desktop,fonts,dotfiles,
                          mise,build,runtimes,shell,verify
  --skip-shell-change     Do not set Fish as the login shell.
  -h, --help              Show this help.

Default sections:
  preflight,directories,packages,desktop,fonts,dotfiles,mise,shell,verify

Optional development setup:
  ./fedora-asahi-bootstrap.sh --only build,runtimes

DOTFILES_DIR selects an existing checkout or a clone destination. Without an
override, the script reuses a managed checkout or looks for ../dotfiles,
~/Projects/dotfiles, ~/Code/dotfiles, and ~/.dotfiles before cloning.
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --check)
        CHECK=true
        shift
        ;;
      --only)
        [[ $# -ge 2 && -n "$2" ]] || fail '--only requires a non-empty section list'
        ONLY="$2"
        shift 2
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

  local section
  local -a requested=()
  if [[ -n "$ONLY" ]]; then
    [[ "$ONLY" != ,* && "$ONLY" != *, && "$ONLY" != *,,* ]] || fail '--only contains an empty section'
    IFS=',' read -r -a requested <<<"$ONLY"
    for section in "${requested[@]}"; do
      section_is_known "$section" || fail "unknown section: $section"
    done
  fi
}

section_is_known() {
  local requested="$1" section
  for section in "${ALL_SECTIONS[@]}"; do
    [[ "$requested" == "$section" ]] && return 0
  done
  return 1
}

section_enabled() {
  local requested="$1" section
  local -a selected=()
  if [[ -z "$ONLY" ]]; then
    for section in "${DEFAULT_SECTIONS[@]}"; do
      [[ "$requested" == "$section" ]] && return 0
    done
    return 1
  fi
  IFS=',' read -r -a selected <<<"$ONLY"
  for section in "${selected[@]}"; do
    [[ "$requested" == "$section" ]] && return 0
  done
  return 1
}

load_manifest() {
  local manifest="$1" output_name="$2" line
  local -n output="$output_name"
  [[ -f "$manifest" ]] || fail "missing package manifest: $manifest"
  output=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && output+=("$line")
  done <"$manifest"
}

read_os_release_value() {
  local key="$1"
  [[ -r "$OS_RELEASE_FILE" ]] || fail "cannot read OS release file: $OS_RELEASE_FILE"
  # shellcheck disable=SC1090
  . "$OS_RELEASE_FILE"
  case "$key" in
    ID) printf '%s\n' "${ID:-}" ;;
    VERSION_ID) printf '%s\n' "${VERSION_ID:-}" ;;
    RELEASE_TYPE) printf '%s\n' "${RELEASE_TYPE:-}" ;;
    PRETTY_NAME) printf '%s\n' "${PRETTY_NAME:-}" ;;
    *) fail "unsupported os-release key: $key" ;;
  esac
}

section_preflight() {
  local os_id os_version release_type pretty_name architecture
  say 'Fedora Asahi prerequisites'
  os_id="$(read_os_release_value ID)"
  os_version="$(read_os_release_value VERSION_ID)"
  release_type="$(read_os_release_value RELEASE_TYPE)"
  pretty_name="$(read_os_release_value PRETTY_NAME)"
  architecture="$(uname -m)"

  [[ "$os_id" == fedora-asahi-remix ]] || fail "Fedora Asahi Remix is required (detected ID=$os_id)"
  [[ "$architecture" == aarch64 ]] || fail "ARM64/aarch64 is required (detected $architecture)"
  has dnf || fail 'DNF is required'
  has rpm || fail 'RPM is required'

  printf '%s\n' "$pretty_name ($architecture)"
  if [[ "$os_version" != 45 ]]; then
    warn "This setup was tested on Fedora Asahi Remix 45, not $os_version"
  fi
  if [[ "$release_type" == development ]]; then
    warn 'This Fedora Asahi Remix build identifies itself as a development/prerelease release'
  fi
  ok 'Fedora Asahi Remix ARM64 detected'
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
  say 'XDG and user directories'
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

section_packages_from_manifest() {
  local manifest="$1" label="$2" package missing_list
  local -a packages=() missing=()
  load_manifest "$manifest" packages
  say "$label (${#packages[@]} packages)"

  if [[ "$CHECK" == true ]]; then
    for package in "${packages[@]}"; do
      rpm -q --quiet "$package" || missing+=("$package")
    done
    if ((${#missing[@]})); then
      missing_list=$(printf '%s ' "${missing[@]}")
      mark_drift "packages missing: ${missing_list% }"
    else
      ok "$label are installed"
    fi
    return
  fi

  sudo dnf install --assumeyes "${packages[@]}"
  ok "$label installed"
}

section_packages() {
  section_packages_from_manifest "$PACKAGE_MANIFEST" 'Core workstation packages'
}

section_desktop() {
  section_packages_from_manifest "$DESKTOP_MANIFEST" 'KDE desktop integration packages'
}

section_build() {
  section_packages_from_manifest "$BUILD_MANIFEST" 'Native development and Erlang Observer build dependencies'
}

font_installed() {
  has fc-list && fc-list 2>/dev/null | grep -F 'FiraCode Nerd Font' >/dev/null
}

section_fonts() {
  say 'FiraCode Nerd Font'
  if font_installed; then
    ok 'FiraCode Nerd Font is installed'
  elif [[ "$CHECK" == true ]]; then
    mark_drift 'FiraCode Nerd Font is missing; run --only fonts to install it'
  else
    bash "$SCRIPT_DIR/user/nerd-fonts-install.sh"
    font_installed || fail 'FiraCode Nerd Font installation could not be verified'
  fi
}

checkout_path() {
  local path="$1" root
  [[ -f "$path/install.sh" ]] || return 1
  root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || return 1
  path=$(cd -P -- "$path" && pwd -P) || return 1
  root=$(cd -P -- "$root" && pwd -P) || return 1
  [[ "$path" == "$root" ]] || return 1
  printf '%s\n' "$path"
}

linked_checkout() {
  local link="$1" suffix="$2" target root
  [[ -L "$link" ]] || return 1
  target=$(readlink "$link") || return 1
  case "$target" in /*) ;; *) target="$(dirname "$link")/$target" ;; esac
  case "$target" in */"$suffix") root=${target%/"$suffix"} ;; *) return 1 ;; esac
  root=$(checkout_path "$root") || return 1
  [[ "$link" -ef "$root/$suffix" ]] || return 1
  printf '%s\n' "$root"
}

resolve_dotfiles() {
  local candidate root active='' found='' multiple=false seen=$'\n'
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"

  if [[ -n "$DOTFILES_OVERRIDE" ]]; then
    DOTFILES_DIR="$DOTFILES_OVERRIDE"
    if [[ -e "$DOTFILES_DIR" || -L "$DOTFILES_DIR" ]]; then
      DOTFILES_DIR=$(checkout_path "$DOTFILES_DIR") || fail 'DOTFILES_DIR is not a dotfiles Git checkout'
    fi
    return
  fi

  for candidate in bash fish launcher doctor; do
    case "$candidate" in
      bash) root=$(linked_checkout "$HOME/.bashrc" bash/bashrc) || continue ;;
      fish) root=$(linked_checkout "$config/fish/config.fish" fish/config.fish) || continue ;;
      launcher) root=$(linked_checkout "$HOME/.local/bin/dotfiles-terminal" bin/dotfiles-terminal) || continue ;;
      doctor) root=$(linked_checkout "$HOME/.local/bin/dotfiles-doctor" bin/dotfiles-doctor) || continue ;;
    esac
    [[ -z "$active" || "$root" == "$active" ]] || fail 'managed links point to different dotfiles checkouts; set DOTFILES_DIR explicitly'
    active="$root"
  done

  for candidate in "$SCRIPT_DIR/../dotfiles" "$HOME/Projects/dotfiles" "$HOME/Code/dotfiles" "$HOME/.dotfiles"; do
    root=$(checkout_path "$candidate") || continue
    case "$seen" in *$'\n'"$root"$'\n'*) continue ;; esac
    seen+="$root"$'\n'
    [[ -z "$found" || "$root" == "$found" ]] || multiple=true
    found="$root"
  done

  if [[ -n "$active" ]]; then
    DOTFILES_DIR="$active"
  elif [[ "$multiple" == true ]]; then
    fail 'multiple dotfiles checkouts found; select one with DOTFILES_DIR'
  elif [[ -n "$found" ]]; then
    DOTFILES_DIR="$found"
  else
    DOTFILES_DIR="$HOME/Projects/dotfiles"
  fi
}

section_dotfiles() {
  local output status=0
  say 'Dotfiles'
  resolve_dotfiles
  printf 'Checkout: %s\n' "$DOTFILES_DIR"

  if ! checkout_path "$DOTFILES_DIR" >/dev/null; then
    if [[ "$CHECK" == true ]]; then
      mark_drift "dotfiles checkout missing: $DOTFILES_DIR"
      return
    fi
    [[ ! -e "$DOTFILES_DIR" && ! -L "$DOTFILES_DIR" ]] || fail "not a Git checkout: $DOTFILES_DIR"
    mkdir -p -- "$(dirname -- "$DOTFILES_DIR")"
    git clone https://github.com/mnishiguchi/dotfiles.git "$DOTFILES_DIR"
    DOTFILES_DIR=$(checkout_path "$DOTFILES_DIR") || fail 'cloned dotfiles checkout is invalid'
  fi

  [[ -z "$(git -C "$DOTFILES_DIR" status --short)" ]] || warn 'local dotfiles changes are preserved'
  output="$(bash "$DOTFILES_DIR/install.sh" --verify 2>&1)" || status=$?
  case "$status" in
    0) ok 'dotfiles already synchronized' ;;
    3)
      if [[ "$CHECK" == true ]]; then
        printf '%s\n' "$output"
        mark_drift 'dotfile links or directories differ'
      else
        bash "$DOTFILES_DIR/install.sh" --force
        bash "$DOTFILES_DIR/install.sh" --verify >/dev/null || fail 'dotfiles still differ after installation'
        ok 'dotfiles synchronized'
      fi
      ;;
    *)
      printf '%s\n' "$output" >&2
      if [[ "$CHECK" == true ]]; then
        mark_drift 'dotfiles verification failed; update dotfiles to a revision supporting --verify'
      else
        fail 'dotfiles verification failed; refusing to replace configuration'
      fi
      ;;
  esac
}

install_mise_cli() {
  local temp_dir installer
  if has mise && mise --version >/dev/null 2>&1; then
    ok "mise is available: $(mise --version)"
    return 0
  fi
  if [[ "$CHECK" == true ]]; then
    mark_drift 'mise is missing; run the mise section to install it'
    return 0
  fi
  has curl || fail 'curl is required to install mise'
  temp_dir=$(mktemp -d)
  installer="$temp_dir/mise-install.sh"
  if ! curl -fsSL https://mise.run -o "$installer"; then
    rm -rf -- "$temp_dir"
    fail 'could not download the official mise installer'
  fi
  if ! sh "$installer"; then
    rm -rf -- "$temp_dir"
    fail 'mise installation failed'
  fi
  rm -rf -- "$temp_dir"
  export PATH="$HOME/.local/bin:$PATH"
  has mise || fail 'mise installer completed but mise is not on PATH'
  ok "mise installed: $(mise --version)"
}

mise_tools_ready() {
  local state spec tool version
  state=$(cd "$HOME" && mise ls --global --json) || return 1
  for spec in "$@"; do
    tool="${spec%@*}"
    version="${spec##*@}"
    jq -e --arg tool "$tool" --arg version "$version" \
      '(.[$tool] // []) | any(.requested_version == $version and .installed == true and .active == true)' \
      <<<"$state" >/dev/null || return 1
  done
}

manage_mise() {
  local target
  target="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
  if [[ -L "$target" || (-e "$target" && ! -f "$target") ]]; then
    if [[ "$CHECK" == true ]]; then
      mark_drift "not a regular mise config: $target"
      return
    fi
    fail "not a regular mise config: $target"
  fi

  if [[ "$CHECK" == true ]]; then
    mise_tools_ready "$@" || mark_drift "Mise tools not ready: $*"
  else
    if mise_tools_ready "$@"; then
      ok 'requested Mise tools are already installed'
    else
      (cd "$HOME" && mise use --global --yes "$@") || fail 'Mise tool installation failed'
    fi
    (cd "$HOME" && mise reshim) || fail 'mise reshim failed'
    mise_tools_ready "$@" || fail 'Mise tools are not ready after installation; review the global configuration'
  fi
}

section_mise() {
  say 'Mise-managed terminal tools'
  install_mise_cli || return
  if ! has jq; then
    if [[ "$CHECK" == true ]]; then mark_drift 'jq is missing; run the packages section first'; return; fi
    fail 'jq is required to verify Mise tool installations'
  fi
  manage_mise "${MISE_TOOLS[@]}"
}

build_prerequisites_ready() {
  local package
  local -a packages=()
  load_manifest "$BUILD_MANIFEST" packages
  for package in "${packages[@]}"; do
    rpm -q --quiet "$package" || return 1
  done
}

section_runtimes() {
  say 'Optional language runtimes'
  if ! build_prerequisites_ready; then
    if [[ "$CHECK" == true ]]; then
      mark_drift 'native build dependencies are missing; run --only build,runtimes before compiling Erlang'
      return
    fi
    fail 'native build dependencies are missing; run --only build,runtimes before compiling Erlang'
  fi

  install_mise_cli || return
  if ! has jq; then
    if [[ "$CHECK" == true ]]; then mark_drift 'jq is missing; run the packages section first'; return; fi
    fail 'jq is required to verify Mise tool installations'
  fi
  if [[ "$CHECK" == true ]]; then
    manage_mise "${MISE_RUNTIMES[@]}"
  else
    # Elixir's OTP-specific build must follow the Erlang toolchain installation.
    manage_mise "${MISE_RUNTIMES[0]}"
    manage_mise "${MISE_RUNTIMES[@]:1}"
  fi
}

section_shell() {
  local fish_path current_shell username
  say 'Fish login shell'
  [[ "$CHANGE_SHELL" == true ]] || { ok 'login shell change skipped'; return; }
  fish_path="$(command -v fish 2>/dev/null || true)"
  [[ -n "$fish_path" && "$fish_path" == /* ]] || {
    if [[ "$CHECK" == true ]]; then mark_drift 'Fish is missing'; return; fi
    fail 'Fish is missing; run the packages section first'
  }
  username="$(id -un)"
  current_shell="$(getent passwd "$username" | cut -d: -f7)"

  if ! grep -Fxq "$fish_path" "$SHELLS_FILE"; then
    if [[ "$CHECK" == true ]]; then
      mark_drift "Fish is not registered in $SHELLS_FILE: $fish_path"
    else
      printf '%s\n' "$fish_path" | sudo tee -a "$SHELLS_FILE" >/dev/null
      ok "registered Fish in $SHELLS_FILE"
    fi
  fi

  if [[ "$current_shell" != "$fish_path" ]]; then
    if [[ "$CHECK" == true ]]; then
      mark_drift "login shell is $current_shell; expected $fish_path"
    else
      chsh -s "$fish_path"
      [[ "$(getent passwd "$username" | cut -d: -f7)" == "$fish_path" ]] || fail 'Fish login shell change could not be verified'
      ok "login shell changed to $fish_path; log out and back in to use it"
    fi
  else
    ok "Fish is already the login shell: $fish_path"
  fi
}

verify_mise_command() {
  local tool="$1" binary
  if ! binary=$(mise which "$tool" 2>/dev/null) || [[ "$binary" != /* ]] || ! "$binary" --version >/dev/null 2>&1; then
    mark_drift "Mise executable is missing or broken: $tool"
  else
    ok "$tool: $binary"
  fi
}

section_verify() {
  local tool
  local -a commands=(fish tmux git gh nvim alacritty eza fzf zoxide rg jq just lazygit copyq fcitx5 clangd)
  say 'Executable and configuration verification'
  for tool in "${commands[@]}"; do
    local version_flag=--version
    [[ "$tool" != tmux ]] || version_flag=-V
    if has "$tool" && "$tool" "$version_flag" >/dev/null 2>&1; then
      ok "$tool"
    else
      mark_drift "missing or broken executable: $tool"
    fi
  done

  if has mise; then
    verify_mise_command yazi
    verify_mise_command shfmt
    verify_mise_command resvg
  else
    mark_drift 'mise is missing'
  fi

  [[ -n "$DOTFILES_DIR" ]] || resolve_dotfiles
  if [[ -n "$DOTFILES_DIR" && -f "$DOTFILES_DIR/fish/config.fish" ]]; then
    if fish -n "$DOTFILES_DIR/fish/config.fish"; then
      ok 'Fish configuration syntax'
    else
      mark_drift 'Fish configuration syntax check failed'
    fi
  else
    mark_drift 'dotfiles Fish configuration is unavailable; run the dotfiles section'
  fi
}

main() {
  local section
  parse_args "$@"
  [[ $EUID -ne 0 ]] || fail 'run as your normal user, not with sudo'

  # Always validate the target before any package or user configuration work.
  section_preflight

  for section in "${ALL_SECTIONS[@]}"; do
    [[ "$section" == preflight ]] && continue
    section_enabled "$section" || continue
    "section_$section"
  done

  if ((DRIFT)); then
    warn 'managed state is incomplete; resolve the reported items and run --check again'
    return 1
  fi
  if [[ "$CHECK" == true ]]; then
    say 'Managed state is ready'
  else
    say 'Restore complete. Log out and back in if the login shell changed.'
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
