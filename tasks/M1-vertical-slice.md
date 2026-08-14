# M1 — Corrected Store Vertical Slice

D-017 supersedes the former sell-pad slice. Hand workers one complete `### [ID]` packet.
No corrected-slice implementation starts before F5.

Global rules for every code packet: `--!strict`; no gameplay numbers outside config; use Net
wrappers; guard unloaded profiles; server revalidates client intent; clean every connection and
Instance; run static checks, relevant tests, and Studio verification.

---

### [F5] V2 contracts and migration

**Owner:** Architect + Server · **Depends on:** D-017

**Read first:** WORKFLOW §2–5, ARCHITECTURE §3–4, ECONOMY, DECISIONS D-015–D-017

**You own:** `src/shared/**`, `src/server/Services/DataService.luau`,
`tests/contracts/**`

**Build:**

- Replace v1 Types/Remotes/config with the v2 target in ARCHITECTURE.
- Define meat ids, upgrade tracks, worker ids/actions, customer states, feedback kinds, state
  payloads, and typed refusal reasons.
- Add all Plot, Store, Customer, CashPickup, Worker, CarryVisual, and Axe tuning fields to
  config. Services must need no numeric literals.
- Keep D-015/D-016 hitbox, cleave, trial duration, product id, and toggle behavior.
- Add profile version 2 and the deterministic migration in ARCHITECTURE §4.
- Update Net generation for added/removed remotes. Remove `RequestSell` from the active
  contract; do not leave a hidden compatibility route that awards cash.
- Contract tests assert exact config shape, table invariants, refusal unions, migration
  preservation, and that every declared remote is created.

**Done when:** old fixture migrates without losing cash/carry/receipts; fresh fixture reconciles;
Auto-Swing state still derives correctly; shared modules typecheck; no service packet needs to
invent a number.

**Out of scope:** implementing plots, customers, register, cash pickup, or workers.

**Handoffs:** post the exact diff and unblock dependent rows on BOARD.

---

### [A15] StateService v2 replication

**Owner:** Server · **Depends on:** F5

**Read first:** ARCHITECTURE §4, existing StateService

**You own:** `src/server/Services/StateService.luau`

Replicate only the v2 subset, including session `plotId`, carry/fridge summaries,
`unclaimedCash`, workers, and Auto-Swing state. Preserve batched partial diffs. Never expose
reservation tokens or customer internals.

**Done when:** changing one fridge item does not resend unrelated state; plot assignment updates
within one flush; unload after profile release produces no update; trial expiry changes derived
state without a rejoin.

---

### [A21] UpgradeService v2 tracks

**Owner:** Server · **Depends on:** F5

**Read first:** ECONOMY §3, Config.Upgrades, Types.RefusalReason

**You own:** `src/server/Services/UpgradeService.luau`

Support only configured tracks `axe`, `carrier`, `fridge`, and `register`. Read level
through DataService with a nil guard. Spend only through
`CurrencyService.Spend(player, cost, sink)`. Expose typed `GetLevel` and `GetValue`.
Apply character effects only when a configured track actually has one.

**Done when:** exact funds succeed; one short refuses; max and unknown tracks return only typed
reasons; migrated axe/carrier levels are read; respawn/rejoin is safe.

---

### [A16] InventoryService carry adaptation

**Owner:** Server · **Depends on:** F5, A21

**Read first:** ARCHITECTURE §4–5, Config.Meat, existing InventoryService

**You own:** `src/server/Services/InventoryService.luau`

Rename pack semantics to carry while preserving partial-add safety. Store counts by `meatId`,
derive weight/capacity from config and UpgradeService, return copies, and expose atomic
remove/transfer primitives for StoreInventoryService. Never collapse variants.

**Done when:** mixed meat weight is exact; partial adds do not overfill; failed removal changes
nothing; mutation of returned contents cannot affect profile; nil profile refuses safely.

---

### [A17] PlotService

**Owner:** Server · **Depends on:** F5, C8

**Read first:** ARCHITECTURE §7, Config.Plots

**You own:** `src/server/Services/PlotService.luau`

Validate Plot01–Plot08 and required markers. Assign one free plot per loaded player, publish
session plot id, move spawning to PlayerSpawn, and release on profile unload/leave. Expose typed
marker lookup, owner checks, and server region membership helpers. Plot numbers never persist.

**Done when:** eight simulated players get unique valid plots; ninth receives configured safe
handling; release/reassignment leaves no owner state; missing markers disable only that plot;
a player cannot operate another plot.

