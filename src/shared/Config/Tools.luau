--!strict
--[[
	TOOLS — cosmetic axe models for D-017.

	Damage comes only from Config.Upgrades.axe. ToolService swaps visuals at the
	configured thresholds and attaches them at AxeGrip.
]]

local Types = require(script.Parent.Parent.Types)

local Tools = {}

Tools.Defs = {
	{ id = "worn", displayName = "Worn Axe", minLevel = 1, modelName = "axe_worn" } :: Types.ToolDef,
	{ id = "steel", displayName = "Steel Axe", minLevel = 4, modelName = "axe_steel" } :: Types.ToolDef,
	{ id = "bone", displayName = "Bone Axe", minLevel = 7, modelName = "axe_bone" } :: Types.ToolDef,
	{ id = "aurora", displayName = "Aurora Axe", minLevel = 10, modelName = "axe_aurora" } :: Types.ToolDef,
}

Tools.GripAttachment = "AxeGrip"
Tools.SwingAnimation = "Swing"

function Tools.ForLevel(level: number): Types.ToolDef
	local best = Tools.Defs[1]
	for _, def in ipairs(Tools.Defs) do
		if level >= def.minLevel then
			best = def
		end
	end
	return best
end

return Tools
