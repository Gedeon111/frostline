# M3 — Meta, Commercial Validation, and Hardening

M3 features are gated by the corrected-loop metrics. A feature does not enter implementation
because it existed in the pre-D-017 plan.

### [D7] Rebirth RFC

**Owner:** Architect + Economy · **Depends on:** D6, V5

Specify what resets, what persists, how worker progression changes, and how the loop avoids
turning the store into passive waiting. The first worker remains pre-rebirth. Include migration,
multiplier cap, UI, analytics, and simulation blast radius before approval.

---

### [D8] Companion RFC

**Owner:** Architect + Economy · **Depends on:** D6

Evaluate companions only against the corrected actions: hunting, carrying, stocking, customers,
registers, and workers. Prefer bonuses that create visible store behavior over a generic
multiplier. No models or hatch system begin before the RFC is accepted.

---

### [D9] Additional monetization RFC

**Owner:** Architect · **Depends on:** D6, V5, soft funnel data

Auto-Swing is already approved. Every additional SKU must pass MONETIZATION §7. Auto-Sell
remains prohibited. The RFC must name free-player experience, server authority, economy
invariant, purchase timing, and rollback plan.

---

### [A32] Security and exploit pass

**Owner:** QA + Server · **Depends on:** all M2 server jobs

Audit swing spam, foreign-plot access, marker spoofing, reservation replay, duplicate checkout,
ledger collection races, worker production, profile unload, teleports, malformed remote
arguments, and receipt idempotency. Fix authority boundaries, not just symptoms.

---

### [A33] Retention services

**Owner:** Server + Client · **Depends on:** D6, A27

Add daily/playtime/quest systems only when rewards feed approved store progression. Timers are
server-time expiry timestamps. Claims are idempotent and never create customer or worker
backlogs while offline.

---

### [A34] Rebirth implementation

**Owner:** Server + Client · **Depends on:** accepted D7

Implement exactly the accepted reset/persistence contract through domain services. Add migration,
state, UI, analytics, and full save/rejoin tests in the same feature sequence.

---

### [A35] Approved commercial additions

**Owner:** Server + Client · **Depends on:** accepted D9

Implement only products named in D9. All receipt processing is idempotent. No product writes
inventory, workers, or cash outside the owning service APIs.

---

### [B19] Settings and accessibility

**Owner:** Client · **Depends on:** B14, B20

Finish music, SFX, reduced effects, Auto-Swing toggle, input hints, text scaling, and
color-independent full/blocked indicators. Setting changes use RequestSetting and persist.

---

### [E7] Device and performance hardening

**Owner:** QA · **Depends on:** all approved M2/M3 implementation

Profile low-end phone, tablet, console, and desktop layouts; eight plots; streaming transitions;
long customer queues; maximum visual stack; cash aggregation; all workers; and reconnect churn.
Failures block release.

---

### [E8] Economy/exploit regression suite

**Owner:** QA · **Depends on:** A32 and any approved meta/commercial service

Run migration fixtures, transaction conservation, receipts, multipliers, rebirth, claims, workers,
and all ECONOMY invariants from one repeatable suite. Any path that mints cash without a named
source is a failure.

---

### [V6] Meta feel check

**Owner:** Gedeon · **Depends on:** approved M3 features

Verify that workers make the shop feel busier rather than empty, rebirth creates a reason to
replay, and purchase prompts do not interrupt the core store actions.
