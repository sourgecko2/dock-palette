#!/usr/bin/env bash
# Links DockPalette.spoon into ~/.hammerspoon/Spoons, so edits in this repo apply on reload.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spoons_dir="${HOME}/.hammerspoon/Spoons"
target="${spoons_dir}/DockPalette.spoon"

mkdir -p "${spoons_dir}"
if [[ -e "${target}" && ! -L "${target}" ]]; then
  echo "error: ${target} exists and is not a symlink. Move it aside, then re-run." >&2
  exit 1
fi

ln -sfn "${repo_dir}/DockPalette.spoon" "${target}"
echo "Linked ${target} -> ${repo_dir}/DockPalette.spoon"
echo "Next: copy examples/init.lua into ~/.hammerspoon/init.lua and reload Hammerspoon."
