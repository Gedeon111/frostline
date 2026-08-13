# P — Automation Pipeline

The jobs that make every other job shippable without a person in the loop. `P1` and `P2` run
in parallel with M0 and should finish before M2's asset work starts.

Read `docs/AUTOMATION.md` before any packet here.

---

### [P1] Toolchain + headless Studio harness

**Owner:** Architect · **Depends on:** F1 · **Channel:** 1

**You own:** `rokit.toml` (extension), `scripts/studio.ps1`, `scripts/itest.ps1`,
`tools/plugin/HuntDevPlugin.lua`

**Build:**
- Add `run-in-roblox` and `lune` to `rokit.toml`, `rokit install`, verify both resolve.
- `scripts/itest.ps1` — build the place with rojo, run a Luau script inside real Studio via
  `run-in-roblox`, capture stdout, exit non-zero on failure. This is the integration-test loop
  that `E1`'s unit tests can't cover (DataStores, workspace, Players).
- Write one smoke test proving the harness works: boot the server bootstrap, assert every
  service `Init`s, print `OK`, exit.
- `tools/plugin/HuntDevPlugin.lua` — a Studio plugin installed by copying into
  `%LOCALAPPDATA%\Roblox\Plugins\`. Toolbar buttons for: regenerate world, dump workspace
  part counts, list unassigned asset IDs, clear test DataStore keys. Agents use this for bulk
  in-Studio operations they'd otherwise be unable to perform.
- `scripts/studio.ps1` — launch Studio on the built place for a visual check.

**Done when:**
- [ ] `./scripts/itest.ps1` runs end to end from a clean clone and exits 0
- [ ] A deliberately failing assertion makes it exit non-zero (verify, don't assume)
- [ ] The plugin loads in Studio and every button works
- [ ] Total harness runtime < 90s

**Out of scope:** CI, publishing (P6).

---

### [P2] Open Cloud client + asset upload pipeline

**Owner:** Architect · **Depends on:** F1 · **Channel:** 2, with 3 for key creation

**You own:** `tools/cloud/*.mjs`, `docs/specs/opencloud.md`, `.env.example`

**Build:**
- Obtain an API key. Use Chrome MCP against `create.roblox.com/dashboard/credentials`:
  create a key scoped to `asset:read`, `asset:write`, `universe.place:write`,
  `universe-datastores:*`, IP `0.0.0.0/0`, and store it in `.env` (gitignored). If a 2FA
  prompt appears, stop and ask for the code rather than retrying.
- `tools/cloud/upload.mjs` — takes a local file + asset type, does the multipart POST to
  `apis.roblox.com/assets/v1/assets`, polls the returned operation until moderation
  resolves, prints the asset ID. Handle: rate limits (backoff), moderation rejection
  (report clearly, don't retry), and duplicate uploads (hash-cache in
  `tools/cloud/.uploaded.json` so re-runs don't re-upload).
- `tools/cloud/sync-ids.mjs` — takes the upload manifest and **writes the resulting asset IDs
  into `src/shared/Config/`** (`Audio.luau`, `Tools.luau`, creature model refs). This closes
  the loop: generate → upload → config → build, no hand-editing.
- `docs/specs/opencloud.md` — document every endpoint used, its scopes, its failure modes.

**Done when:**
- [ ] One test image uploads and returns a real asset ID, proven in the PR output
- [ ] An audio upload is attempted and the result recorded — **if it's rejected for
      verification, say so plainly and note the Roblox-library fallback**; do not fake it
- [ ] Re-running upload on an unchanged file is a no-op
- [ ] `sync-ids.mjs` round-trips: change a file → upload → config contains the new ID
- [ ] `.env` is gitignored and `.env.example` documents every variable

---

### [P3] Generative asset pipeline (image → mesh → Roblox)

**Owner:** World · **Depends on:** P2 · **Channel:** 4 → 1 → 2

**You own:** `tools/assetgen/*`, `scripts/convert.py`

**Build:**
- Install Blender (headless is fine) and write `scripts/convert.py` — a Blender Python script
  run as `blender --background --python convert.py -- in.glb out.fbx` that imports GLB,
  applies scale, sets the origin to the model's base, decimates to the tri budget from
  `docs/ART_BIBLE.md` §4, and exports FBX.
- `tools/assetgen/pipeline.mjs` — one command per asset: Higgsfield `generate_image` (concept,
  from the ART_BIBLE prompt) → `generate_3d` (GLB) → Blender convert (FBX) → P2 upload →
  asset ID → config. Batch mode for the 5 creature tiers at once.
- **Prove it on one asset before generating anything else.** The GLB→FBX→Roblox path is the
  only genuinely unverified step in this whole plan.
- If Roblox's importer accepts GLB directly, delete the Blender step and say so.

**Done when:**
- [ ] One creature mesh goes prompt → in-game, verified via a `run-in-roblox` script that
      loads it and asserts part count and bounding box
- [ ] Tri/part budgets from ART_BIBLE §4 are enforced by the pipeline, not by hope
- [ ] Batch mode produces all 5 tiers in one run
- [ ] The pipeline is idempotent — re-running doesn't duplicate assets

---

### [P4] Integration test suite in real Studio

**Owner:** QA · **Depends on:** P1, and each service as it lands · **Channel:** 1

**You own:** `tests/integration/*.luau`

**Build:** the tests `E1` structurally cannot do, run inside real Studio via P1's harness:
profile save/load round-trip against a test DataStore, two simulated players with independent
state, creature spawn/kill/respawn over 60 simulated seconds, sell-pad region detection,
purchase → effect application, zone barrier enforcement, and a memory check over a compressed
session.

**Done when:**
- [ ] Each M1 service has at least one integration test
- [ ] The suite runs from one command and reports pass/fail per case
- [ ] Test DataStore keys are namespaced and cleaned up after each run
- [ ] It catches a deliberately introduced regression (prove it in the PR)

---

### [P5] Storefront & place configuration via browser

**Owner:** Architect · **Depends on:** P2 · **Channel:** 3

**You own:** `tools/dashboard/*.md` (recorded procedures), `Config/Products.luau` IDs

**Build:** drive `create.roblox.com` to do what Open Cloud can't:
- Create the universe + place if they don't exist; record universe and place IDs into `.env`
- Create the 4 gamepasses and 3 dev products from `docs/GDD.md` §7, with prices and icons
  from P3, and **write the real IDs into `src/shared/Config/Products.luau`** (the one
  sanctioned exception to Architect-owns-Config — IDs only)
- Place settings: max players 16, `StreamingEnabled`, **Studio Access to API Services on**
  (the classic launch-day failure), HTTP requests on
- Game page: title, description, genre, icon, 3 thumbnails from R2
- Badges for first sell, each zone unlock, first rebirth
- Record each procedure as a short markdown runbook so it can be re-run or repaired

**Done when:**
- [ ] Every gamepass and product exists with a real ID in config, verified by a live
      `UserOwnsGamePassAsync` check from `run-in-roblox`
- [ ] API access is confirmed enabled by an actual DataStore write from Studio
- [ ] Screenshots of the finished game page are attached to the PR
- [ ] Each runbook is specific enough to re-execute without re-deriving the UI

**Note:** this job operates a real account and spends real configuration. Confirm before
creating paid products or flipping the game public — those are outward-facing and hard to
undo.

---

### [P6] Build → test → publish pipeline

**Owner:** Architect · **Depends on:** P1, P2, P5 · **Channel:** 1 + 2

**You own:** `scripts/ship.ps1`, `.github/workflows/ci.yml`

**Build:**
- `scripts/ship.ps1`: lint → format check → unit tests (E1) → `rojo build` → integration
  tests (P4) → upload any changed assets (P2) → sync IDs → rebuild → publish the `.rbxl` via
  Open Cloud → print the place version and URL. Any failure aborts before publish.
- A `--dry-run` flag that does everything except the publish call. Default to dry-run;
  publishing requires an explicit flag.
- CI workflow running lint + unit tests on every PR. Integration tests and publish stay
  local — they need Studio and a real key.

**Done when:**
- [ ] `./scripts/ship.ps1 --dry-run` passes from a clean clone
- [ ] A failing unit test blocks the publish step (prove it)
- [ ] A real publish produces a new place version, confirmed by fetching the version list
- [ ] Publishing is never the default action of any script
