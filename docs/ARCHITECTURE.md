# Architecture — FROSTLINE

**Status: V2 TARGET CONTRACT, approved by D-017.** Sections 3–4 define the contract that job
`F5` must implement atomically. Until F5 lands, the checked-in shared Luau modules are the
legacy v1 contract and corrected-slice feature jobs are blocked.

## 1. Workflow

Files are the source of truth. Scripts are authored under `src/`, synced into Studio with
Rojo, and verified in the real engine. Hand-built world geometry and live WorkLog claims remain
Studio-owned. See WORKFLOW.md for branch, ownership, claim, and test rules.

The D-017 reset is intentionally split:

1. Architect approves the design, target contracts, economy requirements, and new packets.
2. `F5` updates all frozen shared Luau contracts plus the profile migration in one reviewed job.
3. Corrected-slice jobs implement only after F5.
4. Old jobs are reused only where the new packets explicitly say so.

Do not make compatibility shims in random services. A temporary v1/v2 bridge belongs in F5 or
DataService and must have a deletion condition.

## 2. Datamodel layout

```text
src/shared/**                    → ReplicatedStorage.Shared
src/server/Server.server.luau    → ServerScriptService.Server
src/server/Services/**           → ServerScriptService.Services
src/server/Lib/**                → ServerScriptService.Lib
src/client/Client.client.luau    → StarterPlayerScripts.Client
src/client/Controllers/**        → StarterPlayerScripts.Controllers
src/client/UI/**                 → StarterPlayerScripts.UI
assets/**                        → ReplicatedStorage.Assets
tests/**                         → ServerStorage.Tests
Packages/**                      → ReplicatedStorage.Packages
DevPackages/**                   → ReplicatedStorage.DevPackages
                                → ReplicatedStorage.Remotes
```

Rojo does not manage `Workspace` or `ServerStorage.WorkLog`.

Target asset layout:

```text
ReplicatedStorage.Assets
  Creatures/
  Customers/
  Meat/
  Tools/Axes/
  CarryRacks/
  StoreFixtures/
  Workers/
  Effects/
```

Runtime world layout:

```text
Workspace
  World/
    Plots/
      Plot01 ... Plot08
    HuntingGround/
  Runtime/
    Creatures/
    Customers/
    CashVisuals/
```

Every service/controller is a strict ModuleScript returning `Init()` and `Start()`. The
existing two-phase loader remains.

## 3. Remote contract — V2 TARGET, FROZEN AFTER F5

All remotes are created from `Shared.Remotes` and accessed through the server/client `Net`
wrappers. Never call `:FireServer()` directly outside `Net`.

### Server → client

| Remote | Payload | Purpose |
|---|---|---|
| `StateChanged` | `(partial: PlayerState)` | Authoritative profile/store state diff. |
| `Notify` | `(kind: NotifyKind, text: string, amount: number?)` | Small user-facing notices. |
| `CombatFeedback` | `(creature: Model, damage: number, killed: boolean)` | Cosmetic hit/kill response. |
| `CreatureSpawned` / `CreatureDied` | `(creature: Model, tierId: string, variant: string?)` | Client decoration lifecycle. |
| `CarryFeedback` | `(kind: CarryFeedbackKind, amount: number, source: Instance?, target: Instance?)` | Meat pickup/unload VFX and SFX trigger. |
| `StoreFeedback` | `(kind: StoreFeedbackKind, amount: number, source: Instance?, target: Instance?)` | Stock, checkout, cash-spawn, and collection feedback. |

Customer models and their movement replicate through the datamodel. Customer logic does not
depend on a client remote.

### Client → server

| Remote | Payload | Server validates |
|---|---|---|
| `RequestSwing` (Event) | `(creature: Model)` | cadence, target registration/alive, character, server-built hitbox, range |
| `RequestPurchase` (Function) | `(track: UpgradeTrack)` → `(ok, RefusalReason?)` | profile loaded, track, next level, configured cost, funds |
| `RequestSetting` (Function) | `(key: string, value: boolean)` → `(ok, RefusalReason?)` | allow-listed key and value |
| `RequestWorkerAction` (Function) | `(workerId: WorkerId, action: WorkerAction)` → `(ok, RefusalReason?)` | plot ownership, worker existence, unlock/upgrade cost, legal transition |

