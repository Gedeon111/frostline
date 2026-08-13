# M1 — Vertical Slice

**Milestone goal:** a player joins Shelf Ice, kills snow cubs, fills a pack, sells at the
outpost, buys upgrades, rejoins, and everything is still there. One zone. One creature.
No shop UI polish, no sound, no monetization. If this isn't fun, nothing later fixes it.

Every packet assumes you have read `docs/WORKFLOW.md` and `docs/ARCHITECTURE.md`.

---

### [A1] DataService

**Owner:** Server · **Depends on:** F4

**Read first:** `docs/ARCHITECTURE.md` §4, `src/shared/Types.luau`

**You own:** `src/server/Services/DataService.luau`, `src/server/Lib/ProfileStore.luau`

**Build:**
- Vendor ProfileStore as a single file under `Lib/`, license header intact, unmodified.
- Profile template = the exact schema in ARCHITECTURE §4. Session-locked.
- `DataService.GetData(player) -> ProfileData?` and `DataService.GetLoaded(player) -> boolean`.
  Every other service goes through this — **no service may hold a profile reference.**
- `TableUtil.Reconcile` against the template on load so new fields appear for old players.
- A `migrations` table keyed by version. v1 is the baseline; write the mechanism now even
  though it's empty, because retrofitting migrations to a live game is miserable.
- Autosave loop at `GameConfig.AutosaveInterval`. Release on `PlayerRemoving`.
  `game:BindToClose` flushes every active profile before shutdown.
- `leaderstats` folder with a `Cash` IntValue mirrored from `data.cash`.
- Kick the player with a clear message if the profile fails to load — playing on a
  non-persisting session is worse than not playing.
- `DataService.Loaded` signal (from `Util/Signal`) other services connect to.

**Done when:**
- [ ] Join → modify cash → leave → rejoin preserves the value
- [ ] Two rapid rejoins do not corrupt or duplicate a profile (session lock holds)
- [ ] Adding a field to the template makes it appear on an existing profile
- [ ] Server shutdown mid-session does not lose the last minute of progress
- [ ] No DataStore API is called anywhere else in the codebase (grep it and say so in the PR)

**Out of scope:** replication to the client (A2), leaderboards (D4).

---

### [A2] StateService — replication

**Owner:** Server · **Depends on:** A1

**You own:** `src/server/Services/StateService.luau`

**Build:**
- Maintain the **replicated subset** listed in ARCHITECTURE §4 per player. Nothing else
  crosses the wire.
- `StateService.Set(player, key, value)` marks dirty. A single loop at
  `GameConfig.StateReplicationHz` (10Hz) fires **one** `StateChanged` with the accumulated
  diff. Never fire per-change — 4 cash awards in one frame must be one packet.
- Full state push on `DataService.Loaded` and on any client `RequestFullState`.
- Derived values (`packWeight`, `packCapacity`, `multipliers`) are computed here from
  authoritative data, not stored.

**Done when:**
- [ ] 20 mutations in one frame produce exactly one `StateChanged`
- [ ] A joining player receives full state exactly once, before their character spawns
- [ ] No non-replicated field ever appears in a payload (assert this in a unit test)

---

### [A3] CurrencyService + InventoryService

**Owner:** Server · **Depends on:** A1

**You own:** `src/server/Services/CurrencyService.luau`, `src/server/Services/InventoryService.luau`

**Build:**

`CurrencyService`
- `Award(player, amount, source: string) -> number` — the **only** function in the codebase
  that increases cash. Increments `totalCashEarned`. Emits an analytics hook (a no-op stub
  until A14). Clamps to a sane max. Pushes to `StateService`.
- `Spend(player, amount, sink: string) -> boolean` — the only function that decreases cash.
  Returns false and changes nothing if insufficient. **Never allows negative.**
- `CanAfford(player, amount) -> boolean`

`InventoryService`
- `GetCapacity(player)` from `Upgrades.pack` level + gamepass bonus hook (stub, A13 fills it)
- `GetWeight(player)` — Σ over `pack` of `count × tier.meatWeight`
- `TryAdd(player, tierId, count) -> added: number` — **partial adds are the correct
  behaviour**. A pack with 3 free weight accepts one 2-weight meat and refuses the rest. It
  must never overfill and never silently drop a whole drop.
