# M0 — Foundation

Everything blocks on these four. Do them in order, one worker (the Architect). Hand each
`### [ID]` block to the worker as its entire opening message.

---

### [F1] Datamodel scaffold

**Owner:** Architect · **Depends on:** — · **Blocks:** everything · **Channel:** 1

**Read first:** `README.md`, `docs/ARCHITECTURE.md` §1–2, `docs/DECISIONS.md` D-009

**You own:** the folder structure in the place. Nothing else.

**Status: DONE** — 2026-08-13. Record of what shipped, for anyone reading the board later.

**Built:**
- Full tree per ARCHITECTURE §2: `Shared.{Config,Util}`,
  `Assets.{Creatures,Props,Traders,Tools,Companions}`, `Services`, `Lib`, `Controllers`,
  `UI`, `Workspace.{World,Creatures}`, `ServerStorage.{Tests,WorkLog}`.
- `ServerScriptService.Server` and `StarterPlayerScripts.Client` as two-phase loaders —
  require all, `Init()` all, then `Start()` all, each pcall-wrapped so one bad service can't
  stop the boot.
- `ServerStorage.WorkLog` — the claim protocol (WORKFLOW §2), with `README` carrying the
  rules and `Active()` / `OwnerOf(path)` helpers, plus `F1` as a reference entry.

**Verified:**
- [x] Play test clean: `[boot] server ready — 0 service(s)` / `[boot] client ready — 0 controller(s)`
- [x] WorkLog proven on a **live** claim, not just the empty case — a claimed path returns
      its owner, an unclaimed path returns nil, release leaves nothing behind
- [x] Place was a fresh baseplate; the only pre-existing content was three one-line stubs
      (`Server`, `Shared`, `Client`), all superseded, nothing lost

**Handoffs:** F4 owns the Net wiring inside both bootstraps (they load nothing yet).
F2 owns `Shared.Config` contents — empty by design. P6 must strip `WorkLog` and `Tests`
before release.

---

### [F2] Shared contracts — Types, Remotes, Config

**Owner:** Architect · **Depends on:** F1 · **Blocks:** every code job

This is the single highest-leverage job on the board. Six workers will code against it in
parallel. Take the time.

**Read first:** `docs/ARCHITECTURE.md` §3–4 (frozen contract), all of `docs/ECONOMY.md`

**You own:** `ReplicatedStorage.Shared.Types`, `.Remotes`, and everything under
`.Config` — all ModuleScripts, created with `multi_edit`

**Build:**

`Types.luau` — exported types: `PlayerState`, `ProfileData`, `CreatureTier`, `ZoneDef`,
`UpgradeTrack`, `ToolDef`, `PackContents`, `PurchaseResult`. These are the vocabulary every
other file imports.

`Remotes.luau` — a table of remote **definitions** (name + kind + a comment giving the
signature), exactly matching ARCHITECTURE §3. Not the instances; `Net` creates those in F4.

`Config/` — transcribe `docs/ECONOMY.md` into data:
- `GameConfig.luau` — `SwingCooldown = 0.6`, `SwingRange`, `AutosaveInterval = 60`,
  `StateReplicationHz = 10`, `MaxMultiplier = 250` (see ECONOMY §5 — the cap catches
  exploits, not customers), `Debug`
- `Creatures.luau` — 5 tiers, all ECONOMY §1 columns, plus `modelName`, `respawnSeconds`,
  and the golden variant definition
- `Zones` — 5 zones: `id`, `displayName`, `unlockCost`, `creatureTier`, `population`, and the
  **instance names** of markers the code looks up (`spawnRegion`, `sellPads`, `barrier`),
  plus the `lighting` block from ART_BIBLE §3. **No geometry, no coordinates** — the map is
  hand-built in Studio now (D-009), and these names are the contract between builder and code
- `Upgrades.luau` — 3 tracks, each with `baseValue`, `perLevel` or `growth`, `maxLevel = 10`,
  and a **`costs` array of 9 literal integers** transcribed from ECONOMY §2. Do not compute
  costs at runtime — a formula drifts from the design doc, a literal table cannot.
- `Tools.luau` — 4 harpoon models mapped to upgrade levels 1/4/7/10
- `Products.luau` — all 22 SKUs from `docs/MONETIZATION.md` §4 as **names and effects with
  `id = 0` placeholders**; `P5` fills in real IDs after creating them on the dashboard

`Companions.luau` and `Eggs.luau` are **not** part of this job — they land in `G2`, which also
files the profile-schema RFC for the growth fields. Leave room for them; don't invent them.

**Status: DONE** — 2026-08-13. **CONTRACT IS NOW FROZEN.** Changes require an RFC.