Unloading, register operation, and cash collection have no client-to-server remote. Server
services detect the player's authoritative character position inside configured world regions.
The client cannot announce that it unloaded, completed a sale, or collected money.

### Rule

The client sends intent, never outcomes or quantities. It never sends damage, meat counts,
sale value, cash value, capacity, worker production, or a trusted position.

## 4. Data schema — V2 TARGET, FROZEN AFTER F5

`ProfileStore` template:

```lua
{
    version = 2,

    cash = 0,
    totalCashEarned = 0,

    carry = {}, -- { [meatId: string]: count: number }
    store = {
        fridge = {}, -- { [meatId: string]: count: number }
        unclaimedCash = 0,
    },

    upgrades = {
        axe = 1,
        carrier = 1,
        fridge = 1,
        register = 1,
    },

    workers = {
        stocker = { unlocked = false, level = 0, enabled = false },
        cashier = { unlocked = false, level = 0, enabled = false },
        hunter = { unlocked = false, level = 0, enabled = false },
    },

    rebirths = 0,
    settings = {
        music = true,
        sfx = true,
        reducedEffects = false,
        autoSwing = true,
    },

    funnelSteps = {},
    stats = {
        kills = 0,
        meatStocked = 0,
        customerSales = 0,
        cashCollections = 0,
        playtimeSeconds = 0,
        goldenKills = 0,
    },

    receipts = {},
    firstJoinAt = 0,
    lastJoinAt = 0,
}
```

`plotId` is session-only and never persisted. Customer reservations and queues are also
session-only; services return reservations before releasing a plot.

### V1 → V2 migration

F5 owns one deterministic migration and tests it:

- `pack` contents map to `carry` meat ids without losing counts.
- `upgrades.pack` maps to `upgrades.carrier`.
- `upgrades.harpoon` maps to `upgrades.axe`.
- refrigerator and register start at their configured initial levels.
- legacy boots and zone unlocks are removed; the game is pre-release, so no Robux entitlement
  or public-player purchase is discarded.
- cash, lifetime earnings, settings, analytics milestones, receipts, timestamps, and applicable
  stats are preserved.
- old companion/meta fields may remain in migrated storage temporarily but are not replicated
  or used until their post-slice design is reapproved.

### Replicated subset

`cash`, `carry`, `carryWeight`, `carryCapacity`, `fridge`, `fridgeWeight`,
`fridgeCapacity`, `unclaimedCash`, `upgrades`, `workers`, session `plotId`,
`autoSwing`, `autoSwingTrialEndsAt`, `autoSwingEnabled`, and `reducedEffects`.

`autoSwing` and `autoSwingTrialEndsAt` remain derived from `firstJoinAt`, gamepass ownership,
the configured trial duration, and the persisted toggle.

Session locking, autosave, BindToClose, and the rule that only DataService touches DataStores
remain unchanged. Every service must guard a nil `DataService.GetData(player)`.

## 5. Server services

| Service | Owns |
|---|---|
| `DataService` | Profile lifecycle, v1→v2 migration, leaderstats, loaded/unloaded signals. |
| `StateService` | Batched v2 state replication and session `plotId`. |
| `CurrencyService` | The only writes to spendable `cash`: `Award` and `Spend`. |
| `InventoryService` | Carry add/remove, weight, capacity, partial adds. |
| `PlotService` | Assign/release one of eight plots; marker lookup; owner checks. |
| `StoreInventoryService` | Refrigerator storage, capacity, atomic reserve/return/consume. |
| `CreatureService` | Shared-ground spawning, server HP, death, configured meat drops. |
| `CombatService` | Server cadence, hitbox/cleave, damage, kill attribution. |
| `ToolService` | Axe model by upgrade threshold and server-triggered swing animation. |
| `CustomerService` | Per-plot customer state machine and queue admission. |
| `RegisterService` | Server region detection, checkout progress, reservation consumption, unclaimed cash. |
| `CashPickupService` | Counter ledger visuals, proximity collection, CurrencyService award. |
| `UpgradeService` | Axe/carrier/fridge/register purchases and configured effects. |
| `WorkerService` | Unlock/upgrade/toggle workers; run work through domain-service APIs. |
| `MonetizationService` | Auto-Swing entitlement/trial and later approved products. |
| `AnalyticsService` | Typed funnel and economy events. |
| `Net` | Remote construction, wrappers, argument/rate validation. |

