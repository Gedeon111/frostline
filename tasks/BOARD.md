# Job Board — FROSTLINE

**Status values:** `TODO` · `IN-PROGRESS` · `REVIEW` · `BLOCKED` · `DONE`
Update **only your own row's status column**. Packets live in `tasks/*.md`.

Parallelism is expressed by the `Depends` column: **any two jobs with satisfied dependencies
can run simultaneously** — they own disjoint files by construction.

Every job here is an agent job. The `Ch` column names the automation channel from
`docs/AUTOMATION.md`: **1** local toolchain/Studio · **2** Open Cloud API · **3** Chrome MCP ·
**4** generative MCP. Exactly one item on this board needs you: **V2**, ten minutes of
playtesting to answer whether the swing feels good.

---

## G · Growth — companions, monetization depth, retention

The commercial layer. `G1` runs **now**, before M1 finishes. Design in `docs/MONETIZATION.md`.

| ID | Job | Owner | Ch | Depends | Status |
|---|---|---|---|---|---|
| G1 | **Store-page hypothesis** — 6 icons, 6 thumbnails, 64px check | Architect | 4,3 | — | TODO |
| G2 | Companion + egg config, hatch tables, schema RFC | Architect | — | F2 | TODO |
| G3 | `CompanionService` — equip, slots, fusion, index, bonuses | Server | 1 | G2, A1 | TODO |
| G4 | `EggService` — weighted rolls, luck, limited windows | Server | 1 | G2, G3 | TODO |
| G5 | Companion client — follow, hatch reveal, index UI | Client | 1 | G3, G4, C1 | TODO |
| G6 | ~40 companion models via the P3 pipeline | World | 4,1,2 | P3, G2 | TODO |
| G7 | `OfferService` — Starter Pack, daily deals, timers | Server | 1 | A13 | TODO |
| G8 | `SeasonService` — 30-tier pass, free + premium tracks | Server+Client | 1 | A13, G3 | TODO |
| G9 | `QuestService` — 3 daily, 3 weekly | Server+Client | 1 | A14, G8 | TODO |
| G10 | Events + potion boosts (expiry timestamps, not durations) | Server+Client | 1 | A13 | TODO |
| G11 | AFK Camp — idle earning at ~15% | Server+Client | 1 | A6, A8 | TODO |
| G12 | Store UI — 19 SKUs, offers, **live multiplier readout** | Client | 1 | B5, G7, G8, G10 | TODO |
| G13 | Social hooks — group reward, friend bonus | Server+Client | 1 | A1, G3 | TODO |

---

## P · Automation pipeline — run alongside M0/M1

| ID | Job | Owner | Ch | Depends | Status |
|---|---|---|---|---|---|
| P1 | Toolchain + headless Studio harness (`run-in-roblox`, dev plugin) | Architect | 1 | F1 | TODO |
| P2 | Open Cloud client: API key, asset upload, ID sync into config | Architect | 2,3 | F1 | TODO |
| P3 | Generative asset pipeline: image → GLB → FBX → upload | World | 4,1,2 | P2 | TODO |
| P4 | Integration test suite inside real Studio | QA | 1 | P1 | TODO |
| P5 | Storefront: universe, gamepasses, products, place settings, badges | Architect | 3 | P2 | TODO |
| P6 | `ship.ps1` — build → test → upload → publish, plus CI | Architect | 1,2 | P1,P2,P5 | TODO |

---

## M0 · Foundation — everything blocks on this (~1 sitting, sequential)

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| F1 | Repo scaffold, rokit toolchain, Rojo project, lint/format config | Architect | — | TODO |
| F2 | Shared contracts: Types, Remotes, Config tables from ECONOMY.md | Architect | F1 | TODO |
| F3 | Core utils: Signal, Trove, RateLimiter, Format, TableUtil | Architect | F1 | TODO |
| F4 | Two-phase loader + Net wrappers (server & client) | Architect | F2, F3 | TODO |

## M1 · Vertical slice — one zone, one bear, full loop, saving

Target: a player can join, kill cubs, fill a pack, sell, buy 3 upgrades, rejoin and keep it all.

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| A1 | `DataService` — ProfileStore, schema, migration, leaderstats, autosave | Server | F4 | TODO |
| A2 | `StateService` — profile→client diff replication at 10Hz | Server | A1 | TODO |
| A3 | `CurrencyService` + `InventoryService` — cash, pack weight, capacity | Server | A1 | TODO |
| A4 | `CreatureService` — spawn from zone config, HP table, respawn, drops | Server | F4 | TODO |
| A5 | `CombatService` — swing validation, damage, cooldown, range, kill | Server | A3, A4 | TODO |
| A6 | `SellService` — sell zone, payout, pack clear, multiplier hook | Server | A3 | TODO |
| A7 | `UpgradeService` — cost curve, purchase validation, effect application | Server | A3 | TODO |
| B1 | Client bootstrap, `Net`, `State` mirror | Client | F4 | TODO |
| B2 | `HarvestController` — prompt binding, hold-to-swing, target tracking | Client | B1, A5 | TODO |
| B3 | `HudController` — cash, pack bar, zone label, sell arrow | Client | B1, C1 | TODO |
| B4 | `EffectsController` — hit flash, particles, floating numbers, hitstop | Client | B1, C1 | TODO |
| C1 | UI kit — `Ui.luau` builder, palette tokens, base components | Client | F1 | TODO |
| C2 | `WorldGen` — Zone 1 blockout, outpost, sell pad, spawn markers | World | F2 | TODO |
| E1 | Test harness + economy/validation unit tests | QA | F2, F3 | TODO |
| V1 | Automated slice verification — full loop driven in real Studio | QA | all M1, P1 | TODO |
| V2 | **You:** 10-minute feel check, five written answers | You | V1 | TODO |

