# Art Bible — FROSTLINE

The visual thesis (revised by D-014): **loud shapes, quiet colours.** Chunky studded Roblox
geometry — the silhouette language players already read as a Roblox game — rendered in a
sparse, high-contrast, almost-empty Antarctic palette.

The differentiator is **not** the geometry. It is the colour restraint and the emptiness. A
screenshot may be mistaken for a Roblox simulator by its *shapes*; if it is mistaken for one
by its *colours*, that's wrong.

## 0. The one deliberate inconsistency (D-008)

Everything below governs the **game**. It does not govern the **store page**. The icon and
thumbnails compete in a grid of loud thumbnails at 250px, and losing that fight means nobody
ever sees the restraint. Loud on the store page, quiet in the game. That split is intentional —
don't reconcile it. Store-page direction lives in `docs/specs/store-page.md` (job G1).

Two in-game exceptions, both earned: the **hatch reveal** (job G5) scales its spectacle with
rarity, and the **Starter Pack takeover** (job G12) is permitted to be loud once. Nothing else.

## 1. Rules

1. **Emptiness is the style.** Wide flat white with 3 objects in frame beats 30. Prop density
   target: ≤ 8 visible props per 100×100 stud area outside the outpost. **Unchanged by D-014** —
   chunkier objects do not license more of them.
2. **Silhouette over detail.** Every creature and prop must be identifiable as a black
   shape. Build from **assembled Parts in the studded idiom** (D-014): few, large, chunky
   blocks with visible studs, exaggerated proportions, hard edges. Detail lives in the
   silhouette, never in surface noise. `Plastic` (studded) is the default material;
   `SmoothPlastic`, `Glass` and `Ice` remain available where a surface should read as
   smooth or transparent.
3. **Two-color-plus-accent per zone.** Snow value, shadow value, one saturated accent. That's it.
4. **No gradients, no bevels, no drop shadows in UI.** Flat fills, 1px strokes, hard corners
   at 4px radius max.
5. **The bear is the only warm thing on screen** until you reach Aurora Basin.
6. **No decals, no images in UI where a shape will do.** Icons are geometry.

## 2. Palette

**This table is now the whole differentiator.** D-014 traded away the restrained *geometry*
and kept the restrained *colour*, so every entry below is load-bearing in a way it wasn't
before. A studded blocky game in these nine colours is a distinct object; a studded blocky
game in saturated primaries is one of ten thousand. Adding a colour here needs an RFC.

| Token | Hex | Use |
|---|---|---|
| `snow` | `#F2F6F8` | ground, primary surfaces |
| `snowShadow` | `#C9D6DE` | ambient shadow, secondary surfaces |
| `ice` | `#7FB2C9` | ice walls, glass, water |
| `iceDeep` | `#2E5C73` | crevasses, depth |
| `night` | `#101820` | Black Ice ground, UI background |
| `bone` | `#E8E2D4` | bear fur base, trader parka trim |
| `blood` | `#C4392E` | meat, damage flash, pack-full state, accent |
| `gold` | `#F2B035` | cash, golden variant, purchase-affordable |
| `aurora` | `#4FE0A8` | Aurora Basin accent, unlock success |

Zone accents: Shelf Ice `blood` · Glacier Ridge `ice` · Crevasse Fields `iceDeep` ·
Aurora Basin `aurora` · Black Ice `blood` on `night`.

## 3. Lighting per zone

| Zone | ClockTime | Ambient | Fog | Feel |
|---|---|---|---|---|
| Shelf Ice | 14 | `#B8C8D0` | 900 studs, `snow` | Flat overcast noon. No shadows to speak of. |
| Glacier Ridge | 10 | `#A0BCCC` | 700, `ice` | Low sun, long blue shadows. |
| Crevasse Fields | 16 | `#8098A8` | 500, `iceDeep` | Dimming, claustrophobic. |
| Aurora Basin | 0 | `#2A3A4A` | 600, `night` | Night, green sky curtain, snow self-glows. |
| Black Ice | 2 | `#181818` | 350, `night` | Near-black, red rim light, blowing snow. |

Transitions are tweened by `ZoneService` over 1.5s when a player crosses a zone boundary.

## 4. Creature spec (job C4 — Part assembly per D-014)

- **Budget:** ≤ 14 Parts, one `PrimaryPart`, **no Humanoid** (D-003). The old ≤ 400-triangle
  budget applied to a generated mesh and no longer means anything — count Parts.
- **Construction:** assembled blocks, studded `Plastic`, hard edges, no bevels. Exaggerate
  proportions rather than adding pieces: one oversized paw block beats four knuckle blocks.
- **Silhouette:** blocky quadruped, oversized front paws, low head, short snout, no visible
  ears. Reads as "bear" at 100 studs from behind.
- **Scale:** cub 4 studs at shoulder → titan 14 studs. Same assembly, scaled + retinted,
  except Titan which gets extra shoulder geometry.

C4 no longer needs a modeller. A Part assembly is buildable from `execute_luau`, is diffable
as code, and regenerates deterministically — which is why D-014 makes it the default.
- **Tint per tier:** `bone` → `#DCE6EC` → `#B8D4E4` → `#9FD8C4` (aurora, emissive eyes) →
  `#3A3F4A` with `blood` rim.
- **Eyes:** two small emissive parts. Always on. This is the "fictional creature" tell.
- **Animations needed:** `Idle`, `Walk`, `Hit` (0.2s flinch), `Death` (0.8s topple).
  Driven by `AnimationController`, not `Humanoid`.
- Lives at `ReplicatedStorage.Assets.Creatures.<tierId>`. `CreatureService` clones from there.

## 5. Trader NPC spec (job C5)

Fictional research-outpost trader in a heavy parka, hood up, goggles. Neutral, non-ethnic
design — see `docs/GDD.md` §4. Static model, no Humanoid, idle head-turn toward nearest
player. One model, 3 palette variants across outposts.

## 6. UI kit (job C1)

- **Font:** `GothamBold` for numbers and buttons, `GothamMedium` for body. Nothing else.
- **Cash counter:** top-left, `gold`, tabular figures, no icon, no panel behind it.
- **Pack bar:** top-left under cash. A single 240×10 bar, `snow` fill on `night` track,
  turns `blood` at 100%. Text `84 / 128` beside it, no label word.
- **Toasts:** bottom-center, slide up 20px, hold 1.6s, fade. Max 3 stacked.
- **Shop:** full-screen `night` at 85% alpha, single column of rows. Each row: track name,
  current → next value, cost, buy button. No icons, no rarity colors, no tabs in M1.
- **Buttons:** flat fill, 4px radius, 1px stroke. Affordable = `gold` fill on `night` text.
  Unaffordable = `night` fill, `snowShadow` text, no red, no shake.
- **Nothing on screen that isn't cash, pack, zone name, sell arrow, and one prompt.**
  If a new UI element is proposed, something else comes off first.

## 7. Audio direction (job C6)

Wind bed per zone (rising in intensity by tier). Swing = short whoosh. Hit = wet thud +
ice crack. Kill = low sub drop. Sell = single coin cluster, no jingle. Purchase = one
ascending blip. Music: sparse ambient pads only, no melody, ducks to 40% during combat.
Total audio budget: ≤ 18 assets.
