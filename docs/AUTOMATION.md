# Automation Channels

Everything in this project — code, 3D models, audio, icons, uploads, Studio runs, place
publishing, storefront setup — is done by an agent. There is no manual-work track.

Four channels cover it. Every job packet names which one it uses.

## Channel 1 — Roblox Studio MCP (primary; verified connected)

The main authoring surface. Studio runs live; the MCP server bridges agents into it.

Verified working against place **"hunt for money"** (PlaceId `83234958310651`):

| Tool | Use |
|---|---|
| `list_roblox_studios` | **call first** — every other call needs a `studio_id` |
| `get_studio_state` | current mode (Edit / Client / Server) before acting |
| `search_game_tree` · `inspect_instance` | explore the datamodel |
| `script_read` · `script_grep` · `script_search` | read existing code |
| `multi_edit` | **create and edit scripts** — atomic, multi-edit, creates by className |
| `execute_luau` | run code in Edit / Client / Server; use for tests and bulk operations |
| `start_stop_play` · `get_console_output` | playtest and read errors |
| `screen_capture` | see the viewport, with optional camera placement |
| `generate_mesh` · `generate_material` · `generate_procedural_model` | **native asset generation** |
| `search_asset` · `insert_asset` | pull from the marketplace |
| `upload_image` · `store_image` | image assets |
| `run_as_job` · `subagent` | long-running work |
| `character_navigation` · `user_mouse_input` · `user_keyboard_input` | drive a playtest |

**Rules of use:**
- Always `list_roblox_studios` first. Several instances are commonly open; confirm the target
  is the right place before modifying anything.
- Check `get_studio_state` before a call that needs Client or Server — those datamodels only
  exist during play.
- Two agents must never edit the same script. MCP edits go straight into the datamodel:
  **no merge, no conflict warning, last write wins.** Track ownership in `WORKFLOW.md` §2 is
  the only thing preventing this.

**Still local, still useful:** `git` for the P7 snapshot, `node`/`python` for Open Cloud
scripting. Rojo, rokit, run-in-roblox, and Blender are **no longer needed** — see D-009.

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
| Image → 3D mesh (GLB) | `generate_3d` — **avoid**; use Channel 1's `generate_mesh` for anything in-game |
| SFX, ambient music | `generate_audio` / `generate_audio_batch` |
| Thumbnail compositing, marketing layouts | Canva `generate-design` / `edit-design` |
| Background removal, upscaling, reframing | `remove_background`, `upscale_image`, `reframe` |

Batch tools + `jobs_wait` exist — fire all 5 creature tiers at once, collect in one call.
Do not generate serially.

**Prefer Channel 1's `generate_mesh` for anything going into the game.** It lands directly in
the datamodel with no conversion and no upload step. Higgsfield is for what Studio can't
make: the game icon, store thumbnails, marketing art, and concept references to art-direct
from. The GLB→FBX conversion risk that D-006 flagged is closed — see D-009.

## The pipeline, end to end

```
  generate_mesh / insert_asset ──▶ ReplicatedStorage.Assets ──▶ used by services
        (C4, C5, G6 — Channel 1, no conversion, no upload)

  multi_edit ──▶ scripts in the datamodel ──▶ execute_luau tests ──▶ start_stop_play
   (all code jobs)                              (P4)                     (V1)
        │
        └──▶ P7 snapshot ──▶ git  (history + rollback only, never flows back)

  Higgsfield / Canva ──▶ icon + thumbnails ──▶ Chrome MCP ──▶ game page
        (G1, R2 — Channel 4)                      (P5)

  Chrome MCP ──▶ gamepasses, product IDs, place settings ──▶ Config.Products
        (P5 — Channel 3)
```

## What still needs you

Three things, all small:

1. **Being logged into Roblox in Chrome** so Channel 3 has a session. If a 2FA code appears,
   type it.
2. **A judgement call on feel.** An agent can verify the game is correct, runs at 60 FPS, and
   has no exploits. It cannot tell you whether a 0.6s swing feels good. Ten minutes after M1 —
   job `V2`.
3. **Level design taste.** Agents can place parts, but composing a zone that reads well is
   yours and your collaborator's. That's the part Team Create is actually for.

Everything else is a job on the board.
