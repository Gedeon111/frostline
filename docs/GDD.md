# Game Design Document — FROSTLINE

## 1. Pitch

You are a hunter dropped on the Antarctic ice with a rusted harpoon. Ice bears roam the
shelf. Kill them, haul the meat back to the outpost, sell it to the traders, and buy a
bigger pack, faster boots, and a sharper harpoon. Every upgrade lets you push further out
onto colder ice where the bears are bigger and worth more.

**Core fantasy:** the trip. Go out light, come back heavy, watch the number go up.

## 2. Core loop

```
      ┌──────────────────────────────────────────────┐
      │                                              │
   HUNT ──▶ CARRY ──▶ SELL ──▶ UPGRADE ──▶ UNLOCK ───┘
   swing    weight    cash     capacity     new zone
   at bear  fills     payout   speed        bigger bears
            up        + toast  damage       higher value
```

1. **Hunt** — Walk up to a bear. Hold the ProximityPrompt (or click) to swing. Bears have
   HP; your tool level sets damage per swing. Bears die, drop meat, meat auto-collects into
   your pack.
2. **Carry** — Meat has *weight*. Your pack has a capacity. Full pack = you stop collecting
   and must walk back. This is the friction that makes the loop a loop.
3. **Sell** — Walk into the outpost sell-zone. A trader NPC prompt sells your whole pack.
   Cash lands, `+$1,240` floats up, pack empties.
4. **Upgrade** — Shop GUI at the outpost. Three tracks, 10 levels each: **Pack** (capacity),
   **Boots** (walkspeed), **Harpoon** (damage).
5. **Unlock** — Cash milestones open new zones. New zone = new bear tier = ~3.5x value.
   Loop restarts one rung higher.

**Manual, not idle.** No auto-collect in the base game. The player's hands are on the
character the whole time. (An auto-swing gamepass is the monetization escape hatch — see §7.)

## 3. Content — 5 zones

| # | Zone | Creature | Bear HP | Meat value | Unlock cost |
|---|---|---|---|---|---|
| 1 | **Shelf Ice** — flat white plain, scattered ice blocks, the outpost | Snow Cub | 30 | 5 | free (start) |
| 2 | **Glacier Ridge** — sloped, blue ice walls, wind | Frost Bear | 120 | 18 | 800 |
| 3 | **Crevasse Fields** — dark cracks, narrow bridges | Ice Bear | 450 | 65 | 8,000 |
| 4 | **Aurora Basin** — night, green sky, glowing snow | Aurora Bear | 1,800 | 240 | 60,000 |
| 5 | **The Black Ice** — near-black, red rim light, storm | Titan Bear | 7,500 | 900 | 400,000 |

Full numbers in `docs/ECONOMY.md`. Zones are separate physical areas on one map, gated by
ice-wall barriers with a locked prompt. No teleport in M1; teleport pads added in M2.

**Rare variants (M2):** each tier has a 2% chance to spawn a **Golden** variant — same HP,
10x meat value, gold-tinted with a light emitter. This is the "screenshot moment."

## 4. Naming and content-safety note

Two naming calls, made deliberately — see `docs/DECISIONS.md` D-001:

- **The traders are not "Eskimos."** That word is an outdated exonym considered offensive in
  Canada and Greenland, and putting it in a published Roblox game is both a real-world
  misstep and a live moderation risk. The vendors are **Outpost Traders** — a fictional
  research-station faction in parkas. No real culture is depicted.
- **The bears are fictional creatures, not polar bears.** Stylized silhouette, over-large
  paws, faintly glowing eyes, tier-colored fur. Reads as fantasy, sidesteps the
  "game about shooting an endangered species" framing entirely.

Neither change costs anything design-wise. Both are settled; don't reopen them per-job.

## 5. Session shape

- **First 60 seconds:** spawn next to a cub, prompt says HOLD. Kill it. Meat flies into pack.
  Pack bar fills. Arrow points to outpost. Sell. `+$50`. Shop pings.
- **First 10 minutes:** ~6 pack upgrades, first Boots level, Zone 2 unlocked.
- **First session (~30 min):** deep in Zone 2, Zone 3 in sight.
- **Full clear:** ~8–12 hours to Zone 5 + max upgrades without gamepasses.

## 6. Feel targets (non-negotiable, these are the game)

- Swing cooldown **0.6s**. Hit registers with a snap: freeze-frame 40ms, white flash on the
  bear, chunk particles, low thud.
- Kill is loud: bear ragdolls, meat pops out in an arc, `x4` counter ticks.
- Walking back must be **short** — never more than ~20s from the far edge of a zone to a
  sell point. Zone 2+ get satellite sell posts.
- Pack-full is legible: bar turns red, a soft "clunk" plays, prompt on further bears reads
  `PACK FULL`.
- Sell is the payoff: whole-pack sell, single big number, coin sound, no confirmation dialog.

## 7. Companions — the collection layer

Sled dogs, arctic foxes, snow owls, wolf pups, bear cubs. Working animals on an Antarctic
expedition — which is why they read as native to this game rather than as Pet Simulator pets
wearing a parka.

~40 companions across 7 rarities. Each carries one bonus — `cash`, `damage`, or `luck` —
mapping onto the three existing upgrade tracks, so companions **multiply what's already
there** instead of adding a fourth system to track. 3 equipped by default, 6 with a gamepass.
Hatched from eggs bought with **in-game cash**, which makes eggs the primary currency sink and
keeps the gacha loop free to enter.

Duplicates fuse: 5 → Golden (2x bonus), 5 Golden → Rainbow (5x). That's what makes a duplicate
a step forward instead of a disappointment, and it's the endgame sink for players who already
own everything.

Full design in `docs/MONETIZATION.md` §2–3.

## 8. Monetization

19 SKUs across gamepasses, dev products, and a season pass. Full table in
`docs/MONETIZATION.md` §4. The design rule underneath all of them:

**Monetize depth, not access.** No paywalled zones, no pay-to-win against other players, no
loot boxes bought directly with Robux (eggs cost in-game cash; Robux buys cash, luck, and
speed). Free players see the entire game — which is what keeps them in the retention funnel
long enough to convert, and what keeps the discovery algorithm feeding the game.

The highest-value single SKU is the **Starter Pack**: one-time, 24-hour window, shown at the
end of the first session, priced to be obviously worth it.

## 9. Retention

- **Season pass** — 4-week seasons, 30 tiers, free + premium tracks. The backbone.
- **Daily ladder** (28 days) + **3 daily / 3 weekly quests** + **playtime chests**
- **Rebirth** at Zone 5 + max upgrades: `+25%` permanent, uncapped, stacks with everything
- **Companion Index** completion milestones at 25/50/75/100%
- **Weekend events** — Blizzard (2x drops), Aurora Storm (2x luck)
- **Limited Eggs** — 7-day windows, then permanently retired
- **AFK Camp** — idle earning at ~15% rate, because session length feeds discovery
- **Social** — group reward, friend-play bonus, global leaderboard, codes

Full ladder in `docs/MONETIZATION.md` §6.

## 10. Out of scope (say no to these)

Trading. PvP. Base building. Crafting. Weather survival/temperature meter. Vehicles. A second
hard currency. Anything that adds a system the multiplier stack doesn't feed.

That last clause is the test. Companions earned their way in because they multiply the core
loop; a crafting tree wouldn't. The bet is still that the loop is tight and the game looks
unlike everything else on the platform — every feature has to serve one of those two.
