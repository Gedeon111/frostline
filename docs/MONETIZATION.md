# Monetization & Retention — FROSTLINE

**Status: corrected-slice scope after D-017.** The previous 22-SKU catalog was designed around
instant sell pads and five-zone progression. It is not approved for implementation. The store
loop must prove that players enjoy hunting, stocking, serving, and collecting before products
are layered onto it.

## 1. Approved monetization: Auto-Swing

D-016 remains unchanged:

| Product | Price | Trial | Effect |
|---|---:|---|---|
| Auto-Swing gamepass | 399 R$ | first ten minutes after first join | automatically submits swing intent while a valid target is in range |

The player may toggle Auto-Swing on or off during the trial and after owning the pass. The
server uses the same cadence, hitbox, range, damage, and cleave validation for manual and
automatic intent.

The trial state is derived from server time and `firstJoinAt`; remaining duration is never
trusted from the client. The HUD shows the trial countdown and toggle without interrupting the
first store loop. When the trial ends, the game may show one clear pass explanation. It must not
spam purchase prompts during combat.

Auto-Swing sells convenience. It does not grant extra damage, higher-value drops, or a faster
server cooldown.

## 2. Explicitly rejected for the corrected loop

**Auto-Sell is removed.** There is no instant sell action anymore, and a product that bypasses
the refrigerator, customers, register, cash pile, and pickup would remove the game's central
fantasy.

The following old products are unapproved hypotheses rather than launch commitments:

- 2x Cash and 2x Drops;
- flat carrier capacity;
- luck, golden-spawn, companion-slot, hatch, and VIP passes;
- cash packs, egg bundles, boosts, limited eggs, and a season pass;
- AFK income.

Their config identifiers may remain temporarily for migration or code isolation, but they must
not be surfaced, created, priced, or sold until a later decision approves them.

## 3. Workers are progression, not an initial paywall

The stocker, cashier, and hunter are bought and upgraded with ordinary in-game cash. At least
one appears in the first session and all are available before rebirth.

Future monetization may add worker slots, cosmetics, or speed after the free worker loop is
proven. It may not make the manual store intentionally unpleasant or prevent free players from
experiencing automation.

## 4. Retention ladder for the real game

| Horizon | Promise |
|---|---|
| Minute 1–2 | first hunt, visible meat stack, refrigerator stock, customer sale, cash pickup |
| Session 1 | meaningful equipment/store upgrades and introduction to the worker computer |
| Sessions 2–3 | first worker, larger visible stock flow, busier customer queue |
| Week 1 | additional worker roles, store appearance goals, stronger creature/meat tier |
| Later | rebirth, worker specialization, cosmetics, companions, events, seasons |

The first session must demonstrate both manual loops before automation replaces any step.

## 5. Funnel

```text
join
  → plot assigned
  → first kill
  → first carry pickup
  → first refrigerator stock
  → first customer reservation
  → first checkout
  → first counter collection
  → first upgrade
  → worker computer opened
  → first worker unlocked
  → D1 return
```

Primary launch-readiness measures:

1. percentage of joins reaching first counter collection;
2. median time from first stock to first checkout;
3. percentage completing another hunt after collecting store cash;
4. first-session upgrade conversion using in-game cash;
5. D1 retention;
6. Auto-Swing trial-to-pass conversion, measured without blocking the core funnel.

Analytics events report stages and configured economy sources/sinks. They never report client-
asserted cash or inventory quantities as authoritative.

## 6. Design guardrails

- No paid product is required to access hunting, plots, customers, registers, or basic workers.
- No paid random reward is introduced in the corrected slice.
- Purchase prompts do not interrupt a first kill, unload, checkout, or cash pickup.
- Automation may save labor but does not invent a second cash formula.
- Auto-Swing remains the only approved corrected-slice SKU.
- A later product must improve a loop players already enjoy; it cannot be the fix for a loop
  deliberately made tedious.
- Prices, entitlement checks, and receipts are server-authoritative and configured centrally.

## 7. Decision gate for further products

New monetization requires Studio metrics from V1, the human feel check from V2, and a short RFC
answering:

- Which enjoyable action does the product deepen or accelerate?
- What does a free player still experience?
- Does it bypass the store transaction chain?
- Which economy invariant and analytics event detect harm?
- Is the product reversible before publication?

Until that gate passes, store polish and worker depth outrank catalog size.
