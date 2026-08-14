# Game Design Document — FROSTLINE

## 1. Pitch

FROSTLINE is a low-input Roblox simulator about running a meat shop on the edge of a fictional
Arctic wilderness. Hunt frost bears with an axe, carry visible stacks of meat back to your own
store, stock the refrigerator, serve customers at the register, collect the cash they leave on
the counter, and reinvest in better equipment and workers.

Eight players share one settlement and one hunting wilderness. Each player owns one store plot,
but everyone hunts in the same world.

**Core fantasy:** leave the shop as a hunter, return loaded, then watch the little store come
alive because of what you brought home.

## 2. The two connected loops

```text
HUNT → CARRY → STOCK
  ▲                │
  │                ▼
UPGRADE ← COLLECT ← CHECKOUT ← CUSTOMER
```

### Hunting loop

1. Enter the shared hunting wilderness.
2. Tap to swing a chopping-style axe at nearby frost bears. The server rebuilds the hitbox,
   enforces range and cadence, and applies bounded cleave.
3. On a kill, meat visibly flies toward the player's carrier and becomes authoritative carry
   inventory.
4. The carrier visibly stacks representative meat pieces. A full carrier stops accepting more.
5. Return to the assigned plot and stand at the refrigerator's unload area. Meat transfers
   automatically from the carrier into refrigerator stock, with pieces flying between them.

### Store loop

1. NPC customers enter from the settlement side of the plot.
2. A customer reserves available refrigerator stock, walks to it, and takes the reserved item.
3. The customer queues at the register.
4. The player stands at the register to process the queue automatically. No repeated clicking.
5. A completed sale increases the plot's server-authoritative unclaimed-cash ledger and creates
   a matching visual cash pile on the counter.
6. Walking near the pile collects it. Cash pieces magnet/fly to the player before the server
   awards currency.
7. Currency buys axe, carrier, refrigerator, register, and worker progression.

The refrigerator is the bridge between the two loops. Hunting without stocking cannot produce
customers; customers without checkout cannot produce collectible cash.

## 3. Combat controls and Auto-Swing

D-015 and D-016 remain authoritative:

- A free player taps once per swing. Holding is not a substitute for the paid automation.
- Every account receives Auto-Swing for the first ten minutes after its first join.
- After the trial, Auto-Swing requires the `autoswing` gamepass.
- Eligible players can toggle Auto-Swing on or off.
- The client cooldown is cosmetic. The server validates the real cooldown, hitbox, targets,
  zone membership, and damage.
- Cleave is server-selected and bounded; the client never submits a victim list.

Automation is a convenience purchase, not extra server-authoritative damage. A crafted client
may imitate the cadence but cannot exceed it.

## 4. World layout

The contractor blockout is an adjacency guide, not final terrain:

- **Eight private plots** form the settlement edge. Each receives exactly one player per
  server session.
- The **shared hunting wilderness** sits beyond the plots and belongs to everyone.
- Customers approach from a settlement road or village side.
- Players and hunter workers leave through the wilderness side.
- Multiple equivalent gates or trails and distributed creature spawns keep travel time fair
  for every plot.
- Snowbanks, fences, rock, trees, elevation, and winding trails make the hunting area feel
  like a broad wilderness rather than a shared backyard.
- Customer paths never cross active creature spawn areas.

Plot identity is session-local. A player keeps store inventory and upgrades, not a permanent
plot number.

## 5. Plot contents

Every functional plot has the same named gameplay markers and fixtures:

- player spawn
- store entrance and customer path
- refrigerator plus unload and pickup markers
- register plus operator, queue, and cash-counter markers
- worker computer
- wilderness exit
- upgrade/shop interaction points

Decoration may differ, but travel distance and usable floor area must stay competitively
equivalent. Instance names are defined in ARCHITECTURE §7 and are a builder/coder contract.

## 6. Progression

The corrected first progression tracks are:

- **Axe** — raises damage and swaps the visible axe model at configured thresholds.
- **Carrier** — raises carried meat capacity and expands the visible wooden rack.
- **Refrigerator** — raises stored meat capacity and may unlock larger visual displays.
- **Register** — reduces player-operated checkout time and increases queue throughput.
- **Workers** — unlock and improve automation through ordinary cash.

