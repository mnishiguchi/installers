#!/bin/bash
# HOME changes in subshells intentionally leave the parent test unchanged.
# shellcheck disable=SC2030,SC2031,SC2034,SC2154
# Offline regression tests. No Homebrew, network, sudo or real home mutations.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REAL_FISH=$(command -v fish || true)
TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME
mkdir -p "$HOME"
export DOTFILES_DIR="$TMP/dotfiles"
# shellcheck source=macos-bootstrap.sh
source "$ROOT/macos-bootstrap.sh"

parse_args --check --only directories,brew --skip-shell-change
[[ "$CHECK" == true && "$CHANGE_SHELL" == false ]]
section_enabled directories
section_enabled brew
if section_enabled shell || section_enabled runtimes || section_enabled copyq || section_enabled colima; then
  echo "unexpected section selected" >&2; exit 1
fi
parse_args --check --only copyq
section_enabled copyq
if section_enabled brew; then echo "unexpected section selected" >&2; exit 1; fi
parse_args --check --only colima
section_enabled colima
if section_enabled brew || section_enabled copyq; then echo "unexpected section selected" >&2; exit 1; fi
parse_args --check --only directories,brew --skip-shell-change
for sections in bogus 'brew,' ',brew' 'brew,,shell'; do
  if (parse_args --only "$sections"); then echo "accepted bad section: $sections" >&2; exit 1; fi
done
section_directories
[[ "$DRIFT" == 1 && ! -e "$HOME/.config" ]]
# CopyQ is an explicit opt-in because its official macOS app needs manual Gatekeeper approval.
COPYQ_MODE=''
run_copyq_installer() { COPYQ_MODE="$1"; return "${COPYQ_INSTALL_STATUS:-0}"; }
CHECK=true
DRIFT=0
section_copyq
[[ "$COPYQ_MODE" == --check && "$DRIFT" == 0 ]]
COPYQ_INSTALL_STATUS=1
section_copyq
[[ "$DRIFT" == 1 ]]
CHECK=false
DRIFT=0
COPYQ_INSTALL_STATUS=0
section_copyq
[[ "$COPYQ_MODE" == install && "$DRIFT" == 0 ]]
# Colima is opt-in and check mode does not start a VM.
COLIMA_MODE=''
run_colima_setup() { COLIMA_MODE="$1"; return "${COLIMA_STATUS:-0}"; }
CHECK=true
DRIFT=0
section_colima
[[ "$COLIMA_MODE" == --check && "$DRIFT" == 0 ]]
COLIMA_STATUS=1
section_colima
[[ "$DRIFT" == 1 ]]
CHECK=false
DRIFT=0
COLIMA_STATUS=0
section_colima
[[ "$COLIMA_MODE" == install && "$DRIFT" == 0 ]]
CHECK=false
DRIFT=0
section_directories
[[ -d "$HOME/.config" && -d "$HOME/.local/bin" ]]
CHECK=true
section_directories
[[ "$DRIFT" == 0 ]]

brew() { printf '%s\n' "$*" >> "$TMP/brew.log"; }
section_brew
grep -F 'bundle check --no-upgrade --verbose' "$TMP/brew.log"
CHECK=false
section_brew
grep -F 'bundle install --no-upgrade' "$TMP/brew.log"