- `Clear(player) -> contents` — returns what was cleared, for SellService
- `IsFull(player) -> boolean`

**Done when:**
- [ ] Unit tests cover: exact-fill, overfill-by-one, empty pack, capacity change while loaded
- [ ] Cash cannot go negative through any code path
- [ ] Grep proves `data.cash` is written in exactly two places, both in `CurrencyService`
- [ ] Capacity increasing mid-session immediately allows more pickup, no rejoin needed

**Out of scope:** payout math (A6), upgrade purchase (A7).

---

### [A4] CreatureService

**Owner:** Server · **Depends on:** F4

**Read first:** `docs/DECISIONS.md` D-003 (no Humanoid), `Config/Creatures.luau`, `Config/Zones.luau`

**You own:** `src/server/Services/CreatureService.luau`

**Build:**
- On start, for each zone in config, spawn `population` creatures at points sampled from the
  zone's `spawnArea` (Poisson-ish spacing, minimum 12 studs apart — clumped bears feel broken).
- Clone from `ReplicatedStorage.Assets.Creatures[tier.modelName]`. **If the asset is missing,
  generate a placeholder block model from tier dimensions and log a warning** — the world
  must be playable before C4 lands. This matters: three other jobs depend on creatures
  existing.
- HP lives in a server-side `{[Model]: {hp, maxHp, tierId, zoneId, variant}}` table.
  Never on the instance, never replicated.
- `CreatureService.Damage(model, amount) -> died: boolean, overkill: number`
- On death: fire `CreatureDied`, detach the model, play nothing (client handles VFX), start a
  `tier.respawnSeconds` timer, respawn at a **new** sampled point.
- `CreatureService.GetInfo(model)` for other services. `CreatureService.Died` signal carrying
  `(killer, model, tierId, variant)`.
- Creatures wander: a slow lerp to a random point within 30 studs every 4–8s. No pathfinding,
  no Humanoid, no physics — set `CFrame` directly, anchored.

**Done when:**
- [ ] 125 creatures across 5 zones cost < 1.5ms/frame of server time
- [ ] Killing one respawns it elsewhere after the configured delay, forever, no leak
- [ ] `Damage` on an already-dead model returns false and does not double-award
- [ ] Zero Humanoids in workspace (assert in a test)
- [ ] Works with placeholder models before any art exists

---

### [A5] CombatService

**Owner:** Server · **Depends on:** A3, A4

**You own:** `src/server/Services/CombatService.luau`

**Build:**
- Handle `RequestSwing(creature)`. Validate, in this order, cheapest first:
  1. rate limit (already applied by `Net`, but assert cooldown ≥ `GameConfig.SwingCooldown`
     using a server-side per-player timestamp — **not** a client-sent one)
  2. creature exists, is alive, is registered with `CreatureService`
  3. player's character exists, is alive
  4. distance ≤ `GameConfig.SwingRange` **× 1.25 tolerance** for lag. Tolerance is a config
     value, not a magic number.
  5. player has the creature's zone unlocked and is inside that zone's bounds
- Damage = `Upgrades.harpoon.damage[level]`. From config, never computed inline.
- Fire `CombatFeedback` to nearby players (within 120 studs) — not to the whole server.
- On kill: `InventoryService.TryAdd(killer, tierId, tier.dropCount × variantMult)`. If the
  pack is full, add what fits and fire `Notify("full")`. **The kill still counts** — losing a
  kill to a full pack feels like theft.
- Credit the kill to the player who dealt the killing blow. No damage-share splitting in M1.

**Done when:**
- [ ] A client firing `RequestSwing` 100×/second lands at most 1 swing per 0.6s
- [ ] A swing from 500 studs away is rejected and logged
- [ ] A swing at a creature in a locked zone is rejected
- [ ] Killing with a full pack awards partial meat, notifies, and does not error
- [ ] Two players swinging at one creature both get feedback; only the finisher gets drops

**Out of scope:** tool models/animation (A10), aggro/creature retaliation (not in this game).

---

### [A6] SellService

**Owner:** Server · **Depends on:** A3

**You own:** `src/server/Services/SellService.luau`

