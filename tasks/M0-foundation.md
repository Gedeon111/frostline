# M0 — Foundation

Everything blocks on these four. Do them in order, one worker (the Architect). Hand each
`### [ID]` block to the worker as its entire opening message.

---

### [F1] Repo scaffold & toolchain

**Owner:** Architect · **Depends on:** — · **Blocks:** everything

**Read first:** `README.md`, `docs/ARCHITECTURE.md` §1–2

**You own:** `rokit.toml`, `default.project.json`, `selene.toml`, `stylua.toml`, `.luaurc`,
`.gitignore`, `scripts/check.sh`, `src/**` (empty placeholder dirs with `.gitkeep`)

**Build:**
- `rokit.toml` pinning: `rojo 7.4+`, `selene 0.27+`, `stylua 0.20+`, `run-in-roblox 0.3+`
- `default.project.json` mapping exactly the tree in ARCHITECTURE §2:
  `src/shared → ReplicatedStorage.Shared`, `src/server → ServerScriptService.Server`,
  `src/client → StarterPlayer.StarterPlayerScripts.Client`,
  `src/world → ServerScriptService.World`, `assets → ReplicatedStorage.Assets`,
  plus a `ReplicatedStorage.Remotes` folder placeholder
- `.luaurc` with `"languageMode": "strict"`
- `selene.toml` using the `roblox` std, warn on unused, error on undefined global
- `stylua.toml`: 4-space indent, 100 col, double quotes
- `scripts/check.sh` running stylua --check, selene, and `rojo build -o /tmp/out.rbxlx`
- A `src/server/init.server.luau` and `src/client/init.client.luau` that each print one
  boot line, so the project builds and runs from commit one

**Done when:**
- [ ] `rokit install && ./scripts/check.sh` exits 0 on a clean clone
- [ ] `rojo build -o Hunt.rbxlx` produces a place file
- [ ] Every directory in ARCHITECTURE §2 exists
- [ ] `.gitignore` covers `*.rbxlx`, `*.rbxl`, `/build`, `.DS_Store`

**Out of scope:** any gameplay code, any Config content, CI pipelines.

---

### [F2] Shared contracts — Types, Remotes, Config

**Owner:** Architect · **Depends on:** F1 · **Blocks:** every code job

This is the single highest-leverage job on the board. Six workers will code against it in
parallel. Take the time.

**Read first:** `docs/ARCHITECTURE.md` §3–4 (frozen contract), all of `docs/ECONOMY.md`

**You own:** `src/shared/Types.luau`, `src/shared/Remotes.luau`, `src/shared/Config/*.luau`

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
- `Zones.luau` — 5 zones: `id`, `displayName`, `unlockCost`, `creatureTier`, `population`,
  `origin` + `size` (world-space bounds), `spawnArea`, `sellPads`, `lighting` block from
  ART_BIBLE §3
- `Upgrades.luau` — 3 tracks, each with `baseValue`, `perLevel` or `growth`, `maxLevel = 10`,
  and a **`costs` array of 9 literal integers** transcribed from ECONOMY §2. Do not compute
  costs at runtime — a formula drifts from the design doc, a literal table cannot.
- `Tools.luau` — 4 harpoon models mapped to upgrade levels 1/4/7/10
- `Products.luau` — all 19 SKUs from `docs/MONETIZATION.md` §4 as **names and effects with
  `id = 0` placeholders**; `P5` fills in real IDs after creating them on the dashboard

`Companions.luau` and `Eggs.luau` are **not** part of this job — they land in `G2`, which also
files the profile-schema RFC for the growth fields. Leave room for them; don't invent them.

**Done when:**
- [ ] Every number in `docs/ECONOMY.md` appears in exactly one Config file
- [ ] Every Config table is typed against `Types.luau` and passes strict mode
- [ ] `Upgrades.costs` sums match the totals stated in ECONOMY §2 (53,629 / 127,750 / 170,581)
- [ ] Remote list matches ARCHITECTURE §3 exactly — no extras, no omissions
- [ ] A one-line comment above every table pointing at its doc section
- [ ] You post the frozen contract diff on the board and announce the freeze

**Out of scope:** any behaviour. These files contain data and types only — no functions
beyond pure lookups like `Upgrades.GetCost(track, level)`.

---

### [F3] Core utilities

**Owner:** Architect · **Depends on:** F1 · **Runs parallel with F2**

**You own:** `src/shared/Util/*.luau`

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

**You own:** `src/server/init.server.luau`, `src/client/init.client.luau`,
`src/server/Services/Net.luau`, `src/client/Controllers/Net.luau`

**Build:**
- Both bootstraps: require every ModuleScript in the sibling `Services`/`Controllers` folder,
  call `.Init()` on all (pcall-wrapped, log failures loudly), then `.Start()` on all. Log
  total boot time. A service failing `Init` must not prevent the others from starting.
- `server/Net.luau`: creates every remote from `shared/Remotes.luau` into
  `ReplicatedStorage.Remotes` during `Init`. Exposes
  `Net.On(name, handler)` / `Net.Fire(player, name, ...)` / `Net.FireAll(name, ...)`.
  **Every inbound handler is wrapped in a rate limiter** (per-player, per-remote budget from
  `GameConfig`) and a pcall. Reject silently, log on the server.
- `client/Net.luau`: `WaitForChild`s the folder, exposes `Net.Fire(name, ...)`,
  `Net.Invoke(name, ...)` with a 10s timeout, `Net.On(name, handler)`.

**Done when:**
- [ ] Server boots with zero services present and logs cleanly
- [ ] Every remote in `Remotes.luau` exists under `ReplicatedStorage.Remotes` at runtime
- [ ] A handler that throws does not kill the remote or the server
- [ ] Rate limiting is applied centrally — **no individual service ever writes a rate check**
- [ ] Client `Net.Invoke` on a dead remote rejects after timeout instead of hanging

**Out of scope:** any game logic. This is plumbing.
