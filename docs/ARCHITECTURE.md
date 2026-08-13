# Architecture — FROSTLINE

**Status: FROZEN.** Everything in §3 (Remotes) and §4 (Data schema) is a contract that
parallel workers code against. Changing it requires a `docs/DECISIONS.md` entry approved by
the Architect. If your job "needs" a contract change, stop and file the RFC first.

## 1. Workflow — Studio-native (see D-009)

**Roblox Studio is the source of truth.** Humans collaborate through Team Create; agents work
through the Roblox Studio MCP server. There is no build step and no file sync.

| Who | How |
|---|---|
| You + collaborator | Team Create, live in the place |
| Agents | Studio MCP — `multi_edit`, `execute_luau`, `search_game_tree`, `screen_capture`, `start_stop_play`, `generate_mesh`, `insert_asset` |
| Git | one-directional script snapshot for history and rollback (job `P7`) — **a backup, never a source** |

Nothing ever flows from git back into Studio. That one rule is what keeps them from fighting.

**No Knit, no Fusion, no Roact, no Wally.** Frameworks create version drift between workers
and hide control flow. We use a small loader (§2) and plain Instance construction for UI.
Third-party code is pasted as a single ModuleScript with its license header intact —
currently ProfileStore only.

## 2. Datamodel layout

Dot-notation paths, exactly as the MCP addresses them. **This tree is a contract** — create
things where the plan says, or dependent jobs won't find them.

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
```

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
`multiplierBreakdown`. Everything else stays server-side.

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
| `HarvestController` | ProximityPrompt binding, hold-to-swing input, target tracking |
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
