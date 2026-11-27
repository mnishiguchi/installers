#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
"$repo/kde/shortcuts-config.sh" --help >/dev/null
python3 "$repo/test/kde-shortcuts-config.py"