## M2 · Full content — 5 zones, shop, gating, art

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| A8 | `ZoneService` — unlock validation, barriers, membership, teleport | Server | A7, C3 | TODO |
| A9 | Creature tiers 2–5 + golden variant + weighted spawning | Server | A4 | TODO |
| A10 | `ToolService` — harpoon model per level, swing animation | Server | A7 | TODO |
| A11 | Trader NPC — prompt, sell-all interaction, idle head-turn | Server | A6, C5 | TODO |
| B5 | `ShopController` + shop screen (upgrades, zones) | Client | B1, C1, A7 | TODO |
| B6 | `ZoneController` — barrier prompts, unlock confirm, teleport menu | Client | B1, A8 | TODO |
| B7 | `SoundController` — SFX bus, per-zone ambience, music ducking | Client | B1, C6 | TODO |
| B8 | `CameraController` + movement feel, snow footsteps | Client | B1 | TODO |
| C3 | `WorldGen` zones 2–5 + per-zone lighting transitions | World | C2 | TODO |
| C4 | Creature models: generate → convert → upload → assemble → animate | World | P3 | TODO |
| C5 | Outpost props, trader model, harpoon models | World | P3 | TODO |
| C6 | Audio generation + upload (Roblox library fallback) | Client | P2 | TODO |
| C7 | Art integration audit — in-engine screenshots, asset/part budgets | World | C3–C6 | TODO |
| D1 | Economy tuning pass + simulation script | Economy | E1, V1, V2 | TODO |

## M3 · Meta, monetization, hardening

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| A12 | `AntiCheat` — rate limits, distance/teleport sanity, arg validation | QA + Server | all M2 | TODO |
| A13 | `MonetizationService` — gamepass cache, receipts, multiplier assembly | Server | A6, P5 | TODO |
| A14 | `AnalyticsService` — typed events, funnel, economy sources/sinks | Server | A1 | TODO |
| D2 | Rebirth system + rank display | Server + Client | A7, A8 | TODO |
| D3 | Daily reward ladder + playtime chests | Server + Client | A1, B5 | TODO |
| D4 | Global leaderboard (OrderedDataStore) + in-world boards | Server + World | A1, C2 | TODO |
| D5 | Codes redemption system | Server + Client | A1, B5 | TODO |
| B9 | Settings menu (music/sfx), codes input | Client | B5 | TODO |
| E2 | Performance pass — streaming, part budget, profiling | QA | all M2 | TODO |
| E3 | Exploit test checklist + red-team pass | QA | A12 | TODO |

## M4 · Release

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| R1 | QA test plan + full progression run | QA | all M3 | TODO |
| R2 | Game page: title, copy, icon, 3 thumbnails | Architect | C7, P5 | TODO |
| R3 | Publish checklist — place config, badges, moderation review | Architect | R1, P6 | TODO |
| R4 | Soft-launch tuning loop — 72h retention/funnel review | Economy | R3, A14 | TODO |

---

## Critical path

```
code      F1 → F2 → F4 → A1 → A3 → A5/A6/A7 → V1 → C3 → A8 → B5 → A12 → E3 → R1 → R3
assets         P2 → P3 → C4 ────────────────────────┘
growth    G1 ──────────────  G2 → G3 → G4 → G5 → G12 ──┘
harness        P1 → P4                                      P5 → P6 ──────────────┘
```

Four lanes, run them together. Serialization risks, in order:

1. **F2** — the contract freeze. One worker, done properly. Six workers code against it.
2. **P3** — the mesh pipeline is the only genuinely unproven step in this plan. Prove it on
   one asset early, not during M2.
3. **G3/G4** — companions feed the multiplier stack that `SellService` already calls. Land
   them before G12 or the store has nothing to display.
4. **V1** — nothing in M2 starts before the slice is confirmed to actually work.

**G1 has no dependencies and gates the most revenue. Start it today.**

## Rough sizing — 67 jobs

| Track | Jobs | Est. | Bottleneck |
|---|---|---|---|
| G | 13 | ~5 days | G6's 40 companion models; G1 blocks nothing but delays everything |
| P | 6 | ~2 days | API key + the GLB→FBX→Roblox hop |
| M0 | 4 | ~1 day | F2 quality, not speed |
| M1 | 16 | ~4 days | — |
| M2 | 14 | ~5 days | C4's five sequential pipeline stages |
| M3 | 10 | ~4 days | live-account operations in P5 |
| M4 | 4 | ~1 day | moderation turnaround on uploads |

**Day one, in parallel: `G1` (store page), `F1` (scaffold), `P2` (Open Cloud).** G1 gates
revenue, P2 gates every asset, F1 gates every code job.

## The three numbers this all exists to move

Per `docs/MONETIZATION.md` §7 — reviewed daily during soft launch, and the only real verdict
on whether any of this worked:

1. **% of joins reaching first sell** — under 80% means the opening is broken
2. **D1 retention** — target 30%+, this is the discovery algorithm's input
3. **Starter Pack conversion** — target 3–5% of D1 players