**Build:**
- Sell pads come from `Config/Zones.luau` `sellPads`. Track player occupancy by region check
  on a 5Hz loop (not `Touched` — `Touched` is unreliable and exploitable).
- Handle `RequestSell()`. Validate: player in a sell region, pack non-empty.
- Payout = `Σ(count × tier.meatValue) × MonetizationService.GetCashMultiplier(player)`.
  Call the multiplier through a stub that returns 1 until A13 lands — **write the call site
  now** so nobody bolts multipliers on later in three different places.
- `InventoryService.Clear` → `CurrencyService.Award(player, payout, "sell")` → `Notify("cash",
  payout)`. In that order; if Award fails, the meat is not lost.
- Increment `stats.sells`.

**Done when:**
- [ ] Selling an empty pack is a no-op with a `Notify`, not an error
- [ ] Payout matches a hand-computed value in a unit test for a mixed-tier pack
- [ ] Standing outside the pad and firing the remote is rejected
- [ ] Selling twice in one frame cannot double-pay (clear before award, guarded)

---

### [A7] UpgradeService

**Owner:** Server · **Depends on:** A3

**You own:** `src/server/Services/UpgradeService.luau`

**Build:**
- Handle `RequestPurchase(track, )` → `(ok, reason)`. Validate: track exists,
  `level+1 ≤ maxLevel`, cost from `Config/Upgrades.costs`, `CurrencyService.Spend` succeeds.
- Apply effects on purchase **and** on `DataService.Loaded` **and** on character respawn:
  - `boots` → `Humanoid.WalkSpeed`
  - `pack` → nothing to apply, `InventoryService` reads the level
  - `harpoon` → nothing to apply, `CombatService` reads the level
- `UpgradeService.GetLevel(player, track)`, `.GetValue(player, track)` — every other service
  reads effects through these, never from the profile directly.
- Return **typed refusal reasons** (`"max_level"`, `"insufficient_funds"`, `"unknown_track"`)
  so the client can show the right message without inventing its own copy.

**Done when:**
- [ ] Buying with exactly enough cash succeeds and leaves 0
- [ ] Buying with 1 short fails, changes nothing, returns `"insufficient_funds"`
- [ ] Level 10 → 11 refuses with `"max_level"`
- [ ] WalkSpeed persists across death/respawn and rejoin
- [ ] Costs match `docs/ECONOMY.md` §2 exactly (unit test asserts the whole table)

---

### [B1] Client bootstrap, Net, State mirror

**Owner:** Client · **Depends on:** F4

**You own:** `src/client/Controllers/State.luau` (and the bootstrap from F4 is yours to extend)

**Build:**
- `State` holds the replicated subset, merges incoming `StateChanged` partials.
- `State.Get(key)`, `State.Observe(key, fn)` — fires immediately with the current value then
  on every change. **Every UI element binds through `Observe`.** No polling, anywhere.
- Block until the first full state arrives; expose `State.Ready` (signal + boolean) so
  controllers don't render an empty HUD for two frames.

**Done when:**
- [ ] A partial update touching only `cash` does not re-fire observers for `pack`
- [ ] `Observe` on an unknown key doesn't error and fires when the key first appears
- [ ] No controller reads a remote directly; everything goes through `State` or `Net`

---

### [B2] HarvestController

**Owner:** Client · **Depends on:** B1, A5

**You own:** `src/client/Controllers/HarvestController.luau`

**Build:**
- One `ProximityPrompt` **per creature**, created client-side on `CreatureSpawned`,
  `HoldDuration = 0`, `RequiresLineOfSight = false`, `MaxActivationDistance` from config.
- Hold-to-swing: while the prompt is held (or the mouse/touch is down on a valid target),
  fire `RequestSwing` at exactly the swing cadence. Client-side cooldown is **cosmetic only** —
  the server is the authority and will silently drop extras.
- Track the current target; show the prompt text as the creature's display name, and swap it
  to `PACK FULL` when `State.packWeight >= packCapacity`.
- Mobile: the prompt is the whole interaction. No separate button. Verify hold works on touch.
- Fire a local `SwingStarted` signal that `EffectsController` and `SoundController` consume —
  do not put VFX in this file.

