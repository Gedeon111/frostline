# M3 — Meta, Monetization, Hardening

**Milestone goal:** the game makes money, keeps players, and survives exploiters. Nothing
here is optional for a public Roblox release — an unhardened simulator is farmed within
hours of hitting the front page of any Discord.

---

### [A12] AntiCheat pass

**Owner:** QA + Server · **Depends on:** all of M2

**You own:** `src/server/Services/AntiCheat.luau` + review authority over every remote handler

**Build:**
- Per-remote, per-player token buckets with budgets in `GameConfig` (already plumbed in F4 —
  this job sets real numbers and adds escalation).
- Argument validation for every remote: type, range, instance ancestry (a `Model` argument
  must actually be a descendant of `workspace.Creatures`), and nil-safety. A remote that
  accepts an arbitrary Instance is an exploit.
- Movement sanity: walkspeed above the player's upgrade level + tolerance, teleport distance
  per tick, and noclip through barriers. Flag, don't insta-kick — false positives on bad
  connections cost more than a slow cheater.
- Escalation ladder: log → soft-reject → temporary remote block → kick. Persist a `flags`
  count on the profile (RFC needed for the schema field).
- A written audit: **every** entry in `Remotes.luau`, what it validates, and the exploit it
  prevents. This document is the deliverable as much as the code is.

**Done when:** the audit table covers 100% of remotes; a scripted client that fires every
remote with garbage arguments 1000×/s causes no state corruption, no errors, and gets
rate-limited; cash, pack contents, upgrade levels, and zone unlocks are provably unreachable
from the client except through validated paths.

---

### [A13] MonetizationService

**Owner:** Server · **Depends on:** A6, P5

**You own:** `src/server/Services/MonetizationService.luau`

**Build:** gamepass ownership cached per session (`UserOwnsGamePassAsync` is rate-limited and
will fail — cache, retry with backoff, and fail *closed* on error rather than granting for
free); `ProcessReceipt` for dev products with idempotency (store processed receipt IDs on the
profile — a dropped confirmation must not double-grant); and
`GetCashMultiplier(player)` implementing ECONOMY §5 exactly, capped at 50x. This replaces the
stub from A6.

Products from `Config/Products.luau` (IDs filled by P5). Gamepass purchase prompts from the
shop UI. `PromptGamePassPurchaseFinished` refreshes the cache immediately.

**Done when:** the multiplier formula matches ECONOMY §5 in a unit test across all
combinations; a failed ownership check never grants a pass; the same receipt processed twice
grants once; buying 2x Cash mid-session applies to the very next sell with no rejoin.

---

### [A14] AnalyticsService

**Owner:** Server · **Depends on:** A1

**Read first:** `docs/ANALYTICS.md` — the complete event schema. Build exactly that.

**You own:** `src/server/Services/AnalyticsService.luau`

**Build:** the 7-step onboarding funnel, the 6-step session funnel, economy events from the
two `CurrencyService` call sites, and the custom events in ANALYTICS §6 — all on Roblox's
built-in `AnalyticsService` (verify its method signatures against current docs first; a wrong
argument order yields empty dashboards, not an error).

Two things that will bite if you skip them:
- **Milestone idempotency** must be guarded on a persisted `funnelSteps` profile flag, not a
  session variable. A session guard double-counts every rejoin and quietly ruins the funnel.
- **Stream events must batch.** One call per cash award will cost you frames.

**Done when:** every currency movement carries a source/sink string (grep and prove it); all
7 onboarding steps fire exactly once per player across rejoins and server hops (test this
explicitly); the funnel renders in the Creator Dashboard with real test data; analytics
failures are pcall-isolated and never block a sell; disabling the config flag removes all
overhead.

**Move this earlier if M3 slips.** Retrofitting analytics means losing the first week of live
data, which is the most informative week the game will ever have.

---

### [D2] Rebirth

**Owner:** Server + Client · **Depends on:** A7, A8

