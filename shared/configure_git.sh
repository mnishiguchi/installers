#!/bin/bash
set -eu

mkdir -p "$XDG_CONFIG_HOME/git"

file="$XDG_CONFIG_HOME/git/config"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."
  touch "$file"

  git config --global user.name "Masatoshi Nishiguchi"
  git config --global user.email "7563926+mnishiguchi@users.noreply.github.com"
  git config --global github.user "mnishiguchi"
  git config --global credential.helper "osxkeychain"
  git config --global core.ignorecase false
  git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
  git config --global core.editor "nvim"
  git config --global init.defaultBranch "main"
  git config --global fetch.prune true
  git config --global interactive.diffFilter "diff-so-fancy --patch"
  git config --global advice.detachedHead false

  open https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup

  cat "${file}"
fi

file="$XDG_CONFIG_HOME/git/gitignore"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."
  src="https://gist.githubusercontent.com/mnishiguchi/e164a451269f8ffb9e9681bb532147f4/raw/539cd0dbbde46ef3ff2d964926813889dd28dc0c/gitignore_global"
  curl --output "${file}" --location "${src}"
  cat "${file}"
  git config --global core.excludesfile "${file}"
fi

file="$XDG_CONFIG_HOME/git/gitmessage"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."
  src="https://gist.githubusercontent.com/mnishiguchi/a96daf18ff6dd8b39da2aa4dd89be1fa/raw/9f08a6b0ed2beb6872b6db9c876860b9eaa43042/gitmessage.txt"
  curl --output "${file}" --location "${src}"
  cat "${file}"
  git config --global core.excludesfile "${file}"
fi

git config --global --list