alacritty_path() { printf '%s\n' "$TMP/alacritty"; }
printf '#!/bin/sh\necho alacritty 0.13.2\n' > "$TMP/alacritty"
chmod +x "$TMP/alacritty"
DRIFT=0
section_alacritty
[[ "$DRIFT" == 1 ]]
printf '#!/bin/sh\necho alacritty 0.17.0\n' > "$TMP/alacritty"
DRIFT=0
section_alacritty
[[ "$DRIFT" == 0 ]]
# Mock preflight without touching the host or invoking Homebrew.
sw_vers() { echo 26.7.3; }
xcode-select() { echo /Library/Developer/CommandLineTools; }
xcrun() { echo /usr/bin/clang; }
mkdir -p "$TMP/prefix/var/homebrew/locks" "$TMP/prefix/Cellar"
DOCTOR_REPORT=''
brew() {
  case "$1" in
    --prefix) printf '%s\n' "$TMP/prefix" ;;
    doctor) if [[ -n "$DOCTOR_REPORT" ]]; then printf '%s\n' "$DOCTOR_REPORT"; return 1; fi ;;
    *) printf '%s\n' "$*" >> "$TMP/brew.log" ;;
  esac
}
DRIFT=0
section_preflight
[[ "$DRIFT" == 0 ]]
DOCTOR_REPORT='Warning: Your Command Line Tools are too outdated.'
section_preflight
[[ "$DRIFT" == 1 ]]
DRIFT=0
DOCTOR_REPORT='Warning: Some installed casks are deprecated or disabled.'
section_preflight
[[ "$DRIFT" == 0 ]]
CHECK=false
section_optional
section_build
grep -F 'Brewfile.optional' "$TMP/brew.log"
grep -F 'Brewfile.build' "$TMP/brew.log"
# Consumer checks exit codes, not human output.
DOTFILES_DIR="$DOTFILES_OVERRIDE"
mkdir -p "$DOTFILES_DIR"
git init -q "$DOTFILES_DIR"
printf '#!/bin/bash\necho "mkdir example"\nexit 0\n' > "$DOTFILES_DIR/install.sh"
CHECK=true
DRIFT=0
section_dotfiles
[[ "$DRIFT" == 0 ]]
printf '#!/bin/bash\nexit 3\n' > "$DOTFILES_DIR/install.sh"
section_dotfiles
[[ "$DRIFT" == 1 ]]
# Apply is a no-op when ready, reconciles only drift, and refuses errors.
cat > "$DOTFILES_DIR/install.sh" <<'INSTALL'
#!/bin/bash
case "$1" in
  --verify) if [[ -f "$HOME/dotfiles.ready" ]]; then exit 0; else exit 3; fi ;;
  --force) touch "$HOME/dotfiles.ready"; printf 'apply\n' >> "$HOME/dotfiles.log" ;;
  *) exit 1 ;;
