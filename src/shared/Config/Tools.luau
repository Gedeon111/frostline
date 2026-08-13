--!strict
--[[
	TOOLS — harpoon models, source: docs/ECONOMY.md §2, docs/ART_BIBLE.md.

	Cosmetic only. Damage comes from Config.Upgrades.harpoon and nothing else —
	the model is feedback for a stat that already exists. If ToolService ever
	starts contributing damage, there are two sources of truth for the same
	number, and the economy stops being tunable from one place (job A10).
]]

local Types = require(script.Parent.Parent.Types)

local Tools = {}

-- Swapped at harpoon upgrade levels 1 / 4 / 7 / 10.
Tools.Defs = {
	{ id = "rusted", displayName = "Rusted Harpoon", minLevel = 1, modelName = "harpoon_rusted" } :: Types.ToolDef,
	{ id = "steel",  displayName = "Steel Harpoon",  minLevel = 4, modelName = "harpoon_steel"  } :: Types.ToolDef,
	{ id = "bone",   displayName = "Bone Harpoon",   minLevel = 7, modelName = "harpoon_bone"   } :: Types.ToolDef,
	{ id = "aurora", displayName = "Aurora Harpoon", minLevel = 10, modelName = "harpoon_aurora" } :: Types.ToolDef,
}

Tools.GripAttachment = "HarpoonGrip"

-- Highest-tier tool unlocked at this harpoon level.
function Tools.ForLevel(level: number): Types.ToolDef
	local best = Tools.Defs[1]
	for _, def in ipairs(Tools.Defs) do
		if level >= def.minLevel then best = def end
	end
	return best
end

return Tools