`SellService` is retired by D-017. It must not be adapted into a hidden instant-sale path.
Legacy `ZoneService` is outside the corrected slice; future hunting-region progression gets a
new packet after the core store loop is measured.

### Customer state machine

```text
ENTER → SEEK_STOCK → RESERVE → TAKE → QUEUE → CHECKOUT → LEAVE
                     │                    │
                     └──── cancel/return ─┘
```

Only StoreInventoryService can reserve or consume fridge stock. A customer carries a reservation
token, not a trusted price. RegisterService resolves sale value from configured meat data at
checkout. Removing a customer or unloading a profile returns any unconsumed reservation.

### Cash transaction boundary

```text
checkout
  → consume reservation
  → add configured value to store.unclaimedCash
  → refresh counter visual

player enters pickup radius
  → atomically remove amount from store.unclaimedCash
  → CurrencyService.Award(player, amount, "store_collection")
  → fire collection feedback
```

A failed award restores the ledger amount. Visual pile count is capped and represents value in
buckets; it is never one Part per currency unit.

### Worker boundary

Workers never mutate profile tables or call CurrencyService directly:

- stocker calls StoreInventoryService transfer APIs;
- cashier calls RegisterService processing APIs;
- hunter calls the configured production/drop pipeline and deposits meat, never cash.

## 6. Client controllers

| Controller | Owns |
|---|---|
| `Net` | Typed remote wrappers. |
| `State` | Local mirror of the replicated subset. |
| `HarvestController` | Tap input, trial/pass Auto-Swing loop, cosmetic cadence, target hint. |
| `CarryController` | Visible wooden carrier and representative stack rendering. |
| `StoreEffectsController` | Meat flight, checkout response, cash magnet/fly animation. |
| `HudController` | Cash, carry fullness, fridge state, Auto-Swing trial/toggle, guidance. |
| `ShopController` | Upgrade display and requests. |
| `WorkerController` | Plot-computer UI and worker requests. |
| `EffectsController` | Combat-only hit/kill effects. |
| `SoundController` | Audio buses and contextual cues. |
| `CameraController` | Restrained movement/combat feel. |

No controller computes carry weight, fridge capacity, sale value, checkout progress, or worker
yield. Those values arrive through StateChanged or cosmetic feedback.

## 7. World contract

All markers are anchored, non-collidable unless they are visible fixtures, and tagged or named
exactly as specified.

```text
Workspace.World
  Plots
    Plot01 ... Plot08
      PlayerSpawn
      StoreEntrance
      CustomerSpawn
      CustomerExit
      CustomerPath
        01 ... NN
      Refrigerator
        UnloadZone
        CustomerPickup
        MeatDisplay
      Register
        OperatorZone
        QueuePoints
          01 ... NN
        CashOrigin
      WorkerComputer
      HunterDropoff
      HuntGate
  HuntingGround
    SpawnZone
    PlayerEntrance01 ... NN
```

PlotService validates all eight plots at startup and refuses duplicate assignment. Missing
required markers fail loudly in debug builds and disable only the affected plot in production.

Travel fairness is part of the contract:

- every plot has an equivalent route to at least one hunting entrance;
- creature distribution cannot permanently favor one entrance;
- customer route length and register queue capacity are equivalent across plots;
- decorative changes cannot move gameplay markers without an architecture review.

The green contractor block is never shipped as literal terrain. World art must make the shared
space read as wilderness using terrain shape, snow cover, occlusion, and multiple trails.

## 8. Performance budget

- `StreamingEnabled = true`.
- Eight plots function concurrently.
- Customer and creature population caps come only from config.
- Customer navigation uses cached plot routes or bounded pathfinding; never one pathfinding
  request per NPC per frame.
- One scheduler loop per service, not one unbounded loop per customer, worker, or creature.
- Carry stacks, refrigerator stock, and cash piles use representative pooled visuals with hard
  config caps.
- Server heartbeat target remains within the configured QA budget at full player count.
- Client target remains at least 50 FPS on the project test phone.
- Every connection and runtime Instance is cleaned when a plot releases or a profile unloads.
