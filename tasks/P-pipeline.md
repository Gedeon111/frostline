# P — Automation Pipeline

The jobs that make every other job shippable without a person in the loop. `P1` and `P2` run
in parallel with M0 and should finish before M2's asset work starts.

Read `docs/AUTOMATION.md` before any packet here.

---

### [P1] Test harness inside Studio

**Owner:** Architect · **Depends on:** F1 · **Channel:** 1

**You own:** `ServerStorage.Tests.*`

**Build:**
- A small spec runner as a ModuleScript (`describe` / `it` / `expect`, ~80 lines). Don't
  vendor TestEZ — this needs to be callable from a single `execute_luau` string.
- `ServerStorage.Tests.RunAll` — requires every sibling spec, runs it, returns a formatted
  pass/fail summary as a string so the result comes straight back through `execute_luau`.
- One smoke spec proving the harness works: boot the server bootstrap, assert every service
  `Init`s, return `OK`.
- Document the one-liner other jobs use to run tests, in the handoff notes.

**Done when:**
- [ ] `execute_luau` returning `require(...Tests.RunAll)()` prints a readable summary
- [ ] A deliberately failing assertion shows up as a failure (verify, don't assume)
- [ ] Specs run in `Edit` mode where possible so no playtest is needed for pure logic
- [ ] Full run under 10s

**Out of scope:** integration tests needing a live server (P4), publishing (P6).

**Note:** this job used to install `run-in-roblox` and write a Studio plugin. D-009 removed
both — `execute_luau` does what the plugin was for, directly.

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

### [P3] Asset generation conventions

**Owner:** World · **Depends on:** F1 · **Channel:** 1

**You own:** `ReplicatedStorage.Assets` structure + `docs/specs/asset-pipeline.md`

**Build:**
- Establish and document how assets get made, now that `generate_mesh`,
  `generate_material`, `generate_procedural_model`, `search_asset` and `insert_asset` are
  native. Decide per asset class which to use — generated mesh, marketplace insert, or plain
  part assembly — and write it down so C4/C5/G6 don't each re-decide.
- Prove the loop once end to end: generate one creature mesh from the ART_BIBLE §4 prompt,
  place it under `ReplicatedStorage.Assets.Creatures`, assemble it into a Model with a
  PrimaryPart and emissive eye parts, `screen_capture` it from 100 studs, confirm it reads
  as a bear in silhouette.
- Write the naming convention and the part/tri budget check as an `execute_luau` snippet
  other jobs can reuse.

**Done when:**
- [ ] One creature mesh exists in `Assets.Creatures` and passes the 100-stud silhouette check
- [ ] The budget-check snippet reports part and tri counts for any model path
- [ ] `docs/specs/asset-pipeline.md` states which tool to use for which asset class, and why
- [ ] Re-running does not duplicate assets

**Note:** this job was Higgsfield-GLB → Blender → FBX → Open Cloud upload, and D-006 flagged
it as the biggest unproven risk in the plan. D-009 closed that: mesh generation is native to
the Studio MCP, so there is no conversion and no upload. Blender is no longer a dependency.
Higgsfield is now only for the icon and store thumbnails (G1, R2).

---

### [P4] Integration tests during play

**Owner:** QA · **Depends on:** P1, and each service as it lands · **Channel:** 1

**You own:** `ServerStorage.Tests.Integration.*`

**Build:** the tests `E1` structurally cannot do — they need a running server, so they run
under `start_stop_play` with `execute_luau` against the `Server` datamodel: profile save/load
round-trip on a test DataStore, two simulated players with independent state, creature
spawn/kill/respawn over 60 seconds, sell-pad region detection, purchase → effect application,
zone barrier enforcement, memory over a compressed session.

Read failures back with `get_console_output`.

**Done when:**
- [ ] Each M1 service has at least one integration test
- [ ] The suite runs from one `execute_luau` call and reports pass/fail per case
- [ ] Test DataStore keys are namespaced and cleaned up after each run
- [ ] It catches a deliberately introduced regression (prove it, don't assert it)

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
      `UserOwnsGamePassAsync` check via `execute_luau` during play
- [ ] API access is confirmed enabled by an actual DataStore write from Studio
- [ ] Screenshots of the finished game page are attached to the PR
- [ ] Each runbook is specific enough to re-execute without re-deriving the UI

**Note:** this job operates a real account and spends real configuration. Confirm before
creating paid products or flipping the game public — those are outward-facing and hard to
undo.

---

### [P6] Release checklist

**Owner:** Architect · **Depends on:** P1, P4, P5, P7 · **Channel:** 1 + 2

**You own:** `docs/release-checklist.md`

**Build:** publishing is now Studio's own **File → Publish**, so this is a gate, not a script.
Write the ordered checklist and the `execute_luau` snippet that verifies each item:

1. `P7` snapshot committed and pushed — never publish un-snapshotted code
2. Unit suite green (`Tests.RunAll`)
3. Integration suite green under play (P4)
4. No `print`/`warn` outside the `Log` util with `Debug` off
5. Every asset ID in Config resolves (no zeros)
6. Place settings confirmed via Open Cloud (P5): API access on, streaming on, max players
7. Then publish, and confirm the new version through the Open Cloud version list rather than
   the dashboard's word for it

**Done when:**
- [ ] The checklist runs top to bottom and each item has an objective check
- [ ] A deliberately broken item (a zeroed asset ID) is caught by the verification snippet
- [ ] Publishing is never something an agent does on its own initiative — it's a gate you
      clear and the human triggers

---

### [P7] ~~Git snapshot~~ — **CANCELLED by D-010**

Scripts live in `src/` under git again, so there is nothing to snapshot out of Studio. Normal
branches, commits, and PRs replace this entirely (WORKFLOW §6).

The gap it was going to cover and git still doesn't: **`Workspace` geometry has no version
control.** It's hand-built in Studio and isn't in the repo. If that starts hurting, the answer
is periodic `.rbxl` exports, not a script snapshotter — file a new job then.

It earned its keep before being cancelled, though: D-010's migration used exactly the
mechanism this job described, which is what made porting nine scripts out of Studio an hour's
work instead of a rewrite.
