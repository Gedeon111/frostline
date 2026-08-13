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
| `docs/MONETIZATION.md` | **The business.** Multiplier stack, companions, 19 SKUs, retention ladder, funnel. |
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

## Build

```bash
rokit install              # rojo, selene, stylua, run-in-roblox, lune
rojo serve                 # live-sync into an open Studio place
rojo build -o Hunt.rbxlx   # produce a place file
./scripts/itest.ps1        # run the suite inside real Studio, headless
./scripts/ship.ps1 --dry-run   # full pipeline, stops short of publishing
```

## Status

Planning complete, no code written yet. **67 jobs** across five tracks.

Day one, in parallel: **`G1`** (store-page creative — gates revenue, depends on nothing),
**`F1`** (repo scaffold — gates every code job), **`P2`** (Open Cloud — gates every asset).

