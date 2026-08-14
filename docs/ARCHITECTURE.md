# Architecture — FROSTLINE

**Status: FROZEN.** Everything in §3 (Remotes) and §4 (Data schema) is a contract that
parallel workers code against. Changing it requires a `docs/DECISIONS.md` entry approved by
the Architect. If your job "needs" a contract change, stop and file the RFC first.

## 1. Workflow — hybrid (see D-010)

**Files are the source of truth.** All scripting and editing happens in `src/`, synced into
Studio by Rojo. The Studio MCP is kept for **verification only**.

| Surface | Tool | Notes |
|---|---|---|
| Write / edit scripts | `src/**` + `Read`/`Edit`/`Grep` | cheap, git-native, branches and PRs work |
| Sync into the engine | `rojo serve` / `rojo build` | one direction: files → Studio |
| Playtest, console, screenshots | Studio MCP | `start_stop_play`, `get_console_output`, `screen_capture` |
| Run checks in-engine | Studio MCP `execute_luau` | **read-only**; never mutate scripts |
| World geometry | Studio, by hand | not managed by Rojo (see §7) |

**The rule: scripts flow one direction, files → Studio.** Never edit a script in Studio — Rojo
overwrites it on the next sync, silently, with no history. `multi_edit` is not used on this
project.

**Do not enable Team Create for scripts.** It makes Studio authoritative and fights Rojo.
Geometry work is coordinated through `ServerStorage.WorkLog` instead (WORKFLOW §2).

```bash
rokit install                       # rojo, wally, selene, stylua, run-in-roblox
wally install                       # React, ReactRoblox, UILabs
rojo serve                          # live sync into an open place
rojo build -o Hunt.rbxlx            # produce a place file
./scripts/check.sh                  # wally + stylua + selene + build
```

**No Knit, no Fusion.** Frameworks create version drift between workers and hide control
flow. We use a small loader (§2) for everything that starts up.

**UI is the one exception (D-011): React Lua, installed by Wally.** It is confined to
`src/client/UI/**` — services and controllers stay plain. Versions are pinned in `wally.toml`
and `wally.lock` is committed, which is what keeps the drift argument answered. Server-side
third-party code is still pasted as a single ModuleScript with its license header intact —
currently ProfileStore only.

```bash
wally install                       # Packages/ and DevPackages/, both gitignored
```

`Packages/` is restored from the lockfile, never committed. Run `wally install` after a fresh
clone and after anyone edits `wally.toml`, or `rojo build` fails on the missing path.

## 2. Datamodel layout

Left column is the file, right is where Rojo puts it. **Both are a contract** — dependent jobs
reference the datamodel path, and `default.project.json` is what makes it true.

```
src/shared/**              →  ReplicatedStorage.Shared
src/server/Server.server.luau →  ServerScriptService.Server        (the bootstrap Script)
src/server/Services/**     →  ServerScriptService.Services
src/server/Lib/**          →  ServerScriptService.Lib
src/client/Client.client.luau →  StarterPlayerScripts.Client       (the bootstrap LocalScript)
src/client/Controllers/**  →  StarterPlayerScripts.Controllers
src/client/UI/**           →  StarterPlayerScripts.UI
assets/**                  →  ReplicatedStorage.Assets
tests/**                   →  ServerStorage.Tests
Packages/**                →  ReplicatedStorage.Packages       (wally, gitignored)
DevPackages/**             →  ReplicatedStorage.DevPackages    (wally, gitignored)
                           →  ReplicatedStorage.Remotes  (empty Folder, Net fills at runtime)
```

**Two things Rojo deliberately does NOT manage**, because it would delete them on sync:
`Workspace` (hand-built geometry) and `ServerStorage.WorkLog` (live claim state). Neither
appears in `default.project.json`, so Rojo leaves them alone.

The resulting datamodel:

