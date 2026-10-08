#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
exec "$CRAFT_GODOT" --path "$CRAFT_PROJECT_ROOT" "$@"
