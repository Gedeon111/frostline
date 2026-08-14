--!strict
--[[
	WORKERS — normal-cash automation curves. Level zero means locked.
]]

local Types = require(script.Parent.Parent.Types)

local Workers = {}

Workers.LockedLevel = 0
Workers.UnlockedLevel = 1
Workers.ActiveStarterItemsPerMinuteBaseline = 15
Workers.MaxInitialHunterFraction = 0.25

Workers.Defs = {
	stocker = {
		id = "stocker",
		displayName = "Stocker",
		unlockCost = 250,
		levels = {
			{ cycleSeconds = 3, unitsPerCycle = 1, upgradeCost = 600 },
			{ cycleSeconds = 2.4, unitsPerCycle = 1, upgradeCost = 1500 },
			{ cycleSeconds = 1.9, unitsPerCycle = 1, upgradeCost = 4000 },
			{ cycleSeconds = 1.5, unitsPerCycle = 1, upgradeCost = 10000 },
			{ cycleSeconds = 1.2, unitsPerCycle = 1 },
		},
	} :: Types.WorkerDef,
	cashier = {
		id = "cashier",
		displayName = "Cashier",
		unlockCost = 750,
		levels = {
			{ cycleSeconds = 1.4, unitsPerCycle = 1, upgradeCost = 1800 },
			{ cycleSeconds = 1.2, unitsPerCycle = 1, upgradeCost = 4500 },
			{ cycleSeconds = 1, unitsPerCycle = 1, upgradeCost = 11000 },
			{ cycleSeconds = 0.85, unitsPerCycle = 1, upgradeCost = 28000 },
			{ cycleSeconds = 0.7, unitsPerCycle = 1 },
		},
	} :: Types.WorkerDef,
	hunter = {
		id = "hunter",
		displayName = "Hunter",
		unlockCost = 2500,
		levels = {
			{ cycleSeconds = 20, unitsPerCycle = 1, upgradeCost = 6000 },
			{ cycleSeconds = 18, unitsPerCycle = 1, upgradeCost = 15000 },
			{ cycleSeconds = 16, unitsPerCycle = 1, upgradeCost = 40000 },
			{ cycleSeconds = 14, unitsPerCycle = 1, upgradeCost = 100000 },
			{ cycleSeconds = 12, unitsPerCycle = 1 },
		},
	} :: Types.WorkerDef,
}

Workers.Order = { "stocker", "cashier", "hunter" }

function Workers.Get(workerId: string): Types.WorkerDef?
	return (Workers.Defs :: any)[workerId]
end

return Workers
