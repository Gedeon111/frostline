# Economy — FROSTLINE

**Status: v0 starting point.** These numbers are internally consistent and playable, but job
`D1` owns tuning them against real playtests. Everything here becomes a literal table in
`src/shared/Config/`. **No gameplay file may hardcode a number that appears in this doc.**

## 1. Creatures

| Tier | Id | Zone | HP | Drops | Weight/meat | Value/meat | Cash/kill | Weight/kill | Cash per weight |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `snow_cub` | Shelf Ice | 30 | 2 | 2 | 5 | 10 | 4 | 2.5 |
| 2 | `frost_bear` | Glacier Ridge | 120 | 3 | 3 | 18 | 54 | 9 | 6.0 |
| 3 | `ice_bear` | Crevasse Fields | 450 | 4 | 4 | 65 | 260 | 16 | 16.3 |
| 4 | `aurora_bear` | Aurora Basin | 1,800 | 5 | 5 | 240 | 1,200 | 25 | 48.0 |
| 5 | `titan_bear` | The Black Ice | 7,500 | 6 | 6 | 900 | 5,400 | 36 | 150.0 |

HP scales ×4/tier, value ×3.6/tier, **cash-per-weight ×~3/tier**. That last column is the one
that matters: it is the real progression curve. A trip in Zone 5 is worth 60x a trip in Zone 1
at the same pack size.

**Golden variant (M2):** 2% spawn chance, same HP, **10x value**, gold fur + PointLight.
**Respawn:** 8s (T1–T2), 15s (T3–T4), 25s (T5). Population per zone: 25 creatures.

## 2. Upgrades — 3 tracks × 10 levels

### Pack (carry capacity) — `+12 per level`

| Lv | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Capacity | 20 | 32 | 44 | 56 | 68 | 80 | 92 | 104 | 116 | 128 |
| Cost to reach | — | 150 | 285 | 542 | 1,029 | 1,955 | 3,715 | 7,059 | 13,412 | 25,482 |

`cost(n) = round(150 × 1.9^(n-2))` — total to max **53,629**

### Boots (walkspeed) — `+1.2 per level`

| Lv | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| WalkSpeed | 16 | 17.2 | 18.4 | 19.6 | 20.8 | 22 | 23.2 | 24.4 | 25.6 | 26.8 |
| Cost to reach | — | 250 | 500 | 1,000 | 2,000 | 4,000 | 8,000 | 16,000 | 32,000 | 64,000 |

`cost(n) = 250 × 2^(n-2)` — total to max **127,750**. Hard ceiling 28 (above that the
character outruns the snow-footstep loop and the camera feels loose).

### Harpoon (damage per swing) — `×1.7 per level`

| Lv | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Damage | 10 | 17 | 29 | 49 | 84 | 143 | 242 | 412 | 700 | 1,190 |
| Cost to reach | — | 200 | 430 | 925 | 1,988 | 4,274 | 9,190 | 19,759 | 42,481 | 91,334 |

`cost(n) = round(200 × 2.15^(n-2))` — total to max **170,581**

Model swap at levels 1 / 4 / 7 / 10 (rusted → steel → bone → aurora harpoon).

## 3. Zone unlocks

| Zone | Cost | Cumulative spend to reach |
|---|---|---|
| Shelf Ice | 0 | 0 |
| Glacier Ridge | 800 | 800 |
| Crevasse Fields | 8,000 | 8,800 |
| Aurora Basin | 60,000 | 68,800 |
| The Black Ice | 400,000 | 468,800 |

Total lifetime cash to 100% (all upgrades + all zones): **~821,000**.

## 4. Pacing model

Swing cooldown 0.6s. Approach time ~3s/creature. Walk-back ~15–20s.

| Zone | Typical pack lv | Kills/trip | Cash/trip | Trip time | Cash/min | Time to next unlock |
|---|---|---|---|---|---|---|
| 1 | 1–4 | 5 | 50 | ~40s | ~75 | ~11 min |
| 2 | 4–6 | 6 | 324 | ~45s | ~430 | ~25 min |
| 3 | 6–8 | 5 | 1,300 | ~50s | ~1,560 | ~40 min |
| 4 | 8–10 | 4 | 4,800 | ~60s | ~4,800 | ~85 min |
| 5 | 10 | 3 | 16,200 | ~65s | ~15,000 | — |

Zone 5's 85-minute approach is the intentional monetization pressure point: 2x Cash halves
it. If playtests show drop-off before Zone 4 instead, **cut Zone 5's cost, not Zone 4's** —
the mid-game is where retention lives.

## 5. Multipliers — the full stack