esac
INSTALL
CHECK=false
DRIFT=0
section_dotfiles
section_dotfiles
[[ "$(cat "$HOME/dotfiles.log")" == apply ]]
printf '#!/bin/bash\nexit 1\n' > "$DOTFILES_DIR/install.sh"
if (section_dotfiles); then exit 1; fi
# Shell registration, post-change verification, and opt-in tmux update.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho fish 3.7.1\n' > "$TMP/bin/fish"
chmod +x "$TMP/bin/fish"
export PATH="$TMP/bin:$PATH"
LOGIN=/bin/bash
REGISTERED=false
TMUX_SHELL=/bin/bash
login_shell() { printf '%s\n' "$LOGIN"; }
shell_registered() { [[ "$REGISTERED" == true ]]; }
register_shell() { REGISTERED=true; }
chsh() { LOGIN=$2; }
tmux() {
  case "$1" in
    show-options) printf '%s\n' "$TMUX_SHELL" ;;
    set-option) TMUX_SHELL=$4 ;;
    *) return 1 ;;
  esac
}
CHANGE_SHELL=true
CHECK=true
DRIFT=0
section_shell
[[ "$DRIFT" == 1 && "$LOGIN" == /bin/bash && "$REGISTERED" == false ]]
CHECK=false
DRIFT=0
section_shell
[[ "$LOGIN" == "$TMP/bin/fish" && "$REGISTERED" == true && "$TMUX_SHELL" == /bin/bash ]]
UPDATE_TMUX=true
section_shell
[[ "$TMUX_SHELL" == "$TMP/bin/fish" ]]
CHECK=true
section_shell
[[ "$DRIFT" == 0 ]]
# Discovery tests run in a child shell so the override and script location
# are isolated. Use actual Git checkouts and relative compatibility links.
(
  unset DOTFILES_DIR
  export HOME="$TMP/discovery-home"
  mkdir -p "$HOME/Projects/installers" "$HOME/Projects/dotfiles" "$HOME/.config/fish"
  # Re-source in a new Bash because configuration variables are readonly.
  cat > "$TMP/discovery-test.sh" <<'DISCOVERY'
set -euo pipefail
source "$1"
make_checkout() {
  mkdir -p "$1/fish" "$1/bash"
  git init -q "$1"
  touch "$1/install.sh" "$1/fish/config.fish" "$1/bash/bashrc"
}
make_checkout "$HOME/Projects/dotfiles"
ln -s Projects "$HOME/Code"
ln -s Projects/dotfiles "$HOME/.dotfiles"
resolve_dotfiles
[[ "$DOTFILES_DIR" == "$HOME/Projects/dotfiles" ]]
# A second real checkout with no active links is ambiguous.
unlink "$HOME/.dotfiles"
make_checkout "$HOME/.dotfiles"
if (resolve_dotfiles); then exit 1; fi
# An active checkout wins over the old sibling, even through a relative link.
ln -s ../../.dotfiles/fish/config.fish "$HOME/.config/fish/config.fish"
resolve_dotfiles
[[ "$DOTFILES_DIR" == "$HOME/.dotfiles" ]]
# Conflicting managed links are not silently replaced.
ln -s "$HOME/Projects/dotfiles/bash/bashrc" "$HOME/.bashrc"
if (resolve_dotfiles); then exit 1; fi
DISCOVERY
  # Isolate sibling-checkout discovery from the real workstation.
  cp "$ROOT/macos-bootstrap.sh" "$HOME/Projects/installers/macos-bootstrap.sh"
  bash "$TMP/discovery-test.sh" "$HOME/Projects/installers/macos-bootstrap.sh"
)
# Ready Mise tools are not reinstalled; reshim is apply-only.
CHECK=true
DRIFT=0
mkdir -p "$HOME/.config/mise"
touch "$HOME/.config/mise/config.toml"
# Use a persistent marker since mise use runs in a subshell.
mise() {
  printf '%s\n' "$*" >> "$TMP/mise.log"
  case "$1" in
    ls) if [[ -f "$TMP/mise.ready" ]]; then
      printf '%s\n' '{"neovim":[{"requested_version":"latest","installed":true,"active":true}],"yazi":[{"requested_version":"latest","installed":true,"active":true}]}'
    else printf '%s\n' '{}'; fi ;;
    use) touch "$TMP/mise.ready" ;;
    reshim) ;;
    *) return 1 ;;
  esac
}
touch "$TMP/mise.ready"
section_mise
[[ "$DRIFT" == 0 ]]
if grep -Eq '^(use|reshim)' "$TMP/mise.log"; then exit 1; fi
CHECK=false
section_mise
if grep -q '^use' "$TMP/mise.log"; then exit 1; fi
grep -qx reshim "$TMP/mise.log"
rm "$TMP/mise.ready"
section_mise
grep -q '^use --global --yes neovim@latest yazi@latest' "$TMP/mise.log"
# Verify the fresh session receives a clean environment and expected paths.
cat > "$TMP/bin/fish-session" <<'FISH'
#!/bin/bash
set -eu
# Bash 3.2 does not reliably stop on failed [[ ]] assertions with set -e.
[[ -z "${MISE_SHELL:-}" && "$PATH" != *inherited-test* ]] || exit 1
[[ "$#" == 4 && "$1" == -lic && "$3" == /expected/nvim && "$4" == /expected/yazi ]] || exit 1
[[ "$2" == *'command -s nvim'* && "$2" == *'command yazi --version'* ]] || exit 1
FISH
chmod +x "$TMP/bin/fish-session"
MISE_SHELL=fish PATH="/inherited-test:$PATH" verify_fresh_fish "$TMP/bin/fish-session" /expected/nvim /expected/yazi
if verify_fresh_fish "$TMP/bin/fish-session" /wrong/nvim /expected/yazi; then exit 1; fi
# Real Fish coverage in CI: use an isolated configuration and fake tool
# executables, not the user's startup files or Mise installation.
if [[ -n "$REAL_FISH" ]]; then
  (
    export HOME="$TMP/fish-home"
    mkdir -p "$HOME/.config/fish" "$HOME/tools" "$HOME/other"
    for tool in nvim yazi; do
      printf '#!/bin/sh\nexit 0\n' > "$HOME/tools/$tool"
      chmod +x "$HOME/tools/$tool"
    done
    ln -s "$HOME/tools/nvim" "$HOME/other/nvim"
    # Expand these variables in Fish, not in this Bash process.
    # shellcheck disable=SC2016
    printf 'set -gx PATH "$HOME/other" "$HOME/tools" $PATH\n' > "$HOME/.config/fish/config.fish"
    verify_fresh_fish "$REAL_FISH" "$HOME/tools/nvim" "$HOME/tools/yazi"
    # Replace the alias with a different executable to simulate shadowing.
    unlink "$HOME/other/nvim"
    cp "$HOME/tools/nvim" "$HOME/other/nvim"
    if verify_fresh_fish "$REAL_FISH" "$HOME/tools/nvim" "$HOME/tools/yazi"; then exit 1; fi
    printf 'Real Fish path-resolution tests passed.\n'
  )
else
  printf 'Real Fish not installed; integration test skipped.\n'
fi
bash "$ROOT/test/macos-colima-setup.sh"
printf 'macOS bootstrap regression tests passed.\n'