**Done when:**
- [ ] Holding the prompt produces a steady swing rhythm with no client-side stutter
- [ ] Releasing stops immediately
- [ ] Prompt text reflects pack-full state within one frame of the state change
- [ ] Works with keyboard, mouse, and touch
- [ ] Prompts are destroyed when creatures die (no orphaned prompts after 20 minutes)

---

### [B3] HudController

**Owner:** Client · **Depends on:** B1, C1

**Read first:** `docs/ART_BIBLE.md` §6 — the restraint rules are the point of this job

**You own:** `src/client/UI/Hud.luau`, `src/client/Controllers/HudController.luau`

**Build:**
- Cash counter (top-left, `gold`, `Format.Abbreviate`, tweened count-up over 0.35s)
- Pack bar directly beneath: 240×10, `snow` fill, `blood` at 100%, `84 / 128` beside it
- Zone name, small, `snowShadow`, top-center, fades in for 2s on zone entry then fades out
- Sell arrow: a small chevron at screen edge pointing to the nearest sell pad. Appears only
  when the pack is ≥ 50% full. This is the single most important onboarding affordance —
  a new player must never wonder where to go.
- **Five elements total.** Nothing else may be added to the HUD without an ART_BIBLE change.

**Done when:**
- [ ] Renders correctly at 16:9, 4:3, and phone portrait
- [ ] No element overlaps the Roblox top bar or the mobile jump button
- [ ] Every value binds via `State.Observe`, zero `RunService` polling except the arrow
- [ ] Matches the palette tokens from C1 by reference, no hardcoded Color3

---

### [B4] EffectsController

**Owner:** Client · **Depends on:** B1, C1

**You own:** `src/client/Controllers/EffectsController.luau`

**Build:** the entire feel layer from `docs/GDD.md` §6.
- On `CombatFeedback`: white flash on the creature (Highlight, 60ms), 3–5 chunk particles in
  the hit direction, 40ms hitstop (scale the local swing animation, **never** touch
  `Workspace.Gravity` or global timescale).
- Floating damage number, small, `snow`, rises 30 studs and fades over 0.5s. Pooled — never
  create a `BillboardGui` per hit at 100 hits/minute.
- On kill: creature topple tween, meat chunks pop out in an arc toward the player, `x4`
  counter tick near the pack bar.
