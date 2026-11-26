#!/bin/bash
# Restore the macOS terminal development environment using native Homebrew.
# Compatible with the system Bash 3.2; do not require Homebrew Bash to bootstrap.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly BREWFILE="$SCRIPT_DIR/manifests/Brewfile"
readonly DOTFILES_OVERRIDE="${DOTFILES_DIR:-}"
DOTFILES_DIR=""
readonly -a DEFAULT_SECTIONS=(preflight directories brew dotfiles mise alacritty shell verify)
readonly -a ALL_SECTIONS=(preflight directories brew dotfiles mise alacritty shell copyq colima verify optional build runtimes linkage)
readonly -a MISE_TOOLS=(neovim@latest yazi@latest)
readonly -a MISE_RUNTIMES=(erlang@28 elixir@1.19.5-otp-28 node@24 python@3.12 ruby@latest go@latest rust@latest uv@latest)
CHECK=false
CHANGE_SHELL=true
UPDATE_TMUX=false
DRIFT=0
ONLY=""

say() { printf '\n%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}
missing() {
  warn "$*"
  DRIFT=1
}

usage() {
  cat <<'USAGE'
Usage: macos-bootstrap.sh [options]

  --check             Check managed state without installing or changing settings.
  --only <sections>   Comma-separated sections (run in dependency order).
                      preflight,directories,brew,dotfiles,mise,alacritty,shell,
                      copyq,colima,verify,optional,build,runtimes,linkage
  --skip-shell-change Do not check or change the login shell.
  --update-tmux       Update a running tmux server to use Fish (no panes killed).
  -h, --help          Show help.

Default: preflight,directories,brew,dotfiles,mise,alacritty,shell,verify
Optional: copyq (official upstream DMG; manual Gatekeeper approval),
          colima (Docker CLI and on-demand Linux VM),
          optional (extra tools), build (native build dependencies),
          runtimes (Mise language runtimes; run build first), linkage (audit).
DOTFILES_DIR selects an existing checkout or a new clone destination.
Without an override, reuse the active checkout or an unambiguous known checkout.
Homebrew and Alacritty are installed manually; see docs/macos-setup.md.
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
      [[ $# -ge 2 && -n "$2" ]] || fail '--only requires sections'
      ONLY="$2"
      shift 2
      ;;
    --update-tmux)
      UPDATE_TMUX=true
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
    *) fail "unknown option: $1" ;;
    esac
  done
  local section
  local -a requested
  if [[ -n "$ONLY" ]]; then
    case "$ONLY" in ,* | *, | *,,*) fail 'empty section in --only' ;; esac
    IFS=',' read -r -a requested <<<"$ONLY"
    for section in "${requested[@]}"; do
      case "$section" in
      preflight | directories | brew | dotfiles | mise | alacritty | shell | copyq | colima | verify | optional | build | runtimes | linkage) ;;
      *) fail "unknown section: $section" ;;
      esac
    done
  fi
}

section_enabled() {
  local section="$1" selected
  if [[ -n "$ONLY" ]]; then
    [[ ",$ONLY," == *",$section,"* ]]
  else
    for selected in "${DEFAULT_SECTIONS[@]}"; do
      [[ "$selected" != "$section" ]] || return 0
    done
    return 1
  fi
}

# Select native Homebrew even when a GUI or a fresh shell has a minimal PATH.
init_brew_path() {
  local prefix
  case "$(uname -m)" in
  arm64) prefix=/opt/homebrew ;;
  x86_64) prefix=/usr/local ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
  esac
  if [[ -x "$prefix/bin/brew" ]]; then
    export PATH="$prefix/bin:$prefix/sbin:$PATH"
  fi
  export PATH="$PATH:$HOME/.local/bin"
}

section_directories() {
  local dir
  say 'XDG and user directories'
  for dir in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_CACHE_HOME:-$HOME/.cache}" \
    "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_STATE_HOME:-$HOME/.local/state}" "$HOME/.local/bin"; do
    if [[ ! -d "$dir" ]]; then
      if [[ "$CHECK" == true ]]; then missing "missing directory: $dir"; else mkdir -p "$dir"; fi
    fi
  done
}

