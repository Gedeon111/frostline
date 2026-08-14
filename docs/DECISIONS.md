# Decision Log

Append-only. Newest at the bottom. Changing a frozen contract requires an entry here first.

Format: `D-NNN · date · status (PROPOSED / ACCEPTED / SUPERSEDED) · title`

---

### D-001 · 2026-08-13 · ACCEPTED · Vendor and creature naming

**Decision:** Vendors are **Outpost Traders**, a fictional research-station faction. Creatures
are fictional **ice bears** with emissive eyes and tier-colored fur, not real polar bears.

**Why:** "Eskimo" is an outdated exonym widely considered offensive in Canada and Greenland;
shipping it in a published Roblox game is both a real-world misstep and a concrete moderation
risk on a platform with a young audience. Separately, framing the core loop as killing a real
endangered species invites criticism the game gains nothing from. Both changes are free — the
Antarctic setting, the hunt loop, and the visual identity are untouched.

**Blast radius:** naming only. `Config/Creatures.luau` display names, NPC model names,
game page copy.

---

### D-002 · 2026-08-13 · **SUPERSEDED by D-009** · Rojo source-of-truth, no framework

**Decision:** The entire game is source files synced by Rojo. No Knit/Fusion/Roact/Wally. A
two-phase `Init`/`Start` loader replaces the DI framework. Third-party code is vendored as
single files under `src/server/Lib/`.

**Why:** AI workers cannot author in Studio, so a Studio-first workflow would make ~80% of the
job board unassignable. Frameworks add version drift between workers and hide control flow
that reviewers need to see. The loader is 30 lines and does the one thing we need.

**Blast radius:** all code jobs.

---

### D-003 · 2026-08-13 · ACCEPTED · Creatures have no Humanoid

**Decision:** Creatures are Models with a PrimaryPart and an `AnimationController`. HP lives
in a server-side table keyed by model, never in a `Humanoid.Health`.

**Why:** 125 concurrent Humanoids is a server-side non-starter, and `Humanoid.Health` is a
replicated property that invites client-side tampering confusion. Server-table HP is
authoritative by construction.

**Blast radius:** `CreatureService`, `CombatService`, C4 model spec, E2 perf budget.

---

### D-004 · 2026-08-13 · PROPOSED · Final game title

Working title **FROSTLINE**. Alternatives: *Ice Bear Hunter*, *Cold Coast*, *Shelf*.
Needs a Roblox-search check for collisions before R2 (game page assets). Human decision.

---

### D-005 · 2026-08-13 · **SUPERSEDED by D-009** · World is generated from config, not hand-placed

**Decision:** `world/WorldGen.luau` builds terrain, barriers, sell pads, spawn markers and
per-zone lighting at server start from `Config/Zones.luau`. Only hand-modelled props ship as
`.rbxmx` in `assets/`.

**Why:** a code-generated map is diffable, reviewable, and regenerable by an agent. Hand-
placing several hundred parts in Studio is not a task that can be handed to an AI worker, and
it would make zone re-tuning (a D1 activity) a manual re-build every time.

**Blast radius:** C2, C3, ZoneService, SellService.

---

### D-006 · 2026-08-13 · ACCEPTED · Agents ship the whole game, including assets and publishing

**Decision:** There is no manual-work track. Art, audio, uploads, Studio runs, storefront
setup, and publishing are all agent jobs, delivered through four channels documented in
`docs/AUTOMATION.md`: the local toolchain (Studio is installed; `run-in-roblox` executes Luau
inside the real engine headlessly), the Roblox Open Cloud API (asset upload, place publishing,
DataStores), Chrome MCP (creator dashboard, gamepasses, game page), and generative MCP
(Higgsfield image/3D/audio, Canva).

**Supersedes:** the earlier human-only task track, which was written on the wrong assumption
that authoring required a person in Studio. Studio is scriptable, uploads are an HTTP API, and
the dashboard is a website — none of those need hands.

**Retained for a person:** judging feel (job `V2`, ~10 minutes), typing a 2FA code if one
appears, and approving outward-facing irreversible actions (creating paid products, making the
place public).

**Open risk:** Higgsfield `generate_3d` emits GLB and Roblox's importer is FBX/OBJ-first. Job
`P3` proves the conversion path on a single asset before any bulk generation. If it fails,
the fallback is code-built part assemblies in `WorldGen` — uglier, but the low-poly art
direction absorbs it better than most styles would.

