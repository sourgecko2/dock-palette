#!/usr/bin/env bash
# Runs the same checks as CI: luacheck and a StyLua format check.
# Setup on macOS: brew install luarocks stylua && luarocks install luacheck
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

luacheck .
stylua --check .
echo "All checks passed."