# The preflight is diagnostic only. brew doctor may refresh cached metadata.
# Most doctor warnings (legacy packages, taps, etc.) are advisory; do not
# attempt automatic ownership, OS, certificate or package repairs.
section_preflight() {
  local prefix dir report os major
  say 'macOS prerequisites'
  os=$(sw_vers -productVersion) || fail 'cannot determine macOS version'
  major=${os%%.*}
  printf 'macOS %s (%s)\n' "$os" "$(uname -m)"
  if [[ "$major" =~ ^[0-9]+$ ]] && ((major < 15)); then
    warn 'Older macOS may lack bottles. Check https://docs.brew.sh/Support-Tiers before continuing.'
  fi
  if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find clang >/dev/null 2>&1; then
    missing 'Command Line Tools unavailable; run xcode-select --install or Software Update'
  fi
  if ! command -v brew >/dev/null 2>&1; then
    missing 'Install native Homebrew first: https://brew.sh/'
    return
  fi
  prefix=$(brew --prefix) || fail 'cannot determine Homebrew prefix'
  for dir in "$prefix" "$prefix/Cellar" "$prefix/var/log" "$prefix/var/homebrew/locks"; do
    if [[ -e "$dir" && (! -d "$dir" || ! -w "$dir") ]]; then
      missing "Homebrew directory not writable: $dir; inspect ownership manually"
    fi
  done
  if [[ -d "$prefix/var/homebrew/locks" ]]; then
    local lock
    for lock in "$prefix/var/homebrew/locks/"*; do
      [[ -e "$lock" ]] || continue
      if [[ ! -w "$lock" ]]; then missing "Homebrew lock not writable: $lock"; fi
    done
  fi
  if ! report=$(LC_ALL=C HOMEBREW_NO_AUTO_UPDATE=1 brew doctor 2>&1); then
    printf '%s\n' "$report"
    if grep -Eiq 'Command Line Tools are too outdated|Xcode.*too outdated|directories are not writable|permission denied|bad file descriptor' <<<"$report"; then
      missing 'Repair developer tools or Homebrew permissions before installing packages (see docs/macos-setup.md)'
    else
      warn 'Review brew doctor warnings; not all warnings block setup'
    fi
  fi
  # Report the version before potentially expensive installs. Alacritty is
  # manual, but a missing app should not prevent core CLI installation.
  if section_enabled alacritty; then
    if ! alacritty_compatible; then warn 'Install or update Alacritty before GUI acceptance testing'; fi
  fi
  if [[ -f "$HOME/.tool-versions" ]]; then warn "$HOME/.tool-versions may override Mise global config; review and archive manually if obsolete, then run mise reshim"; fi
  if [[ -f "$HOME/.netrc" ]]; then
    local mode
    mode=$(stat -f '%Lp' "$HOME/.netrc" 2>/dev/null || true)
    case "$mode" in 400 | 600) ;; *) warn 'Review ~/.netrc permissions (chmod 600 if it is your regular file)' ;; esac
  fi
}

bundle_manifest() {
  local manifest="$1"
  if ! command -v brew >/dev/null 2>&1; then
    if [[ "$CHECK" == true ]]; then
      missing 'Homebrew is missing'
      return
    fi
    fail 'Install native Homebrew first: https://brew.sh/ (see docs/macos-setup.md)'
  fi
  [[ -f "$manifest" ]] || fail "missing manifest: $manifest"
  if [[ "$CHECK" == true ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --verbose --file="$manifest" || missing "Homebrew packages missing: $manifest"
  else
    brew bundle install --no-upgrade --file="$manifest"
  fi
}
section_brew() {
  say 'Essential Homebrew packages'
  bundle_manifest "$BREWFILE"
}
section_optional() {
  say 'Optional Homebrew packages'
  bundle_manifest "$SCRIPT_DIR/manifests/Brewfile.optional"
}
section_build() {
  say 'Native build dependencies'
  bundle_manifest "$SCRIPT_DIR/manifests/Brewfile.build"
}

# Resolve real checkout paths so aliases do not count as duplicate repositories.
checkout_path() {
  local path="$1" root
  [[ -f "$path/install.sh" ]] || return 1
  root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || return 1
  path=$(cd -P -- "$path" && pwd -P) || return 1
  root=$(cd -P -- "$root" && pwd -P) || return 1
  [[ "$path" == "$root" ]] || return 1
  printf '%s\n' "$path"
}

# Only infer roots from known managed links, not arbitrary directories.
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
    [[ -z "$active" || "$root" == "$active" ]] || fail 'Managed links point to different dotfiles checkouts; inspect them and set DOTFILES_DIR explicitly'
    active="$root"
  done
  for candidate in "$SCRIPT_DIR/../dotfiles" "$HOME/Projects/dotfiles" "$HOME/Code/dotfiles" "$HOME/.dotfiles"; do
    root=$(checkout_path "$candidate") || continue
    case "$seen" in *$'\n'"$root"$'\n'*) continue ;; esac
    seen+="$root"$'\n'
    if [[ -n "$active" && "$root" != "$active" ]]; then
      warn "Other dotfiles checkout found: $root (keeping active checkout: $active)"
    fi
    if [[ -n "$found" && "$root" != "$found" ]]; then multiple=true; fi
    found="$root"
  done
  if [[ -n "$active" ]]; then
    DOTFILES_DIR="$active"
  elif [[ "$multiple" == true ]]; then
    fail 'Multiple dotfiles checkouts found; select one with DOTFILES_DIR'
  elif [[ -n "$found" ]]; then
    DOTFILES_DIR="$found"
  else
    DOTFILES_DIR="$SCRIPT_DIR/../dotfiles"
  fi
}