**Build:** eligibility (Black Ice unlocked + all tracks at 10), a confirm flow that states
exactly what is lost and gained, the reset transaction (atomic — a failure mid-reset must not
strip upgrades without granting the bonus), `+25%` per rebirth into the multiplier chain, and
a rank display next to the player name and on the leaderboard.

**Done when:** rebirthing is atomic and survives a server crash mid-transaction; the bonus
appears in the next sell; `totalCashEarned` and `stats` survive; rebirthing while ineligible
is refused server-side.

---

### [D3] Daily reward + playtime chests

**Owner:** Server + Client · **Depends on:** A1, B5

**Build:** a 7-day ladder with streak reset on a missed day (use `os.time` server-side, never
client clocks — timezone/clock exploits are the classic bug here); playtime chests every 10
minutes of *active* session; a claim UI that is one button.

Rewards scale with the player's current zone so day 7 isn't worthless at Zone 5 — express
them as a multiple of "one trip's cash at the player's best zone," not flat numbers.

**Done when:** changing the client clock cannot claim early; a claim is idempotent across
double-clicks and rejoins; the streak survives a server restart.

---

### [D4] Global leaderboard

**Owner:** Server + World · **Depends on:** A1, C2

**Build:** `OrderedDataStore` on `totalCashEarned`, updated on a throttle (not per-sell —
that's a datastore budget fire); top 50 fetched every 60s and cached; physical boards in the
outpost showing rank, name, and abbreviated cash.

**Done when:** DataStore request budget stays under 30% at 20 players; boards update without
a rejoin; a player's own rank shows even when outside the top 50.

---

### [D5] Codes system

**Owner:** Server + Client · **Depends on:** A1, B5

**Build:** a codes table in config (code → reward, expiry, one-time-per-player), redemption
validated server-side against `claims.redeemedCodes`, case-insensitive input, typed refusal
reasons (`expired`, `already_redeemed`, `invalid`).

**Done when:** a code cannot be redeemed twice across rejoins or servers; expired codes
refuse cleanly; adding a code is a config edit with no code change.

---

### [B9] Settings menu + codes input

**Owner:** Client · **Depends on:** B5

**Build:** music/SFX toggles, reduced-effects toggle, codes text input, all persisted through
`settings` on the profile. Same visual language as the shop — this is not a place for new UI
patterns.

**Done when:** settings persist across rejoin; toggles take effect within one frame; the menu
adds no persistent HUD element (it opens from the shop screen).

---

### [E2] Performance pass

**Owner:** QA · **Depends on:** all of M2

**Build:** enable `StreamingEnabled` (radius 512) and fix what breaks; audit part counts per
zone against the 20k budget; profile the server at 20 simulated players; find and kill every
per-frame allocation on the client; verify the no-Humanoid rule holds; confirm the effect
pools from B4 actually pool.

**Done when:** server heartbeat ≤ 4ms at 20 players; client ≥ 50 FPS on a 2018 mid-range
phone in Aurora Basin; memory flat over a 30-minute session (no leak in prompts, effects,
sounds, or creature tables); a written before/after profile table in the PR.

---

### [E3] Exploit red-team

**Owner:** QA · **Depends on:** A12

**Build:** a written attack checklist and an actual attempt at each: remote fuzzing, infinite
swing, remote-swing at range, sell without a pad, purchase with insufficient funds via direct
invoke, zone entry without unlock, teleport into a locked zone, instance-argument injection,
receipt replay, code re-redemption, walkspeed/noclip/fly, and profile duplication via rapid
rejoin.

**Done when:** every item is attempted and documented with the result; anything that succeeds
is filed as a blocking bug and fixed before R1; the checklist is committed as
`docs/security-checklist.md` for re-running after every future feature.

---

Monetization setup (gamepass and product creation, real IDs into `Config/Products.luau`) is
job **P5** on the pipeline track, driven through Chrome MCP. `A13` depends on it.
