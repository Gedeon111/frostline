# Job Board — FROSTLINE

**Status values:** `TODO` · `IN-PROGRESS` · `REVIEW` · `BLOCKED` · `DONE` · `SUPERSEDED`

**Current design authority:** D-017. The corrected product is eight private stores around one
shared hunting wilderness. The first playable loop is hunt → visible carry → refrigerator →
customer → register → counter cash → proximity collection → upgrade.

## Resume here — architecture reset, 2026-08-14

The existing code proves data loading, currency, creatures, validated combat, state replication,
upgrades, and analytics. It does **not** prove the intended game. Instant sell pads, the trader,
harpoons, and five-zone progression are legacy.

Do not start a corrected-slice implementation job until `F5` lands. The checked-in shared Luau
contract is still v1; ARCHITECTURE §3–4 describes the approved v2 target.

Next order:

1. Review and merge this architecture-reset branch.
2. Run `F5`: shared types/remotes/config plus v1→v2 profile migration and contract tests.
3. Build/validate the eight-plot world contract while server foundations adapt.
4. Land carry + refrigerator authority before customers.
5. Land customers before register/cash.
6. Add visible motion and one worker proof.
7. Run the one-player slice, then eight-player fairness/performance, then the human feel check.

## Reuse and retirement audit

| Existing work | Decision |
|---|---|
| DataService | reuse with v2 migration |
| CurrencyService | reuse unchanged; remains the only spendable-cash writer |
| StateService | adapt to v2 replicated state |
| InventoryService | adapt from pack to carry |
| CreatureService | reuse spawn/HP; adapt drops to variant-preserving meat ids |
| CombatService | reuse validation/cleave; read axe track |
| UpgradeService | adapt tracks to axe/carrier/fridge/register |
| AnalyticsService | reuse emitter; replace funnel events |
| Net and client State | reuse, then update after F5 |
| HarvestController | reuse D-015/D-016 control design; update names/state |
| EffectsController | reuse combat effects |
| React UI kit | reuse |
| SellService | **retired**; never route around the store loop |
| ZoneService | removed from corrected M1; reconsider later |
| A10 harpoon ToolService branch | **do not merge**; replace with axe packet |
| Trader NPC | **cancelled** |
| Shelf-Ice sell-pad world packet | **superseded** |

## F · Contract reset

| ID | Job | Owner | Depends | Status |
|---|---|---|---|---|
| F5 | V2 contracts, configs, profile template/migration, contract tests | Architect + Server | D-017 | TODO |

## M1 · Corrected vertical slice

Target: eight assignable plots and one complete player-owned-store loop with saving.

### Server

| ID | Job | Owns | Depends | Status |
|---|---|---|---|---|
| A15 | StateService v2 replication | `StateService.luau` | F5 | TODO |
| A16 | InventoryService carry adaptation | `InventoryService.luau` | F5, A21 | TODO |
| A17 | PlotService assignment and marker validation | `PlotService.luau` | F5, C8 | TODO |
| A18 | StoreInventoryService fridge/reservations | `StoreInventoryService.luau` | F5, A16, A21 | TODO |
| A19 | CreatureService meat-id/shared-ground adaptation | `CreatureService.luau` | F5, C9 | TODO |
| A20 | CombatService axe-track adaptation | `CombatService.luau` | F5, A19, A21 | TODO |
| A21 | UpgradeService v2 tracks | `UpgradeService.luau` | F5 | TODO |
| A22 | CustomerService state machine | `CustomerService.luau` | A17, A18, C10 | TODO |
| A23 | RegisterService checkout/ledger | `RegisterService.luau` | A17, A18, A21, A22 | TODO |
| A24 | CashPickupService ledger projection/collection | `CashPickupService.luau` | A17, A23 | TODO |
| A25 | WorkerService: one stocker proof | `WorkerService.luau` | A17, A18, A21 | TODO |
| A26 | ToolService axes | `ToolService.luau` | F5, A20, C11 | TODO |
| A27 | Analytics funnel adaptation | `AnalyticsService.luau` | A18, A23, A24 | TODO |

CurrencyService is intentionally absent: no change is required unless F5's typed award-source
contract forces a narrow update, which F5 must own explicitly.

### Client

| ID | Job | Owns | Depends | Status |
|---|---|---|---|---|
| B10 | State mirror v2 | client `State.luau` | F5, A15 | TODO |
| B11 | Harvest axe + Auto-Swing preservation | `HarvestController.luau` | F5, A20, B10 | TODO |
| B12 | Visible carrier/rack controller | `CarryController.luau` | B10, C11 | TODO |
| B13 | Store transfer and cash-flight effects | `StoreEffectsController.luau` | F5, B10, C11 | TODO |
| B14 | Corrected HUD and guidance | HUD controller/components | B10, UI kit | TODO |
| B15 | Axe/carrier/fridge/register shop | shop controller/screen | A21, B10, UI kit | TODO |
| B16 | Worker computer UI | worker controller/screen | A25, B10, UI kit | TODO |