Movement upgrades are secondary and must not make one plot location objectively superior.
Additional creature regions, product tiers, cosmetics, companions, and rebirth are later
layers, not dependencies of the first store loop.

## 7. Workers

Workers are managed from the computer on the player's plot:

- **Stocker** transfers authoritative carry/drop-off inventory into the refrigerator.
- **Cashier** processes the register queue while enabled.
- **Hunter** produces meat through the same configured hunting economy and deposits it at a
  defined drop-off; it does not mint cash directly.

At least one worker must be reachable before rebirth. Workers cost normal currency, have clear
on/off state, and operate through the same service APIs as players. Rebirth can add slots,
speed, yield, or worker tiers, but it cannot gate the feature that defines the management
fantasy.

## 8. Authority and failure behavior

- Carry contents, refrigerator stock, customer reservations, checkout value, and unclaimed
  cash are server-owned.
- Visual meat, customers, and cash piles project server state; deleting or moving a visual
  never changes the ledger.
- Stock is reserved before a customer takes it. Cancelled customers return their reservation.
- Checkout moves value into `unclaimedCash`; it does not immediately award spendable cash.
- Only proximity collection calls `CurrencyService.Award`.
- Unclaimed cash and refrigerator stock persist across leave/rejoin. The game must never erase
  earned value because a server closes.
- If a profile unloads, every service stops acting for that player and releases session-only
  reservations safely.

## 9. First-session shape

The corrected vertical slice must teach the real game without menus explaining it:

1. Assign a plot and show the refrigerator, register, and wilderness route.
2. Let the player feel Auto-Swing during its existing trial.
3. Kill a nearby starter creature and visibly load the carrier.
4. Guide the player home when the carrier is useful or full.
5. Auto-unload into the refrigerator.
6. Spawn a customer who takes meat and queues.
7. Teach the player to stand at the register.
8. Place cash on the counter and magnet it to the player on approach.
9. Offer the first meaningful axe, carrier, refrigerator, or register upgrade.
10. Introduce the worker computer only after the manual loop has been completed once.

The first collected store sale remains a release-blocking funnel event. Exact timing and costs
belong to ECONOMY.md and must be measured in Studio.

## 10. Feel targets

These interactions carry more product value than additional zones:

- Axe hits have a readable wind-up, contact snap, creature flash, impact sound, and restrained
  hitstop.
- Meat arcs into the carrier and visibly builds a stack without creating one Instance per
  inventory unit.
- Unloading sends a short stream of pieces from the player's back to the refrigerator.
- Customers communicate intent through movement and carried items, not text-heavy dialogs.
- Register processing has a visible progress response and a satisfying completion beat.
- Counter cash forms a readable pile, then behaves like collectible studs: anticipation,
  magnet pull, accelerating flight, arrival tick, and count-up.
- Every automatic interaction has an obvious zone and immediate feedback. No hidden waiting.
- Full carrier, full refrigerator, empty stock, blocked queue, and disabled worker states are
  legible in the world and HUD.

## 11. Content safety and tone

The setting is a fictional Arctic frontier, not a depiction of a real Indigenous culture.
Frost bears are fantasy creatures rather than real polar bears. Hunting is stylized and
non-graphic: blocky meat pieces, impact chunks, no blood or gore.

The visual language remains chunky, studded Roblox construction with a restrained snowy
palette. Shops should feel handmade and warm against the wilderness, using timber, metal,
canvas, lamps, and refrigeration equipment.

## 12. Scope order

### Corrected vertical slice

Eight assignable plots, one shared hunting area, one creature tier, one axe, visible carrying,
refrigerator stocking, one customer behavior, player-operated register, persistent counter
cash, proximity collection, core upgrades, save/rejoin, and one worker proof.

### After the slice proves fun

More store layouts, customer types, creature regions, workers, upgrade visuals, rare meat,
cosmetics, companions, events, rebirth, and additional monetization.

### Explicitly out of scope for the slice

PvP, trading, vehicles, temperature survival, free-form base building, crafting trees, five
separate progression zones, a large SKU catalog, and any Auto-Sell mechanic that bypasses the
store.
