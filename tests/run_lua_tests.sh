#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd -- "$script_dir/.." && pwd)"
love_bin="${LOVE_BIN:-love}"

if ! command -v "$love_bin" >/dev/null 2>&1; then
  printf 'LÖVE executable not found: %s\n' "$love_bin" >&2
  printf 'Install LÖVE 11.5 or set LOVE_BIN to its executable path.\n' >&2
  exit 1
fi

export GEN2_CLEAN_UI_ROOT="$root"
export GEN2_CLEAN_UI_HEADLESS="${GEN2_CLEAN_UI_HEADLESS:-1}"
"$love_bin" "$script_dir/love_runner"
