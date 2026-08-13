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

<!-- Add new decisions below this line -->
