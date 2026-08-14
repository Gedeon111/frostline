# Analytics & Funnel Spec — FROSTLINE

Every gameplay event is server-fired and server-authoritative. A client never reports its own
progress, inventory, checkout value, cash, or worker output.

## 1. Transport

The project wrapper `AnalyticsService` sends onboarding, session, economy, and custom events to
Roblox's analytics API. Verify current engine method signatures against official Roblox
documentation when A27 is implemented; analytics API mistakes can fail silently.

Never block gameplay on analytics. Calls are protected, queued/batched where appropriate, and
fail open without changing a transaction.

## 2. Milestones versus streams

| | Milestone events | Stream events |
|---|---|---|
| Example | `first_fridge_stock`, `first_collection` | `meat_stocked`, `cash_awarded` |
| Frequency | once per player, persisted | repeated during sessions |
| Sampling | never | aggregate/batch |
| Purpose | funnel abandonment | throughput and balance |
| Source | owning server service | domain service/CurrencyService |

Persist milestone guards in `funnelSteps`. A session variable would double-count every rejoin.

## 3. Corrected onboarding funnel

| Step | Name | Owning service | Fires when |
|---:|---|---|---|
| 1 | `joined` | DataService | profile loaded and character available |
| 2 | `plot_assigned` | PlotService | valid unique plot assigned |
| 3 | `first_kill` | CombatService | first creature kill |
| 4 | `first_carry` | InventoryService | first meat enters carry |
| 5 | `first_fridge_stock` | StoreInventoryService | first meat enters refrigerator |
| 6 | `first_reservation` | CustomerService | first customer reserves stock |
| 7 | `first_checkout` | RegisterService | first reservation becomes unclaimed cash |
| 8 | `first_collection` | CashPickupService | first counter cash becomes spendable cash |
| 9 | `first_upgrade` | UpgradeService | first v2 upgrade purchase |
| 10 | `worker_computer_opened` | WorkerService/UI handoff | server validates first owned-computer use |
| 11 | `first_worker` | WorkerService | first worker unlock succeeds |

Steps fire once ever even if later steps occur out of order in test data. The funnel report may
show skipped steps; the services must not fabricate missing events.

## 4. Session funnel

Use a unique server-created session funnel id.

| Step | Name | Fires when |
|---:|---|---|
| 1 | `session_start` | profile loaded |
| 2 | `hunted_once` | first kill this session |
| 3 | `stocked_once` | first refrigerator transfer this session |
| 4 | `checked_out_once` | first completed checkout this session |
| 5 | `collected_once` | first counter collection this session |
| 6 | `repeat_hunt` | first kill after a collection this session |
| 7 | `session_5min` | configured five-minute observation point |
| 8 | `session_20min` | configured twenty-minute observation point |

Return retention is derived from session timestamps; do not guess D1/D7 boundaries in gameplay
code.

## 5. Economy events

Economy events originate only from `CurrencyService.Award` and `CurrencyService.Spend`.
The source/sink argument becomes the SKU/category and every event includes ending balance.

Corrected-slice sources:

- `store_collection`;
- explicitly configured test/admin sources, disabled in production;
- later approved retention or product sources.

Corrected-slice sinks:

- `upgrade_axe`;
- `upgrade_carrier`;
- `upgrade_fridge`;
- `upgrade_register`;
- `worker_unlock_<id>`;
- `worker_upgrade_<id>`.

Checkout is not a spendable-cash source; it changes `unclaimedCash`. Log it as a store custom
event, not a currency award. This distinction detects ledger/award mismatches.

Daily reconciliation metrics:

```text
sum(store checkout value)
- change in unclaimedCash
- sum(store_collection awards)
= expected pending/rounding delta
```

Any unexplained delta is a transaction bug.

## 6. Store stream events

Batch per player/plot and configured interval:

| Event | Value | Useful fields |
|---|---:|---|
| `meat_carried` | item count/weight | meat tier, variant |
| `meat_stocked` | item count/weight | fridge level |
| `customer_reserved` | basket value | customer type |
| `customer_cancelled` | basket value | state/reason |
| `checkout_completed` | resolved value | register level, operator type |
| `cash_collected` | awarded value | pending age bucket |
| `queue_blocked` | blocked seconds | reason |
| `worker_cycle` | units moved/created | worker id/level |
| `auto_swing_trial_state` | state transition | eligible/enabled |

Custom fields stay within the engine-supported field count. Prefer coarse configured buckets over
high-cardinality ids or positions. Never include player-entered text or personal data.

## 7. Diagnostic events

These diagnose unclear or tedious play:

- carry full while outside the owned plot for too long;
- fridge empty while customers are waiting;
- fridge full while carry still has stock;
- stock available with no customer action during onboarding;
- queue blocked while owner is standing in OperatorZone;
- unclaimed cash left on the counter when a player leaves;
- customer/reservation cancelled by profile unload;
- plot assignment failure;
- hunt round-trip bucket by plot id;
- trial expiration followed by session exit.

Durations and thresholds come from analytics config, not literals in services.

## 8. Soft-launch measures

1. joins reaching `first_collection`;
2. median time from `first_fridge_stock` to `first_checkout`;
3. percentage reaching `repeat_hunt`;
4. first-session in-game upgrade and worker unlock rates;
5. plot fairness and assignment failures;
6. D1 retention;
7. Auto-Swing trial-to-pass conversion without funnel harm;
8. checkout-ledger-collection reconciliation.

## 9. Rules

- Server-side events only.
- Milestones persist and never sample.
- Stream events batch; transaction ids prevent duplicate accounting where needed.
- Analytics failure never changes gameplay state.
- No names, chat, free text, or other personal data.
- New feature packets add their event names here before implementation.
- Removed sell/zone/egg events remain historical dashboard data, not active v2 events.
