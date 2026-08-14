--!strict
--[[
	WORKERS — the automation layer. Source: ECONOMY §7, GDD §7.

	Workers change LABOUR, not the source of value:
	  stocker  moves owned meat, creates none
	  cashier  consumes valid reservations, creating only the same checkout
	           value the player would have
	  hunter   creates configured meat at a capped rate and never awards cash

	ECONOMY §7 sets the one hard balance rule: initial hunter output stays below
	25% of measured active-player meat production at the same progression point,
	so active play remains the fastest route. That measurement does not exist
	yet — the rate below is a deliberate underestimate, and V1 must check it.

	GDD §7: at least one worker must be reachable before rebirth, and rebirth
	cannot gate the feature that defines the management fantasy. Costs are
	ordinary cash for all three.
]]

local Types = require(script.Parent.Parent.Types)

local Workers = {}

Workers.Defs = {
	--[[
		STOCKER — reachable first (ECONOMY §7 table). Removes the repeated
		walk from carrier to fridge inside the plot, which is the first chore a
		player notices once the loop is understood.

		Rate is meat ITEMS moved per minute.
	]]
	stocker = {
		id = "stocker",
		displayName = "Stocker",
		description = "Moves meat from your drop-off into the refrigerator.",
		unlockCost = 2500,
		maxLevel = 5,
		levels = {
			{ cost = 0, ratePerMinute = 30 },
			{ cost = 4000, ratePerMinute = 48 },
			{ cost = 9000, ratePerMinute = 72 },
			{ cost = 20000, ratePerMinute = 105 },
			{ cost = 45000, ratePerMinute = 150 },
		},
	} :: Types.WorkerDef,

	--[[
		CASHIER — reachable second. Keeps the queue moving while the player is
		out hunting, which is what turns the store from a place you stand into a
		place that runs.

		Rate is SALES processed per minute. Deliberately below what a player
		achieves at the same register level: ECONOMY §5 constraint 3 requires
		cashier throughput not to exceed available stock over a full cycle, and
		a cashier that outpaced the player would make standing at the register
		pointless the moment it was bought.
	]]
	cashier = {
		id = "cashier",
		displayName = "Cashier",
		description = "Serves the register queue while you are away.",
		unlockCost = 6000,
		maxLevel = 5,
		levels = {
			{ cost = 0, ratePerMinute = 12 },
			{ cost = 11000, ratePerMinute = 18 },
			{ cost = 24000, ratePerMinute = 26 },
			{ cost = 52000, ratePerMinute = 36 },
			{ cost = 110000, ratePerMinute = 50 },
		},
	} :: Types.WorkerDef,

	--[[
		HUNTER — reachable last, and the one with the balance risk.

		Rate is meat ITEMS produced per minute, deposited at the plot's
		HunterDropoff. It never awards cash: its output still has to be stocked,
		sold to a customer, and collected from the counter like everything else
		(ECONOMY §7).

		12/min against a player who can produce far more per active minute keeps
		it comfortably under the 25% ceiling. V1 measures the real player rate
		and this number should be revisited then, not before.
	]]
	hunter = {
		id = "hunter",
		displayName = "Hunter",
		description = "Hunts on its own and leaves meat at your drop-off.",
		unlockCost = 15000,
		maxLevel = 5,
		levels = {
			{ cost = 0, ratePerMinute = 12 },
			{ cost = 28000, ratePerMinute = 18 },
			{ cost = 60000, ratePerMinute = 25 },
			{ cost = 130000, ratePerMinute = 34 },
			{ cost = 275000, ratePerMinute = 45 },
		},
	} :: Types.WorkerDef,
}

-- Unlock order. Also the order the UI lists them and the order ECONOMY §7
-- specifies they become reachable.
Workers.Order = { "stocker", "cashier", "hunter" }

-- What the hunter produces. Kept here rather than inferred from the creature
-- table so raising a creature's drop never silently raises worker output.
Workers.HunterMeatId = "frost_cut"

--[[
	Seconds a worker waits before re-checking when it has nothing to do.

	GDD §7 / ECONOMY §7: workers pause safely when their destination is full,
	when no stock or customer is available, or when the owner's profile
	unloads — and paused time creates NO backlog payout. A paused worker
	resumes at its rate; it does not catch up.
]]
Workers.IdleRetrySeconds = 2

function Workers.Get(workerId: string): Types.WorkerDef?
	return (Workers.Defs :: any)[workerId]
end

function Workers.GetLevel(workerId: string, level: number): Types.WorkerLevel?
	local def = Workers.Get(workerId)
	if not def then
		return nil
	end
	local clamped = math.clamp(math.floor(level), 1, def.maxLevel)
	return def.levels[clamped]
end

function Workers.GetRate(workerId: string, level: number): number
	local record = Workers.GetLevel(workerId, level)
	return (record and record.ratePerMinute) or 0
end

-- Cost to go from `level` to `level + 1`. nil means maxed. Level 0 means the
-- worker is not unlocked yet — use `unlockCost` for that, not this.
function Workers.GetUpgradeCost(workerId: string, level: number): number?
	local def = Workers.Get(workerId)
	if not def then
		return nil
	end
	if level < 1 or level >= def.maxLevel then
		return nil
	end
	return def.levels[level + 1].cost
end

return Workers
