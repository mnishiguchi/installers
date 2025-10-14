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

Notes:
  - Set ALACRITTY_FONT_FAMILY to override the detected font family.
EOF
}

pick_font_family() {
  # Allow manual override via env var
  if [[ -n "${ALACRITTY_FONT_FAMILY:-}" ]]; then
    printf '%s\n' "$ALACRITTY_FONT_FAMILY"
    return
  fi

  # Prefer fully monospaced Nerd Font family names
  local candidates=(
    "FiraCode Nerd Font Mono"
    "Fira Code Nerd Font Mono"
    "FiraCode Nerd Font"
    "Fira Code Nerd Font"
  )

  if has fc-list; then
    # Match against fontconfig's family names, case-insensitive
    local fam
    for fam in "${candidates[@]}"; do
      if fc-list : family | grep -iqF -- "$fam"; then
        printf '%s\n' "$fam"
        return
      fi
    done
  fi

  # Fallback if we can’t detect via fontconfig
  printf '%s\n' "FiraCode Nerd Font Mono"
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

  blue "Detect Nerd Font family"
  local font_family
  font_family="$(pick_font_family)"
  ok "using font family: ${font_family}"

  # Quick sanity: warn if fontconfig doesn't think this family exists
  if has fc-list && ! fc-list : family | grep -iqF -- "$font_family"; then
    warn "Font family '$font_family' not found via fontconfig; configs will still be written."
    warn "You can set ALACRITTY_FONT_FAMILY or install the font, then run with --force."
  fi

  blue "Write configs in both formats (TOML & YAML)"
  local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
  local toml="$cfg_dir/alacritty.toml"
  local yaml="$cfg_dir/alacritty.yml"
  mkdir -p "$cfg_dir"

  if [[ $force -eq 1 || ! -f "$toml" ]]; then
    cat >"$toml" <<TOML
[window.dimensions]
columns = 120
lines = 40

[font]
size = 10
builtin_box_drawing = true

[font.normal]
family = "$font_family"
style = "Regular"

[font.bold]
family = "$font_family"
style = "Bold"

[font.italic]
family = "$font_family"
style = "Italic"

[font.bold_italic]
family = "$font_family"
style = "Bold Italic"

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
    lines: 40

font:
  size: 10
  builtin_box_drawing: true
  normal:
    family: "$font_family"
    style: "Regular"
  bold:
    family: "$font_family"
    style: "Bold"
  italic:
    family: "$font_family"
    style: "Italic"
  bold_italic:
    family: "$font_family"
    style: "Bold Italic"

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
    - { key: C,    mods: Control|Shift, action: Copy }
    - { key: V,    mods: Control|Shift, action: Paste }
YAML
    ok "wrote $yaml"
  else
    ok "kept existing $yaml (use --force to overwrite)"
  fi

  blue "Done. Newer Alacritty reads TOML; older reads YAML."
  blue "Tip: emoji fallback -> sudo apt install fonts-noto-color-emoji"
}

main "$@"
