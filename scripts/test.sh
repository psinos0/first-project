#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
craft_test_data="$(mktemp -d /tmp/craft-tests.XXXXXX)"
trap 'rm -rf "$craft_test_data"' EXIT
# Tests replace saves; isolate them from the player's workshop.
export XDG_DATA_HOME="$craft_test_data"
"$CRAFT_GODOT" --headless --path "$CRAFT_PROJECT_ROOT" --script res://scripts/tests/gameplay_test.gd
