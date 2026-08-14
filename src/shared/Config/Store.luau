--!strict
--[[
	STORE — customers, register, and counter cash. Source: ECONOMY §5–6, GDD §2.

	ECONOMY §5 constraint 5 requires customer spawn cadence, basket size, queue
	capacity and checkout duration to all come from here. Every one of these is
	provisional until the corrected slice is measured (ECONOMY preamble) — they
	are starting points chosen to satisfy the stated constraints, not results.

	Checkout duration and queue capacity are NOT here: they live per register
	level in Config.Upgrades, because they are what the register upgrade buys.
]]

local Store = {}

-- ── Customers ───────────────────────────────────────────────────────────────

--[[
	Arrival cadence. Randomised between min and max so a queue forms unevenly
	and the store never reads as a metronome.

	ECONOMY §5 constraint 1: with the player operating the starter register,
	throughput must exceed arrival rate. Starter checkout is 2.0s, so arrivals
	averaging ~7s leave a wide margin — the player should never feel behind
	while actually standing there.

	Constraint 2: with nobody at the register a queue may form but must not be
	unbounded. `MaxActiveCustomers` and the register's queue capacity together
	are what bound it.
]]
Store.CustomerSpawnInterval = { min = 5, max = 9 }

-- Hard cap on customers alive per plot, including those walking and queueing.
-- Eight plots run concurrently (ARCHITECTURE §8), so this is multiplied by
-- eight on a full server — the number is a performance decision as much as a
-- pacing one.
Store.MaxActiveCustomers = 6

--[[
	How much one customer buys. Weighted so most baskets are small: a queue of
	single-item customers reads as busy, while an occasional large basket makes
	the fridge visibly drain.

	ECONOMY §5: customer demand should consume one full carrier in roughly the
	time the player needs for another hunting trip.
]]
Store.BasketSize = { min = 1, max = 3 }

-- Seconds a customer will wait in the queue before giving up and leaving.
-- A cancelled customer returns its reservation exactly once (ECONOMY §10
-- rule 4) — the timeout is the main path that rule is tested against.
Store.CustomerPatienceSeconds = 75

-- Seconds a customer spends walking to and taking stock before it queues.
-- Purely pacing; the transfer itself is instantaneous and server-owned.
Store.CustomerCollectSeconds = 1.2

-- Walk speed for customer NPCs. Slower than a player so they read as ambient
-- rather than racing the person who owns the shop.
Store.CustomerWalkSpeed = 11

--[[
	How long a customer waits when the fridge has nothing it can reserve.

	Rather than despawning instantly on empty stock — which makes a restocked
	fridge feel dead for a full spawn interval — a customer lingers briefly and
	re-checks. GDD §10 wants "time with stock available but no actionable
	customer" under 10 seconds during onboarding.
]]
Store.CustomerRetrySeconds = 3

-- ── Counter cash ────────────────────────────────────────────────────────────

--[[
	Visual piles are generated from value buckets, and the piece count is capped
	(ECONOMY §6). One sale must never create one part per currency unit.

	The ledger is authoritative and is a single number; these settings only
	decide how that number is DRAWN.
]]
Store.CashPieceValue = 25 -- one visible piece represents this much cash
Store.MaxCashPieces = 12 -- pile stops growing visually past this

-- Studs. Walking within this of the counter starts collection.
Store.CashCollectRadius = 10

-- Seconds a cash piece takes to fly to the player once collection starts.
-- Cosmetic: the award is atomic and already resolved before the flight
-- finishes (ECONOMY §6).
Store.CashFlightSeconds = 0.45

-- ── Zones ───────────────────────────────────────────────────────────────────

--[[
	Radii for the three proximity interactions that have NO remote
	(ARCHITECTURE §3): unloading, operating the register, and collecting cash.

	The server detects the player's authoritative character position inside
	these; the client cannot announce that it unloaded or completed a sale.
]]
Store.UnloadRadius = 8
Store.RegisterOperatorRadius = 8

-- How often the server polls character positions against those regions.
-- 5Hz is enough for a walk-in interaction and cheap across eight plots.
Store.ProximityCheckHz = 5

-- Meat transferred per tick while unloading, in ITEMS not weight. Makes
-- unloading a visible stream rather than an instant swap (GDD §10).
Store.UnloadItemsPerTick = 2
Store.UnloadTickSeconds = 0.15

return Store