**Blast radius:** C4, C5, C6, R2, R3; new P track; `docs/WORKFLOW.md` §7.

---

### D-007 · 2026-08-13 · ACCEPTED · Companions are in. Supersedes GDD §9's "no pets."

**Decision:** Add a ~40-companion collection layer with eggs, rarities, fusion, and an index,
plus 22 monetization SKUs, a season pass, quests, events, timed offers, and an AFK camp. New
job track `G`, ~13 jobs. Full design in `docs/MONETIZATION.md`.

**Why the reversal:** the original plan excluded pets on design-purity grounds — the loop is
tighter without them. That reasoning was correct about craft and wrong about the objective.
The stated goal is a commercially successful game with strong retention, and in this category
the collection layer is the monetization engine and most of the day-6 retention: it's a gacha
loop, it justifies luck and slot SKUs, it gives infinite content without new zones, and it
converts collectors, who spend the most. Excluding it capped the ceiling for aesthetic reasons
the objective doesn't support.

**What kept it from being a bolt-on:** companions carry `cash`/`damage`/`luck` bonuses mapping
onto the three existing upgrade tracks, so they multiply the core loop rather than sitting
beside it. Eggs cost in-game cash, making them the currency sink the economy was missing. The
thematic framing — working animals on an expedition — is native to the setting.

**What did not change:** in-game visual restraint, no paywalled content, no PvP, no trading, no
direct Robux loot boxes, server-authoritative everything. The architecture absorbed this with
no structural change — every new system is a service feeding the single multiplier assembly
point that already existed.

**Blast radius:** GDD §7–10, ECONOMY §5/§5b/§5c/§7, ARCHITECTURE §4–6 (schema, services,
remotes), new `docs/MONETIZATION.md`, new `tasks/G-growth.md`, board.

---

### D-008 · 2026-08-13 · ACCEPTED · Store-page work moves to the front

**Decision:** Icon and thumbnail creative (was `R2`, scheduled last) becomes `G1` and runs
before M1 finishes. Six candidates each, not one.

**Why:** on Roblox, store-page CTR gates everything downstream — a game nobody clicks earns
nothing regardless of build quality. It was the highest-leverage item on the board and it was
scheduled where there'd be no time to iterate.

**Corollary — the restraint split:** in-game visual restraint stays; it's the differentiator.
The store page is a different surface with a different job, competing in a grid of loud
thumbnails at 250px. Loud there, quiet in-game. This is a deliberate inconsistency and is
documented in `ART_BIBLE` so nobody "fixes" it.

**Blast radius:** ART_BIBLE, board ordering, R2 (now a follow-through on G1).

---

### D-009 · 2026-08-13 · ACCEPTED · Studio-native workflow. Supersedes D-002 and D-005.

**Decision:** Roblox Studio is the source of truth. Team Create for human collaboration,
the Roblox Studio MCP server for agent work. No Rojo, no file-based sync. Git keeps a
one-directional snapshot of scripts for history and rollback only — it is a backup, never a
source (job `P7`).

**Why the reversal:** D-002 rested on one claim — that agents cannot author in Studio, so a
file-based project was the only way to make the job board assignable. A Studio MCP server is
now connected, and that claim is false. Verified against the live instance: read the game
tree, read and create and edit scripts (`multi_edit`), run Luau (`execute_luau`), capture the
viewport, start and stop playtests, generate meshes and materials, insert and upload assets.
That is a complete authoring surface. Every argument D-002 made follows from a premise that
no longer holds.

**What this improves, beyond unblocking Team Create:**
- **The mesh pipeline risk is gone.** D-006 flagged Higgsfield-GLB → Blender → FBX → Open
  Cloud as the only genuinely unproven step in the plan. `generate_mesh` and
  `generate_material` are native to the MCP, and `insert_asset` reaches the marketplace. P3
  shrinks from a multi-stage conversion pipeline to a direct call, and Blender is no longer
  a dependency.
- **Hand-built worlds.** D-005 generated the map from config purely because agents could not
  drag parts. A human doing level design in Studio produces a better map than a config table
  ever will. Zone building moves to Studio; `Config/Zones.luau` keeps only the gameplay data
  (unlock costs, spawn counts, tiers), not geometry.
- **A tighter agent loop.** Edit a script, run it, screenshot the result, playtest — all in
  the live datamodel, no build step.