section_dotfiles() {
  local output status=0
  say 'Dotfiles'
  resolve_dotfiles
  printf 'Checkout: %s\n' "$DOTFILES_DIR"
  if ! checkout_path "$DOTFILES_DIR" >/dev/null; then
    if [[ "$CHECK" == true ]]; then
      missing "dotfiles checkout missing: $DOTFILES_DIR"
      return
    fi
    [[ ! -e "$DOTFILES_DIR" && ! -L "$DOTFILES_DIR" ]] || fail "not a Git checkout: $DOTFILES_DIR"
    git clone https://github.com/mnishiguchi/dotfiles.git "$DOTFILES_DIR"
    DOTFILES_DIR=$(checkout_path "$DOTFILES_DIR") || fail 'cloned dotfiles checkout is invalid'
  fi
  [[ -z "$(git -C "$DOTFILES_DIR" status --short)" ]] || warn 'Local dotfiles changes are preserved'
  [[ -f "$DOTFILES_DIR/install.sh" ]] || fail 'dotfiles install.sh is missing'
  output="$(bash "$DOTFILES_DIR/install.sh" --verify 2>&1)" || status=$?
  case "$status" in
  0) printf '%s\n' 'Dotfiles already synchronized' ;;
  3)
    if [[ "$CHECK" == true ]]; then
      printf '%s\n' "$output"
      missing 'dotfile links or directories differ'
    else
      bash "$DOTFILES_DIR/install.sh" --force
      bash "$DOTFILES_DIR/install.sh" --verify >/dev/null || fail 'dotfiles still differ after installation'
    fi
    ;;
  *)
    printf '%s\n' "$output" >&2
    if [[ "$CHECK" == true ]]; then
      missing 'dotfiles verification failed; update dotfiles to a revision supporting --verify'
    else
      fail 'dotfiles verification failed; refusing to replace configuration'
    fi
    ;;
  esac
}

mise_tools_ready() {
  local state spec tool version
  state=$(cd "$HOME" && mise ls --global --json) || return 1
  for spec in "$@"; do
    tool="${spec%@*}"
    version="${spec##*@}"
    jq -e --arg tool "$tool" --arg version "$version" '(.[$tool] // []) | any(.requested_version == $version and .installed == true and .active == true)' <<<"$state" >/dev/null || return 1
  done
}

manage_mise() {
  local target
  if ! command -v mise >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    if [[ "$CHECK" == true ]]; then
      missing 'mise or jq is missing'
      return
    fi
    fail 'run the brew section first'
  fi
  target="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
  if [[ -L "$target" || (-e "$target" && ! -f "$target") ]]; then
    if [[ "$CHECK" == true ]]; then
      missing "not a regular mise config: $target"
      return
    fi
    fail "not a regular mise config: $target"
  fi
  if [[ "$CHECK" == true ]]; then
    mise_tools_ready "$@" || missing "Mise tools not ready: $*"
  else
    if mise_tools_ready "$@"; then
      printf '%s\n' 'Mise tools already configured and installed'
    else
      (cd "$HOME" && mise use --global --yes "$@") || fail 'Mise installation failed'
    fi
    (cd "$HOME" && mise reshim) || fail 'Mise reshim failed'
    mise_tools_ready "$@" || fail 'Mise tools are not ready after installation; review global configuration'
  fi
}
section_mise() {
  say 'Mise-managed terminal tools'
  manage_mise "${MISE_TOOLS[@]}"
}
section_runtimes() {
  say 'Optional programming runtimes'
  # Erlang must be available before the Elixir OTP-specific build is installed.
  if [[ "$CHECK" == true ]]; then
    manage_mise "${MISE_RUNTIMES[@]}"
  else
    manage_mise "${MISE_RUNTIMES[0]}"
    manage_mise "${MISE_RUNTIMES[@]:1}"
  fi
}