**Verified:**
- [x] All 8 modules require cleanly (`Types`, `Remotes`, 6 × `Config`)
- [x] Cost totals match ECONOMY §2 exactly — 53,629 / 127,750 / 170,581
- [x] `#values == maxLevel` and `#costs == maxLevel-1` on all three tracks
- [x] ECONOMY §7 rule 1 (cash/weight ≥ 2.5x per tier) — **failed at 2.40x, fixed, now 2.53x**
- [x] ECONOMY §7 rule 3 (≤ 8 swings at max harpoon) — worst case Titan at 7
- [x] Zone order 1–5 contiguous, every zone references a real creature tier
- [x] 22 products, all `assetId = 0` pending P5
- [x] 15 remotes, zero name collisions across the three groups

**Three defects caught before any code was written against them:**

1. **`frost_bear` cash/weight was 2.40x, below the 2.5x floor.** ECONOMY §1's table and §7's
   rule 1 contradicted each other — written separately, never cross-checked. `meatValue`
   18 → 19 (6.33 c/w, 2.53x). The data moved rather than the rule, because tier 1→2 is the
   first zone transition a player ever feels.
2. **22 SKUs, not 19.** MONETIZATION §4 collapsed 4 cash packs and 2 egg bundles into single
   rows, then counted rows. Docs corrected everywhere.
3. **`require()` caches across `execute_luau` calls.** The first re-check after fixing #1
   returned the *pre-edit* value with no error. Documented in WORKFLOW §8 with a
   `freshRequire` clone helper. Left undiscovered, this would have silently invalidated
   every verification for the rest of the project.

**Handoffs:** G2 adds `Config.Companions` and `Config.Eggs`. P5 fills real ids into
`Config.Products`. C6 creates `Config.Audio`. F4 owns `Net` and consumes `Remotes.All()`.

**Out of scope (respected):** no behaviour — data, types, and pure lookups only.

---

### [F3] Core utilities

**Owner:** Architect · **Depends on:** F1 · **Runs parallel with F2**

**You own:** `ReplicatedStorage.Shared.Util.*`

**Build:**
- `Signal.luau` — minimal typed signal (`Connect`, `Fire`, `Destroy`). ~60 lines.
- `Trove.luau` — cleanup container: `Add(obj)`, `Connect(sig, fn)`, `Clean()`. Handles
  Instances, connections, functions, tables with `Destroy`.
- `RateLimiter.luau` — token bucket, `Check(key, budget, perSeconds) -> boolean`
- `Format.luau` — `Abbreviate(1234567) -> "1.23M"` (K/M/B/T/Qa/Qi), `Comma(n)`, `Time(s)`
- `TableUtil.luau` — `DeepCopy`, `Diff(old, new)`, `Reconcile(data, template)`
- `Log.luau` — `Log.info/warn/error`, no-ops unless `GameConfig.Debug`

**Done when:**
- [ ] All six modules `--!strict`, zero external dependencies
- [ ] `Format.Abbreviate` handles 0, negatives, and exactly 1000 correctly
- [ ] `TableUtil.Reconcile` fills missing keys from a template without clobbering existing
- [ ] Each module has a `tests/`-ready pure API (no Instance/service access except `Log`)

**Out of scope:** promises, maid variants, anything not listed. Six modules, no more.

---

### [F4] Loader + Net wrappers

**Owner:** Architect · **Depends on:** F2, F3

**You own:** `ServerScriptService.Bootstrap`, `StarterPlayerScripts.Bootstrap`,
`ServerScriptService.Services.Net`, `StarterPlayerScripts.Controllers.Net`

**Build:**
- Both bootstraps: require every ModuleScript in the sibling `Services`/`Controllers` folder,
  call `.Init()` on all (pcall-wrapped, log failures loudly), then `.Start()` on all. Log
  total boot time. A service failing `Init` must not prevent the others from starting.
- `Services.Net`: creates every remote from `Shared.Remotes` into
  `ReplicatedStorage.Remotes` during `Init`. Exposes
  `Net.On(name, handler)` / `Net.Fire(player, name, ...)` / `Net.FireAll(name, ...)`.
  **Every inbound handler is wrapped in a rate limiter** (per-player, per-remote budget from
  `GameConfig`) and a pcall. Reject silently, log on the server.
- `Controllers.Net`: `WaitForChild`s the folder, exposes `Net.Fire(name, ...)`,
  `Net.Invoke(name, ...)` with a 10s timeout, `Net.On(name, handler)`.

**Done when:**
- [ ] Server boots with zero services present and logs cleanly
- [ ] Every remote in `Shared.Remotes` exists under `ReplicatedStorage.Remotes` at runtime,
      verified with `start_stop_play` + `search_game_tree`
- [ ] A handler that throws does not kill the remote or the server
- [ ] Rate limiting is applied centrally — **no individual service ever writes a rate check**
- [ ] Client `Net.Invoke` on a dead remote rejects after timeout instead of hanging

**Out of scope:** any game logic. This is plumbing.
