#!/usr/bin/env bash
# Keep the shell entry point consistent with other desktop installers.
set -euo pipefail
exec python3 "$(dirname -- "${BASH_SOURCE[0]}")/shortcuts-config.py" "$@"