**What is genuinely lost:** version control. Team Create has no diff, no branches, no revert
beyond coarse place-level history. `P7` recovers most of it by snapshotting scripts out of
Studio into git on a schedule.

**New risk this introduces:** Team Create's script locking protects humans from each other.
It does **not** protect against two agents editing the same script, because MCP edits go
straight into the datamodel — no merge, no warning, last write wins. The track ownership
split in `WORKFLOW.md` is now the only thing preventing that collision, which raises its
importance considerably.

**Blast radius:** ARCHITECTURE §1/§2/§7, AUTOMATION channel 1, WORKFLOW §2/§5/§8, F1–F4,
P1/P3/P6, new P7, C2/C3, D-006's open risk (now closed).

---

### D-010 · 2026-08-13 · ACCEPTED · Hybrid: Rojo authors, Studio MCP verifies

**Decision (Dionis's call).** Files are the source of truth again. All scripting and editing
happens in `src/` through Rojo. The Roblox Studio MCP is kept, but **only for verification and
inspection** — playtesting, console output, screenshots, read-only `execute_luau`. Authoring
tools (`multi_edit`) are not used.

Partially supersedes D-009: its Studio-as-source-of-truth clause is reversed. Its
world-building clause survives — geometry is still hand-built in Studio (see below).

**Why:** MCP authoring is measurably more expensive per operation. `search_game_tree` at depth
2 returned ~60 entries, nearly all built-in services (`TimerService`, `CookiesService`,
`HeatmapService`) — noise we paid for. `Grep`/`Glob` answer the same question for a fraction,
the file tools carry no extra schema cost, and there is no per-call `studio_id` boilerplate.

**Why not pure Rojo:** verification still needs the engine. F2 caught three real defects by
running checks in Studio. Dropping the MCP entirely moves those catches to a human playtest,
or nowhere. Keeping it read-only is strictly better than either extreme.

**The rule that keeps them from fighting:** scripts flow **one direction only, files →
Studio**. Nobody edits a script in Studio; Rojo overwrites it on the next sync, silently and
with no history.

**Cost:** Team Create is off again for scripts — Rojo and Team Create genuinely conflict.
Geometry is still hand-built, so world work is coordinated through the WorkLog, not git.

**Migration:** F1 and F2's nine scripts ported out of Studio into `src/`, verified
byte-for-byte with a djb2 hash against the live datamodel. Seven matched exactly. Three
differed by a total of 8 bytes — two blank lines and two comment-separator dashes, zero
semantic difference — confirmed by inspection rather than assumed. `Config`, `Types`, and
`Remotes` are unchanged; only their location moved.

**Adopted from PR #1:** `rokit.toml`, `.luaurc`, `selene.toml`, `stylua.toml`,
`scripts/check.sh`. Dionis's scaffold turned out to be exactly what the hybrid needs, so the
work that D-009 invalidated is now in use.

**Changed from his `default.project.json`:** the server and client bootstraps map as explicit
files rather than directory `init.*.luau` markers, so `Services`/`Controllers` stay siblings of
the bootstrap instead of nesting under it. That preserves the datamodel paths already
documented in ARCHITECTURE §2 and used throughout the job packets.

**Verified:** `rojo build` produces a 37KB place from the ported tree.

**Note on churn:** this is the third foundation change before any gameplay code exists
(D-002 → D-009 → D-010). Each flip has cost real work — PR #1 the first time, a port the
second. The tooling question is now settled; the next reversal should require a stronger
argument than the last two did.

**Blast radius:** ARCHITECTURE §1–2, AUTOMATION channel 1, WORKFLOW §2/§5/§6/§8, F1/F4
packets, P1/P4/P7, board.

---

### D-011 · 2026-08-13 · ACCEPTED · React Lua + Wally for UI. Partially supersedes D-002.

**Decision (Dionis's call).** UI is built in React Lua (`jsdotlua/react` 17.2.0 and
`jsdotlua/react-roblox` 17.2.0), installed by Wally, previewed in Studio through the UI Labs
storybook plugin (`pepeeltoro41/ui-labs` 2.3.2, a dev-dependency). The studded kit imported
from Figma via FigBloxUI is ported to components under `src/client/UI/`.

This reverses one clause of D-002 — "no Roact, no Wally" — which D-010 left standing when it
restored the rest of the file-based workflow. Nothing else in D-002 changes: the two-phase
loader still owns startup, and UI mounts from a normal controller (`UIController`) under the
same `Init`/`Start` contract as every other client module.

**Why:** the Figma import arrives as a dead instance tree. FigBlox emitted 144 nested Frames
in `StarterGui` with every button as a non-interactive `Frame`, sizes carrying rounding noise
(`UDim2.new(-0.0015, 307, 0.0006, 86)`), a `UIScale` of 0.3719 baked to whatever fit the
Studio viewport that day, and near-identical geometry repeated per instance. It is not
maintainable by hand and it is not diffable, so it fails the same test D-002 applied to
Studio-authored code. Porting it to components makes it reviewable, gives the buttons real
`Activated` events, and replaces the frozen `UIScale` with one computed from the viewport.

**Why a framework rather than plain Instance construction:** the argument in D-002 was version
drift between workers. Wally answers that directly — `wally.toml` pins exact versions and
`wally.lock` is committed, so every worker resolves identical trees. The remaining cost is
that reviewers must know React; the gain is that UI Labs hot-reloads a component in about a
second, against a build-and-playtest loop measured in tens of seconds. UI is the one area of
this project where iteration count dominates, which is why the trade lands differently here
than it did for services.

**What this does NOT change:** services, controllers, the loader, the remote contract, the
data schema. React is confined to `src/client/UI/**`. No other track picks up a dependency.

**Blast radius:** ARCHITECTURE §1–2, `default.project.json`, `scripts/check.sh` (now needs
`wally install` before `rojo build`), README, and job `B1` — whose packet still specifies
"No reactivity framework; binding is `State.Observe`". B1 now binds React props from
`State.Observe` rather than writing to instances directly; the state layer itself is
unchanged.

**Cost, stated plainly:** this is the fourth foundation change before gameplay code exists
(D-002 → D-009 → D-010 → D-011), and D-010 closed by saying the next reversal should carry a
stronger argument than the last two. This one is narrower than those — it touches one folder
rather than the whole authoring model, and it is additive, since nothing was built on the
banned clause. That is the argument; it is not a blank cheque for a fifth.

**Verified:** all 23 UI modules require cleanly in the live datamodel; `rojo build` produces a
place; a solo playtest mounts the HUD, opens the shop from three entry points and closes it,
with no errors on the client.

---

### D-012 · 2026-08-14 · ACCEPTED · Add `funnelSteps` to the profile schema

**Decision:** add `funnelSteps = {}` to the profile template (ARCHITECTURE §4).

**Why:** ANALYTICS §3's onboarding funnel requires each milestone to fire **exactly once
per player, ever**. A session-scoped guard re-fires every one of them on every rejoin, so
`first_sell` would be counted thousands of times and the funnel silently becomes a
measure of how often people rejoin. The guard has to survive a session, which means it
has to live on the profile.

**Blast radius:** additive only. `ProfileStore:Reconcile()` backfills it for existing
players on their next load, so there is no migration and no version bump. Nothing reads
it except `AnalyticsService`.

**Not replicated.** It stays server-side — the client has no use for it and every
replicated field is one more thing an exploiter can reason about.

---

### D-013 · 2026-08-14 · ACCEPTED · Analytics carries 3 custom fields, not 5

**Decision:** custom fields on analytics events are `zone`, `payer`, and `progress` —
three, not the five ANALYTICS §6 originally specified.

**Why:** Roblox's `Enum.AnalyticsCustomFieldKeys` has exactly three members
(`CustomField01/02/03`). The doc asked for five (`zone`, `rebirths`, `multiplier`,
`isPayer`, `playtimeMinutes`), which the platform cannot carry. Verified against the live
enum rather than assumed.

**Which three, and why those:** ANALYTICS §7's stated purpose for segmentation is
questions like *"conversion is 0.4% for players who never reached Zone 2 and 9% for those
who did"* — that needs **zone** and **payer**. The third slot goes to a coarse
**progress** bucket (rebirth count), which is the next most useful cut and subsumes what
`playtimeMinutes` would have told us. `multiplier` is recoverable from economy events.

**Blast radius:** ANALYTICS §6 corrected; `AnalyticsService` only.

---

### D-014 · 2026-08-14 · ACCEPTED · Blocky studded geometry, restrained palette

**Decision (Gedeon's call).** Assets are built as **assembled Parts in the chunky studded
Roblox idiom** — the silhouette language of *Steal a Brainrot* and its neighbours — while
keeping ART_BIBLE §2's restrained Antarctic palette and §1's sparse prop density.
**Loud shapes, quiet colours.**

This withdraws one sentence from ART_BIBLE §1: *"an Antarctic ad-game, not a Roblox
simulator... if a screenshot could be mistaken for Pet Simulator, it's wrong."* The **shape**
language may now be mistaken for one. The **colour** language may not.

**Why:** two reasons, and the first is already sitting in the repo.

1. **The UI shipped this way.** C1's `Theme.luau` is built explicitly as "the three-layer
   studded look" with stud-texture overlays on every control. The document was out of date,
   not the work.
2. **Blocky studded geometry is what the audience reads as a Roblox game.** The
   differentiator was never the geometry — it is the palette and the emptiness. Both survive
   this change unchanged.

**What changes — and this is the P3 decision, made here rather than deferred:**
- **Part assembly is the default** for props, tools and creatures. `generate_mesh` returns
  smooth organic single forms with no studs, which is the wrong idiom under this decision;
  it becomes the exception (organic shapes that blocks genuinely cannot express), not the rule.
- ART_BIBLE §1 rules 1–2, §2 preamble and §4 creature spec updated to match.

**What explicitly does NOT change:**
- **The palette (§2).** Two-colour-plus-accent per zone stands, unaltered.
- **Prop density (§1 rule 1).** ≤ 8 props per 100×100 studs stands. Emptiness is still the style.
- **The store-page inversion (§0).** Still loud there — now differently loud.

**This is not the fifth foundation reversal D-011 warned about.** D-002 → D-009 → D-010 →
D-011 were all changes to the authoring model. This one touches no code, no config, no type,
no remote, and no tooling — it is an art-direction call, and `src/` is untouched by it.

**Blast radius:** `ART_BIBLE.md` §1/§2/§4; jobs C4, C5, C7, G6 and P3; `assets/**`.

**Handoff to C1 (Dionis):** `Theme.Color.Cash` is `RGB(0, 255, 9)` and `Theme.Color.Bundle`
is `RGB(255, 246, 0)`. Neither exists in the §2 palette — and under this decision the palette
is precisely the half that was kept. Nearest tokens are `aurora #4FE0A8` and `gold #F2B035`.
Flagged, not changed: `src/client/UI/**` is C1's and the work is uncommitted.

---

### D-015 · 2026-08-14 · ACCEPTED · Hitbox combat replaces the ProximityPrompt

**Decision (Gedeon's call).** There is no prompt and no keypress. A box is carried in front
of the character (`GameConfig.HitboxSize`, offset `HitboxForwardOffset`), and every live
creature inside it is struck once per `SwingCooldown`. **Full cleave** — all creatures in the
box take damage, bounded by `MaxCleaveTargets` (8).

Supersedes GDD §2's "Hold the ProximityPrompt (or click) to swing."

**Why:** it is the genre-native control scheme, and tapping E on each of 25 cubs is friction
the player never asked for. Walking into a crowd and watching it melt is the core pleasure of
this category.

**The remote contract does NOT change.** `RequestSwing(creature: Model)` still means "I am
swinging, and here is roughly what at." Every server check in ARCHITECTURE §3 still applies.
No RFC was needed on `Remotes.luau` — only `GameConfig` gained keys.

**The cleave is server-side, and that is the security-relevant part.** The obvious
implementation — client sends one `RequestSwing` per creature it overlaps — fails twice: six
bears would fire six remotes in a frame and trip the `budget = 10, perSeconds = 1` rate limit,
and it would let a crafted client nominate its own victim list. Instead the client names one
creature, and `CombatService` rebuilds the hitbox from the character's **server-side CFrame**
and picks the targets itself. The client's nomination is a cadence hint, never a list.

The zone gate is re-checked **per struck creature**, not just the nominated one. Without that,
cleave becomes the way to farm a locked zone from across its border.

**Economy consequence — this is a real cost, stated plainly.** One swing now yields up to 8
kills' worth of drops instead of 1. `ECONOMY.md` §4's pacing table and the 90-second
time-to-first-sell target (§7 rule 5, a release blocker) were both computed against
single-target swings and are now wrong. **This is a D1 input, and V1 must re-measure it.**
The cap exists so the worst case is a known 8x rather than unbounded.

**Monetization: `autoswing` must be re-scoped.** `Products.luau` sells Auto-Swing at 399
Robux — *"Swing for you while in range"* — which the base game now does for free. That SKU
has nothing left to sell and is the 4th-priciest pass. Re-scope it to sell **speed and reach**
instead (halved cooldown, wider box), which is what this genre's comparables actually charge
for and which the player feels continuously rather than only while idle. Damage is already
sold through the `harpoon` upgrade track, so speed and reach are unclaimed.

**Not yet done — carried as open work:**
- `Products.luau` / `MONETIZATION.md` §4: the Auto-Swing re-scope above.
- Pack-full feedback. The prompt used to read `PACK FULL`; with no prompt there is nowhere to
  say it. **Handoff to B3** — the HUD is now the only place that can.

**Blast radius:** `GameConfig` (additive), `CombatService`, `CreatureService` (new
`GetAliveInBox`), `HarvestController` (rewritten), GDD §2/§6, ARCHITECTURE §6, ECONOMY §4/§7,
MONETIZATION §4, jobs B2 (superseded), A5, V1, D1.

---

### D-016 · 2026-08-14 · ACCEPTED · Auto-swing is a 10-minute trial, then a pass, with a toggle

**Decision (Gedeon's call).** Swinging is **tap-per-swing** by default. Auto-swing — the
hitbox firing on cooldown with no input — is granted free for the first **10 minutes** of a
player's lifetime, after which it requires the `autoswing` gamepass. Either way the player can
turn it **on and off** with a toggle, persisted in `settings`.

**Supersedes D-015's monetization clause only.** D-015 re-scoped `autoswing` to sell speed and
reach, because the base game had made automation free. That is withdrawn: automation is
monetized again and the SKU's existing copy — *"Swing for you while in range"* — is literally
true once more. Everything else in D-015 stands, including the hitbox, the server-side cleave,
and the economy consequence.

**Why a trial rather than a demo screenshot:** the player has to feel the difference. Ten
minutes of frictionless play followed by tapping for every cub is a far stronger conversion
argument than any store copy, and it front-loads the good experience during the window where
D1 retention is decided.

**Why tap-per-swing and not hold-to-swing** (the option not taken): maximum contrast. Hold is
comfortable enough that the pass stops feeling necessary, which would leave the trial with
nothing to sell.

**Schema:** one additive field, `settings.autoSwing = true` (the toggle). **No new field is
needed for the trial** — it derives from the existing `firstJoinAt` plus
`GameConfig.AutoSwingTrialSeconds`, which keeps it a timestamp comparison and honours §4's
rule that nothing stores remaining time. `ProfileStore:Reconcile()` backfills the setting, so
there is no migration and no version bump (same pattern as D-012).

**Wall-clock, not playtime.** The trial expires 10 minutes after first join, whether or not
the player is online. Playtime-based would be fairer, but it needs a new accumulator and a
tick, and the urgency of a wall-clock window is part of what makes a trial convert. Noted as
a D1 tuning input if it proves too harsh.

**Contract change — `RequestSetting`:** a new RemoteFunction,
`(key: string, value: boolean) -> (ok, reason?)`, server-validated against an allow-list of
settable keys. Needed here for the toggle, and B9's settings menu needs exactly this remote
rather than one-off remotes per switch.

**Replicated additions:** `autoSwing` (is it active *right now* — trial or pass, AND toggled
on) and `autoSwingTrialEndsAt` (so the HUD can count the trial down, which is the conversion
moment).

**Enforceability, stated honestly.** Auto-swing **cannot be enforced** against a crafted
client. `RequestSwing` carries intent only, so the server cannot tell "held the button" from
"sent one every 0.6s". Rate limits and `SwingCooldown` already cap the *rate*, so an exploiter
gains no damage advantage over a legitimate pass holder — they get the convenience free. This
is inherent to the genre; the pass sells convenience to honest players. A12 should not waste
effort trying to close it.

**Blast radius:** `Remotes.luau` (new function — CONTRACT CHANGE), `GameConfig` (additive),
`DataService` TEMPLATE, `StateService` REPLICATED, `HarvestController`, ARCHITECTURE §3/§4,
GDD §2/§7, MONETIZATION §4, jobs B3 (the toggle button + trial countdown), A13 (real gamepass
ownership — stubbed to `false` until then), B9.

---

<!-- Add new decisions below this line -->
