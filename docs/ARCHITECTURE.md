# Architecture — FROSTLINE

**Status: FROZEN.** Everything in §3 (Remotes) and §4 (Data schema) is a contract that
parallel workers code against. Changing it requires a `docs/DECISIONS.md` entry approved by
the Architect. If your job "needs" a contract change, stop and file the RFC first.

## 1. Toolchain — why file-based

**The entire game is source files**, synced into Studio by Rojo. Studio is a *runtime*, never
an authoring tool. Hand-authoring in the Studio UI produces a binary blob that can't be
diffed, reviewed, split across parallel workers, or regenerated — which would make most of
this board unassignable.

Studio still *runs* the game, and agents drive it headlessly via `run-in-roblox` — see
`docs/AUTOMATION.md`. What's ruled out is authoring by hand in the Studio UI, not using Studio.

- **rokit** — toolchain manager (`rokit.toml`)
- **Rojo 7** — source ⇄ Studio sync (`default.project.json`)
- **selene** — Luau lint (`selene.toml`)
- **StyLua** — formatter (`stylua.toml`)
- **run-in-roblox** — headless test runner for CI
- **No Wally, no package manager.** Third-party code is vendored as a single file under
  `src/server/Lib/` with its license header intact. Currently: ProfileStore only.

No Knit, no Fusion, no Roact. Frameworks create version drift between workers and hide
control flow. We use a 30-line loader (§2) and plain Instance construction for UI.

## 2. Folder layout

```
src/
  shared/                    → ReplicatedStorage.Shared
    Config/                  ★ ARCHITECT-OWNED. Every tunable number lives here.
      GameConfig.luau          global constants (swing cd, respawn, autosave)
      Zones.luau               5 zone defs: bounds, spawn points, unlock cost, lighting
      Creatures.luau           5 tiers: hp, drops, weight, value, model name, variants
      Upgrades.luau            3 tracks x 10 levels: effect value + cost curve
      Tools.luau               harpoon tiers: model, damage mult, swing anim
      Products.luau            gamepass/devproduct IDs + effects
    Types.luau               ★ shared Luau type defs. Import, never redefine.
    Remotes.luau             ★ remote NAME + signature table (§3)
    Util/
      Signal.luau  Trove.luau  RateLimiter.luau  Format.luau  TableUtil.luau
  server/                    → ServerScriptService.Server
    init.server.luau         bootstrap/loader
    Services/                one file per service, see §5
    Lib/ProfileStore.luau    vendored
  client/                    → StarterPlayerScripts.Client
    init.client.luau         bootstrap/loader
    Controllers/             one file per controller
    UI/                      code-built GUI: Ui.luau builder + one file per screen
  world/                     → ServerScriptService.World
    WorldGen.luau            builds the map from Config/Zones at runtime (see §7)
assets/                      → ReplicatedStorage.Assets (.rbxmx, human-exported)
tests/                       *.spec.luau, run headless
```

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

## 7. World generation

`world/WorldGen.luau` builds the entire map at server start from `Config/Zones.luau`:
terrain regions, ice-wall barriers, sell pads, spawn point markers, per-zone `Lighting`
blends. Hand-modelled props (bear models, trader NPCs, outpost buildings) live in
`assets/*.rbxmx` and are *placed* by WorldGen at coordinates from config.

Rationale: a code-generated map is diffable, reviewable, and regenerable by an AI worker.
Hand-placing 400 parts in Studio is not a job you can hand to an agent.

## 8. Performance budget (enforced in E2)

- `StreamingEnabled = true`, target radius 512
- ≤ 20k parts in workspace at rest
- Creatures use **no Humanoid** — a Model with a PrimaryPart, custom animation via
  `AnimationController`. 5 zones × 25 creatures = 125 Humanoids would eat the server.
- Server heartbeat ≤ 4ms at 20 players
- Client ≥ 50 FPS on a 2018 mid-range phone
- One `RunService` connection per controller, maximum. Batch, don't sprinkle.