```
ReplicatedStorage
  Shared
    Config/                ★ ARCHITECT-OWNED. Every tunable number lives here.
      GameConfig             global constants (swing cd, respawn, autosave)
      Zones                  5 zones: unlock cost, tier, population, spawn region names
      Creatures              5 tiers: hp, drops, weight, value, model name, variants
      Upgrades               3 tracks x 10 levels: effect value + cost curve
      Companions / Eggs      added by G2
      Tools / Products / Audio   asset + product ids
    Types                  ★ shared Luau type defs. Import, never redefine.
    Remotes                ★ remote NAME + signature table (§3)
    Util/                    Signal · Trove · RateLimiter · Format · TableUtil · Log
  Assets/                  Creatures · Props · Traders · Tools   (models, see §7)
  Remotes/                 created at runtime by Net from Shared.Remotes

ServerScriptService
  Bootstrap                Script — the loader
  Services/                one ModuleScript per service, see §5
  Lib/ProfileStore         pasted, license header intact

StarterPlayer.StarterPlayerScripts
  Bootstrap                LocalScript — the loader
  Controllers/             one ModuleScript per controller, see §6
  UI/                      Ui builder + one ModuleScript per screen

Workspace
  World/                   hand-built zone geometry (see §7)
  Creatures/               runtime spawn parent — never edited by hand

ServerStorage
  Tests/                   spec ModuleScripts, run via execute_luau
  WorkLog/                 ★ claim before you edit — see WORKFLOW.md §2
    README                   the protocol + Active() / OwnerOf() helpers
    <JobID>                  one ModuleScript per job. NEVER a shared file.
```

`WorkLog` and `Tests` are dev-only and are stripped at release (P6).

**Naming is load-bearing.** `multi_edit` and `search_game_tree` address scripts by exact
path. Every packet references `ServerScriptService.Services.SellService`; create it at
`ServerScriptService.SellService` and the jobs that depend on it break.

### Loader pattern

Every service/controller is a ModuleScript returning:

```lua
local MyService = {}
function MyService.Init() end   -- wire references, no cross-service calls yet
function MyService.Start() end  -- safe to call other services, connect events
return MyService
```

`init.server.luau` requires every module in `Services/`, calls `.Init()` on all, then
`.Start()` on all. Two phases removes require-order dependency entirely. Same on client.

## 3. Remote contract — FROZEN

All remotes live in a single `ReplicatedStorage.Remotes` folder, created by the server at
boot from `shared/Remotes.luau`, awaited by the client. Access only through `Net` wrappers
(`server/Services/Net.luau`, `client/Controllers/Net.luau`) — never `:FireServer()` raw.

**Server → Client**

| Remote | Payload | Notes |
|---|---|---|
| `StateChanged` | `(partial: PlayerState)` | Partial diff of replicated state. Client merges. |
| `Notify` | `(kind: "cash"\|"unlock"\|"error"\|"full", text: string, amount: number?)` | Toasts. |
| `CombatFeedback` | `(creature: Model, damage: number, killed: boolean)` | VFX/SFX trigger only. Never authoritative. |
| `CreatureSpawned` / `CreatureDied` | `(creature: Model, tierId: string, variant: string?)` | Client-side decoration. |

**Client → Server** (all rate-limited, all revalidated server-side)

| Remote | Payload | Server validates |
|---|---|---|
| `RequestSwing` (Event) | `(creature: Model)` | creature alive, distance ≤ `GameConfig.SwingRange`, cooldown elapsed, player in that zone |
| `RequestSell` (Event) | `()` | player standing in a sell zone, pack non-empty |
| `RequestPurchase` (Function) | `(track: string, )` → `(ok: boolean, reason: string?)` | track exists, next level exists, cash ≥ cost |
| `RequestUnlockZone` (Function) | `(zoneId: string)` → `(ok, reason)` | zone exists, previous zone unlocked, cash ≥ cost |
| `RequestTeleport` (Event) | `(zoneId: string)` | zone unlocked |
| `RequestHatch` (Function) | `(eggId, count)` → `(ok, companions[], reason?)` | egg available in window, cash ≥ cost × count, count ≤ bundle limit |
| `RequestEquip` (Function) | `(companionId, slot)` → `(ok, reason)` | owned, slot < limit (3 or 6 w/ pass) |
| `RequestFuse` (Function) | `(companionId, tier)` → `(ok, reason)` | ≥ 5 duplicates at that tier |
| `RequestClaim` (Function) | `(kind: "daily"\|"quest"\|"season"\|"index", id)` → `(ok, reward?, reason)` | earned, unclaimed, window valid per server `os.time` |
| `RequestOffer` (Event) | `(offerId)` | offer active for this player, not expired, not purchased |