---

### [A18] StoreInventoryService

**Owner:** Server · **Depends on:** F5, A16, A21

**Read first:** ARCHITECTURE §5 customer state machine, ECONOMY §1/§5

**You own:** `src/server/Services/StoreInventoryService.luau`

Own refrigerator capacity and stock. Atomically transfer what fits from carry at the owner's
UnloadZone. Provide reserve, return, and consume APIs using opaque server-only tokens. Available
stock excludes active reservations. Return all outstanding reservations on profile unload.

**Done when:** unload preserves overflow in carry; two customers cannot reserve one item;
return/consume is exactly-once; fridge never overfills; another player cannot unload into or
reserve from the plot.

---

### [A19] CreatureService shared-ground adaptation

**Owner:** Server · **Depends on:** F5, C9

**Read first:** Config.Creatures/Meat/HuntingGround, existing CreatureService

**You own:** `src/server/Services/CreatureService.luau`

Keep server HP, respawn, and duplicate-death protection. Spawn only in the configured shared
ground for M1. Resolve a configured `meatId` including variant on death and award through
InventoryService. Preserve visual spawn/death signals.

**Done when:** all creatures stay in the shared region; golden/rare kills create distinct meat
ids with correct configured value; full carry permits only the configured partial award; one
death cannot award twice.

---

### [A20] CombatService axe adaptation

**Owner:** Server · **Depends on:** F5, A19, A21

**Read first:** D-015/D-016, Config.GameConfig, existing CombatService

**You own:** `src/server/Services/CombatService.luau`

Preserve server cadence, server-built hitbox, bounded cleave, per-target registration/alive
checks, and kill attribution. Damage comes from UpgradeService's `axe` value. Client
nomination remains a hint, never a victim list.

**Done when:** spam cannot beat configured cadence; remote range lies fail; cleave respects cap;
all struck targets are server-selected; equivalent manual and Auto-Swing intent have the same
damage ceiling.

---

### [A22] CustomerService

**Owner:** Server · **Depends on:** A17, A18, C10

**Read first:** ARCHITECTURE §5 state machine, Config.Store.Customers

**You own:** `src/server/Services/CustomerService.luau`

Run one bounded scheduler for all plots. Customers enter, seek stock, reserve one configured
basket, take it, queue, await checkout, and leave. Use plot route markers; do not infer gameplay
from client animation. Return reservations on cancellation, model destruction, plot release,
and profile unload.

**Done when:** empty stores do not consume stock; stocked stores form a bounded queue; cancellation
returns stock once; customers never cross plots; population stays within config after a long run.

---

### [A23] RegisterService

**Owner:** Server · **Depends on:** A17, A18, A21, A22

**Read first:** ARCHITECTURE §5 cash boundary, ECONOMY §1/§5

**You own:** `src/server/Services/RegisterService.luau`

Detect the owner in OperatorZone server-side. Progress the head queued customer at configured
register speed, consume its reservation on completion, resolve configured value and the
approved multiplier once, and add the integer result to `store.unclaimedCash`. Expose the same
processing API to the future cashier worker.

**Done when:** no owner means no progress; another player cannot operate it; leaving pauses
without duplicating completion; one token checks out once; profile unload halts cleanly; no
spendable cash is awarded here.

---

### [A24] CashPickupService

**Owner:** Server · **Depends on:** A17, A23

**Read first:** ARCHITECTURE §5 cash transaction boundary, Config.Store.Cash

**You own:** `src/server/Services/CashPickupService.luau`

Project `unclaimedCash` into a capped counter visual and detect owner proximity on the server.
Atomically remove the ledger amount, call
`CurrencyService.Award(player, amount, "store_collection")`, restore on failure, and fire
StoreFeedback. Visual parts never determine value.

**Done when:** two collection ticks cannot double-pay; visual deletion does not erase or award
cash; failed award restores ledger; leave/rejoin restores the visual; non-owner proximity does
nothing.

---

### [A25] WorkerService — stocker proof

**Owner:** Server · **Depends on:** A17, A18, A21

**Read first:** GDD §7, Config.Workers

**You own:** `src/server/Services/WorkerService.luau`

Implement unlock/upgrade/toggle validation for configured workers, but activate only the stocker
behavior in M1. The stocker calls StoreInventoryService; it never writes profile inventory.
Pause on full fridge, empty source, disabled state, plot release, or unloaded profile.

