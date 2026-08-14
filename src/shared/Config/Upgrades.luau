--!strict
--[[
	UPGRADES — literal v2 effect/cost tables.

	ActiveOrder is the purchase contract. LegacyTracks exists only so the
	pre-A16/A20 services remain bootable during the atomic transition.
]]

local Types = require(script.Parent.Parent.Types)

local Upgrades = {}

Upgrades.InitialLevel = 1

local carrierValues = { 20, 32, 44, 56, 68, 80, 92, 104, 116, 128 }
local carrierCosts = { 150, 285, 542, 1029, 1955, 3715, 7059, 13412, 25482 }
local axeValues = { 10, 17, 29, 49, 84, 143, 242, 412, 700, 1190 }
local axeCosts = { 200, 430, 925, 1988, 4274, 9190, 19759, 42481, 91334 }

Upgrades.Tracks = {
	axe = {
		id = "axe",
		displayName = "Axe",
		unit = "damage",
		maxLevel = 10,
		values = axeValues,
		costs = axeCosts,
	} :: Types.UpgradeDef,

	carrier = {
		id = "carrier",
		displayName = "Carrier",
		unit = "weight",
		maxLevel = 10,
		values = carrierValues,
		costs = carrierCosts,
	} :: Types.UpgradeDef,

	fridge = {
		id = "fridge",
		displayName = "Refrigerator",
		unit = "weight",
		maxLevel = 10,
		values = { 40, 64, 88, 112, 136, 160, 184, 208, 232, 256 },
		costs = { 100, 225, 506, 1139, 2563, 5767, 12976, 29196, 65691 },
	} :: Types.UpgradeDef,

	register = {
		id = "register",
		displayName = "Register",
		unit = "seconds",
		maxLevel = 10,
		values = { 1.2, 1.1, 1, 0.9, 0.82, 0.75, 0.68, 0.62, 0.56, 0.5 },
		costs = { 200, 450, 1013, 2279, 5128, 11538, 25961, 58412, 131427 },
	} :: Types.UpgradeDef,
}

Upgrades.ActiveOrder = { "axe", "carrier", "fridge", "register" }
Upgrades.Order = Upgrades.ActiveOrder

-- Temporary definitions used only by services not yet adapted to v2.
Upgrades.LegacyTracks = {
	pack = {
		id = "pack",
		displayName = "Pack (legacy)",
		unit = "weight",
		maxLevel = 10,
		values = carrierValues,
		costs = carrierCosts,
	} :: Types.UpgradeDef,
	boots = {
		id = "boots",
		displayName = "Boots (legacy)",
		unit = "studs/s",
		maxLevel = 10,
		values = { 16, 17.2, 18.4, 19.6, 20.8, 22, 23.2, 24.4, 25.6, 26.8 },
		costs = { 250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000 },
	} :: Types.UpgradeDef,
	harpoon = {
		id = "harpoon",
		displayName = "Harpoon (legacy)",
		unit = "damage",
		maxLevel = 10,
		values = axeValues,
		costs = axeCosts,
	} :: Types.UpgradeDef,
}

function Upgrades.GetActive(track: string): Types.UpgradeDef?
	return (Upgrades.Tracks :: any)[track]
end

function Upgrades.IsActive(track: string): boolean
	return Upgrades.GetActive(track) ~= nil
end

function Upgrades.Get(track: string): Types.UpgradeDef?
	return Upgrades.GetActive(track) or (Upgrades.LegacyTracks :: any)[track]
end

function Upgrades.GetValue(track: string, level: number): number
	local def = Upgrades.Get(track)
	if not def then
		return 0
	end
	local clamped = math.clamp(math.floor(level), Upgrades.InitialLevel, def.maxLevel)
	return def.values[clamped]
end

function Upgrades.GetCost(track: string, level: number): number?
	local def = Upgrades.Get(track)
	if not def then
		return nil
	end
	if level < Upgrades.InitialLevel or level >= def.maxLevel then
		return nil
	end
	return def.costs[level]
end

function Upgrades.IsMaxed(track: string, level: number): boolean
	local def = Upgrades.Get(track)
	return def ~= nil and level >= def.maxLevel
end

function Upgrades.TotalCost(track: string): number
	local def = Upgrades.Get(track)
	if not def then
		return 0
	end
	local sum = 0
	for _, cost in ipairs(def.costs) do
		sum += cost
	end
	return sum
end

return Upgrades
