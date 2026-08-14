--!strict
--[[
	CREATURES — server combat/spawn definitions.

	Each tier points to a Config.Meat id. Legacy meatWeight/meatValue fields stay
	until A19 moves all inventory valuation to Config.Meat.
]]

local Types = require(script.Parent.Parent.Types)
local Palette = require(script.Parent.Palette)

local Creatures = {}

Creatures.Tiers = {
	snow_cub = {
		id = "snow_cub",
		displayName = "Snow Cub",
		hp = 30,
		dropCount = 2,
		meatId = "snow_cub",
		meatWeight = 2,
		meatValue = 5,
		respawnSeconds = 8,
		modelName = "snow_cub",
		shoulderHeight = 4,
		tint = Palette.bone,
	} :: Types.CreatureTier,
	frost_bear = {
		id = "frost_bear",
		displayName = "Frost Bear",
		hp = 120,
		dropCount = 3,
		meatId = "frost_bear",
		meatWeight = 3,
		meatValue = 19,
		respawnSeconds = 8,
		modelName = "frost_bear",
		shoulderHeight = 6,
		tint = Palette.snowShadow,
	} :: Types.CreatureTier,
	ice_bear = {
		id = "ice_bear",
		displayName = "Ice Bear",
		hp = 450,
		dropCount = 4,
		meatId = "ice_bear",
		meatWeight = 4,
		meatValue = 65,
		respawnSeconds = 15,
		modelName = "ice_bear",
		shoulderHeight = 8,
		tint = Palette.ice,
	} :: Types.CreatureTier,
	aurora_bear = {
		id = "aurora_bear",
		displayName = "Aurora Bear",
		hp = 1800,
		dropCount = 5,
		meatId = "aurora_bear",
		meatWeight = 5,
		meatValue = 240,
		respawnSeconds = 15,
		modelName = "aurora_bear",
		shoulderHeight = 11,
		tint = Palette.aurora,
	} :: Types.CreatureTier,
	titan_bear = {
		id = "titan_bear",
		displayName = "Titan Bear",
		hp = 7500,
		dropCount = 6,
		meatId = "titan_bear",
		meatWeight = 6,
		meatValue = 900,
		respawnSeconds = 25,
		modelName = "titan_bear",
		shoulderHeight = 14,
		tint = Palette.night,
	} :: Types.CreatureTier,
}

Creatures.Order = { "snow_cub", "frost_bear", "ice_bear", "aurora_bear", "titan_bear" }

Creatures.Variants = {
	golden = {
		id = "golden",
		chance = 0.02,
		valueMultiplier = 10,
		meatSuffix = "_golden",
		tint = Palette.gold,
		emissive = true,
	} :: Types.CreatureVariant,
}

function Creatures.Get(tierId: string): Types.CreatureTier?
	return (Creatures.Tiers :: any)[tierId]
end

function Creatures.MeatIdFor(tierId: string, variant: string?): string?
	local tier = Creatures.Get(tierId)
	if not tier then
		return nil
	end
	if not variant then
		return tier.meatId
	end
	local variantDef = (Creatures.Variants :: any)[variant]
	if not variantDef then
		return nil
	end
	return tier.meatId .. variantDef.meatSuffix
end

-- Legacy helpers retained through A19.
function Creatures.CashPerWeight(tierId: string): number
	local tier = Creatures.Get(tierId)
	if not tier then
		return 0
	end
	return tier.meatValue / tier.meatWeight
end

function Creatures.CashPerKill(tierId: string): number
	local tier = Creatures.Get(tierId)
	if not tier then
		return 0
	end
	return tier.meatValue * tier.dropCount
end

function Creatures.WeightPerKill(tierId: string): number
	local tier = Creatures.Get(tierId)
	if not tier then
		return 0
	end
	return tier.meatWeight * tier.dropCount
end

return Creatures
