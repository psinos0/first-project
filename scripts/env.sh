#!/usr/bin/env bash
# Source this only for the Linux cloud workspace. No credentials are used.
CRAFT_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CRAFT_GODOT="${CRAFT_GODOT:-/workspace/tools/craft-godot/Godot_v4.7.2-stable_linux.x86_64}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.cache/craft}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.config/craft}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.data/craft}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
export CRAFT_PROJECT_ROOT CRAFT_GODOT
