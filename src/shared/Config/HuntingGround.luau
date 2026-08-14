--!strict
--[[
	HUNTINGGROUND — the one shared wilderness used by all plots.
]]

return {
	WorldFolderName = "World",
	FolderName = "HuntingGround",
	SpawnRegionName = "SpawnZone",
	RuntimeFolderName = "Creatures",
	StarterTierId = "snow_cub",
	Population = 25,
	MinSpawnSpacing = 12,
	WanderRadius = 30,
	WanderInterval = { min = 4, max = 8 },
	PlayerEntranceNames = {
		"PlayerEntrance01", "PlayerEntrance02", "PlayerEntrance03", "PlayerEntrance04",
		"PlayerEntrance05", "PlayerEntrance06", "PlayerEntrance07", "PlayerEntrance08",
	},
}