### The one rule

**The client sends intent, never outcome.** It never sends damage, cash, item counts,
positions, or "I killed it." Any remote that would let the client assert a number is a bug,
and job `A10` will find it.

## 4. Data schema — FROZEN

`ProfileStore` template. Bump `version` and add a migration in `DataService` to change it.

```lua
{
  version = 1,
  cash = 0,
  totalCashEarned = 0,          -- lifetime, drives leaderboard + rebirth eligibility
  pack = {},                    -- { [tierId: string]: count: number }
  upgrades = { pack = 1, boots = 1, harpoon = 1 },
  unlockedZones = { shelf_ice = true },
  rebirths = 0,

  -- Growth track (G) — see docs/MONETIZATION.md
  companions = {},              -- { [companionId]: { count, golden, rainbow } }
  equipped = {},                -- array of ≤ 6 { id, tier }
  indexClaimed = {},            -- { [milestone: string]: true }
  eggStats = { hatches = 0, byEgg = {} },
  quests = { daily = {}, weekly = {}, dailyResetAt = 0, weeklyResetAt = 0 },
  season = { id = "", xp = 0, tier = 0, premium = false, claimed = {} },
  boosts = {},                  -- { [boostId]: expiresAt }  ← timestamp, never remaining time
  offers = { starterShownAt = 0, starterPurchased = false, dealsSeed = 0 },
  social = { groupClaimed = false },

  funnelSteps = {},          -- onboarding milestones already fired (D-012)
  stats = { kills = 0, sells = 0, playtimeSeconds = 0, goldenKills = 0 },
  settings = { music = true, sfx = true, reducedEffects = false },
  claims = { lastDailyAt = 0, dailyStreak = 0, redeemedCodes = {} },
  receipts = {},                -- processed dev-product receipt IDs, for idempotency
  firstJoinAt = 0,
  lastJoinAt = 0,
}
```

**Replicated subset** (what the client is allowed to know, sent via `StateChanged`):
`cash`, `pack`, `packWeight`, `packCapacity`, `upgrades`, `unlockedZones`, `rebirths`,
`companions`, `equipped`, `indexClaimed`, `quests`, `season`, `boosts`, `offers`,
`multiplierBreakdown`, plus `autoSwing`, `autoSwingTrialEndsAt`, `autoSwingEnabled` (D-016)
and `reducedEffects` (B4). Everything else stays server-side.

`autoSwing` and `autoSwingTrialEndsAt` are **derived, not stored** — computed per flush from
`firstJoinAt` and pass ownership, so a trial cannot go stale mid-session.

**Two schema rules that prevent the classic bugs in this genre:**
- **Boosts store an expiry timestamp, never remaining duration.** Remaining-time is wrong the
  moment a player rejoins or the server hops.
- **All timers derive from server `os.time`.** Nothing in this schema is ever compared against
  a client-supplied clock.

Session-locked. Autosave every 60s (`GameConfig.AutosaveInterval`) and on leave.
`game:BindToClose` flushes all profiles. Never write a DataStore call outside `DataService`.

## 5. Server services

| Service | Owns |
|---|---|
| `DataService` | ProfileStore lifecycle, schema migration, leaderstats, `GetData(player)` |
| `StateService` | Diffing profile → client, batching `StateChanged` at 10Hz |
| `CurrencyService` | `Award(player, amount, source)`, `Spend(player, amount)` — the **only** paths that touch `cash` |
| `InventoryService` | pack add/remove, weight math, capacity from upgrades, full-check |
| `CreatureService` | spawning from zone config, HP tracking, respawn timers, death → drops |
| `CombatService` | `RequestSwing` handling, damage calc, cooldown, range, aggro-free |
| `SellService` | sell-zone detection, payout calc (value × count × multipliers), pack clear |
| `UpgradeService` | purchase validation, cost lookup, applying effects (WalkSpeed, capacity, damage) |
| `ZoneService` | unlock validation, barrier state, zone membership per player, teleport |
| `ToolService` | equipping harpoon model per upgrade level, swing animation trigger |
| `MonetizationService` | gamepass ownership cache, dev product receipts, multiplier assembly |
| `AnalyticsService` | typed event emit, funnel + economy sinks/sources |
| `AntiCheat` | rate limiters, distance/teleport sanity, remote arg validation |
| `Net` | remote creation, typed wrappers, per-remote rate limiting |
| `CompanionService` | ownership, equip slots, fusion, index, `GetBonus(player, type)` |
| `EggService` | hatch rolls, luck application, egg availability windows |
| `OfferService` | Starter Pack, daily deals, server-authoritative countdowns |
| `SeasonService` | season XP, tiers, free/premium tracks, rollover |
| `QuestService` | daily/weekly quest progress off analytics events |
| `EventService` | scheduled events, potion boosts, expiry timestamps |

