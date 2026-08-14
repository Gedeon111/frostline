# M2 — Store Depth and Content

M2 begins only after V3 proves the corrected one-player loop and V4 identifies no eight-plot
fairness blocker. It deepens the store; it does not restore the old sell-pad or five-zone plan.

### [A28] Cashier worker

**Owner:** Server · **Depends on:** A25, A23, V3
**You own:** `src/server/Services/WorkerService.luau` for this follow-up job

Implement the configured cashier role through RegisterService's public processing API. It pauses
on empty queue, disabled state, plot release, or unloaded profile. It creates no alternate sale
formula.

**Done when:** player and cashier cannot double-complete one customer; upgrades affect only
configured speed; checkout value matches player operation exactly.

---

### [A29] Hunter worker

**Owner:** Server · **Depends on:** A25, A18, A19, D6
**You own:** `src/server/Services/WorkerService.luau` for this follow-up job

Implement configured hunter production into HunterDropoff/fridge through authoritative inventory
APIs. The worker never awards cash and never accumulates offline backlog.

**Done when:** output stays under ECONOMY's active-play ratio; full destination pauses; toggling,
leave/rejoin, and plot release cannot duplicate output.

---

### [A30] Customer archetypes and baskets

**Owner:** Server · **Depends on:** A22, V3
**You own:** `src/server/Services/CustomerService.luau` for this follow-up job

Add config-defined customer appearance, patience, basket, and frequency variants. Reservation
and checkout authority stay unchanged. No archetype may request stock unavailable to the current
progression without a configured fallback.

**Done when:** weighted rates sum exactly; every basket reserves atomically; queue abandonment
returns stock; behavior remains bounded at all eight plots.

---

### [A31] Additional creature and meat tiers

**Owner:** Server · **Depends on:** A19, V3, D6
**You own:** `src/server/Services/CreatureService.luau` for this follow-up job

Add configured tiers and variant-preserving meat items within the shared wilderness. Use terrain
regions or spawn bands only after route and value simulations show they improve progression.
Do not reintroduce five locked zones by default.

**Done when:** stronger tiers have readable placement/value; starter players cannot be trapped
by population replacement; variants retain their sale value through carry→fridge→customer.

---

### [B17] Full worker computer

**Owner:** Client · **Depends on:** A28, A29, B16

Expand the computer UI for stocker, cashier, and hunter levels/toggles, current blocked reason,
and configured next upgrade. Keep normal cash affordability and server refusals authoritative.

---

### [B18] Store customization

**Owner:** Client + Server · **Depends on:** C12, V3

Define a narrow cosmetic-only customization contract: approved fixture skins, signs, and colors.
Cosmetics cannot move markers, change capacity, shorten paths, or expose another plot's state.

---

### [B20] SoundController

**Owner:** Client · **Depends on:** B13, C15

Add axe impact, meat pickup/unload, refrigerator, customer, register, counter buildup, magnet
collection, wilderness ambience, and store ambience through configured audio ids. Respect
music/sfx settings and avoid one Sound per transaction.

---

### [B21] Camera and movement feel

**Owner:** Client · **Depends on:** B11, B13

Add restrained configured FOV/impact response and snow footsteps. Camera effects cannot move the
authoritative character or hide register/cash interaction zones.

---

### [C13] Finished settlement and stores

**Owner:** World · **Depends on:** C12, V4
**Studio claim:** `Workspace.World.Plots` and settlement-only surroundings

Replace plot shells with eight equivalent Arctic-frontier shops. Keep exact marker positions or
re-run route fairness. Give customer-facing fronts and wilderness-facing service exits distinct
readability.

---

### [C14] Finished shared hunting wilderness

**Owner:** World · **Depends on:** C9, V4, A31
**Studio claim:** `Workspace.World.HuntingGround`

Finish terrain, trails, landmarks, spawn bands, and sightlines. Preserve multiple equivalent
entrances and keep customers out. The result must not read as a rectangular backyard.

---

### [C15] Audio assets

**Owner:** Tech Art · **Depends on:** V3

Produce or source moderation-safe audio for M2 interactions, record ids in Config.Audio, and
verify every id resolves in the target experience.

---

### [D6] Store economy tuning simulation

**Owner:** Economy · **Depends on:** V3, V4

Build a simulation from actual config for hunt production, customer demand, register throughput,
fridge capacity, upgrade costs, and workers. Tune only from measured Studio timings. Assert all
ECONOMY §10 invariants and report free/manual versus automated session curves.

---

### [E6] Full worker/customer performance pass

**Owner:** QA · **Depends on:** A28–A31, B20, C13–C15, D6

Profile eight active plots, maximum configured customers, shared creatures, all workers, visual
pools, streaming, leave/join churn, and long-idle cleanup. Reduce populations/effects through
config before weakening authority or transaction correctness.

---

### [C16] M2 art integration audit

**Owner:** World/QA · **Depends on:** C13–C15, B20, B21, E6

Capture fixed views from every plot front, every hunt entrance, the register, refrigerator,
carrier at several capacities, and cash pickup. Verify palette, part budgets, marker visibility,
streaming, collision, animation, and mobile readability.