```
finalPayout = Σ(count × value)
            × (1 + companionCashBonus)   -- 1.0 → 12.0   (earned, boostable by luck)
            × gamepassMultiplier          -- 1.0 or 2.0   (paid)
            × (1 + 0.25 × rebirths)       -- uncapped     (earned)
            × boostMultiplier             -- 1.0 → 3.0    (paid, timed)
            × eventMultiplier             -- 1.0 → 2.0    (free, scheduled)
            × seasonTierBonus             -- 1.0 → 1.5    (mixed)
```

Assembled in exactly one place: `MonetizationService.GetCashMultiplier()`. Multiplicative
across axes, additive within each axis. **Hard cap `GameConfig.MaxMultiplier = 250`.**

### Why 250 and not 50

With companions at 12x, gamepass 2x, 4 rebirths at 2x, a potion at 2x and an event at 2x, a
committed paying player legitimately reaches ~192x. A cap below that punishes exactly the
player who spent the most — the worst possible outcome. Set the cap where it catches
exploits and stacking bugs, not where it catches customers.

### Expected multiplier by player type

| Player | Companions | Passes | Rebirths | Typical total |
|---|---|---|---|---|
| Free, day 1 | 1.4x | — | 0 | **~1.4x** |
| Free, week 1 | 3.5x | — | 0 | **~3.5x** |
| Free, month 1 | 7x | — | 2 | **~10.5x** |
| Starter Pack buyer | 4x | 2x | 0 | **~8x** |
| Committed payer | 12x | 2x | 4 | **~96x** |

A free month-one player sits around 10x; a payer at the same point sits near 100x. That ~10:1
gap is the design target — wide enough that paying obviously matters, narrow enough that free
play never feels pointless. **If tuning ever pushes this past ~20:1, free players churn and
the discovery algorithm stops feeding you.** That is the ratio D1 protects above all others.

## 5b. Companion bonuses

| Rarity | Hatch rate | Cash/damage bonus | Luck bonus |
|---|---|---|---|
| Common | 50% | +5% | +2% |
| Uncommon | 27% | +12% | +5% |
| Rare | 15% | +30% | +10% |
| Epic | 6% | +75% | +20% |
| Legendary | 1.8% | +180% | +40% |
| Mythic | 0.15% | +450% | +80% |
| Secret | 0.05% | +1000% | +150% |

Rates sum to exactly 1.0 — asserted in E1, per job G2.
Golden = 2x the bonus. Rainbow = 5x. Slots: 3 base, 6 with the gamepass.

**Best realistic loadout** (3 Legendary equipped, no pass): `1 + 3×1.8 = 6.4x`
**Whale loadout** (6 Rainbow Mythic): capped by the 12x design ceiling on companion bonus.

The luck stat compounds into itself — luck raises rare hatch odds, rarer companions carry more
luck. **D1 must verify this doesn't runaway**: simulate 1,000 hatches with maximum luck
equipped and confirm the rare rate stays under 3x base.

## 5c. Egg costs vs. zone income

| Egg | Cost | Trips to afford at its zone | Intent |
|---|---|---|---|
| Shelf | 500 | ~10 | first hatch is free; second is a real goal |
| Ridge | 8,000 | ~25 | |
| Crevasse | 75,000 | ~58 | |
| Aurora | 600,000 | ~125 | first Legendary tier, a multi-session goal |
| Black Ice | 5,000,000 | ~310 | endgame sink, where Mythic lives |

Eggs are the primary **cash sink**. Without them the currency inflates and upgrades stop
feeling like decisions. Target: a player at steady state spends **60–70% of lifetime cash on
eggs**, the rest on upgrades and zones. A14 measures the real split; D1 tunes toward it.

## 6. Rebirth (M3)

Eligible at: Black Ice unlocked **and** all three tracks at level 10.
Reset: `cash`, `upgrades`, `unlockedZones`. Keep: `totalCashEarned`, `stats`, `rebirths`.
Gain: `+25%` permanent cash, rank badge next to name. Uncapped, no cost curve — each
rebirth is just "do it again ~25% faster."

## 7. Tuning invariants — D1 must not break these

1. Cash-per-weight rises **≥2.5x per zone**. Below that, players don't feel the new zone.
2. A player can afford the **next pack upgrade within 3 trips** at any point in the curve.
3. No creature takes **more than 8 swings** at the appropriate tool level for its zone —
   above 8, holding the prompt stops being satisfying and becomes a chore.
4. Zone unlock cost ≤ **60%** of expected cash earned in the previous zone's dwell time,
   so unlocking never means grinding a zone you've already exhausted.
5. First sell happens within **90 seconds** of first join. Non-negotiable.
6. The paying:free multiplier ratio stays under **20:1** (ECONOMY §5). Above that, free
   players churn and discovery dies — which costs more revenue than the squeeze gains.
7. Eggs absorb **60–70%** of lifetime cash. Below 50% the currency inflates; above 80% the
   upgrade tracks stop mattering.
8. The AFK Camp rate never exceeds **20%** of active play in the same zone.
