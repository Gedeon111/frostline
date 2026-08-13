# Automation Channels

Everything in this project — code, 3D models, audio, icons, uploads, Studio runs, place
publishing, storefront setup — is done by an agent. There is no manual-work track.

Four channels cover it. Every job packet names which one it uses.

## Channel 1 — Local toolchain (verified present on this machine)

```
Studio    C:\Users\eebi9\AppData\Local\Roblox\Versions\version-*\RobloxStudioBeta.exe
plugins   C:\Users\eebi9\AppData\Local\Roblox\Plugins\
rojo      C:\Users\eebi9\.aftman\bin\rojo.exe
rokit     C:\Users\eebi9\.rokit\bin\rokit.exe
git, node, python  on PATH
```

**What it does:** source → place file (`rojo build`), live sync (`rojo serve`), and — once
`run-in-roblox` is installed via rokit — **headless Studio execution**: launch Studio with a
place and a Luau script, run it inside the real engine, capture output, exit. That is a full
integration-test loop with no human in it.

**Studio plugins are just `.lua` files in a folder.** An agent writes one, drops it in the
plugins directory, and Studio runs it on next launch. Bulk in-Studio operations (mesh import,
prop placement, asset auditing, place-wide fixups) are scriptable this way.

**Not installed yet, install in P1:** `run-in-roblox`, `lune`, and Blender (headless CLI, for
format conversion — see P3).

## Channel 2 — Roblox Open Cloud API (needs one API key)

HTTP, `x-api-key` header, callable from `curl` / node / python.

| Capability | Endpoint | Use |
|---|---|---|
| Upload asset | `POST apis.roblox.com/assets/v1/assets` | meshes, images, audio |
| Poll upload | `GET apis.roblox.com/assets/v1/operations/{id}` | moderation result + asset ID |
| Publish place | `POST apis.roblox.com/universes/v1/{u}/places/{p}/versions?versionType=Published` | ship a `.rbxl` |
| DataStores | `apis.roblox.com/datastores/v1/...` | inspect/repair live player data |
| Universe info | `apis.roblox.com/cloud/v2/universes/{u}` | place config reads |

This is the backbone: **build → upload assets → write IDs into config → rebuild → publish**
is a single scripted pipeline (job P6).

**Two setup facts to confirm in P1, not assume:**
- The API key is created once on the creator dashboard. An agent can drive that through
  Channel 3, but it touches account security — if 2FA prompts, hand the browser back for the
  code, then continue.
- Audio uploads may require the account to be ID-verified. If the Assets API rejects audio,
  P3 falls back to Roblox's own audio library (free, pre-moderated, and honestly fine for the
  18 assets this game needs).

## Channel 3 — Chrome MCP (`mcp__claude-in-chrome__*`)

Drives a real logged-in browser session against `create.roblox.com`. Covers everything Open
Cloud has no endpoint for:

- Creating the Open Cloud API key itself
- **Gamepasses and developer products** — creation, pricing, icons (no Open Cloud endpoint)
- Game page: title, description, genre, thumbnails, icon
- Place settings: max players, streaming, API access, permissions
- Badge creation
- Reading analytics and moderation status

Rules from the harness apply: `tabs_context_mcp` first, new tab per task, never trigger a
JS dialog, stop and ask after 2–3 failed attempts rather than looping.

## Channel 4 — Generative MCP (Higgsfield, Canva)

| Need | Tool |
|---|---|
| Creature/prop concept art, UI icons, game icon | `generate_image` / `generate_image_batch` |
| **Image → 3D mesh (GLB)** | `generate_3d` |
| SFX, ambient music | `generate_audio` / `generate_audio_batch` |
| Thumbnail compositing, marketing layouts | Canva `generate-design` / `edit-design` |
| Background removal, upscaling, reframing | `remove_background`, `upscale_image`, `reframe` |

Batch tools + `jobs_wait` exist — fire all 5 creature tiers at once, collect in one call.
Do not generate serially.

**The one real unknown:** `generate_3d` returns GLB. Roblox's 3D importer is FBX/OBJ-first.
P3 resolves this by installing Blender and converting headlessly
(`blender --background --python convert.py`) — a 15-line script, done once, reused for every
mesh. Confirm the pipeline end-to-end on one test mesh before generating all five tiers.

## The pipeline, end to end

```
  Higgsfield ──▶ .glb ──▶ Blender CLI ──▶ .fbx ──▶ Open Cloud Assets API ──▶ asset ID
      (C4)                    (P3)                        (P2)                  │
                                                                                ▼
  src/ ──▶ rojo build ──▶ .rbxl ──▶ run-in-roblox (tests) ──▶ Open Cloud publish
   (all code jobs)         (P1)          (P4)                      (P6)
                                                                    │
  Chrome MCP ──▶ gamepasses, product IDs, game page ─────────────────┘
      (P5)
```

## What still needs you

Two things, both one-time, both ~5 minutes:

1. **Being logged into Roblox in Chrome** so Channel 3 has a session. If a 2FA code appears,
   type it.
2. **A judgement call on feel.** An agent can verify the game is correct, runs at 60 FPS, and
   has no exploits. It cannot tell you whether a 0.6s swing feels good. Play it for ten
   minutes after M1 and answer the five questions in `tasks/M1-vertical-slice.md` → `[V1]`.

Everything else is a job on the board.
