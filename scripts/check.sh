#!/usr/bin/env bash
# Format, lint, and build. Must exit 0 on a clean clone after `rokit install`.
set -euo pipefail

cd "$(dirname "$0")/.."

# Packages/ is gitignored, so a clean clone has no React and `rojo build` would fail on
# the missing path. Only install when it is actually absent: wally reinstalls by deleting
# the tree first, and on the shared network drive that delete fails with "directory is not
# empty" (os error 145) while Studio and Rojo hold handles into it.
#
# The cost of that guard: editing wally.toml does NOT refresh Packages here. Run
# `wally install` yourself after changing dependencies.
if [ ! -d Packages ]; then
    echo "==> wally install"
    wally install
fi

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
