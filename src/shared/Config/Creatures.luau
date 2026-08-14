--!strict
--[[
	CREATURES — V2 (D-017). Source: ECONOMY §2, tints/scale from ART_BIBLE.

	ONE TIER. GDD §12 scopes the corrected slice to a single creature, and the
	four higher tiers from the five-zone design are gone with the zones they
	belonged to. They return as "additional creature regions" after the slice
	proves fun, each with its own meat ids — not as a table of numbers waiting
	for a game that no longer exists.

	The V1 shape carried `meatWeight` and `meatValue` directly on the creature.
	V2 carries a `meatId` instead, and weight and value live on the meat
	(Config.Meat). That indirection is the whole point of ECONOMY §2's rule that
	a rare variant must map to a DISTINCT meat id: a golden kill has to yield
	genuinely different inventory, not a recoloured model over ordinary stock.
]]

local Types = require(script.Parent.Parent.Types)
local Palette = require(script.Parent.Palette)

local Creatures = {}

Creatures.Tiers = {
	--[[
		SNOW CUB — the starter, retained verbatim from the prototype because it
		already worked in Studio (ECONOMY §2). 30 HP, 2 drops.

		Weight 2 and value 5 per item now live on `frost_cut`, so a kill is
		still 4 weight and 10 base value.
	]]
	snow_cub = {
		id = "snow_cub",
		displayName = "Snow Cub",
		hp = 30,
		dropCount = 2,
		meatId = "frost_cut",
		respawnSeconds = 8,
		modelName = "snow_cub",
		shoulderHeight = 4,
		tint = Palette.bone,
	} :: Types.CreatureTier,
}

Creatures.Order = { "snow_cub" }

-- The tier that spawns in the shared hunting ground. One entry today; when
-- regions return, this becomes a per-region lookup rather than a constant.
Creatures.StarterTier = "snow_cub"

--[[
	Variants, rolled per spawn.

	Golden is the screenshot moment and the reason someone posts about the game.
	It overrides the MEAT ID, so the value difference is carried by the stock a
	customer actually buys rather than by a multiplier applied somewhere else.

	A9 must guarantee at least one per reasonable window rather than rolling raw
	2% — pure chance produces dry spells that players read as a bug.
]]
Creatures.Variants = {
	golden = {
		id = "golden",
		chance = 0.02,
		meatId = "frost_cut_golden",
		tint = Palette.gold,
		emissive = true,
	} :: Types.CreatureVariant,
}

function Creatures.Get(tierId: string): Types.CreatureTier?
	return (Creatures.Tiers :: any)[tierId]
end

function Creatures.GetVariant(variantId: string): Types.CreatureVariant?
	return (Creatures.Variants :: any)[variantId]
end

--[[
	Which meat a kill yields, honouring the variant.

	This is the one place the variant→meat mapping happens. CreatureService (A19)
	calls it on death; nothing else should re-derive it, or a variant will end
	up meaning two different things in two services.
]]
function Creatures.MeatIdFor(tierId: string, variantId: string?): string?
	if variantId then
		local variant = Creatures.GetVariant(variantId)
		if variant then
			return variant.meatId
		end
	end
	local tier = Creatures.Get(tierId)
	return tier and tier.meatId or nil
end

return Creatures