**Done when:** exact-cost unlock works through CurrencyService.Spend; invalid transitions return
typed reasons; toggle persists; stocker cannot overfill or create meat; no offline backlog accrues.

---

### [A26] ToolService — axes

**Owner:** Server · **Depends on:** F5, A20, C11

**Read first:** Config.Tools, Config.Upgrades.axe

**You own:** `src/server/Services/ToolService.luau`

Equip the configured axe model for the player's axe level, swap at configured thresholds, attach
at `AxeGrip`, and play the configured swing animation only after CombatService accepts a swing.
No Tool instances and no harpoon compatibility branch.

**Done when:** join/respawn equips once; threshold purchase swaps without duplicates; accepted
swing animates; rejected spam does not; every created instance/connection cleans up.

---

### [A27] Analytics funnel adaptation

**Owner:** Server · **Depends on:** A18, A23, A24

**Read first:** MONETIZATION §5, existing AnalyticsService

**You own:** `src/server/Services/AnalyticsService.luau`

Preserve the event transport and replace obsolete sell/zone funnel definitions with D-017 stages:
plot assigned, first kill/carry, first stock, reservation, checkout, collection, upgrade, computer,
worker. Economy values come from server event call sites only.

**Done when:** each first-time milestone emits once across rejoin; collection source/sink totals
balance; no client value is logged as authoritative.

---

### [B10] Client State v2

**Owner:** Client · **Depends on:** F5, A15

**You own:** `src/client/Controllers/State.luau`

Update typed keys for v2 while preserving immediate observation and partial-diff behavior.

**Done when:** carry and fridge updates are independent; plot id can arrive after initial profile
state; removed v1 keys have no observers; unknown keys remain safe.

---

### [B11] HarvestController — axes and Auto-Swing

**Owner:** Client · **Depends on:** F5, A20, B10

**Read first:** D-015/D-016, existing HarvestController

**You own:** `src/client/Controllers/HarvestController.luau`

Preserve tap-per-swing, the ten-minute trial, pass entitlement state, and toggle. Select only a
nearby cosmetic target hint and send through Controllers.Net. The local cadence is cosmetic; do
not synchronize around server drops. Fire the existing local swing signal for effects/audio.

**Done when:** tap works on mouse/touch/controller; trial Auto-Swing starts/stops with state;
expiry falls back to manual; toggle applies; no direct FireServer; no gameplay number literal.

---

### [B12] CarryController

**Owner:** Client · **Depends on:** B10, C11

**You own:** `src/client/Controllers/CarryController.luau`

Render the configured wooden carrier and a bounded representative meat stack from authoritative
carry state. Scale the representation up to its configured visual cap; never clone one piece per
item. Rebuild on character respawn and clean old models.

**Done when:** empty/partial/full states are distinct; large capacity stays under the visual part
cap; variant visuals are preserved; respawn and rapid updates leak nothing.

---

### [B13] StoreEffectsController

**Owner:** Client · **Depends on:** F5, B10, C11

**You own:** `src/client/Controllers/StoreEffectsController.luau`

Consume CarryFeedback/StoreFeedback and animate pooled meat/cash representatives. Meat flies to
the carrier and refrigerator; counter cash magnetizes to the player with accelerating arrival
ticks. No service rule or value calculation lives here.

**Done when:** effects still complete if source streams out; reduced-effects mode uses a cheaper
path; steady-state allocations flatten; deleting cosmetics cannot affect server state.

---

### [B14] Corrected HUD

**Owner:** Client · **Depends on:** B10, UI kit

**You own:** corrected HUD controller/components named in the PR

Show cash, carry fullness, refrigerator status while on the owned plot, concise guidance for the
next incomplete funnel step, and the Auto-Swing trial/toggle. Remove sell arrows and zone-unlock
surfaces.

**Done when:** first-time guidance advances only from authoritative state/events; phone/desktop
layouts are clear; full carry/fridge and empty-stock queue states are legible; no polling except
world-direction guidance.

---

### [B15] Corrected upgrade shop

**Owner:** Client · **Depends on:** A21, B10, UI kit

**You own:** shop controller/screen paths declared before work

Present axe, carrier, refrigerator, and register tracks from replicated/config data. Requests go
through Net; typed refusals map to user messages. No client affordability authority.

**Done when:** all four tracks update after purchase; max/unaffordable states are distinct;
rapid taps cannot produce optimistic levels; no harpoon/boots/zone UI remains.