Combat EffectsController and the React UI kit remain reusable work; their owners must rebase
only after this reset is merged.

### World and art

| ID | Job | Owns | Depends | Status |
|---|---|---|---|---|
| C8 | Eight plot shells + exact marker contract | `Workspace.World.Plots` | F5 | TODO |
| C9 | Shared snowy hunting wilderness + fair entrances | `Workspace.World.HuntingGround` | F5 | TODO |
| C10 | Refrigerator/register/customer routes + counter | plot fixture geometry | C8 | TODO |
| C11 | Axe, carrier, meat, customer, worker assets | asset folders from ARCHITECTURE §2 | F5 | TODO |
| C12 | Store-loop art integration audit | corrected M1 world/assets | C8–C11, B12, B13 | TODO |

### QA and validation

| ID | Job | Depends | Status |
|---|---|---|---|
| E4 | Pure v2 inventory/reservation/ledger/migration tests | F5, A16, A18, A23 | TODO |
| E5 | Customer cancellation, profile unload, double-pay exploit tests | A22–A24, E4 | TODO |
| V3 | One-player corrected slice in Studio | all corrected M1 except V4/V5 | TODO |
| V4 | Eight-player plot fairness, isolation, and performance | V3 | TODO |
| V5 | Human feel check: hunt, unload, queue, checkout, pickup | V3 | TODO |

## M2 · Store depth

| ID | Job | Depends | Status |
|---|---|---|---|
| A28 | Cashier worker | A25, A23 | TODO |
| A29 | Hunter worker with capped meat production | A25, A18, A19 | TODO |
| A30 | Customer archetypes and basket config | A22, V3 | TODO |
| A31 | Additional meat/creature tiers in shared wilderness | A19, V3 | TODO |
| B17 | Full worker management UI | A28, A29, B16 | TODO |
| B18 | Store customization UI | C12 | TODO |
| B20 | SoundController for combat/store transactions | B13, C15 | TODO |
| B21 | Camera and movement feel | B11, B13 | TODO |
| C13 | Finished settlement/shop fronts | C12, V4 | TODO |
| C14 | Finished hunting terrain and landmarks | C9, V4, A31 | TODO |
| C15 | Audio assets | V3 | TODO |
| C16 | M2 art integration audit | C13–C15, B20, B21, E6 | TODO |
| D6 | Store economy tuning simulation | V3, V4 | TODO |
| E6 | Full worker/customer performance pass | A28–A31, B20, C13–C15, D6 | TODO |

## M3 · Meta and commercial validation

| ID | Job | Depends | Status |
|---|---|---|---|
| D7 | Rebirth RFC for store + workers | D6, V5 | TODO |
| D8 | Companion RFC against corrected loop | D6 | TODO |
| D9 | Additional monetization RFC | V5, D6, analytics | TODO |
| A32 | Anti-cheat/red-team pass | all M2 | TODO |
| A33 | Daily/playtime retention systems | D6, A27 | TODO |
| A34 | Approved rebirth implementation | accepted D7 | TODO |
| A35 | Approved commercial additions | accepted D9 | TODO |
| B19 | Settings/accessibility completion | B14, B20 | TODO |
| E7 | Device/performance hardening | all approved M2/M3 | TODO |
| E8 | Economy/exploit regression suite | A32, approved meta | TODO |
| V6 | Human meta feel check | approved M3 | TODO |

Auto-Swing implementation/entitlement is part of F5 plus B11 and remains the only approved paid
corrected-slice feature.

## M4 · Release

| ID | Job | Depends | Status |
|---|---|---|---|
| R1 | Full QA progression and save/rejoin test | all approved M3 | TODO |
| R2 | Store-page assets based on finished store loop | C13, C14 | TODO |
| R3 | Product, moderation, privacy, and publish checklist | R1, R2 | TODO |
| R4 | Soft-launch telemetry and 72-hour go/no-go | R3 | TODO |

## Critical path

```text
D-017 → F5 → carry/fridge → plot → customer → register → cash → V3 → V4/V5 → M2 depth
                    world C8/C9 ────────────────┘
```

## Release-driving measures

1. Joins reaching first counter collection.
2. Time from refrigerator stock to first checkout.
3. Players who begin another hunt after collecting cash.
4. Eight-plot travel fairness and state isolation.
5. D1 retention.
6. Auto-Swing trial-to-pass conversion without damage to the free funnel.
