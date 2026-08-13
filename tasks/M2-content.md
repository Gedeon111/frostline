# M2 — Full Content

**Milestone goal:** all 5 zones playable and gated, the shop exists, the game has art and
sound. The schedule here is set by `C4` — generate → convert → upload → assemble → animate is
the longest sequential chain on the board, and it can't start until `P3` proves the mesh
pipeline. Get `P3` done during M1.

---

### [A8] ZoneService

**Owner:** Server · **Depends on:** A7, C3

**You own:** `src/server/Services/ZoneService.luau`

**Build:** unlock validation (`RequestUnlockZone`: zone exists, previous zone unlocked, cash ≥
cost via `CurrencyService.Spend`), barrier state per player (barriers are client-invisible for
unlocked players via a per-player `LocalTransparencyModifier` approach, or collision groups —
pick one and document it), zone membership tracking on a 5Hz region check with a
`ZoneChanged` signal, and `RequestTeleport` to any unlocked zone's spawn point.

`ZoneService.GetZone(player) -> zoneId` is consumed by `CombatService`, `SellService`, and
`SoundController` — make it cheap and cached.

**Done when:** unlocking is atomic (cash never leaves without the zone arriving); a locked
zone cannot be entered by walking, teleporting, or falling; teleport to a locked zone is
refused; zone membership is correct within 200ms of crossing a boundary; unlock order cannot
be skipped even by direct remote calls.

---

### [A9] Creature tiers 2–5 + golden variants

**Owner:** Server · **Depends on:** A4

**You own:** `src/server/Services/CreatureService.luau` (extension)

**Build:** all five tiers spawning from config with correct HP/drops/respawn; the 2% golden
variant with 10x value, gold tint, and a `PointLight`; a `CreatureSpawned` payload carrying
the variant so the client can decorate it. Spawn weighting must guarantee at least one golden
somewhere per zone within a reasonable window — pure 2% rolls produce dry spells that read as
a bug.

**Done when:** each zone spawns only its own tier; golden rate measured over 10,000 simulated
spawns is 2% ±0.3%; a golden kill awards exactly 10x and increments `stats.goldenKills`;
placeholder models still work for any tier whose art hasn't landed.

---

### [A10] ToolService

**Owner:** Server · **Depends on:** A7

**You own:** `src/server/Services/ToolService.luau`

**Build:** attach the correct harpoon model (from `Config/Tools.luau`, thresholds at levels
1/4/7/10) to the character on spawn and on upgrade; play the swing animation via
`AnimationController`; expose nothing that affects damage — damage stays in `CombatService`
reading `Upgrades`. The tool is **cosmetic feedback for a stat that already exists**; do not
let it become a second source of truth.

**Done when:** buying harpoon level 4 swaps the model without a respawn; the model survives
death, reset, and rejoin; no `Tool` instance is used (backpack UI must stay hidden).

---

### [A11] Trader NPC

**Owner:** Server · **Depends on:** A6, C5

**You own:** `src/server/Services/TraderService.luau`

**Build:** place trader models at each zone's sell pads from config; a `ProximityPrompt`
reading `SELL` that routes to the same validated `RequestSell` path (the pad region check
still applies — the prompt is not the authority); idle head-turn toward the nearest player
within 25 studs; one flavor line on sell, rotating from a small list.

Naming per `docs/DECISIONS.md` D-001 — **Outpost Trader**, never "Eskimo".

**Done when:** prompt and pad-walk-in both sell correctly and identically; the NPC never
blocks player movement; head-turn costs < 0.1ms/frame with 5 traders.

---

### [B5] ShopController + shop screen

**Owner:** Client · **Depends on:** B1, C1, A7

**You own:** `src/client/UI/Shop.luau`, `src/client/Controllers/ShopController.luau`

**Build:** a full-screen `night`-at-85% overlay opened by a prompt at the outpost. Single
column. Upgrades section: three rows (Pack / Boots / Harpoon) each showing `current → next`,
cost via `Format.Abbreviate`, and a buy button tinted by affordability. Zones section: five
rows, locked/unlocked/current state, unlock cost, buy button.

Purchase flow: disable the button, `Net.Invoke`, handle the typed refusal reasons from A7 with
specific copy, re-enable. **Never predict the result client-side** — the button reflects
server truth or nothing.