---

### [B16] Worker computer UI

**Owner:** Client · **Depends on:** A25, B10, UI kit

**You own:** worker controller/screen paths declared before work

Open only at the owned WorkerComputer. Show all three configured roles, but only implemented/
available actions are enabled. Unlock, upgrade, and toggle through RequestWorkerAction.

**Done when:** remote plot computer cannot be used; server refusal corrects stale UI; stocker
state persists; cashier/hunter are clearly upcoming rather than fake functional buttons.

---

### [C8] Eight plot shells

**Owner:** World · **Depends on:** F5 · **Studio claim:** `Workspace.World.Plots`

Build Plot01–Plot08 with every exact marker in ARCHITECTURE §7. Match route lengths, usable area,
queue capacity, and hunt access. Geometry can be placeholder quality but markers are final
contracts.

**Done when:** PlotService validator accepts all eight; simultaneous spawn points do not overlap;
measured route spread is within ECONOMY's fairness invariant; no sell pad remains in the loop.

---

### [C9] Shared hunting wilderness

**Owner:** World · **Depends on:** F5 · **Studio claim:** `Workspace.World.HuntingGround`

Turn the blockout adjacency into snowy wilderness with multiple equivalent entrances, distributed
spawn area, occlusion, terrain variation, and no customer traffic. Preserve a clear visual route
home.

**Done when:** it reads as wilderness rather than lawn/backyard; all plot round trips meet
fairness; creatures stay in SpawnZone; streaming does not hide the nearest return landmark.

---

### [C10] Functional store fixtures/routes

**Owner:** World · **Depends on:** C8 · **Studio claim:** plot fixture geometry

Build refrigerator, unload/pickup markers, customer route, bounded queue points, register operator
zone, counter/cash origin, WorkerComputer, and HunterDropoff on all plots.

**Done when:** customer state machine can complete every route; players cannot trigger adjacent
plot zones; fixtures communicate use without dense text.

---

### [C11] Slice assets

**Owner:** World/Tech Art · **Depends on:** F5

**You own:** asset folders named in ARCHITECTURE §2

Create blocky studded axes, wooden carrier/rack, meat representatives, customer, worker
placeholder, and cash pieces. Axes expose `AxeGrip` and configured Swing animation.

**Done when:** assets load by exact config name; visual bounds are consistent; meat is stylized and
non-graphic; mobile part budgets pass.

---

### [C12] Store-loop art integration audit

**Owner:** World/QA · **Depends on:** C8–C11, B12, B13

Capture fixed views of all plots, every hunting entrance, empty/full carrier, refrigerator
unload, customer queue, register, counter pile, and cash flight. Validate exact markers, route
fairness, palette, streaming, collisions, visual pool/part caps, and phone readability.

**Done when:** the corrected slice looks like one coherent game; no plot has an art-created
gameplay advantage; no legacy sell/trader/harpoon prop communicates a false action.

---

### [E4] V2 pure tests

**Owner:** QA · **Depends on:** F5, A16, A18, A23

Test migration, mixed meat/variants, partial carry→fridge transfer, capacity, reservation
exactly-once behavior, checkout integer value, queue bounds, and every ECONOMY §10 invariant
that can be pure.

---

### [E5] Exploit/integration tests

**Owner:** QA · **Depends on:** A22–A24, E4

Test foreign-plot interaction, remote spam, customer destruction in every state, profile unload,
simultaneous collection ticks, visual deletion, and save/rejoin with fridge and unclaimed cash.

---

### [V3] One-player corrected slice

**Owner:** QA · **Depends on:** all corrected M1 implementation/art jobs

Drive join → plot → kill → carry → unload → customer reserve/take/queue → operate register →
cash spawn → collect → upgrade → save/rejoin. Record every ECONOMY §4 target.

---

### [V4] Eight-player verification

**Owner:** QA · **Depends on:** V3

Fill all plots, assert ownership/state isolation, route fairness, customer isolation, shared-ground
spawn distribution, server heartbeat, client FPS, and cleanup after churn.

---

### [V5] Human feel check

**Owner:** Gedeon · **Depends on:** V3

Play ten minutes and answer: Does tap combat remain acceptable after the trial? Does carrying look
rewarding? Is unloading obvious? Does the queue make sense? Is standing at the register satisfying?
Does cash pickup feel magnetic and valuable? Where did boredom first appear?
