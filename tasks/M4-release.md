# M4 — Release

---

### [R1] QA test plan + full playtest script

**Owner:** QA · **Depends on:** all of M3

**You own:** `docs/test-plan.md`

**Build:** a complete manual pass covering the full progression (new account → Zone 5), every
purchase path, every persistence boundary (leave/rejoin/server-hop at each milestone),
multiplayer (4 clients in one server), mobile, and every refusal reason surfacing correct
copy. Each case: steps, expected, actual, pass/fail.

Include a **fresh-account run** timed against `docs/ECONOMY.md` §4. If first sell takes more
than 90 seconds, that is a release blocker per ECONOMY §7 rule 5.

**Done when:** every case is executed and recorded; all blockers fixed and re-tested; the
plan is repeatable by someone who hasn't read the codebase.

---

### [R2] Game page assets

**Owner:** Architect · **Depends on:** G1, C7, P5 · **Channel:** 3, 4, and 1

`G1` already produced 6 icon and 6 thumbnail candidates with a ranked recommendation. This job
is the follow-through: pick, refine with real in-engine captures, upload, publish the page.

**Build:**
- Close out `docs/DECISIONS.md` D-004 (final title) — search Roblox via Chrome MCP for name
  collisions first, then decide.
- Description copy: one hook line, three bullets, one controls line. Written for a
  ten-year-old skimming on a phone.
- Icon: one bear silhouette, `blood` on `snow`, no text, readable at 64px. Generate via
  Higgsfield, or composite in Canva — but **check it at 64px**, which is where most icons die.
- Three thumbnails: (1) a bear mid-swing with the pack bar full, (2) the Aurora Basin wide
  shot — this is the visual differentiator and the reason anyone clicks, (3) the Black Ice
  titan. Prefer real in-engine captures from C7's screenshot harness over generated art;
  players should recognize the game they clicked. **No arrows, no red circles, no screaming
  faces** — restraint is the entire visual pitch, and thumbnails are where games abandon it.
- Upload and fill in the page via Chrome MCP (P5's runbooks), or the Assets API where it
  applies.

**Done when:** the page is filled and screenshotted into the PR; the icon reads at 64px; the
three thumbnails are recognizably the same game as the in-engine screenshots.

---

### [R3] Publish checklist

**Owner:** Architect · **Depends on:** R1, P6 · **Channel:** 2 + 3

**You own:** `docs/release-checklist.md`

**Build and execute** — most of this is verifiable programmatically; do that rather than
eyeballing the dashboard:
- Place config: max players (12–20), `StreamingEnabled`, physics/network settings, HTTP
  requests, API access for DataStores **enabled** (the classic launch-day failure)
- Separate **production and test DataStore keys** — verify the live game is not reading
  development data
- Badges for first sell, each zone unlock, first rebirth
- **Moderation review**: re-read every player-facing string against `docs/DECISIONS.md` D-001.
  No "Eskimo" anywhere in code, comments, assets, or the game page. Confirm creature naming
  and description read as fictional.
- Chat/filter check: every dynamic string shown to a player (names on leaderboards, codes
  feedback) passes through `TextService:FilterStringAsync`
- Clear the P6 release checklist, publish from Studio (File → Publish), then confirm the new
  place version through the Open Cloud version list — don't trust the dashboard's word for it

**Flipping the game public is outward-facing and effectively irreversible.** Do everything up
to that point, then confirm before making the place public.

**Done when:** every checklist item is ticked with evidence (API response, screenshot, or test
output — not "looks right"); a fresh account joins the live place and progresses correctly for
10 minutes.

---

### [R4] Soft-launch tuning loop

**Owner:** Economy · **Depends on:** R3, A14

**Build:** 72 hours of analytics review after going public. Report: D1 retention, median
session length, funnel drop-off (`join → first kill → first sell → first upgrade → zone 2`),
time-to-zone by cohort, conversion rate, and cash source/sink balance.

Propose config changes as RFCs. Expect the real fixes to be in the first 5 minutes, not the
endgame — if players quit before the first sell, no amount of Zone 5 tuning matters.

**Done when:** the report is written, the top three drop-off points are identified with a
proposed fix each, and the E1 invariant suite still passes after any config change ships.
