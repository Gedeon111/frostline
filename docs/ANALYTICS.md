# Analytics & Funnel Spec — FROSTLINE

The build spec for job `A14`. Every event below is server-fired and server-authoritative.
A client never reports its own progress.

## 1. Use Roblox's built-in AnalyticsService

Roblox ships an `AnalyticsService` with native funnel support, surfaced in the Creator
Dashboard. No backend, no HTTP, no cost. Relevant methods:

```lua
LogOnboardingFunnelStepEvent(player, step, stepName)
LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName)
LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku)
LogCustomEvent(player, eventName, value, customFields)
```

**Verify these signatures against current Roblox docs before implementing** — this API has
changed since introduction, and getting an argument order wrong produces silently empty
dashboards rather than an error.

Our wrapper service is *also* called `AnalyticsService`, which collides with the engine
service name. Alias it at the top of the file (`local RbxAnalytics = game:GetService(...)`)
and don't rename ours — every job packet already references it.

**Optional later:** mirror events to an external endpoint via `HttpService` for custom
queries. Ship behind `GameConfig.AnalyticsExternal`, default off. Don't build this for launch.

## 2. Two classes of event — handle them differently

| | Milestone events | Stream events |
|---|---|---|
| Example | `first_sell`, `zone_unlocked` | `cash_awarded`, `egg_hatched` |
| Volume | once per player, ever | thousands per player per session |
| Sampling | **never sample** | batch, aggregate, sample if needed |
| Purpose | the funnel — where players quit | economy balance — where cash goes |
| Fired from | the service that owns the milestone | `CurrencyService` / `EggService` |

Conflating these is the classic mistake: sampling milestone events destroys the funnel, and
sending every stream event unbatched destroys performance.

## 3. The onboarding funnel — the one that matters

Fired via `LogOnboardingFunnelStepEvent`. Steps are ordered and each fires **exactly once per
player, ever.**

| Step | Name | Fired by | Fires when |
|---|---|---|---|
| 1 | `joined` | DataService | profile loaded, character spawned |
| 2 | `first_kill` | CombatService | first creature killed |
| 3 | `first_sell` | SellService | first successful sell |
| 4 | `first_upgrade` | UpgradeService | first upgrade purchased |
| 5 | `first_hatch` | EggService | first egg hatched |
| 6 | `zone_2` | ZoneService | Glacier Ridge unlocked |
| 7 | `first_rebirth` | RebirthService | first rebirth |

**Idempotency is the whole game here.** Guard on a persisted profile flag
(`funnelSteps[stepName] = true`), not a session variable. A session guard double-counts every
rejoin and silently inflates your funnel until the numbers are meaningless.

Add `funnelSteps = {}` to the profile schema — file it in the `G2` schema RFC so it lands with
the other growth fields rather than as a separate migration.

## 4. Session funnel — retention

Fired via `LogFunnelStepEvent` with a per-session `funnelSessionId`.

| Step | Name | Fires when |
|---|---|---|
| 1 | `session_start` | join |
| 2 | `sold_once` | first sell this session |
| 3 | `offer_shown` | Starter Pack surfaced |
| 4 | `offer_purchased` | Starter Pack bought |
| 5 | `session_5min` | 5 minutes elapsed |
| 6 | `session_20min` | 20 minutes elapsed |

**D1/D7 retention are not events.** They're derived by comparing `firstJoinAt` against
subsequent `session_start` timestamps. Don't try to fire a `d1_return` event — you'd have to
guess the boundary, and the dashboard computes it correctly from session data already.

## 5. Economy events — where cash comes from and goes

Fired via `LogEconomyEvent` from **exactly two call sites**: `CurrencyService.Award` and
`CurrencyService.Spend`. Those functions already take a `source` / `sink` string (job `A3`) —
that string becomes the `itemSku`.

**Sources:** `sell`, `daily`, `quest`, `season`, `playtime_chest`, `code`, `group_reward`,
`afk_camp`, `product_purchase`, `starter_pack`

**Sinks:** `upgrade_pack`, `upgrade_boots`, `upgrade_harpoon`, `zone_unlock`, `egg_<id>`,
`fusion`

Every event carries `endingBalance`, which lets you reconstruct the whole economy without
tracking state yourself.

**The question this answers:** `docs/ECONOMY.md` §7 rule 7 requires eggs absorb 60–70% of
lifetime cash. Summing sinks by category is the only way to know whether that's true. If eggs
are at 30%, currency is inflating and upgrades have stopped mattering — a problem invisible
from any other data.

## 6. Custom events — monetization detail

Via `LogCustomEvent`, with these custom fields on **every** event:

```lua
{ zone = "glacier_ridge", payer = "free", progress = "rebirth_2" }
```

**Three, not five (D-013).** `Enum.AnalyticsCustomFieldKeys` has exactly three members —
verified against the live enum. `zone` and `payer` are the two §7 actually needs; the
third is a coarse progress bucket. `multiplier` is recoverable from economy events.

Those fields are what let you segment. "Conversion is 3%" is nearly useless; "conversion
is 0.4% for players who never reached Zone 2 and 9% for those who did" tells you exactly where
to spend effort.

| Event | Value | Extra fields |
|---|---|---|
| `egg_hatched` | rarity index | `eggId`, `companionId`, `luckApplied` |
| `product_purchased` | robux | `productId`, `productName` |
| `gamepass_purchased` | robux | `passId` |
| `quest_claimed` | reward | `questId`, `kind` |
| `boost_activated` | duration | `boostId` |
| `pack_full_idle` | seconds | fires when a full pack sits unsold > 30s |

That last one is a diagnostic, not a milestone: a player standing around with a full pack
doesn't know where to sell. If it's common, the `HudController` sell arrow (job `B3`) isn't
working, and no other event would ever reveal that.

## 7. The three numbers reviewed daily at soft launch

Per `docs/MONETIZATION.md` §7:

1. **% of joins reaching `first_sell`** — under 80% means the opening is broken and every
   number below it is polluted. Fix this before reading anything else.
2. **D1 retention** — target 30%+. This is the discovery algorithm's input, so it gates
   traffic, which gates everything.
3. **Starter Pack conversion** — target 3–5% of D1 players.

## 8. Rules

- **Server-side only.** A client that lies or disconnects mid-event corrupts the dataset.
- **Never block gameplay on analytics.** Every call is wrapped in `pcall` and fired in a
  separate thread. An analytics outage must never cost a player their sell.
- **Batch stream events.** Never one call per cash award.
- **No personally identifying data.** User IDs only — no names, no chat, nothing typed.
- **Ship it before launch, not after.** Retrofitting a funnel means the first week of data —
  the most valuable week you will ever have — is gone permanently.