- On sell: one big `+$1,240` in `gold` at screen center, scale-punch, 0.8s.
- All of it respects a `settings.reducedEffects` flag (add to the settings table via RFC if
  it isn't there — some phones will need it).

**Done when:**
- [ ] Object pools for numbers and particles; steady-state allocation ≈ 0 after 2 minutes
- [ ] 5 players killing simultaneously in view holds ≥ 50 FPS on a mid-range phone
- [ ] Hitstop never affects character movement input
- [ ] Nothing in this file talks to a remote directly or knows any game rule

---

### [C1] UI kit

**Owner:** Client · **Depends on:** F1

**Read first:** `docs/ART_BIBLE.md` §2, §6

**You own:** `src/client/UI/Ui.luau`, `src/client/UI/Theme.luau`

**Build:**
- `Theme.luau` — the palette table from ART_BIBLE §2 as `Color3` values, plus font, corner
  radius, stroke width, and standard tween info. **The only place a color is defined.**
- `Ui.luau` — a small declarative builder: `Ui.new("Frame", {props}, {children})`, plus
  helpers `Ui.Text`, `Ui.Button`, `Ui.Bar`, `Ui.Row`, `Ui.Screen`. Returns real Instances.
  No reactivity framework; binding is `State.Observe` from B1.
- Buttons handle hover/press/disabled states and an affordable/unaffordable variant.

**Done when:**
- [ ] Grep across `src/client/` finds zero `Color3.fromRGB` outside `Theme.luau`
- [ ] Every helper is typed and works under `--!strict`
- [ ] A 5-line example screen in a comment demonstrates the whole API

---

### [C2] Build Zone 1 — Shelf Ice

**Owner:** World (you or your collaborator, in Studio) · **Depends on:** F2 · **Channel:** 1

**Read first:** `docs/DECISIONS.md` D-009, `docs/ARCHITECTURE.md` §7,
`Config.Zones`, `docs/ART_BIBLE.md` §1, §3

**You own:** `Workspace.World.shelf_ice`

**Build** — by hand in Studio, with an agent placing repetitive scatter via `execute_luau`
where that's faster:
- A flat plate with scattered ice blocks at **≤ 8 props per 100×100 studs**. ART_BIBLE §1 —
  the emptiness is the style; resist decorating.
- The outpost: 3–4 simple structures, a visibly distinct 20×20 sell platform, a trader
  placeholder, and the shop trigger. Placed so a player spawning at the outpost sees cubs
  within ~15 seconds of walking.
- Apply the zone's lighting block from config.
- A locked ice barrier toward Zone 2.

**The instance names are the contract** (ARCHITECTURE §7). This zone must contain parts named
exactly `SpawnZone`, `SellPad`, and `Barrier` — `CreatureService` and `SellService` find them
by name. Renaming one is a contract change, not a tidy-up.

**Done when:**
- [ ] Part count ≤ 2,000, everything anchored, `CastShadow = false` on decorative parts
- [ ] `SpawnZone`, `SellPad`, `Barrier` exist at the exact names, verified by `search_game_tree`
- [ ] Walking from the far edge to the sell pad takes ≤ 20s at WalkSpeed 16 — measure it
- [ ] A `screen_capture` from player height is committed to `docs/specs/zone-review.md`
- [ ] Reads as Antarctic and sparse, not as a Roblox baseplate with boxes on it

**Out of scope:** zones 2–5 (C3), final art models (C5).

---

### [E1] Test harness + unit tests

**Owner:** QA · **Depends on:** F2, F3

**You own:** `tests/**`, `scripts/test.sh`

**Build:**
- A minimal spec runner (~80 lines: `describe`/`it`/`expect`) — do not vendor TestEZ, we need
  it callable from a single `execute_luau` string in Edit mode.
- Specs for: `Format`, `TableUtil`, upgrade cost tables vs `docs/ECONOMY.md`, payout math,
  inventory weight/partial-add edge cases, capacity curve, zone unlock ordering.
- An **invariant suite** asserting `docs/ECONOMY.md` §7 rules 1–4 hold against the actual
  Config tables. If a designer tunes a number that breaks a design invariant, tests fail.
  This is the highest-value test in the project.

**Done when:**
- [ ] `./scripts/test.sh` runs headless, exits non-zero on failure
- [ ] ≥ 90% of pure logic modules have specs
- [ ] The invariant suite fails loudly if someone sets a zone cost that breaks pacing
- [ ] Test run takes < 10s

---

### [V1] Slice verification

**Owner:** QA · **Depends on:** all of M1, P1 · **Channel:** 1

**Build:** an automated slice run under `start_stop_play` that drives a simulated player through
the entire loop and asserts it: spawn → locate nearest creature → swing until dead → confirm
drops entered the pack → repeat until full → walk to the sell pad → sell → confirm cash →
purchase one upgrade of each track → confirm effects applied → save → reload profile →
confirm everything persisted. Then the same with two simulated players, asserting their
state stays independent.

Report measured values against `docs/ECONOMY.md` §4: time-to-first-sell, cash/min, kills per
trip, walk-back duration. If time-to-first-sell exceeds 90s, that is a failure (ECONOMY §7
rule 5), not a note.

**Done when:** the whole loop passes unattended from one command; both-player independence
asserted; measured pacing committed to `docs/specs/slice-metrics.md`; any deviation over 15%
from the ECONOMY §4 table filed as a D1 input.

---

### [V2] Feel check — the one thing that isn't automatable

**Owner:** You · **Depends on:** V1 · **Est:** 10 minutes

Everything else on this board an agent can verify. It cannot tell you whether swinging feels
good. Run `./scripts/studio.ps1`, play the slice, and answer five questions in the PR:

1. Does the swing feel right at 0.6s, or does it want to be faster/heavier?
2. Is the walk back boring at WalkSpeed 16, or is it the right amount of friction?
3. Three trips from the next pack upgrade — do you *want* it, or does it feel far?
4. Did you know where to sell without being told?
5. Where did you get bored? Timestamp it.

These five answers are the highest-value input D1 receives. M2 art work can proceed in
parallel; **M2 tuning cannot start until this exists.**
