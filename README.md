# FROSTLINE — Arctic Hunting & Store Simulator (Roblox)

FROSTLINE is a low-input Roblox simulator about running a meat shop beside a shared fictional
Arctic wilderness. Hunt frost bears with an axe, carry visible meat home, stock your
refrigerator, serve customers at the register, collect cash from the counter, and grow the store
with upgrades and workers.

Eight players receive one private plot each and share the same hunting ground. Auto-Swing is
available for the first ten minutes, then requires its gamepass; the free control remains
tap-per-swing.

## Read first

| Document | Purpose |
|---|---|
| `docs/GDD.md` | Approved fantasy, loops, map, workers, scope. |
| `docs/ARCHITECTURE.md` | V2 target services, remotes, profile schema, and world markers. |
| `docs/ECONOMY.md` | Value flow, pacing targets, and invariants. |
| `docs/MONETIZATION.md` | Approved Auto-Swing trial/pass and commercial guardrails. |
| `docs/ANALYTICS.md` | Corrected store funnel and economy reconciliation. |
| `docs/ART_BIBLE.md` | Wilderness/store visual language, assets, UI, and motion. |
| `docs/AUTOMATION.md` | Tooling and verification channels. |
| `docs/WORKFLOW.md` | Ownership, frozen contracts, tests, branches, and handoffs. |
| `docs/DECISIONS.md` | Decision history; D-017 is the product reset. |
| `tasks/BOARD.md` | Active jobs, dependencies, and superseded work. |

## Current contract status

D-017 approves the corrected game. F5's v2 shared contract/profile migration and A15's
canonical state replication have landed. A16 carry inventory is the next server dependency.

Existing Data, Currency, Creature, Combat, State, Upgrade, Analytics, Net, and React UI foundations
are reused where their new packets say so. SellService, the trader, harpoon ToolService work,
and five-zone-first progression are not part of the corrected slice.

## Worker rules

Workers receive one complete packet from `tasks/*.md` and own only its listed paths. Pull and
re-read the packet before work. Do not edit `src/shared/**` except in an Architect-owned
contract job. Use the Studio WorkLog for geometry or a long Studio session. Never merge your
own job.

## Build workflow

Files are authoritative; Studio verifies.

| Surface | Method |
|---|---|
| Scripts | edit `src/**` on a job branch/worktree |
| Sync/build | Rojo |
| Tests/playtest | Roblox Studio and project test harness |
| World geometry | Studio-owned, coordinated through `ServerStorage.WorkLog` |
| Place | “hunt for money” — `83234958310651` (universe `10694878805`) |

```bash
rokit install
wally install
rojo serve
./scripts/check.sh
rojo build -o Hunt.rbxlx
```

The UI uses React Lua under `src/client/UI/`. UI Labs discovers
`UI.Stories.Frostline.storybook` after `wally install`; install the
[UI Labs plugin](https://create.roblox.com/store/asset/14293316215) to preview components
without starting a full play session.

Never edit synced scripts in Studio; Rojo overwrites them.
