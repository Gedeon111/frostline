# M4 — Release

### [R1] Full QA plan and progression run

**Owner:** QA · **Depends on:** all approved M3 work

**You own:** `docs/test-plan.md`

Cover fresh account → plot assignment → hunting → carry → refrigerator → customers → register →
counter collection → upgrades → all free workers → any approved rebirth/meta features. Test
leave/rejoin/server shutdown at carry, fridge, reservation, queue, unclaimed-cash, worker, and
receipt boundaries. Run one, eight, and churned-client scenarios plus phone/tablet/console.

**Done when:** every case has steps, expected, actual, and evidence; all ECONOMY targets and
invariants pass; a tester unfamiliar with the code can repeat the run.

---

### [R2] Game-page assets

**Owner:** Architect + Art · **Depends on:** C16, R1

Use real finished-loop captures: hunter with visible loaded carrier, warm busy store with customer
queue, and cash magnetizing from the counter. Check the icon at phone size. The page copy says
hunt, stock, serve, collect, and upgrade; it does not advertise sell pads, harpoons, five zones,
or unimplemented workers/products.

Do not upload or publish outward-facing assets without the owner's final confirmation.

---

### [R3] Publish checklist

**Owner:** Architect · **Depends on:** R1, R2

**You own:** `docs/release-checklist.md`

Verify max players supports eight plots, StreamingEnabled, physics/network settings, production
DataStore separation, receipt handling for approved products, moderation-safe fictional
creatures/meat, text filtering, audio/image ownership, all exact world markers, no legacy sell
remote/pad, and no active unapproved SKU.

Complete every reversible step, then ask before making the experience public.

---

### [R4] Soft-launch telemetry and go/no-go

**Owner:** Economy + Architect · **Depends on:** R3, A27

Review at least 72 hours of: plot-assignment failures; corrected funnel conversion; time from
stock to checkout; repeat-hunt rate after collection; upgrade/worker pacing; queue/fridge
bottlenecks; D1 retention; Auto-Swing trial/pass behavior; cash sources/sinks; server/client
performance; and plot fairness.

Config changes require a short RFC and regression run. Do not add new SKUs to compensate for an
unclear or tedious core loop.

**Done when:** the top three drop-offs have evidence-backed fixes, all economy/security tests
remain green, and a written go/no-go decision exists.
