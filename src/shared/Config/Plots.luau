--!strict
--[[
	PLOTS — the world contract in code. Source: ARCHITECTURE §7.

	These names are the contract between whoever builds a plot in Studio and the
	services that read it. PlotService validates all eight at startup and
	refuses duplicate assignment; a missing required marker fails loudly in
	debug and disables only the affected plot in production.

	Renaming a marker in Studio silently breaks a service with no error, so it
	is a contract change needing an architecture review — not a tidy-up
	(ARCHITECTURE §7).

	Nothing here describes geometry. Positions, sizes and decoration belong to
	the builder; only the NAMES and their required/optional status are fixed.
]]

local Plots = {}

-- GDD §4: eight private plots, exactly one player each per server session.
Plots.Count = 8

-- Plot01 .. Plot08. Zero-padded, because Studio sorts children as strings and
-- Plot10 would otherwise sort between Plot01 and Plot02 the day this grows.
Plots.FolderName = "Plots"
Plots.NamePrefix = "Plot"
Plots.NameDigits = 2

--[[
	Required markers, as paths relative to the plot folder.

	A plot missing any of these cannot run the loop, so PlotService disables it
	rather than assigning a player to a store they cannot use.
]]
Plots.RequiredMarkers = {
	"PlayerSpawn",
	"StoreEntrance",
	"CustomerSpawn",
	"CustomerExit",
	"Refrigerator",
	"Refrigerator/UnloadZone",
	"Refrigerator/CustomerPickup",
	"Register",
	"Register/OperatorZone",
	"Register/CashOrigin",
	"WorkerComputer",
	"HunterDropoff",
	"HuntGate",
}

--[[
	Ordered marker sequences. Each is a folder of children named 01..NN, walked
	in numeric order.

	`CustomerPath` is the route from the spawn to the store; `QueuePoints` are
	the standing positions at the register. Both need at least one entry — a
	queue with no points has nowhere to put a customer.
]]
Plots.OrderedMarkers = {
	CustomerPath = { path = "CustomerPath", minimum = 1 },
	QueuePoints = { path = "Register/QueuePoints", minimum = 1 },
}

-- Optional. Absent means the plot simply shows no meat in the fridge window.
Plots.OptionalMarkers = {
	"Refrigerator/MeatDisplay",
}

-- ── Shared hunting ground ───────────────────────────────────────────────────

--[[
	One wilderness shared by everyone (GDD §4), NOT a per-plot area.

	`PlayerEntrance01..NN` are the gates. ARCHITECTURE §7 requires every plot to
	have an equivalent route to at least one entrance, and creature distribution
	not to permanently favour one — both are V1 measurements, not properties
	this file can enforce.
]]
Plots.HuntingGroundName = "HuntingGround"
Plots.HuntingSpawnZone = "SpawnZone"
Plots.HuntingEntrancePrefix = "PlayerEntrance"

-- Root folder under Workspace holding both Plots and HuntingGround.
Plots.WorldFolderName = "World"

-- Formats an index as its plot instance name: 1 -> "Plot01".
function Plots.NameFor(index: number): string
	return string.format("%s%0" .. Plots.NameDigits .. "d", Plots.NamePrefix, index)
end

-- Every plot name, in order. The list PlotService validates at startup.
function Plots.AllNames(): { string }
	local names = {}
	for i = 1, Plots.Count do
		table.insert(names, Plots.NameFor(i))
	end
	return names
end

--[[
	Resolves a "Refrigerator/UnloadZone" style path under a plot.

	Returns nil rather than erroring: a missing marker is a builder problem that
	PlotService reports as a disabled plot, not a crash that takes the server
	down with it.
]]
function Plots.Resolve(plot: Instance, path: string): Instance?
	local current: Instance? = plot
	for segment in string.gmatch(path, "[^/]+") do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

return Plots
