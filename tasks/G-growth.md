# G — Growth: Companions, Monetization Depth, Retention

The track that turns a good loop into a business. Read `docs/MONETIZATION.md` first — every
packet here implements a section of it.

**Sequencing:** `G1` runs immediately, before any of this is built. `G2`–`G6` (companions)
land in M2 alongside the zones. `G7`–`G12` (offers, seasons, quests, events) land in M3.

---

### [G1] Store-page hypothesis — **RUN THIS FIRST, BEFORE M1 FINISHES**

**Owner:** Architect · **Depends on:** — · **Channel:** 4, 3

The icon and thumbnails determine more of this game's revenue than any code job on the board,
and they are currently scheduled last (`R2`). That's backwards. Do the creative work now, so
there's time to test and iterate rather than shipping the first attempt.

**Build:**
- **6 icon candidates**, not one. Generate via Higgsfield / composite in Canva. Every one must
  read at 64px — check at 64px, which is where icons die. Vary the axis deliberately: bear
  face vs. bear silhouette vs. hunter-with-harpoon, `blood`-on-`snow` vs. `gold`-on-`night`.
- **6 thumbnail candidates** across three concepts: the swing moment, the Aurora Basin wide
  shot, a companion + multiplier flex shot. Use real in-engine captures where possible —
  players should recognize the game they clicked.
- **Resolve the restraint tension explicitly.** In-game visual restraint is the
  differentiator and it stays. The store page is a different surface with a different job:
  it competes in a grid of loud thumbnails at 250px. Loud there, quiet in-game. Document the
  split in `docs/ART_BIBLE.md` so nobody "fixes" the inconsistency later.
- Write `docs/specs/store-page.md`: candidates, the reasoning, and the test plan (sponsored-ad
  CTR test at soft launch, R4).

**Done when:** 6 icons + 6 thumbnails committed as files; each icon checked at 64px with the
render attached; a ranked recommendation with reasoning; the ART_BIBLE split documented.

---

### [G2] Companion data model + config

**Owner:** Architect · **Depends on:** F2 · **Channel:** —

**You own:** `src/shared/Config/Companions.luau`, `src/shared/Config/Eggs.luau`, schema RFC

**Build:**
- ~40 companions across 7 rarities, each with: `id`, `displayName`, `rarity`, `bonusType`
  (`cash` / `damage` / `luck`), `bonusPercent`, `modelName`, `eggSources`.
- 6 eggs from `docs/MONETIZATION.md` §3 with **hatch tables whose weights sum to exactly 1.0**
  (assert this in E1 — a drifting weight table is a silent economy bug).
- Fusion rules: 5 → Golden (2x bonus), 5 Golden → Rainbow (5x).
- Index milestones at 25/50/75/100%.
- File the profile schema RFC in `docs/DECISIONS.md`: `companions` (owned, with count and
  fusion tier), `equipped` (array of ≤ 6), `eggStats`, `indexClaimed`.

**Done when:** every hatch table sums to 1.0; rarity weights produce the documented drop rates
under 100k simulated hatches; no companion's bonus breaks the ECONOMY §7 invariants; the
schema RFC is approved and merged into ARCHITECTURE §4.

---

### [G3] CompanionService

**Owner:** Server · **Depends on:** G2, A1 · **Channel:** 1

**You own:** `src/server/Services/CompanionService.luau`

**Build:** ownership tracking, equip/unequip with slot-limit validation (3 base, 6 with the
gamepass), bonus aggregation by type, fusion (5 → Golden, 5 Golden → Rainbow, **atomic** —
a failure mid-fuse must not consume duplicates without granting the result), and Index
progress + milestone claims.

Feeds `MonetizationService.GetCashMultiplier` through a single
`CompanionService.GetBonus(player, bonusType)`. Damage and luck bonuses are read by
`CombatService` and `EggService` through the same function.

