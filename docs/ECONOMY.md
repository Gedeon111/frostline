# Economy — FROSTLINE

**Status: D-017 redesign baseline.** The old five-zone sell-pad model is no longer authoritative.
The starter hunting values below are retained because they already worked in Studio; store,
register, and worker values are provisional until the corrected slice is measured. Every value
must live in `src/shared/Config/**` after F5. Gameplay services contain no numeric balance values.

## 1. Value flow

```text
creature death
  → configured meat items
  → carry inventory
  → refrigerator inventory
  → customer reservation
  → register checkout
  → store.unclaimedCash
  → proximity collection
  → spendable cash
```

There is no payout at death, unload, reservation, or queue entry. The only source of spendable
store revenue is `CurrencyService.Award(player, amount, "store_collection")` after an atomic
counter pickup.

A sale uses the meat item's configured value at checkout:

```text
saleValue = Σ(reservedCount × configuredUnitValue) × approvedCashMultiplier
```

The resolved integer value is added to `unclaimedCash`. It is not recomputed when collected,
so a changing multiplier cannot alter money already earned.

## 2. Starter hunting baseline

The existing starter creature values remain the prototype baseline:

| Creature | HP | Drops/kill | Weight/item | Value/item | Weight/kill | Base value/kill |
|---|---:|---:|---:|---:|---:|---:|
| Snow Cub | 30 | 2 | 2 | 5 | 4 | 10 |

The existing starter carrier remains capacity 20. It holds ten starter items or five complete
starter kills. The existing axe level-one damage and configured swing cadence remain until the
feel check changes them.

Rare variants must map to distinct `meatId` values or equivalent variant-preserving records.
A golden creature cannot merely increase a visual drop count while producing ordinary-value
inventory.

## 3. Upgrade tracks

### Axe

The current harpoon damage/cost table is renamed to `axe` for the first prototype. The values
do not change during the naming migration. D1 may retune after combat and the store loop are
measured together.

### Carrier

The current pack capacity/cost table is renamed to `carrier`. Capacity is authoritative
inventory weight; the visible rack is a bounded representation, not one part per carried item.

### Refrigerator

The starting refrigerator must hold at least two full starter carriers. Its level table is
explicit config containing `capacity` and `cost`; services never derive it as a multiple of
carrier capacity. The prototype curve should let the player buy the first refrigerator upgrade
after experiencing an actual stock bottleneck, not before.

### Register

Each level defines configured `checkoutSeconds`, queue capacity, and cost. Register speed
cannot reach zero. The starter level must process a one-item customer quickly enough that
standing at the register feels active rather than idle.

### Workers

Workers have separate configured unlock and level tables:

| Worker | Earliest purpose | Initial pacing target |
|---|---|---|
| Stocker | removes repeated unloading trips inside the plot | reachable first |
| Cashier | keeps the customer queue moving while the player hunts | reachable second |
| Hunter | produces meat at the drop-off | reachable last |

The exact cash tables are a D1 output, but all three use normal currency and at least the first
worker appears before rebirth.

## 4. Corrected slice pacing model

The first slice is measured as stages, not as an instant whole-pack sale:

```text
hunt starter creatures
+ return to assigned plot
+ unload
+ wait for customer movement
+ operate register
+ collect counter cash
= first store-sale loop
```

Release targets:

| Metric | Target |
|---|---|
| First creature kill | within 30 seconds of join |
| First refrigerator stock | within 60 seconds |
| First completed checkout | within 90 seconds |
| First collected store cash | within 100 seconds |
| Return from active hunting edge to any plot gate | no plot more than 15% slower than another |
| Time with stock available but no actionable customer | under 10 seconds in onboarding |
| Player-operated starter checkout | visibly responsive; never a long idle bar |
| First worker | earned in the first normal session |

V1 records median and worst-case values with one player and eight players. These are targets,
not literals for services.

## 5. Throughput balance

Three rates determine whether the store feels alive:

- **hunt production** — meat weight earned per active minute;
- **customer demand** — reserved meat weight per stocked minute;
- **register throughput** — completed sale value per operated minute.

At the starter tier, customer demand should consume one full carrier in roughly the time needed
for the player to perform another hunting trip. That creates a visible queue without permanently
overfilling it.

Constraints:

1. With the player operating the starter register, register throughput exceeds starter customer
   arrival rate.
2. With no cashier, leaving to hunt may create a short queue but never an unbounded one.
3. With a cashier, register throughput does not exceed available stock over a full cycle.
4. Refrigerator capacity, not customer AI randomness, is the readable stock bottleneck.
5. Customer spawn cadence, basket size, queue capacity, and checkout duration all come from
   `Config.Store`.

Customers reserve before walking to stock. Reservations count against available fridge stock
immediately and are returned on cancellation.

## 6. Cash pile model

`unclaimedCash` is one persistent ledger value per player store. Counter visuals are generated
from configured value buckets and capped at a configured number of pieces.

Collection is atomic:

1. snapshot and remove the ledger amount;
2. award exactly that amount through CurrencyService;
3. restore it if the award fails;
4. fire cosmetic feedback.

Many sales may aggregate into one collection. One sale must never create one physical part per
currency unit.

## 7. Worker economy

Worker automation changes labor, not the source of value:

- Stocker moves owned meat and creates none.
- Cashier consumes valid reservations and creates only the same checkout value the player would.
- Hunter creates configured meat at a capped rate and never awards cash.

Initial hunter output must stay below 25% of measured active-player meat production at the same
progression point. Rebirth and worker upgrades may raise it, but active play must remain the
fastest baseline route unless a later approved monetization design explicitly changes that.

Workers pause safely when their destination is full, when no stock/customer is available, or
when the owner profile unloads. Paused time creates no backlog payout.

## 8. Multipliers

The corrected slice keeps only the multiplier hooks required for future compatibility. A cash
multiplier is resolved once at checkout and centralized in
`MonetizationService.GetCashMultiplier(player)`.

Auto-Swing does not change damage, meat value, or cash multipliers. It automates legitimate
swing intent at the existing server-enforced cadence.

Companions, boosts, events, seasons, and rebirth multipliers are deferred until the corrected
loop passes V1/V2. Their old tables are historical hypotheses, not current balance promises.

## 9. Rebirth

Rebirth is post-slice. It should reset selected cash upgrades while preserving earned meta
progression and may improve worker slots, worker efficiency, or store multipliers. It may not
be required to unlock the first stocker, cashier, or hunter.

The exact reset set and multiplier require a separate decision after store-loop telemetry exists.

## 10. Tuning invariants

1. No path except CurrencyService writes spendable cash.
2. No path awards store revenue before counter collection.
3. No customer can consume or sell unreserved stock.
4. Cancelling a customer returns every unconsumed reservation exactly once.
5. Carry and refrigerator capacity never overfill; partial transfers preserve the remainder.
6. First collected store cash occurs within 100 seconds in the onboarding run.
7. No plot's hunting round trip is more than 15% slower than another's.
8. Active starter play outproduces the initial hunter worker by at least 4:1.
9. The first worker is attainable before rebirth in a normal first session.
10. The register queue remains bounded under every configured customer cadence.
11. Visual meat and cash counts are capped independently of inventory and ledger values.
12. Paid Auto-Swing never exceeds the damage/cadence ceiling available to equivalent manual input.
