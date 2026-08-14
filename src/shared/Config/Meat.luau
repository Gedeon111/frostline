--!strict
--[[
	MEAT — authoritative weight, checkout value, model, and variant identity.
]]

local Types = require(script.Parent.Parent.Types)
local Palette = require(script.Parent.Palette)

local Meat = {}

Meat.Defs = {
	snow_cub = {
		id = "snow_cub", displayName = "Snow Cub Meat", creatureTier = "snow_cub",
		weight = 2, unitValue = 5, modelName = "meat_snow_cub", tint = Palette.blood,
	} :: Types.MeatDef,
	snow_cub_golden = {
		id = "snow_cub_golden", displayName = "Golden Snow Cub Meat", creatureTier = "snow_cub",
		variant = "golden", weight = 2, unitValue = 50, modelName = "meat_snow_cub_golden", tint = Palette.gold,
	} :: Types.MeatDef,
	frost_bear = {
		id = "frost_bear", displayName = "Frost Bear Meat", creatureTier = "frost_bear",
		weight = 3, unitValue = 19, modelName = "meat_frost_bear", tint = Palette.blood,
	} :: Types.MeatDef,
	frost_bear_golden = {
		id = "frost_bear_golden", displayName = "Golden Frost Bear Meat", creatureTier = "frost_bear",
		variant = "golden", weight = 3, unitValue = 190, modelName = "meat_frost_bear_golden", tint = Palette.gold,
	} :: Types.MeatDef,
	ice_bear = {
		id = "ice_bear", displayName = "Ice Bear Meat", creatureTier = "ice_bear",
		weight = 4, unitValue = 65, modelName = "meat_ice_bear", tint = Palette.blood,
	} :: Types.MeatDef,
	ice_bear_golden = {
		id = "ice_bear_golden", displayName = "Golden Ice Bear Meat", creatureTier = "ice_bear",
		variant = "golden", weight = 4, unitValue = 650, modelName = "meat_ice_bear_golden", tint = Palette.gold,
	} :: Types.MeatDef,
	aurora_bear = {
		id = "aurora_bear", displayName = "Aurora Bear Meat", creatureTier = "aurora_bear",
		weight = 5, unitValue = 240, modelName = "meat_aurora_bear", tint = Palette.blood,
	} :: Types.MeatDef,
	aurora_bear_golden = {
		id = "aurora_bear_golden", displayName = "Golden Aurora Bear Meat", creatureTier = "aurora_bear",
		variant = "golden", weight = 5, unitValue = 2400, modelName = "meat_aurora_bear_golden", tint = Palette.gold,
	} :: Types.MeatDef,
	titan_bear = {
		id = "titan_bear", displayName = "Titan Bear Meat", creatureTier = "titan_bear",
		weight = 6, unitValue = 900, modelName = "meat_titan_bear", tint = Palette.blood,
	} :: Types.MeatDef,
	titan_bear_golden = {
		id = "titan_bear_golden", displayName = "Golden Titan Bear Meat", creatureTier = "titan_bear",
		variant = "golden", weight = 6, unitValue = 9000, modelName = "meat_titan_bear_golden", tint = Palette.gold,
	} :: Types.MeatDef,
}

Meat.Order = {
	"snow_cub", "snow_cub_golden",
	"frost_bear", "frost_bear_golden",
	"ice_bear", "ice_bear_golden",
	"aurora_bear", "aurora_bear_golden",
	"titan_bear", "titan_bear_golden",
}

function Meat.Get(meatId: string): Types.MeatDef?
	return (Meat.Defs :: any)[meatId]
end

function Meat.GetValue(contents: Types.MeatContents): number
	local total = 0
	for meatId, count in pairs(contents) do
		local def = Meat.Get(meatId)
		if def and count > 0 then
			total += def.unitValue * math.floor(count)
		end
	end
	return total
end

function Meat.GetWeight(contents: Types.MeatContents): number
	local total = 0
	for meatId, count in pairs(contents) do
		local def = Meat.Get(meatId)
		if def and count > 0 then
			total += def.weight * math.floor(count)
		end
	end
	return total
end

return Meat
