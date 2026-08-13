--!strict
--[[
	UPGRADES — source: docs/ECONOMY.md §2.

	Costs are LITERAL INTEGERS, transcribed from the doc, not computed at runtime.
	This is deliberate: a formula silently drifts from the design doc the moment
	someone tweaks a growth rate, and then the doc and the game disagree with
	nobody noticing. A literal table cannot drift — and E1 asserts the sums.

		values[level]  → effect at that level          (#values == maxLevel)
		costs[n]       → cash to go from level n to n+1 (#costs == maxLevel - 1)

	So costs[1] is the price of reaching level 2. There is no cost to reach 1.
]]

local Types = require(script.Parent.Parent.Types)

local Upgrades = {}

Upgrades.Tracks = {
	pack = {
		id = "pack",
		displayName = "Pack",
		unit = "weight",
		maxLevel = 10,
		-- 20, +12 per level
		values = { 20, 32, 44, 56, 68, 80, 92, 104, 116, 128 },
		-- round(150 * 1.9^(n-1)) — total to max: 53,629
		costs = { 150, 285, 542, 1029, 1955, 3715, 7059, 13412, 25482 },
	} :: Types.UpgradeDef,

	boots = {
		id = "boots",
		displayName = "Boots",
		unit = "studs/s",
		maxLevel = 10,
		-- 16, +1.2 per level. Ceiling 28 (GameConfig.MaxWalkSpeed).
		values = { 16, 17.2, 18.4, 19.6, 20.8, 22, 23.2, 24.4, 25.6, 26.8 },
		-- 250 * 2^(n-1) — total to max: 127,750
		costs = { 250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000 },
	} :: Types.UpgradeDef,

	harpoon = {
		id = "harpoon",
		displayName = "Harpoon",
		unit = "dmg",
		maxLevel = 10,
		-- x1.7 per level. L10 = 1190 kills a 7,500hp Titan in ~7 swings (~3.8s),
		-- which is ECONOMY §7 rule 3's ceiling — past 8 swings, holding the prompt
		-- stops being satisfying and becomes a chore.
		values = { 10, 17, 29, 49, 84, 143, 242, 412, 700, 1190 },
		-- round(200 * 2.15^(n-1)) — total to max: 170,581
		costs = { 200, 430, 925, 1988, 4274, 9190, 19759, 42481, 91334 },
	} :: Types.UpgradeDef,
}

Upgrades.Order = { "pack", "boots", "harpoon" }

function Upgrades.Get(track: string): Types.UpgradeDef?
	return (Upgrades.Tracks :: any)[track]
end

-- Effect value at a level. Clamps rather than erroring — a bad level is a caller
-- bug, but returning nil here would turn it into a nil-arithmetic crash three
-- frames later, somewhere unrelated.
function Upgrades.GetValue(track: string, level: number): number
	local def = Upgrades.Get(track)
	if not def then return 0 end
	local clamped = math.clamp(math.floor(level), 1, def.maxLevel)
	return def.values[clamped]
end

-- Cost to go from `level` to `level + 1`. nil means there is no next level.
function Upgrades.GetCost(track: string, level: number): number?
	local def = Upgrades.Get(track)
	if not def then return nil end
	if level < 1 or level >= def.maxLevel then return nil end
	return def.costs[level]
end

function Upgrades.IsMaxed(track: string, level: number): boolean
	local def = Upgrades.Get(track)
	return def ~= nil and level >= def.maxLevel
end

-- Total cash to take a track from 1 to max. Asserted against ECONOMY §2 in E1.
function Upgrades.TotalCost(track: string): number
	local def = Upgrades.Get(track)
	if not def then return 0 end
	local sum = 0
	for _, c in ipairs(def.costs) do sum += c end
	return sum
end

return Upgrades
