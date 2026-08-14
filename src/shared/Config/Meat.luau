--!strict
--[[
	MEAT — the item that moves through the whole game. Source: ECONOMY §1–2.

	One inventory vocabulary spans carrier, refrigerator, customer basket and
	checkout, so a meat id is the single thing every store service agrees on.

	ECONOMY §2 is explicit that a rare variant must map to a DISTINCT id rather
	than dropping more of the ordinary item. `frost_cut_golden` therefore exists
	as its own entry with its own value — a golden kill produces genuinely
	different stock, and the customer paying for it pays the difference.
]]

local Types = require(script.Parent.Parent.Types)
local Palette = require(script.Parent.Palette)

local Meat = {}

Meat.Defs = {
	frost_cut = {
		id = "frost_cut",
		displayName = "Frost Cut",
		-- ECONOMY §2 starter baseline, carried over unchanged from the prototype:
		-- weight 2, value 5, so a Snow Cub kill is 4 weight and 10 base value.
		weight = 2,
		value = 5,
		modelName = "frost_cut",
		tint = Palette.blood,
	} :: Types.MeatDef,

	frost_cut_golden = {
		id = "frost_cut_golden",
		displayName = "Golden Frost Cut",
		-- Same weight so it never distorts capacity maths; 10x value is where
		-- the variant is actually felt (the old golden valueMultiplier).
		weight = 2,
		value = 50,
		modelName = "frost_cut",
		tint = Palette.gold,
	} :: Types.MeatDef,
}

-- Display order for the fridge UI and the index. Not a progression.
Meat.Order = { "frost_cut", "frost_cut_golden" }

function Meat.Get(meatId: string): Types.MeatDef?
	return (Meat.Defs :: any)[meatId]
end

-- Total weight of a { [meatId]: count } table. Used identically for carrier and
-- fridge, which is the point of having one function rather than two.
function Meat.WeightOf(counts: { [string]: number }): number
	local total = 0
	for meatId, count in pairs(counts) do
		local def = Meat.Get(meatId)
		if def then
			total += def.weight * count
		end
	end
	return total
end

-- Total cash value before multipliers. The multiplier is applied once, at
-- checkout, by whoever resolves the sale (ECONOMY §1).
function Meat.ValueOf(counts: { [string]: number }): number
	local total = 0
	for meatId, count in pairs(counts) do
		local def = Meat.Get(meatId)
		if def then
			total += def.value * count
		end
	end
	return total
end

function Meat.CountOf(counts: { [string]: number }): number
	local total = 0
	for _, count in pairs(counts) do
		total += count
	end
	return total
end

return Meat