**Done when:** equipping a 4th companion without the gamepass is refused server-side; fusion
is atomic across a simulated crash; bonuses apply to the very next sell with no rejoin; a
player with 0 companions has bonus exactly 0 (not nil, not 1); duplicate handling is correct
at every fusion tier.

---

### [G4] EggService + hatch

**Owner:** Server · **Depends on:** G2, G3 · **Channel:** 1

**You own:** `src/server/Services/EggService.luau`

**Build:** purchase validation against in-game cash via `CurrencyService.Spend`; weighted roll
applying the player's total luck bonus; grant via `CompanionService`; hatch-count stats;
triple/ten-hatch bundles; Auto-Hatch and Fast Hatch gamepass behaviour; **Limited Egg
availability windows enforced on `os.time` server-side**.

The roll must be **server-side only** and its result never predictable from anything the
client holds. Log every hatch to analytics with the egg, the roll, and the luck applied —
this is the data D1 needs to tune rates.

**Done when:** rolls match config weights within 0.5% over 100k simulated hatches; luck
correctly shifts the distribution toward rare without ever exceeding 100%; an expired Limited
Egg refuses; a client cannot influence or predict a roll; hatching with insufficient cash
changes nothing.

---

### [G5] Companion client — follow, hatch UI, index

**Owner:** Client · **Depends on:** G3, G4, C1 · **Channel:** 1

**You own:** `src/client/Controllers/CompanionController.luau`, `src/client/UI/Eggs.luau`,
`src/client/UI/Index.luau`

**Build:** equipped companions following the character in a smooth trailing formation (client-
side visual only, no server replication of positions — never send 6 CFrames per player per
frame); the hatch sequence with a rarity-scaled reveal (the reveal is the product — a Mythic
must feel different from a Common); the egg shop; the Index grid with locked silhouettes and
milestone claims; equip/unequip and fusion UI.

**Done when:** 6 companions × 12 players in view holds ≥ 50 FPS on a mid-range phone;
companions never block movement or camera; the hatch animation is skippable after the first;
Fast Hatch is visibly faster; the Index grid renders 40 entries without a frame hitch.

---

### [G6] Companion assets

**Owner:** World · **Depends on:** P3, G2 · **Channel:** 4 → 1 → 2

**Build:** ~40 companion models through the P3 pipeline. These can be far simpler than the
creatures — ≤ 150 tris, ≤ 6 parts, viewed small and in motion. Golden and Rainbow variants
are **material/tint swaps on the base mesh**, not new models; generating 120 meshes when 40
plus two shaders will do is a week wasted.

**Done when:** 40 base models uploaded with real asset IDs; Golden/Rainbow variants render
correctly as tint swaps; total companion asset memory within the E2 budget; each is
identifiable at the size it's actually seen.

---

### [G7] OfferService — Starter Pack, daily deals, timers

**Owner:** Server · **Depends on:** A13 · **Channel:** 1

**You own:** `src/server/Services/OfferService.luau`

**Build:** the Starter Pack (one-time per account, 24h window from first join, tracked on the
profile); daily deal rotation on a server-authoritative 24h cycle; countdown timers computed
from `os.time`, never trusted from the client; purchase fulfilment via `ProcessReceipt` with
idempotency.

Per `docs/MONETIZATION.md` §4, the Starter Pack is the single highest-value SKU in the game.
It must be shown at the **end of the first session** (on a pack-full or first-sell trigger,
not on join) and never shown again once expired or purchased.

**Done when:** the pack cannot be purchased after expiry through any path including a direct
remote call; changing the client clock does nothing; it appears exactly once per account; a
double-purchase attempt grants once and refunds correctly.

---

### [G8] SeasonService — 4-week season pass

**Owner:** Server + Client · **Depends on:** A13, G3 · **Channel:** 1

**Build:** a 30-tier season with a free and a premium track; XP from kills, sells, and quests;
tier rewards (cash, eggs, companions, boosts, an exclusive Mythic at tier 30); premium unlock
via dev product that **retroactively grants every already-earned tier** (this is what makes
players buy at tier 20 instead of tier 1); a season rollover that archives cleanly.

