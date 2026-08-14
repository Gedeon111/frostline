--!strict
--[[
	UPGRADES — the four V2 tracks. Source: ECONOMY §3.

	Axe and carrier keep the prototype's damage and capacity tables verbatim,
	renamed from `harpoon` and `pack`. ECONOMY §3 is explicit that the values do
	not change during the naming migration — retuning happens in D1, after
	combat and the store loop are measured *together*, and moving both at once
	would leave us unable to tell which change caused what.

	Fridge and register are new and provisional.

	Costs are LITERAL INTEGERS, not computed. A formula drifts from the design
	doc the moment someone tweaks a growth rate, and then the doc and the game
	disagree with nobody noticing. Contract tests assert the sums.

		levels[n].cost   cash to REACH level n. levels[1].cost is always 0.

	That differs from V1, where `costs[n]` was the price of reaching n+1. The
	shape changed because the four tracks carry different fields — the register
	has a duration AND a queue size — and a parallel values/costs pair could not
	express that without inventing a second convention per track.
]]

local Types = require(script.Parent.Parent.Types)

local Upgrades = {}

Upgrades.Tracks = {
	--[[
		AXE — the renamed harpoon table, x1.7 per level, values unchanged.
		L10 = 1190 damage, which killed the largest prototype creature in ~7
		swings. Model swaps at 1/4/7/10 carry over from the old Tools.Defs.
	]]
	axe = {
		id = "axe",
		displayName = "Axe",
		unit = "dmg",
		maxLevel = 10,
		levels = {
			{ cost = 0, damage = 10, modelName = "axe_rusted" },
			{ cost = 200, damage = 17 },
			{ cost = 430, damage = 29 },
			{ cost = 925, damage = 49, modelName = "axe_steel" },
			{ cost = 1988, damage = 84 },
			{ cost = 4274, damage = 143 },
			{ cost = 9190, damage = 242, modelName = "axe_bone" },
			{ cost = 19759, damage = 412 },
			{ cost = 42481, damage = 700 },
			{ cost = 91334, damage = 1190, modelName = "axe_aurora" },
		},
	} :: Types.UpgradeDef,

	--[[
		CARRIER — the renamed pack table, 20 then +12 per level, unchanged.

		Capacity is authoritative inventory WEIGHT. The visible rack is a
		bounded representation, never one part per carried item (ECONOMY §3,
		GDD §10).
	]]
	carrier = {
		id = "carrier",
		displayName = "Carrier",
		unit = "weight",
		maxLevel = 10,
		levels = {
			{ cost = 0, capacity = 20, modelName = "carrier_frame" },
			{ cost = 150, capacity = 32 },
			{ cost = 285, capacity = 44 },
			{ cost = 542, capacity = 56, modelName = "carrier_rack" },
			{ cost = 1029, capacity = 68 },
			{ cost = 1955, capacity = 80 },
			{ cost = 3715, capacity = 92, modelName = "carrier_large" },
			{ cost = 7059, capacity = 104 },
			{ cost = 13412, capacity = 116 },
			{ cost = 25482, capacity = 128 },
		},
	} :: Types.UpgradeDef,

	--[[
		FRIDGE — new. ECONOMY §3 requires the starting refrigerator to hold at
		least two full starter carriers, so level 1 is 40 against a carrier of 20.

		Capacities are explicit and never derived as a multiple of carrier
		capacity. The doc calls that out specifically: derive it, and retuning
		the carrier silently retunes the bottleneck the fridge exists to be
		(ECONOMY §5 constraint 4).

		The curve is deliberately slower than the carrier's, so the player meets
		a real stock bottleneck before the first fridge upgrade is affordable
		rather than pre-empting it.
	]]
	fridge = {
		id = "fridge",
		displayName = "Refrigerator",
		unit = "weight",
		maxLevel = 10,
		levels = {
			{ cost = 0, capacity = 40, modelName = "fridge_small" },
			{ cost = 300, capacity = 70 },
			{ cost = 700, capacity = 110 },
			{ cost = 1500, capacity = 160, modelName = "fridge_double" },
			{ cost = 3200, capacity = 220 },
			{ cost = 6800, capacity = 300 },
			{ cost = 14000, capacity = 400, modelName = "fridge_walkin" },
			{ cost = 29000, capacity = 520 },
			{ cost = 60000, capacity = 660 },
			{ cost = 125000, capacity = 820 },
		},
	} :: Types.UpgradeDef,

	--[[
		REGISTER — new. Each level defines checkout duration AND queue capacity.

		ECONOMY §3: speed cannot reach zero, and the starter level must process
		a one-item customer quickly enough that standing at the register feels
		active rather than idle. 2.0s at level 1 falling to 0.45s at level 10 —
		responsive from the first customer, with real headroom left to buy.
	]]
	register = {
		id = "register",
		displayName = "Register",
		unit = "sec",
		maxLevel = 10,
		levels = {
			{ cost = 0, checkoutSeconds = 2.0, queueCapacity = 3, modelName = "register_basic" },
			{ cost = 400, checkoutSeconds = 1.75, queueCapacity = 4 },
			{ cost = 900, checkoutSeconds = 1.5, queueCapacity = 4 },
			{ cost = 1900, checkoutSeconds = 1.3, queueCapacity = 5, modelName = "register_scanner" },
			{ cost = 4000, checkoutSeconds = 1.1, queueCapacity = 5 },
			{ cost = 8500, checkoutSeconds = 0.95, queueCapacity = 6 },
			{ cost = 17500, checkoutSeconds = 0.8, queueCapacity = 6, modelName = "register_terminal" },
			{ cost = 36000, checkoutSeconds = 0.65, queueCapacity = 7 },
			{ cost = 74000, checkoutSeconds = 0.55, queueCapacity = 8 },
			{ cost = 150000, checkoutSeconds = 0.45, queueCapacity = 8 },
		},
	} :: Types.UpgradeDef,
}

