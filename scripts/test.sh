#!/usr/bin/env bash
# Run the E1 spec suite. Exits non-zero on failure.
#
# Two paths, because the headless one is not currently available on this machine:
#
#   run-in-roblox   fully headless, what CI wants. Installed by `rokit install`,
#                   which cannot reach GitHub without a token (see BOARD.md).
#   Studio MCP      run the same entry point against an open Studio and read the
#                   result. What we actually use today.
#
# Either way the entry point is identical, which is the point of RunAll:
#   require(game.ServerStorage.Tests.RunAll)()
set -euo pipefail

cd "$(dirname "$0")/.."

PLACE="${TMPDIR:-/tmp}/frostline-test.rbxlx"

echo "==> rojo build"
rojo build -o "$PLACE"

if command -v run-in-roblox >/dev/null 2>&1; then
    echo "==> run-in-roblox"
    # RunAll prints its report, so stdout carries the detail. A non-zero exit
    # comes from the harness script asserting on the failure count.
    cat > "${TMPDIR:-/tmp}/frostline-test-entry.lua" <<'LUA'
local passed, failed, report = require(game.ServerStorage.Tests.RunAll)()
print(report)
if failed > 0 then
    error(string.format("%d spec(s) failed", failed), 0)
end
LUA
    run-in-roblox --place "$PLACE" --script "${TMPDIR:-/tmp}/frostline-test-entry.lua"
    echo "OK"
else
    cat <<'MSG'
run-in-roblox is not installed, so the suite cannot run headless here.

  Cause: `rokit install` needs a GitHub token — one run costs more than the
  whole 60/hr anonymous API budget. See BOARD.md, standing hazard #2.
  Fix:   rokit authenticate github --token <token>   (zero scopes is enough)
         rokit install

Until then, run it against an open Studio via the MCP:

  require(game.ServerStorage.Tests.RunAll)()

The place file was still built successfully at:
MSG
    echo "  $PLACE"
    exit 1
fi
