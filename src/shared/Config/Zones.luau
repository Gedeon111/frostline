--!strict
--[[
	ZONES — source: docs/ECONOMY.md §3, lighting from docs/ART_BIBLE.md §3.

	NO GEOMETRY LIVES HERE (D-009). Zones are hand-built in Studio under
	Workspace.World.<id>. What this file holds is gameplay data plus the *names*
	of marker instances the code looks up.

	Those names are the contract between whoever builds a zone and the code that
	reads it: CreatureService finds `spawnRegion` by name, SellService finds
	`sellPads`, ZoneService finds `barrier`. Rename one in Studio and the service
	stops working with no error — so renaming a marker is a contract change and
	needs an RFC, not a tidy-up.
]]

local Types = require(script.Parent.Parent.Types)

local Zones = {}

Zones.Defs = {
	shelf_ice = {
		id = "shelf_ice",
		displayName = "Shelf Ice",
		order = 1,
		unlockCost = 0,             -- starting zone
		creatureTier = "snow_cub",
		population = 25,
		spawnRegion = "SpawnZone",
		sellPads = { "SellPad" },
		barrier = "Barrier",
		lighting = {
			ClockTime = 14,
			Ambient = Color3.fromHex("B8C8D0"),
			OutdoorAmbient = Color3.fromHex("B8C8D0"),
			FogEnd = 900,
			FogColor = Color3.fromHex("F2F6F8"),   -- snow
		},
	} :: Types.ZoneDef,

	glacier_ridge = {
		id = "glacier_ridge",
		displayName = "Glacier Ridge",
		order = 2,
		unlockCost = 800,
		creatureTier = "frost_bear",
		population = 25,
		spawnRegion = "SpawnZone",
		sellPads = { "SellPad" },
		barrier = "Barrier",
		lighting = {
			ClockTime = 10,
			Ambient = Color3.fromHex("A0BCCC"),
			OutdoorAmbient = Color3.fromHex("A0BCCC"),
			FogEnd = 700,
			FogColor = Color3.fromHex("7FB2C9"),   -- ice
		},
	} :: Types.ZoneDef,

	crevasse_fields = {
		id = "crevasse_fields",
		displayName = "Crevasse Fields",
		order = 3,
		unlockCost = 8000,
		creatureTier = "ice_bear",
		population = 25,
		spawnRegion = "SpawnZone",
		sellPads = { "SellPad" },
		barrier = "Barrier",
		lighting = {
			ClockTime = 16,
			Ambient = Color3.fromHex("8098A8"),
			OutdoorAmbient = Color3.fromHex("8098A8"),
			FogEnd = 500,
			FogColor = Color3.fromHex("2E5C73"),   -- iceDeep
		},
	} :: Types.ZoneDef,

	aurora_basin = {
		id = "aurora_basin",
		displayName = "Aurora Basin",
		order = 4,
		unlockCost = 60000,
		creatureTier = "aurora_bear",
		population = 25,
		spawnRegion = "SpawnZone",
		sellPads = { "SellPad" },
		barrier = "Barrier",
		lighting = {
			ClockTime = 0,
			Ambient = Color3.fromHex("2A3A4A"),
			OutdoorAmbient = Color3.fromHex("2A3A4A"),
			FogEnd = 600,
			FogColor = Color3.fromHex("101820"),   -- night
		},
	} :: Types.ZoneDef,

	black_ice = {
		id = "black_ice",
		displayName = "The Black Ice",
		order = 5,
		unlockCost = 400000,
		creatureTier = "titan_bear",
		population = 25,
		spawnRegion = "SpawnZone",
		sellPads = { "SellPad" },
		barrier = "Barrier",
		lighting = {
			ClockTime = 2,
			Ambient = Color3.fromHex("181818"),
			OutdoorAmbient = Color3.fromHex("181818"),
			FogEnd = 350,
			FogColor = Color3.fromHex("101820"),
		},
	} :: Types.ZoneDef,
}

-- Unlock sequence. ZoneService enforces this — order cannot be skipped, even by
-- a direct remote call with enough cash.
Zones.Order = {
	"shelf_ice", "glacier_ridge", "crevasse_fields", "aurora_basin", "black_ice",
}

Zones.StartingZone = "shelf_ice"
Zones.LightingTweenSeconds = 1.5

function Zones.Get(zoneId: string): Types.ZoneDef?
	return (Zones.Defs :: any)[zoneId]
end

-- The zone that must be unlocked before `zoneId`. nil for the starting zone.
function Zones.Previous(zoneId: string): string?
	local def = Zones.Get(zoneId)
	if not def or def.order <= 1 then return nil end
	return Zones.Order[def.order - 1]
end

return Zones
