#!/usr/bin/env bash
# Format, lint, and build. Must exit 0 on a clean clone after `rokit install`.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> stylua --check"
stylua --check src/

# selene's roblox std is generated, not vendored. Regenerate if missing so a
# clean clone works without an extra manual step.
if [ ! -f roblox.yml ]; then
    echo "==> generating roblox std"
    selene generate-roblox-std
fi

echo "==> selene"
selene src/

echo "==> rojo build"
rojo build -o "${TMPDIR:-/tmp}/frostline-check.rbxlx"

echo "OK"