**Done when:** every row updates live via `State.Observe` while the shop is open; a purchase
that fails server-side shows the right reason and leaves the UI consistent; spam-clicking buy
cannot double-purchase; the whole screen is ≤ 6 distinct visual elements per ART_BIBLE §6.

---

### [B6] ZoneController

**Owner:** Client · **Depends on:** B1, A8

**You own:** `src/client/Controllers/ZoneController.luau`, `src/client/UI/ZoneGate.luau`

**Build:** barrier prompts showing zone name + cost + a one-line teaser ("Frost Bears — 3.6x
value"); an unlock confirmation that is a single button press, not a dialog; a full-screen
`aurora` flash + zone-name card on successful unlock (this is the game's biggest reward
moment — make it land); a teleport menu listing unlocked zones.

**Done when:** approaching a locked barrier always shows the correct cost; the unlock moment
is unmistakable; teleport menu never lists a locked zone even if state arrives out of order.

---

### [B7] SoundController

**Owner:** Client · **Depends on:** B1, C6

**You own:** `src/client/Controllers/SoundController.luau`

**Build:** an SFX bus honoring `settings.sfx`; per-zone wind/ambience crossfaded over 1.5s on
`ZoneChanged`; music ducking to 40% for 3s after combat; a small pool of `Sound` instances
(never `Instance.new("Sound")` per hit); pitch variance ±5% on repeated SFX so rapid swings
don't machine-gun.

**Done when:** zone transitions never hard-cut audio; toggling SFX off silences everything
within one frame; 100 hits/minute allocates no new Sound instances.

---

### [B8] CameraController + movement feel

**Owner:** Client · **Depends on:** B1

**You own:** `src/client/Controllers/CameraController.luau`

**Build:** a 2° FOV kick on swing (0.12s out, 0.2s back); a ≤ 0.15 stud positional nudge on
kill; snow footstep SFX + small particle puffs tied to walk speed; nothing that fights player
camera input. Per `docs/ART_BIBLE.md`, restraint — if a playtester notices the camera, it's
too much.

**Done when:** effects are disabled by `settings.reducedEffects`; the camera never moves while
the player is not acting; total camera displacement per swing is measured and logged, not
eyeballed.

---

### [C3] WorldGen zones 2–5

**Owner:** World · **Depends on:** C2

**You own:** `src/world/ZoneBuilder.luau` (extension), `src/world/Zones/*.luau`

**Build:** each zone as a builder module driven by config — Glacier Ridge (sloped, blue ice
walls), Crevasse Fields (dark cracks, narrow bridges — real fall risk, add a respawn volume),
Aurora Basin (night, sky curtain, self-glowing snow), Black Ice (near-black, red rim light,
blowing snow particles). Per-zone lighting from ART_BIBLE §3, tweened over 1.5s on boundary
crossing. Each zone gets its own satellite sell pad so the ≤ 20s walk-back rule holds.

**Done when:** all 5 zones build in < 8s total; ≤ 20k parts at rest across the map; the
walk-back rule holds in every zone, measured; no zone is reachable from another except through
its barrier; a player falling into a crevasse respawns rather than falling forever.

---

### [C4] Creature models — generate, convert, upload, rig — **LONGEST LEAD, START FIRST**

**Owner:** World · **Depends on:** P3 · **Channel:** 4 → 1 → 2

**Build:**
- Write `docs/specs/creature-model.md` from ART_BIBLE §4 first: per-tier dimensions, tri/part
  budget, pivot placement, attachment names, animation names and durations, naming convention.
  The spec is the prompt source — a vague prompt produces a generic bear.
- Run the P3 pipeline in batch for all 5 tiers: Higgsfield `generate_image` (concept, one
  prompt per tier derived from the spec's silhouette and tint rules) → `generate_3d` →
  Blender convert → Open Cloud upload → asset IDs into config.
- Assemble each into a Roblox Model with a PrimaryPart, `AnimationController`, and emissive
  eye parts, via a `run-in-roblox` assembly script. Export `.rbxmx` into `assets/Creatures/`.
- Author the 4 animations (`Idle`, `Walk`, `Hit` 0.2s, `Death` 0.8s) as KeyframeSequences
  built in code and uploaded — for a 12-part rigid model, hand-authored keyframes in Luau are
  more controllable than generated motion and far quicker to iterate.
- **Iterate on the prompt until the silhouette rule passes.** Render each tier from behind at
  100 studs via a `run-in-roblox` screenshot and check it reads as a bear. Generation gives
  you five tries cheaply; use them.

**Done when:** all 5 tiers exist as `.rbxmx` with real uploaded mesh IDs; each ≤ 400 tris,
≤ 12 parts, zero Humanoids; all 4 animations play via `AnimationController`; the 100-stud
silhouette check passes for every tier; the placeholder generator from A4 is no longer used.

Start this the moment P3 lands. Nothing else on the board has this many sequential steps.

---

### [C5] Outpost props, trader model, harpoon models

**Owner:** World · **Depends on:** P3 · **Channel:** 4 → 1 → 2

**Build:** same pipeline as C4. Write `docs/specs/props.md` first, covering outpost buildings,
sell pad, the trader (per D-001: fictional research-station parka, hood, goggles — no ethnic
depiction; state this constraint *inside the generation prompt*, not just the doc), and the 4
harpoon tiers with grip attachment placement. Generate, convert, upload, assemble, export into
`assets/Props/`, `assets/Traders/`, `assets/Tools/`.

Simple architectural props may be cheaper to build directly as part assemblies in `WorldGen`
than to generate as meshes — a rectangular hut is 6 parts. Use generation for the trader and
the harpoons, code for the buildings.

**Done when:** WorldGen places every prop from config; harpoons attach correctly at all 4
tiers; the trader reads as a parka-wearing researcher and depicts no real culture; prop part
count fits the C3 budget.

---

### [C6] Audio generation + upload

**Owner:** Client · **Depends on:** P2 · **Channel:** 4 → 2

**Build:** write `docs/specs/audio.md` — the ≤ 18 assets from ART_BIBLE §7 with length,
loop/one-shot, volume, and trigger point. Generate via Higgsfield `generate_audio_batch`
(wind beds per zone, swing whoosh, hit thud, ice crack, kill sub-drop, coin cluster, purchase
blip, ambient pads). Upload via P2, write IDs into `Config/Audio.luau`.

**Fallback, and take it early rather than late:** if the Assets API rejects audio for
verification reasons, use Roblox's own audio library — search the creator marketplace via
Chrome MCP, collect IDs for the 18 slots, and move on. Free, pre-moderated, and indistinguishable
to the player. Record which path was taken in the PR.

**Done when:** every trigger in `SoundController` maps to a real asset ID; each sound is
audibly correct when played via `run-in-roblox`; the game still runs without errors if any
ID is 0.

---

### [D1] Economy tuning pass

**Owner:** Economy · **Depends on:** E1, V1, V2

**You own:** `docs/ECONOMY.md`, `scripts/simulate.luau`, and RFCs against `Config/`

**Build:** a headless simulation that plays the curve — given upgrade purchase heuristics
(greedy-cheapest, capacity-first, damage-first), report time-to-each-zone, cash/min per zone,
and total time to 100%. Compare against the pacing table in ECONOMY §4, against V1's measured
metrics, and against V2's five written answers. Propose config changes as an RFC in `docs/DECISIONS.md`; the
Architect applies them.

**Done when:** the sim reproduces the ECONOMY §4 table within 15%; all five invariants in
ECONOMY §7 pass; V2's five answers are each addressed with a specific config change or an
explicit "no change, because"; any proposed change lands as a decision entry with the
before/after pacing table, and E1's invariant suite still passes afterward.

---

### [C7] Art integration audit

**Owner:** World · **Depends on:** C3–C6 · **Channel:** 1

**Build:** a `run-in-roblox` audit script that loads the built place and, for each zone:
captures a screenshot from a fixed camera position with UI hidden, dumps part count, counts
draw calls, and verifies every referenced asset ID resolves. Assemble the five screenshots
into `docs/specs/zone-review.md`.

Then check the results yourself against ART_BIBLE §1–3: are the five zones distinguishable
from their screenshots alone? Does any lighting transition strobe? Does anything in frame
read as a default Roblox asset? Do the bears read as fictional creatures rather than real
polar bears? File what fails as issues against C3–C6 and re-run.

**Done when:** five screenshots committed; every asset ID resolves; part counts inside budget;
each zone is identifiable from its screenshot with no UI or label; every failure found is
either fixed or filed with a specific owner.
