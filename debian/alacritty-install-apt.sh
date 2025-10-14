#!/usr/bin/env bash
set -euo pipefail

blue() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'EOF'
Usage: alacritty-install-apt.sh [--force]

Options:
  --force   Overwrite existing $XDG_CONFIG_HOME/alacritty/{alacritty.toml,alacritty.yml}
EOF
}

main() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then
    force=1
  elif [[ "${1:-}" != "" ]]; then
    usage
    exit 1
  fi

  blue "Install Alacritty via apt (system package)"
  if ! has alacritty; then
    sudo apt update -yq
    sudo apt install -y alacritty || {
      warn "apt install failed; is the package available on this Mint release?"
      exit 1
    }
  fi
  ok "alacritty present ($(alacritty --version 2>/dev/null || echo 'installed'))"

  blue "Write configs in both formats (TOML & YAML)"
  local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
  local toml="$cfg_dir/alacritty.toml"
  local yaml="$cfg_dir/alacritty.yml"
  local default_font="FiraCode Nerd Font"

  mkdir -p "$cfg_dir"

  if [[ $force -eq 1 || ! -f "$toml" ]]; then
    cat >"$toml" <<TOML
[window.dimensions]
columns = 120
lines = 80

[font]
size = 10

[font.normal]
family = "$default_font"
style = "Regular"

[font.bold]
family = "$default_font"
style = "Bold"

[colors.primary]
background = '#212121'
foreground = '#F8F8F2'

[colors.cursor]
text = '#0E1415'
cursor = '#ECEFF4'

[colors.normal]
black = '#21222C'
red = '#FF5555'
green = '#50FA7B'
yellow = '#FFCB6B'
blue = '#82AAFF'
magenta = '#C792EA'
cyan = '#8BE9FD'
white = '#F8F9F2'

[colors.bright]
black = '#545454'
red = '#FF6E6E'
green = '#69FF94'
yellow = '#FFCB6B'
blue = '#D6ACFF'
magenta = '#FF92DF'
cyan = '#A4FFFF'
white = '#F8F8F2'

[[keyboard.bindings]]
key = "C"
mods = "Control|Shift"
action = "Copy"

[[keyboard.bindings]]
key = "V"
mods = "Control|Shift"
action = "Paste"

[[keyboard.bindings]]
key = "Up"
mods = "Control|Shift"
action = "ScrollPageUp"

[[keyboard.bindings]]
key = "Down"
mods = "Control|Shift"
action = "ScrollPageDown"

[[keyboard.bindings]]
key = "K"
mods = "Control|Shift"
action = "ScrollPageUp"

[[keyboard.bindings]]
key = "J"
mods = "Control|Shift"
action = "ScrollPageDown"
TOML
    ok "wrote $toml"
  else
    ok "kept existing $toml (use --force to overwrite)"
  fi

  if [[ $force -eq 1 || ! -f "$yaml" ]]; then
    cat >"$yaml" <<YAML
window:
  dimensions:
    columns: 120
    lines: 80

font:
  size: 10
  normal:
    family: "$default_font"
    style: "Regular"
  bold:
    family: "$default_font"
    style: "Bold"

colors:
  primary:
    background: '#212121'
    foreground: '#F8F8F2'
  cursor:
    text: '#0E1415'
    cursor: '#ECEFF4'
  normal:
    black:   '#21222C'
    red:     '#FF5555'
    green:   '#50FA7B'
    yellow:  '#FFCB6B'
    blue:    '#82AAFF'
    magenta: '#C792EA'
    cyan:    '#8BE9FD'
    white:   '#F8F9F2'
  bright:
    black:   '#545454'
    red:     '#FF6E6E'
    green:   '#69FF94'
    yellow:  '#FFCB6B'
    blue:    '#D6ACFF'
    magenta: '#FF92DF'
    cyan:    '#A4FFFF'
    white:   '#F8F8F2'

keyboard:
  bindings:
    - { key: C,   mods: Control|Shift, action: Copy }
    - { key: V,   mods: Control|Shift, action: Paste }
    - { key: Up,  mods: Control|Shift, action: ScrollPageUp }
    - { key: Down,mods: Control|Shift, action: ScrollPageDown }
    - { key: K,   mods: Control|Shift, action: ScrollPageUp }
    - { key: J,   mods: Control|Shift, action: ScrollPageDown }
YAML
    ok "wrote $yaml"
  else
    ok "kept existing $yaml (use --force to overwrite)"
  fi

  blue "Done. Newer Alacritty will read TOML; older will read YAML."
}

main "$@"