**Done when:** a mid-season premium purchase grants all prior tiers atomically; season
rollover doesn't strip unclaimed rewards without granting them; XP sources match config;
the pass survives a server restart mid-claim.

---

### [G9] QuestService — daily and weekly

**Owner:** Server + Client · **Depends on:** A14, G8 · **Channel:** 1

**Build:** 3 daily + 3 weekly quests drawn from a config pool ("kill 50 Frost Bears", "sell
5 full packs", "hatch 10 eggs", "earn 100k"), progress tracked off existing analytics events
(don't build a second tracking system), rewards in cash + eggs + season XP, server-authoritative
reset on `os.time`.

**Done when:** progress is accurate across rejoins and server hops; a quest completed at the
moment of reset still pays; rerolls (if added) can't farm easy quests; adding a quest is a
config edit.

---

### [G10] Events + boosts

**Owner:** Server + Client · **Depends on:** A13 · **Channel:** 1

**Build:** scheduled weekend events (Blizzard = 2x drops, Aurora Storm = 2x luck) driven by a
server-side schedule config; potion boosts from dev products with durations that **persist
across rejoin and server hop** (store the expiry timestamp, not remaining time — this is the
bug every implementation of this ships first); a HUD indicator showing active boosts and
remaining time; event multipliers feeding the single assembly point.

**Done when:** a boost bought with 20 minutes left survives a rejoin with 20 minutes left; a
server hop doesn't reset or extend it; events start and end on schedule without a restart;
the total multiplier respects `GameConfig.MaxMultiplier`.

---

### [G11] AFK Camp

**Owner:** Server + Client · **Depends on:** A6, A8 · **Channel:** 1

**Build:** a small zone at the outpost where an idle player earns ~15% of their best zone's
rate. Requires the player to be genuinely in the region; awards on a server timer; shows
accumulated earnings and a claim. No anti-AFK defeat mechanics — the entire point is that the
session stays open.

**Done when:** rate matches config as a percentage of the player's best unlocked zone, not a
flat number; earnings accrue only while actually in the region; leaving mid-accrual banks
rather than loses; it can't out-earn active play in any zone.

---

### [G12] Monetization UI — shop, offers, boosts

**Owner:** Client · **Depends on:** B5, G7, G8, G10 · **Channel:** 1

**You own:** `src/client/UI/Store.luau` and extensions to `Shop.luau`

**Build:** a Robux store screen covering all 22 SKUs, grouped (Boosts / Passes / Cash /
Companions); the Starter Pack as a full-screen timed takeover — the one place in this game
permitted to be loud; daily deals with live countdowns; a persistent multiplier readout on the
HUD showing the current `×N` and what's contributing to it.

**That readout is the most important UI element in the game.** It's the number every SKU
raises. Make it legible, live, and tappable to see the breakdown — a player who understands
why their multiplier is 8.4x is a player who knows exactly what to buy to make it 16.8x.

Everything except the Starter Pack takeover obeys `docs/ART_BIBLE.md` §6.

**Done when:** every SKU is purchasable and correctly fulfilled end-to-end against real
product IDs; countdowns are driven by server time; the multiplier breakdown matches
`MonetizationService` exactly; the store opens in under 200ms with all 22 SKUs.

---

### [G13] Social hooks

**Owner:** Server + Client · **Depends on:** A1, G3 · **Channel:** 1

**Build:** a group-join reward (free Rare companion, verified server-side via
`IsInGroup`, granted once); a friend-play bonus (+25% cash while a friend is in the same
server — a genuine multiplayer reason to bring someone); social links to Discord/group in
the menu; a codes system tie-in.

**Done when:** the group reward can't be farmed by leave/rejoin; the friend bonus applies and
removes correctly as players join and leave; `IsInGroup` failures fail closed with a retry.
