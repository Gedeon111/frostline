# Monetization & Retention — FROSTLINE

The commercial thesis: **monetize depth, not access.** Nothing here paywalls content. Every
SKU compresses time or multiplies output, which means free players keep playing (feeding
retention and the discovery algorithm) while paying players compound.

Roblox discovery rewards playtime and D1/D7 retention. A game that converts hard and retains
badly gets buried in a week. So where a monetization idea and a retention idea conflict, **the
retention idea wins** — the ceiling is set by how long people stay, not by how hard you squeeze
on day one.

## 1. The multiplier stack — the whole business

Every purchase in this game feeds one number. Players understand it, chase it, and pay to
raise it.

```
payout = Σ(meat value)
       × (1 + companionBonus)      ← Companions   ~1.0 → 12.0
       × gamepassMultiplier         ← 2x Cash      1.0 or 2.0
       × (1 + 0.25 × rebirths)      ← Rebirth      uncapped
       × boostMultiplier            ← Potions      1.0 → 3.0
       × eventMultiplier            ← Events       1.0 → 2.0
       × seasonTierBonus            ← Season pass  1.0 → 1.5
```

Assembled in **exactly one place** (`MonetizationService.GetCashMultiplier`), capped at
`GameConfig.MaxMultiplier`. Displayed to the player as a single live `×N` on the HUD — the
number going up is the product.

Four of those six axes are purchasable. Two are earned. That ratio is deliberate: a free
player can reach a respectable multiplier and feel the game is winnable, which is what keeps
them in the retention funnel long enough to convert later.

## 2. Companions — the collection layer

Sled dogs, arctic foxes, snow owls, wolf pups, bear cubs. They follow you and multiply your
output. Thematically these are working animals on an Antarctic expedition, which is why they
read as native to this game rather than bolted-on Pet Simulator pets.

Each companion carries **one** of three bonuses, mapping onto the existing upgrade tracks so
the system multiplies what's already there instead of adding a fourth thing to track:

| Bonus | Effect | Fantasy |
|---|---|---|
| `cash` | +% sell value | sled dogs haul more to market |
| `damage` | +% harpoon damage | wolves help bring the bear down |
| `luck` | +% rare spawn & rare hatch chance | foxes find what's hidden |

**Rarity:** Common · Uncommon · Rare · Epic · Legendary · Mythic · Secret (0.05%)
**Slots:** 3 equipped by default, up to 6 with a gamepass.
**Fusion:** 5 duplicates → 1 Golden version (2x its bonus). 5 Goldens → 1 Rainbow (5x).
This is the endgame sink that makes duplicates valuable instead of disappointing, and it's
why a whale keeps hatching after they own everything.

**The Index:** a completion grid of every companion. Milestone rewards at 25/50/75/100%.
Cheap to build, and it converts collectors — the players who spend most.

## 3. Eggs — the gacha loop

Eggs are bought with **in-game cash**, not Robux. This matters: it keeps the hatching loop
free, drives the cash economy (a sink for the currency the whole game produces), and makes the
Robux SKUs *accelerators* of a loop players are already in rather than the entry fee to one
they aren't.

| Egg | Zone | Cost | Notable |
|---|---|---|---|
| Shelf Egg | 1 | 500 | tutorial hatch is free |
| Ridge Egg | 2 | 8,000 | |
| Crevasse Egg | 3 | 75,000 | |
| Aurora Egg | 4 | 600,000 | first Legendary tier |
| Black Ice Egg | 5 | 5,000,000 | Mythic + Secret |
| **Limited Egg** | any | Robux | rotates every 7 days, then gone permanently |

The Limited Egg is the FOMO engine and the highest-margin SKU. Exclusive companions from it
are never re-released — that promise has to be kept or the mechanic dies.

## 4. Robux SKUs

### Gamepasses (permanent)

| # | Pass | R$ | Effect |
|---|---|---|---|
| 1 | 2x Cash | 199 | doubles all sell payouts |
| 2 | 2x Drops | 249 | doubles meat per kill |
| 3 | +100 Pack | 149 | flat capacity |
| 4 | Auto-Swing | 399 | holds the swing while in range |
| 5 | Auto-Sell | 299 | sells from anywhere when full |
| 6 | Lucky | 399 | 2x rare hatch + rare spawn chance |
| 7 | +3 Companion Slots | 349 | 3 → 6 equipped |
| 8 | Auto-Hatch | 199 | hatches continuously |
| 9 | Fast Hatch | 149 | 3x hatch animation speed |
| 10 | Triple Golden | 299 | 3x golden creature spawn rate |
| 11 | VIP | 499 | private sell pad every zone, chat tag, daily bonus, exclusive companion |

