--!strict
--[[
	CREATURES — source: docs/ECONOMY.md §1, tints/scale from docs/ART_BIBLE.md §4.

	The column that actually matters is cash-per-weight (value*drops / weight*drops,
	i.e. meatValue/meatWeight). It rises ~3x per tier, and that is the real
	progression curve — a trip in Black Ice is worth ~60x a trip in Shelf Ice at
	the same pack size. ECONOMY §7 rule 1 requires >= 2.5x per tier; below that a
	new zone doesn't feel like an upgrade. Tests assert it (E1).
]]

local Types = require(script.Parent.Parent.Types)

local Creatures = {}

Creatures.Tiers = {
	snow_cub = {
		id = "snow_cub",
		displayName = "Snow Cub",
		hp = 30,
		dropCount = 2,
		meatWeight = 2,
		meatValue = 5,            -- 2.5 cash/weight
		respawnSeconds = 8,
		modelName = "snow_cub",
		shoulderHeight = 4,
		tint = Color3.fromHex("E8E2D4"),   -- bone
	} :: Types.CreatureTier,

	frost_bear = {
		id = "frost_bear",
		displayName = "Frost Bear",
		hp = 120,
		dropCount = 3,
		meatWeight = 3,
		meatValue = 19,           -- 6.33 cash/weight (2.53x tier 1 — see note below)
		respawnSeconds = 8,
		modelName = "frost_bear",
		shoulderHeight = 6,
		tint = Color3.fromHex("DCE6EC"),
	} :: Types.CreatureTier,

	ice_bear = {
		id = "ice_bear",
		displayName = "Ice Bear",
		hp = 450,
		dropCount = 4,
		meatWeight = 4,
		meatValue = 65,           -- 16.3
		respawnSeconds = 15,
		modelName = "ice_bear",
		shoulderHeight = 8,
		tint = Color3.fromHex("B8D4E4"),
	} :: Types.CreatureTier,

	aurora_bear = {
		id = "aurora_bear",
		displayName = "Aurora Bear",
		hp = 1800,
		dropCount = 5,
		meatWeight = 5,
		meatValue = 240,          -- 48.0
		respawnSeconds = 15,
		modelName = "aurora_bear",
		shoulderHeight = 11,
		tint = Color3.fromHex("9FD8C4"),
	} :: Types.CreatureTier,

	titan_bear = {
		id = "titan_bear",
		displayName = "Titan Bear",
		hp = 7500,
		dropCount = 6,
		meatWeight = 6,
		meatValue = 900,          -- 150.0
		respawnSeconds = 25,
		modelName = "titan_bear",
		shoulderHeight = 14,
		tint = Color3.fromHex("3A3F4A"),
	} :: Types.CreatureTier,
}

-- Tier order, low to high. Zones reference tiers by id; this is for tests and UI.
Creatures.Order = { "snow_cub", "frost_bear", "ice_bear", "aurora_bear", "titan_bear" }

--[[
	Variants (M2, job A9). Rolled per spawn.

	Golden is the screenshot moment and the reason someone posts about the game.
	A9 must guarantee at least one per zone within a reasonable window rather than
	rolling raw 2% — pure chance produces dry spells that players read as a bug.
]]
Creatures.Variants = {
	golden = {
		id = "golden",
		chance = 0.02,
		valueMultiplier = 10,
		tint = Color3.fromHex("F2B035"),   -- gold
		emissive = true,
	} :: Types.CreatureVariant,
}

function Creatures.Get(tierId: string): Types.CreatureTier?
	return (Creatures.Tiers :: any)[tierId]
end

-- The progression curve, exposed so tests and tuning don't recompute it.
function Creatures.CashPerWeight(tierId: string): number
	local t = Creatures.Get(tierId)
	if not t then return 0 end
	return t.meatValue / t.meatWeight
end

function Creatures.CashPerKill(tierId: string): number
	local t = Creatures.Get(tierId)
	if not t then return 0 end
	return t.meatValue * t.dropCount
end

function Creatures.WeightPerKill(tierId: string): number
	local t = Creatures.Get(tierId)
	if not t then return 0 end
	return t.meatWeight * t.dropCount
end

return Creatures
