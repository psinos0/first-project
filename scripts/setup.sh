#!/usr/bin/env bash
set -euo pipefail

craft_project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
craft_engine_dir="/workspace/tools/craft-godot"
craft_archive="Godot_v4.7.2-stable_linux.x86_64.zip"
craft_binary="$craft_engine_dir/Godot_v4.7.2-stable_linux.x86_64"
export XDG_CACHE_HOME="/workspace/.cache/craft"
export XDG_CONFIG_HOME="/workspace/.config/craft"
export XDG_DATA_HOME="/workspace/.data/craft"
mkdir -p "$craft_engine_dir" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

if [[ ! -x "$craft_binary" ]]; then
  curl --fail --show-error --location --retry 2 \
    "https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt" \
    --output "$craft_engine_dir/SHA512-SUMS.txt"
  curl --fail --show-error --location --retry 2 \
    "https://github.com/godotengine/godot/releases/download/4.7.2-stable/$craft_archive" \
    --output "$craft_engine_dir/$craft_archive"
  (
    cd "$craft_engine_dir"
    awk -v artifact="$craft_archive" '$2 == artifact {print; found=1} END {if (!found) exit 1}' SHA512-SUMS.txt > CHECKSUM.txt
    sha512sum --check CHECKSUM.txt
    unzip -o "$craft_archive"
    chmod +x "$craft_binary"
  )
fi

craft_version="$("$craft_binary" --version)"
[[ "$craft_version" == 4.7.2.stable.* ]] || { echo "Expected Godot 4.7.2 Stable; got $craft_version" >&2; exit 1; }
craft_import_log="$(mktemp /tmp/craft-import.XXXXXX)"
trap 'rm -f "$craft_import_log"' EXIT
if "$craft_binary" --headless --path "$craft_project_root" --editor --import > "$craft_import_log" 2>&1; then
  cat "$craft_import_log"
else
  craft_status=$?
  cat "$craft_import_log"
  exit "$craft_status"
fi
if rg -q 'SCRIPT ERROR|^ERROR:' "$craft_import_log"; then
  echo "Godot reported import errors" >&2
  exit 1
fi
echo "MeatCraft Empire: Godot 4.7.2 installed and project imported."
