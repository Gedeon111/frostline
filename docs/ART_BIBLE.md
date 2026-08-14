# Art Bible — FROSTLINE

The visual thesis remains **loud shapes, quiet colours**: chunky studded Roblox construction,
clear silhouettes, restrained surfaces, and a snowy world with room to breathe.

D-017 changes the composition. The wilderness stays cold and sparse; player shops introduce a
small amount of handmade warmth through timber, lamps, customers, stocked refrigerators, and
moving cash. The contrast between empty wilderness and busy store is now the visual identity.

## 0. Store page versus game

Store-page art may be louder than the in-game palette so it survives at phone size, but it must
show the real loop: loaded carrier, stocked refrigerator/customer queue, and cash flying from
the counter. No sell pads, harpoons, unbuilt zones, screaming faces, or unrelated simulator
imagery.

In-game spectacle is reserved for axe contact, a full visible carrier, unloading, checkout,
cash collection, rare meat, and later approved progression moments.

## 1. Shape and density rules

1. **Wilderness is sparse; stores are legibly busy.** The shared hunting ground uses broad
   negative space and a few strong landmarks. A stocked plot may contain repeated meat/cash
   representatives, but their visual counts are capped.
2. **Silhouette over surface detail.** Use assembled Parts, visible studs, exaggerated
   proportions, and hard edges. A few large shapes beat many small ones.
3. **Gameplay fixtures read at a glance.** Refrigerator, register, counter cash, worker
   computer, hunt gate, carrier, and axe need unique silhouettes before labels.
4. **Two cold colours plus one warm accent per view.** Store warmth is concentrated around
   timber, lamps, meat, and cash rather than sprayed across every prop.
5. **No graphic hunting.** Meat is a clean blocky red cut with a pale fat edge; no blood pools,
   bones, wounds, or gore.
6. **Motion communicates state.** Flying meat, queue movement, register progress, cash buildup,
   and magnet collection do more work than floating text.
7. **No gradients or decorative image noise in UI.** Flat fills, restrained strokes, and
   geometry-first icons remain.

## 2. Palette

| Token | Hex | Use |
|---|---|---|
| `snow` | `#F2F6F8` | ground, primary cold surfaces |
| `snowShadow` | `#C9D6DE` | secondary cold surfaces |
| `ice` | `#7FB2C9` | ice, glass, cold depth |
| `iceDeep` | `#2E5C73` | deep shadow, wilderness landmarks |
| `night` | `#101820` | UI background, darkest structure |
| `bone` | `#E8E2D4` | creature fur, cloth, pale meat edge |
| `blood` | `#C4392E` | stylized meat, damage/full accent |
| `gold` | `#F2B035` | cash, affordability, rare reward |
| `aurora` | `#4FE0A8` | success/status accent used sparingly |
| `timber` | `#7A5230` | carrier sticks, shop structure |
| `timberDark` | `#493321` | timber shadow and register base |
| `lamp` | `#FFD27A` | localized store lighting only |

The D-017 store loop adds the three warm construction tokens. They do not permit saturated
primary-colour plots. Customization must choose architect-approved combinations from config.

## 3. Lighting and composition

Use one coherent overcast Arctic daylight across the settlement and shared hunting ground.
Wilderness depth comes from snow haze, blue ice shadow, terrain occlusion, and sparse dark
landmarks—not five abrupt lighting zones.

Plots are warmer locally:

- lamp light pools stay close to entrances, refrigerator, register, and computer;
- customer-facing fronts read as welcoming from the settlement road;
- wilderness-facing gates stay cold and practical;
- windows may show warm interiors without turning the snow orange;
- every plot uses equivalent gameplay lighting even if decoration varies.

Customer routes and cash on the counter must remain readable against both snow and timber.

## 4. Creature spec

- **Construction:** assembled blocky Parts in the studded idiom.
- **Budget:** exact cap comes from art/performance config and C11 acceptance; prefer fewer,
  larger pieces.
