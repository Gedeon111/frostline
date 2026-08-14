# P — Automation Pipeline

These jobs support the D-017 plan. They may run beside feature work when ownership is disjoint.
Outward-facing account changes still require confirmation.

### [P1] Test runner audit

**Owner:** QA · **Depends on:** F5

Verify the existing pure/integration harness can load v2 shared modules, migrations, and service
tests in the real game context. Preserve one-command reporting and non-zero failure behavior.
Do not claim stateful service coverage from Studio's isolated execute context.

---

### [P2] Open Cloud and environment runbook

**Owner:** Architect · **Depends on:** none

Document universe/place ids, test versus production DataStore separation, API permissions, and
read-only verification commands without committing secrets. Stop at any 2FA prompt or
outward-facing mutation requiring owner approval.

---

### [P3] Asset conventions and budget checks

**Owner:** World/Tech Art · **Depends on:** F5

Update deterministic naming, pivots, attachments, collision, AnimationController, palette, and
part-budget checks for Creatures, Customers, Meat, Tools/Axes, CarryRacks, StoreFixtures,
Workers, and Effects. Provide one reusable Studio validation script.

---

### [P4] Corrected integration tests during play

**Owner:** QA · **Depends on:** P1 and each service as it lands

Run inside the bootstrap/game context. Cover profile v2 round-trip, eight unique plots, shared
creature spawn/kill/respawn, carry→fridge transfer, reservation cancellation, checkout ledger,
counter collection, upgrades, worker pause/cleanup, Auto-Swing trial/toggle, and two-player
state isolation.

Test DataStore keys are namespaced. Do not delete broad or unresolved keys.

---

### [P5] Storefront and place configuration

**Owner:** Architect · **Depends on:** P2, accepted product decision

Configure the place for eight plots and create only approved products. During the corrected
slice, the only approved SKU is the existing 399 R$ Auto-Swing gamepass with its ten-minute
trial. Verify its real id in Config.Products and entitlement in Studio.

Do not create old Auto-Sell, zone, egg, boost, season, companion, VIP, or cash products. Do not
publish game-page assets that show obsolete mechanics.

Creating products or changing public visibility is outward-facing; prepare evidence and ask
before execution.

---

### [P6] Release automation and checklist evidence

**Owner:** Architect + QA · **Depends on:** P1, P2, P4, P5

Automate reversible checks: build, package lock, test suite, exact world markers, eight plot
count, no legacy RequestSell contract, asset-id resolution, test/production key separation,
StreamingEnabled, performance config, and approved product ids. Store evidence for R3.

Publishing and flipping the experience public remain explicit owner-confirmation steps.