**Multiplier assembly** is centralized: `MonetizationService.GetCashMultiplier(player)`
returns the full product from `docs/MONETIZATION.md` §1 —
`(1 + companionBonus) × gamepass × (1 + 0.25×rebirths) × boost × event × seasonBonus`,
clamped to `GameConfig.MaxMultiplier`.

**This is the single most important function in the codebase.** Six systems feed it and one
system reads it. If a seventh system ever stacks its own multiplier at a call site, the
economy becomes unpredictable and untunable. `SellService` calls it. Nothing else multiplies.
It also returns a `breakdown` table so the HUD can show the player exactly what's contributing
(job G12) — legibility here is what makes players buy the next multiplier.

## 6. Client controllers

| Controller | Owns |
|---|---|
| `Net` | remote wrappers, request/response |
| `State` | local mirror of replicated state + `Changed` signal per key |
| `HarvestController` | swing hitbox — scans for creatures in front of the character, fires `RequestSwing` on cooldown (D-015; no prompt, no input) |
| `HudController` | cash counter, pack weight bar, zone label, sell-direction arrow |
| `ShopController` | shop screen open/close, purchase requests, affordability tinting |
| `ZoneController` | barrier prompts, unlock confirm, teleport menu |
| `NotifyController` | toast queue |
| `EffectsController` | hit particles, floating numbers, hitstop, kill pop |
| `SoundController` | SFX bus, per-zone ambience/music crossfade, settings respect |
| `CameraController` | slight FOV kick on swing, no shake beyond 0.15 studs |

## 7. World and assets (revised by D-009)

**Zones are built by hand in Studio**, under `Workspace.World.<zoneId>`. A human doing level
design produces a better map than a config table, and Team Create makes that collaborative.
The earlier code-generation approach existed only because agents couldn't drag parts.

Config no longer describes geometry. `Config.Zones` keeps **gameplay data only** — unlock
cost, creature tier, population, and the *names* of marker instances the code looks up:

```lua
shelf_ice = {
    displayName = "Shelf Ice",
    unlockCost = 0,
    creatureTier = "snow_cub",
    population = 25,
    spawnRegion = "SpawnZone",   -- Workspace.World.shelf_ice.SpawnZone
    sellPads   = { "SellPad" },  -- Workspace.World.shelf_ice.SellPad
    barrier    = "Barrier",
    lighting   = { ClockTime = 14, Ambient = ..., FogEnd = 900 },
}
```

**The contract between builder and coder is instance names.** Whoever builds a zone creates
a Part named `SellPad` and a Part named `SpawnZone`; `SellService` and `CreatureService` find
them by name. Rename one in Studio and the service silently stops working — so renaming a
marker is a contract change and needs the same RFC as any other.

Agents can still build geometry when it's faster (`execute_luau` to place parts
procedurally, `generate_mesh` for models, `insert_asset` for marketplace props). Use whichever
is quicker for the thing at hand: code for repetitive scatter, hands for composition.

**Models** live under `ReplicatedStorage.Assets`, produced by `generate_mesh` /
`insert_asset` / `upload_image` rather than exported files.

## 8. Performance budget (enforced in E2)

- `StreamingEnabled = true`, target radius 512
- ≤ 20k parts in workspace at rest
- Creatures use **no Humanoid** — a Model with a PrimaryPart, custom animation via
  `AnimationController`. 5 zones × 25 creatures = 125 Humanoids would eat the server.
- Server heartbeat ≤ 4ms at 20 players
- Client ≥ 50 FPS on a 2018 mid-range phone
- One `RunService` connection per controller, maximum. Batch, don't sprinkle.
