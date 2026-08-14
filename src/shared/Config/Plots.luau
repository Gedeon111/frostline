--!strict
--[[
	PLOTS — exact eight-plot world-marker contract.
]]

local Plots = {}

Plots.WorldFolderName = "World"
Plots.FolderName = "Plots"
Plots.Count = 8
Plots.Names = { "Plot01", "Plot02", "Plot03", "Plot04", "Plot05", "Plot06", "Plot07", "Plot08" }
Plots.AssignmentOrder = Plots.Names
Plots.MarkerWaitSeconds = 5
Plots.CharacterSpawnOffset = Vector3.new(0, 3, 0)

Plots.RequiredPaths = {
	"PlayerSpawn",
	"StoreEntrance",
	"CustomerSpawn",
	"CustomerExit",
	"CustomerPath",
	"Refrigerator",
	"Refrigerator/UnloadZone",
	"Refrigerator/CustomerPickup",
	"Refrigerator/MeatDisplay",
	"Register",
	"Register/OperatorZone",
	"Register/QueuePoints",
	"Register/CashOrigin",
	"WorkerComputer",
	"HunterDropoff",
	"HuntGate",
}

return Plots