-- Display order in the shop, and the order a new player meets them.
Upgrades.Order = { "axe", "carrier", "fridge", "register" }

function Upgrades.Get(track: string): Types.UpgradeDef?
	return (Upgrades.Tracks :: any)[track]
end

-- The level record. Clamps rather than erroring: a bad level is a caller bug,
-- but returning nil turns it into a nil-index crash three frames later,
-- somewhere unrelated.
function Upgrades.GetLevel(track: string, level: number): Types.UpgradeLevel?
	local def = Upgrades.Get(track)
	if not def then
		return nil
	end
	local clamped = math.clamp(math.floor(level), 1, def.maxLevel)
	return def.levels[clamped]
end

-- Cost to go from `level` to `level + 1`. nil means there is no next level,
-- which is how callers detect "maxed" without a second lookup.
function Upgrades.GetCost(track: string, level: number): number?
	local def = Upgrades.Get(track)
	if not def then
		return nil
	end
	if level < 1 or level >= def.maxLevel then
		return nil
	end
	return def.levels[level + 1].cost
end

function Upgrades.IsMaxed(track: string, level: number): boolean
	local def = Upgrades.Get(track)
	return def ~= nil and level >= def.maxLevel
end

-- ── Typed accessors ─────────────────────────────────────────────────────────
-- One per field, so services never index a possibly-nil level record and a
-- track missing a field fails here rather than as arithmetic-on-nil at a call
-- site that has no idea what a register is.

function Upgrades.GetDamage(level: number): number
	local record = Upgrades.GetLevel("axe", level)
	return (record and record.damage) or 0
end

function Upgrades.GetCarryCapacity(level: number): number
	local record = Upgrades.GetLevel("carrier", level)
	return (record and record.capacity) or 0
end

function Upgrades.GetFridgeCapacity(level: number): number
	local record = Upgrades.GetLevel("fridge", level)
	return (record and record.capacity) or 0
end

function Upgrades.GetCheckoutSeconds(level: number): number
	local record = Upgrades.GetLevel("register", level)
	return (record and record.checkoutSeconds) or 0
end

--[[
	The visible model at a level, searching DOWNWARD.

	Only some levels define a `modelName` — the axe swaps at 1, 4, 7 and 10, so
	a level-6 player is still carrying the level-4 steel axe. Reading
	`levels[6].modelName` directly returns nil and would leave them empty-handed,
	which is why nothing should index that field without going through here.

	Returns nil only if no level at or below this one names a model at all.
]]
function Upgrades.GetModelName(track: string, level: number): string?
	local def = Upgrades.Get(track)
	if not def then
		return nil
	end
	local clamped = math.clamp(math.floor(level), 1, def.maxLevel)
	for i = clamped, 1, -1 do
		local record = def.levels[i]
		if record and record.modelName then
			return record.modelName
		end
	end
	return nil
end

function Upgrades.GetQueueCapacity(level: number): number
	local record = Upgrades.GetLevel("register", level)
	return (record and record.queueCapacity) or 0
end

-- Total cash to take a track from 1 to max. Asserted in the contract tests.
function Upgrades.TotalCost(track: string): number
	local def = Upgrades.Get(track)
	if not def then
		return 0
	end
	local sum = 0
	for _, level in ipairs(def.levels) do
		sum += level.cost
	end
	return sum
end

return Upgrades