- **Silhouette:** fictional frost bear with oversized front paws, low head, short snout, and
  emissive eyes. It must not be a realistic polar-bear depiction.
- **Rig:** PrimaryPart plus AnimationController; no gameplay reads from Humanoid health.
- **Animations:** Idle, Walk, Hit, Death.
- **Variants:** tint and small configured accent changes; rare identity must remain visible when
  converted into a meat representative.
- **Death:** stylized topple/poof followed by meat motion; no wounds or blood.

## 5. Tools, carrier, and meat

### Axe

Chopping-tool silhouette: broad head, short readable handle, oversized enough to see on a phone.
Model tiers change material/shape at configured upgrade thresholds without becoming realistic
weapons. Every model exposes `AxeGrip` and the configured Swing animation.

### Carrier

A handmade back rack of timber sticks, straps, and a shallow supporting frame. It grows by
configured model thresholds. Representative meat stacks vertically and may rise above the
character at high capacity, but never blocks the camera or head completely.

The client renders a bounded sample: visual height communicates fullness while authoritative
inventory may be much larger.

### Meat

Chunky, stylized, clearly readable at movement speed: `blood` main block with `bone` fat edge.
Variants use a small configured material/accent treatment. Do not add faces, gore, packaging
labels, or realistic texture.

## 6. Store, customer, and worker spec

### Refrigerator

Large cold silhouette, visible empty/stocked interior, simple shelves, and a clear unload side
for the player. Stock visuals are representative and pooled.

### Register and cash

Register sits on a timber counter with an obvious player standing zone and customer-facing side.
Cash visual uses a few `gold` bills/coins/stud-like pieces that aggregate value. Collection
motion starts at the counter and converges on the player with staggered arrival ticks.

### Customers

Simple blocky winter visitors with palette-controlled coats. Silhouette variants come from hats,
hoods, body scale, and carried item pose—not dozens of colors. Their intent should be readable
from walking, looking, carrying meat, queueing, and leaving.

### Workers

Workers share the customer art language but have one role prop: stocker crate/apron, cashier
cap/register pose, hunter axe/carrier. Avoid real cultural uniforms or stereotypes.

## 7. UI

- Cash remains top-left in `gold`.
- Carry bar sits beneath it and turns `blood` at full.
- Refrigerator status appears only while the owned plot/store is relevant.
- Guidance shows one next action, not a permanent checklist.
- Auto-Swing trial/toggle is compact and does not cover combat or store interactions.
- The upgrade screen has axe, carrier, refrigerator, and register rows.
- Worker management belongs on the in-world computer screen, not the permanent HUD.
- Sell arrows, zone names, harpoon labels, and trader prompts are removed.
- Phone portrait, tablet, desktop, and controller focus are required.

Use the established React UI kit and Theme tokens; no hardcoded colors outside Theme.

## 8. Motion language

- **Kill → carrier:** a short readable arc, then a small stack response.
- **Carrier → refrigerator:** several pooled representatives stream along slightly varied arcs;
  the authoritative transfer may already be complete.
- **Customer pickup:** one representative attaches to hands/basket.
- **Checkout:** brief progress, register response, customer turns to leave, counter pile punches.
- **Cash collection:** anticipation, magnet pull, acceleration, staggered arrival, cash count-up.
- **Reduced effects:** fewer representatives and no camera impulse, but the transaction remains
  understandable.

Motion never delays or determines server state.

## 9. Audio direction

Wilderness: wind, snow footstep, distant ice, restrained ambience.
Combat: axe whoosh, solid stylized impact, creature response, kill beat.
Store: refrigerator hum/door, meat unload ticks, customer footsteps/murmur, register click,
counter buildup, bright cash-arrival ticks, upgrade confirmation.

Music stays sparse and ducks around important transaction sounds. Asset count and concurrency
caps come from Config.Audio and the performance packet.
