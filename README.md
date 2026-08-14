# HUNT — Antarctic Hunt-Sell-Upgrade Simulator (Roblox)

Working title: **FROSTLINE** (final name TBD, see `docs/DECISIONS.md` D-004).

A manual-control Roblox simulator: hunt ice bears on the Antarctic shelf, haul meat back to
the trading outpost, sell it, upgrade your gear, unlock colder and more dangerous zones.
Low-poly, high-contrast, deliberately minimal UI — the stripped-down look of hyper-casual
ad games, not the pastel clutter of Pet Simulator.

## Read this first (in order)

| Doc | What it is |
|---|---|
| `docs/GDD.md` | What the game is. Loop, content, progression, scope. |
| `docs/ARCHITECTURE.md` | Folder layout, service pattern, remote contract, data schema. **Frozen contract.** |
| `docs/ECONOMY.md` | Every number in the game. Config tables derive from this. |
| `docs/MONETIZATION.md` | **The business.** Multiplier stack, companions, 22 SKUs, retention ladder. |
| `docs/ANALYTICS.md` | Funnel and event schema — where players quit and where cash goes. |
| `docs/ART_BIBLE.md` | Palette, silhouette rules, UI kit, model specs. |
| `docs/AUTOMATION.md` | The four channels agents ship through — toolchain, Open Cloud, browser, generative. |
| `docs/WORKFLOW.md` | **How workers operate.** File ownership, DoD, PR rules. Read before touching code. |
| `docs/DECISIONS.md` | Decision log. Changing a frozen contract requires an entry here. |
| `tasks/BOARD.md` | The master job list. Status, dependencies, assignments. |

## For workers

You have been assigned a job ID (e.g. `A3`). Find it in `tasks/`. That packet is your whole
brief: what to read, what files you own, what "done" means. Do not edit files outside your
ownership list. Do not change anything in `src/shared/Config/` or `src/shared/Remotes.luau`
unless you are the Architect.

Before declaring a job blocked, read `docs/AUTOMATION.md`. Studio runs headlessly, assets
upload over HTTP, the creator dashboard is a website, and meshes and audio are generated.
Almost nothing here actually needs hands.

## How this is built — hybrid (D-010)

**Files are the source of truth. Studio verifies.**

| | |
|---|---|
| Write code | `src/**`, synced by Rojo. Normal branches and PRs. |
| Verify | Roblox Studio MCP — playtest, console, screenshots, read-only `execute_luau` |
| World geometry | hand-built in Studio, **not** in git — coordinate via `ServerStorage.WorkLog` |
| Place | **"hunt for money"** — `83234958310651` (universe `10694878805`) |

**Scripts flow one direction: files → Studio.** Never edit a script in Studio; Rojo overwrites
it on the next sync, silently. Don't enable Team Create for scripts — it fights Rojo.

```bash
rokit install                # rojo, wally, selene, stylua, run-in-roblox
wally install                # React Lua + UI Labs (Packages/, gitignored)
rojo serve                   # live sync into an open place
./scripts/check.sh           # wally + stylua + selene + build
rojo build -o Hunt.rbxlx
```

**UI is React Lua** (D-011), confined to `src/client/UI/`. Preview components without
playtesting: install the [UI Labs](https://create.roblox.com/store/asset/14293316215) plugin
and open it — it finds `UI.Stories.Frostline.storybook` on its own.

## Status

**67 jobs.** `F1` (scaffold) and `F2` (contract freeze) are **done** — `src/shared/` holds the
frozen `Types`, `Remotes`, and six `Config` modules, and `rojo build` produces a place.
`P7` was cancelled by D-010.

Next: **`F3`** (core utils, independent), **`F4`** (loader + Net). **`G1`** (store-page
creative) still gates the most revenue and depends on nothing.

