#!/usr/bin/env bash
# setup_github_ssh.sh
# Set up SSH auth for GitHub on a fresh Linux Mint/LMDE machine.

set -euo pipefail

# ------------- UI (Yazi-style) -------------
echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }
echo_warning() { echo -e " \033[33m⚠ $1\033[0m"; }
echo_info() { echo -e " \033[36mℹ $1\033[0m"; }

# (Aliases for internal reuse; keep functions readable)
bold() { echo_heading "$*"; }
ok() { echo_success "$*"; }
warn() { echo_warning "$*"; }
err() { echo_failure "$*"; }
info() { echo_info "$*"; }

# ------------- Defaults -------------
COMMENT=""
KEY_TYPE="ed25519"
KEY_DIR="${HOME}/.ssh"
KEY_NAME="id_ed25519"
KEY_PATH="${KEY_DIR}/${KEY_NAME}"
CLIP_CMD=""
BROWSER_OPEN="yes"
TEST_SSH="yes"

# ------------- Usage -------------
usage() {
  cat <<'USAGE'
Usage:
  setup_github_ssh.sh [--comment "LMDE6 • Work Laptop"] [--key-name id_ed25519]
                      [--no-browser] [--no-test] [--git auto|ask|skip]
                      [-h|--help]

Options:
  --comment      Optional SSH key comment (metadata shown in GitHub UI).
  --key-name     Basename for key file under ~/.ssh (default: id_ed25519).
  --no-browser   Do not open GitHub SSH keys page automatically.
  --no-test      Skip SSH connectivity test.
  -h, --help     Show this help.
USAGE
}

# ------------- Helpers -------------
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command not found: ${cmd}"
    exit 1
  fi
}

detect_clipboard() {
  if command -v wl-copy >/dev/null 2>&1; then
    CLIP_CMD="wl-copy"
  elif command -v xclip >/dev/null 2>&1; then
    CLIP_CMD="xclip -selection clipboard"
  elif command -v xsel >/dev/null 2>&1; then
    CLIP_CMD="xsel --clipboard --input"
  else
    CLIP_CMD=""
  fi
}

ensure_ssh_agent() {
  if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "${SSH_AUTH_SOCK:-/dev/null}" ]; then
    eval "$(ssh-agent -s)" >/dev/null
    ok "ssh-agent started."
  else
    ok "ssh-agent already running."
  fi
}

# ------------- Core Steps -------------
generate_key() {
  echo_heading "Generating SSH key"
  mkdir -p "${KEY_DIR}"
  chmod 700 "${KEY_DIR}"

  if [ -f "${KEY_PATH}" ]; then
    warn "Key already exists at ${KEY_PATH}"
    read -r -p "Generate a new key with a different name? [y/N]: " ans
    if [ "${ans}" = "y" ] || [ "${ans}" = "Y" ]; then
      read -r -p "Enter new key name (basename only, e.g. id_ed25519_github): " newname
      if [ -n "$newname" ]; then
        KEY_NAME="$newname"
        KEY_PATH="${KEY_DIR}/${KEY_NAME}"
      fi
    else
      ok "Reusing existing key."
      return
    fi
  fi

  if [ -z "${COMMENT}" ]; then
    local default_c="${USER}@$(hostname -s) $(date +%Y-%m-%d)"
    read -r -p "Key comment (leave blank to use '${default_c}'): " input_c
    if [ -n "$input_c" ]; then
      COMMENT="$input_c"
    else
      COMMENT="$default_c"
    fi
  fi

  ssh-keygen -t "${KEY_TYPE}" -C "${COMMENT}" -f "${KEY_PATH}"
  ok "Key generated at ${KEY_PATH}"
}

add_key_to_agent() {
  echo_heading "Adding key to ssh-agent"
  ensure_ssh_agent
  ssh-add "${KEY_PATH}" || true
  ok "Key added to agent."
}

copy_pubkey_to_clipboard() {
  echo_heading "Copying public key to clipboard"
  detect_clipboard
  if [ -z "${CLIP_CMD}" ]; then
    warn "No clipboard tool found (wl-copy/xclip/xsel)."
    info "Public key: ${KEY_PATH}.pub"
    info "Print it with:  cat ${KEY_PATH}.pub"
    return
  fi
  if [ ! -f "${KEY_PATH}.pub" ]; then
    err "Public key not found: ${KEY_PATH}.pub"
    return
  fi
  # shellcheck disable=SC2086
  ${CLIP_CMD} <"${KEY_PATH}.pub"
  ok "Public key copied to clipboard."
}

open_github_keys_page() {
  echo_heading "Opening GitHub SSH Keys page"
  if [ "${BROWSER_OPEN}" != "yes" ]; then
    info "Skipping browser open by request."
    info "Add your key at: https://github.com/settings/keys"
    return
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://github.com/settings/keys" >/dev/null 2>&1 || true
    ok "Opened GitHub SSH keys page."
  else
    info "Open this page to add your key: https://github.com/settings/keys"
  fi
}

test_github_ssh() {
  echo_heading "Testing GitHub authentication"
  if [ "${TEST_SSH}" != "yes" ]; then
    info "Skipping SSH connectivity test."
    return
  fi

  bold "ssh -T git@github.com"
  set +e
  SSH_ASKPASS_REQUIRE=force ssh -T git@github.com 2>&1 | tee /tmp/gh_ssh_test.log
  local rc=${PIPESTATUS[0]}
  set -e

  if grep -qi "successfully authenticated" /tmp/gh_ssh_test.log; then
    ok "SSH authentication with GitHub works."
  else
    warn "No success message yet—did you add the key on GitHub?"
  fi

  if command -v gh >/dev/null 2>&1; then
    bold "gh auth status"
    set +e
    gh auth status
    set -e
  else
    info "Tip: Install GitHub CLI (gh) for extra workflows."
  fi
}

show_tips() {
  echo_heading "Tips"
  cat <<EOF
- Your public key file: ${KEY_PATH}.pub
- If GitHub says "Permission denied (publickey)":
  1) Ensure the key is added on https://github.com/settings/keys
  2) Check ssh-agent has the key: ssh-add -l
  3) Add the key if missing:      ssh-add ${KEY_PATH}
- Test: ssh -T git@github.com
EOF
}

preflight_checks() {
  echo_heading "Pre-flight checks"
  require_cmd ssh
  require_cmd ssh-keygen
  require_cmd ssh-add
  ok "All required commands are available."
}

# ------------- Arg parsing -------------
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --comment)
      COMMENT="${2:-}"
      shift 2
      ;;
    --key-name)
      KEY_NAME="${2:-}"
      KEY_PATH="${KEY_DIR}/${KEY_NAME}"
      shift 2
      ;;
    --no-browser)
      BROWSER_OPEN="no"
      shift
      ;;
    --no-test)
      TEST_SSH="no"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
  done
}

# ------------- Main -------------
main() {
  echo_heading "GitHub SSH setup"
  parse_args "$@"
  preflight_checks
  generate_key
  add_key_to_agent
  copy_pubkey_to_clipboard
  open_github_keys_page
  test_github_ssh
  show_tips
  echo_heading "All done. Happy hacking."
}

main "$@"
