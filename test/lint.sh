#!/usr/bin/env bash
# Run syntax and static-analysis checks for every tracked shell script.
set -Eeuo pipefail
IFS=$'\n\t'

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v shellcheck >/dev/null 2>&1 || fail "shellcheck is required"
command -v bash >/dev/null 2>&1 || fail "bash is required"
command -v dash >/dev/null 2>&1 || fail "dash is required"

mapfile -d '' -t scripts < <(git ls-files -z '*.sh')
((${#scripts[@]} > 0)) || fail "no tracked shell scripts found"

for script in "${scripts[@]}"; do
  if [[ "$(head -n 1 -- "$script")" == '#!/bin/sh' ]]; then
    dash -n "$script"
  else
    bash -n "$script"
  fi
done

shellcheck -- "${scripts[@]}"
printf 'Checked %d shell scripts.\n' "${#scripts[@]}"