alacritty_path() {
  local app
  for app in /Applications/Alacritty.app "$HOME/Applications/Alacritty.app"; do
    if [[ -x "$app/Contents/MacOS/alacritty" ]]; then
      printf '%s\n' "$app/Contents/MacOS/alacritty"
      return
    fi
  done
  command -v alacritty
}

alacritty_compatible() {
  local binary version major minor
  if ! binary="$(alacritty_path)" || ! version="$("$binary" --version)"; then return 1; fi
  printf '%s\n' "$version"
  if [[ "$version" =~ ^alacritty[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    if ((major > 0 || minor >= 14)); then return 0; fi
  fi
  return 1
}
section_alacritty() {
  say 'Alacritty (manual installation)'
  alacritty_compatible || missing 'Install Alacritty 0.14 or newer from https://alacritty.org/'
}

run_copyq_installer() {
  bash "$SCRIPT_DIR/macos/copyq-install.sh" "$@"
}

section_copyq() {
  say 'CopyQ clipboard manager (official upstream DMG; opt-in)'
  if [[ "$CHECK" == true ]]; then
    if ! run_copyq_installer --check; then
      missing 'CopyQ is not ready; run ./macos-bootstrap.sh --only copyq to install the official DMG'
    fi
  else
    run_copyq_installer install
  fi
}

run_colima_setup() {
  bash "$SCRIPT_DIR/macos/colima-setup.sh" "$@"
}

section_colima() {
  say 'Colima container development (opt-in)'
  if [[ "$CHECK" == true ]]; then
    run_colima_setup --check || missing 'Colima CLI setup incomplete; run --only colima (see docs/colima.md)'
  else
    run_colima_setup install
  fi
}

section_shell() {
  local fish_path current_shell tmux_shell
  [[ "$CHANGE_SHELL" == true ]] || return 0
  say 'Login shell'
  if ! fish_path="$(command -v fish)" || [[ "$fish_path" != /* ]] || ! "$fish_path" --version >/dev/null 2>&1; then
    if [[ "$CHECK" == true ]]; then
      missing 'Fish is missing'
      return
    fi
    fail 'run the brew section first'
  fi
  current_shell="$(login_shell)"
  if ! shell_registered "$fish_path"; then
    if [[ "$CHECK" == true ]]; then missing "Fish is not registered in /etc/shells: $fish_path"; else register_shell "$fish_path"; fi
  fi
  if [[ "$current_shell" != "$fish_path" ]]; then
    if [[ "$CHECK" == true ]]; then missing "login shell is $current_shell; expected $fish_path"; else chsh -s "$fish_path"; fi
  fi
  if [[ "$CHECK" == false ]]; then
    if [[ "$(login_shell)" != "$fish_path" ]] || ! shell_registered "$fish_path"; then
      fail 'Fish login shell change could not be verified'
    fi
  fi
  if tmux_shell=$(tmux show-options -gv default-shell 2>/dev/null); then
    if [[ "$tmux_shell" != "$fish_path" ]]; then
      if [[ "$CHECK" == false && "$UPDATE_TMUX" == true ]]; then
        tmux set-option -g default-shell "$fish_path" || fail 'could not update running tmux server'
        [[ "$(tmux show-options -gv default-shell)" == "$fish_path" ]] || fail 'tmux shell change not verified'
      else
        if [[ "$CHECK" == true ]]; then
          missing 'Running tmux uses another shell; run --only shell --update-tmux, or log out and back in'
        else
          warn 'Running tmux uses another shell; run --only shell --update-tmux, or log out and back in'
        fi
      fi
    fi
  fi
}
login_shell() { dscl . -read "/Users/$(id -un)" UserShell | sed 's/^UserShell: //'; }
shell_registered() { grep -Fxq "$1" /etc/shells; }
register_shell() { printf '%s\n' "$1" | sudo tee -a /etc/shells >/dev/null; }

verify_fresh_fish() {
  local fish_path="$1" nvim_path="$2" yazi_path="$3" prefix
  prefix=$(brew --prefix) || return 1
  # Start without inherited Mise activation or project-specific PATH entries.
  # Fish's normal startup may update its own caches or universal variables.
  # shellcheck disable=SC2016
  (cd "$HOME" && env -i HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" \
    SHELL="$fish_path" TERM=xterm-256color LANG="${LANG:-en_US.UTF-8}" PATH="$prefix/bin:$prefix/sbin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}" XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" \
    "$fish_path" -lic '
      set -l nvim_path (command -s nvim)
      set -l yazi_path (command -s yazi)
      /bin/bash -c '\''[[ "$1" -ef "$2" && "$3" -ef "$4" ]]'\'' _ "$nvim_path" "$argv[1]" "$yazi_path" "$argv[2]"; or begin
        printf "Fresh Fish tool paths: nvim=%s yazi=%s\n" "$nvim_path" "$yazi_path" >&2
        exit 1
      end
      command nvim --version >/dev/null; and command yazi --version >/dev/null
    ' "$nvim_path" "$yazi_path")
}

section_verify() {
  local tool flag binary nvim_path='' yazi_path=''
  say 'Executable verification'
  for tool in fish tmux git mise eza fzf zoxide rg jq just lazygit; do
    case "$tool" in tmux) flag=-V ;; *) flag=--version ;; esac
    if ! command -v "$tool" >/dev/null 2>&1 || ! "$tool" "$flag" >/dev/null 2>&1; then
      missing "missing or broken executable: $tool"
    fi
  done
  if command -v mise >/dev/null 2>&1; then
    for tool in nvim yazi; do
      # mise exec can install missing tools. Resolve and run the existing binary instead.
      if ! binary=$(cd "$HOME" && mise which "$tool") || [[ "$binary" != /* ]] || ! "$binary" --version >/dev/null 2>&1; then
        missing "Mise executable not working: $tool"
      else
        case "$tool" in nvim) nvim_path="$binary" ;; yazi) yazi_path="$binary" ;; esac
      fi
    done
  fi
  if [[ -x "$HOME/.local/bin/dotfiles-terminal" ]]; then :; else missing 'terminal launcher missing'; fi
  if ! fish -n "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"; then
    missing 'Fish config syntax check failed'
  elif [[ -n "$nvim_path" && -n "$yazi_path" ]]; then
    verify_fresh_fish "$(command -v fish)" "$nvim_path" "$yazi_path" || missing 'Fresh Fish cannot resolve the expected Mise tools; review Mise activation and PATH'
  fi
  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew missing || missing 'Homebrew reports missing dependencies'
  fi
}
section_linkage() {
  say 'Homebrew shared library audit (may enable Homebrew developer mode)'
  HOMEBREW_NO_AUTO_UPDATE=1 brew linkage --test || missing 'Broken library links; repair affected packages manually'
}

main() {
  parse_args "$@"
  [[ "$(uname -s)" == Darwin ]] || fail 'macOS is required; use lm-bootstrap.sh on LMDE'
  [[ $EUID -ne 0 ]] || fail 'run as your normal user, not with sudo'
  [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" != 1 ]] || fail 'use a native terminal, not Rosetta'
  init_brew_path
  local section
  # Check prerequisites even when installing only a package section.
  if [[ "$CHECK" == false ]] && ! section_enabled preflight; then
    if section_enabled brew || section_enabled colima || section_enabled optional || section_enabled build || section_enabled runtimes; then
      section_preflight
      ((DRIFT == 0)) || fail 'preflight failed; no packages installed'
    fi
  fi
  for section in "${ALL_SECTIONS[@]}"; do
    if section_enabled "$section"; then
      "section_$section"
      if [[ "$section" == preflight && "$CHECK" == false ]] && ((DRIFT)); then fail 'preflight failed; no packages installed'; fi
    fi
  done
  if ((DRIFT)); then
    warn 'Managed state is incomplete; resolve the warnings and run --check again'
    return 1
  fi
  if [[ "$CHECK" == true ]]; then say 'Managed state is ready'; else say 'Restore complete. Log out and back in if the login shell changed.'; fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