### Developer products (repeatable)

| # | Product | R$ | Notes |
|---|---|---|---|
| 12 | Cash packs ×4 | 49 / 199 / 799 / 1999 | scaled to the player's current zone, not flat |
| 13 | Egg bundles | 99 / 299 | 3× / 10× instant hatches |
| 14 | **Starter Pack** | 99 | one-time, first 24h only: 2x Cash + exclusive companion + cash |
| 15 | Luck Potion (30m) | 49 | |
| 16 | Cash Potion 2x (30m) | 49 | |
| 17 | Instant Full Pack | 99 | |
| 18 | Season Pass premium | 599 | unlocks the paid reward track |

**19 SKUs.** The Starter Pack is the most important line in this table — a one-time, heavily
over-valued, timer-limited offer shown at the end of the first session converts more first-time
buyers than everything else combined. Price it so it's obviously worth it.

## 5. Limited-time pressure

| Mechanic | Cadence | Purpose |
|---|---|---|
| Daily deals | 24h rotation, countdown timer | return visit |
| Limited Egg | 7 days, then permanently retired | urgency + collector spend |
| Weekend events | Blizzard (2x drops), Aurora Storm (2x luck) | weekend session spike |
| Season pass | 4-week seasons, free + premium tracks | the retention backbone |
| Starter Pack | first 24h per account | first-purchase conversion |

All timers are **server-authoritative on `os.time`.** Client clocks are the classic exploit in
every one of these mechanics.

## 6. Retention ladder

| Horizon | Mechanic |
|---|---|
| Minute 1–5 | first kill → first sell → first upgrade → free egg → first companion |
| Session 1 | Zone 2 unlocked, 3+ companions, Starter Pack offer at session end |
| Day 1–7 | daily ladder, 3 daily quests, playtime chests every 10 min |
| Week 1–4 | season pass tiers, weekly quests, Limited Egg rotations |
| Month+ | rebirth stacking, fusion (Golden → Rainbow), Index completion, new seasons |
| Social | group-join reward, friend-play bonus, global leaderboard, codes |

**The AFK Camp:** a small zone where an idle player earns at ~15% rate. This looks like a
giveaway; it is actually an algorithm play. Session length is a discovery input, and an AFK
option converts "I'm done" into "I'll leave it running." It also makes Auto-Swing more
attractive, not less — players who AFK see how much faster active play is.

## 7. Conversion funnel — what analytics must prove

```
join → first kill → first sell → first upgrade → first hatch → zone 2
     → session-end Starter Pack shown → purchased?
     → D1 return → daily claimed → season tier 1 → D7 return
```

Every arrow is an `AnalyticsService` event (job A14). The three numbers that decide whether
this game is a business:

1. **% reaching first sell** — if under 80%, the opening is broken and nothing else matters
2. **D1 retention** — target 30%+, this is the discovery input
3. **Starter Pack conversion** — target 3–5% of D1 players

Everything else is a tuning detail. These three get reviewed daily during soft launch (R4).

## 8. The line we don't cross

- **No paywalled zones or content.** Free players see the whole game.
- **No pay-to-win over other players.** There's no PvP, so multipliers hurt nobody.
- **No loot boxes bought directly with Robux.** Eggs cost in-game cash; Robux buys cash,
  luck, and speed. This is both the more durable design and the one that stays clear of
  regulatory attention on paid random rewards.
- **Odds are displayed** on every egg. Hidden rates are how these games get review-bombed.
- **Limited means limited.** A re-released "exclusive" kills the mechanic permanently.

These aren't ethics decorations — each one protects revenue over a longer horizon than the
version that skips it.

## 9. What this costs in scope

Companions, eggs, fusion, index, quests, season pass, offers, events, and boosts are ~14
additional jobs (track `G`). That's roughly a 30% increase over the design-led plan, and it
roughly triples the monetization surface and the retention ceiling.

The architecture absorbs it without change: every one of these systems is a service reading
config and feeding the single multiplier assembly point that already exists.
