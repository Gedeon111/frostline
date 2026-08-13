--!strict
--[[
	ZONESERVICE — zone unlocking, membership, barriers, teleport.

	CombatService already refuses swings in zones the player hasn't unlocked;
	this is what lets them unlock one. Without it there is exactly one zone
	forever and that check is unreachable.

	THREE RULES THIS ENFORCES, ALL SERVER-SIDE:

	1. Order cannot be skipped. Even with the cash for Black Ice, a player must
	   own every zone before it. Otherwise a single lucky payout jumps straight
	   to the highest-value tier and the whole progression curve is bypassed.
	2. Unlocking is atomic. Cash never leaves without the zone arriving — the
	   spend happens last, after every other check has passed.
	3. Teleport only into unlocked zones. Otherwise the barrier is decorative
	   and RequestTeleport becomes the exploit instead.

	Geometry is optional. Zones with no folder built yet still unlock and still
	track membership from config; barriers and teleport simply do nothing until
	C2/C3 build them. The game must stay playable while the world is half-built.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Types = require(Shared.Types)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local StateService = require(ServerScriptService.Services.StateService)

local ZoneService = {}

-- (player, zoneId, previousZoneId) — SoundController and the HUD zone label
-- read this rather than polling.
ZoneService.ZoneChanged = Signal.new()
ZoneService.ZoneUnlocked = Signal.new()

local currentZone: { [Player]: string } = {}

-- Forward declaration: unlock() below needs this, but it is defined with the
-- rest of the barrier code further down. Without this the call resolves as a
-- global at runtime and is nil.
local applyPlayerGroup: (player: Player) -> ()

-- ── Queries ─────────────────────────────────────────────────────────────────

function ZoneService.IsUnlocked(player: Player, zoneId: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.unlockedZones[zoneId] == true
end

function ZoneService.GetZone(player: Player): string?
	return currentZone[player]
end

-- The zone a player is standing in, by testing the spawn regions. Returns nil
-- when they're between zones (on the plot strip, in the outpost, mid-air).
local function zoneAt(position: Vector3): string?
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, zoneId in ipairs(Zones.Order) do
		local def = Zones.Get(zoneId)
		local folder = def and world:FindFirstChild(zoneId)
		local region = folder and folder:FindFirstChild(def.spawnRegion)
		if region and region:IsA("BasePart") then
			local lp = region.CFrame:PointToObjectSpace(position)
			local half = region.Size * 0.5
			if math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z and math.abs(lp.Y) <= half.Y + 40 then
				return zoneId
			end
		end
	end
	return nil
end

-- ── Unlocking ───────────────────────────────────────────────────────────────

local function unlock(player: Player, zoneId: any): (boolean, Types.RefusalReason?)
	-- Argument sanity first: this arrives straight off a remote.
	if type(zoneId) ~= "string" then
		return false, "unknown_zone"
	end

	local def = Zones.Get(zoneId)
	if not def then
		return false, "unknown_zone"
	end

	local data = DataService.GetData(player)
	if not data then
		return false, "not_loaded"
	end

	if data.unlockedZones[zoneId] then
		return false, "already_owned"
	end

	-- Order. Checked before cost so the refusal explains the real reason: a
	-- player told "insufficient_funds" for a zone they could never buy yet
	-- would go and grind for nothing.
	local previous = Zones.Previous(zoneId)
	if previous and not data.unlockedZones[previous] then
		return false, "out_of_order"
	end

	if not CurrencyService.CanAfford(player, def.unlockCost) then
		return false, "insufficient_funds"
	end

	-- Spend LAST. Every other condition is already satisfied, so this cannot
	-- take cash and then fail to grant the zone.
	if not CurrencyService.Spend(player, def.unlockCost, "zone_unlock") then
		return false, "insufficient_funds"
	end

	data.unlockedZones[zoneId] = true
	StateService.Mark(player, "unlockedZones")

	applyPlayerGroup(player) -- they can now walk through this barrier
	ZoneService.ZoneUnlocked:Fire(player, zoneId)
	Net.Fire(player, "Notify", "unlock", def.displayName, nil)
	Log.info("Zone", "%s unlocked %s for %d", player.Name, zoneId, def.unlockCost)
	return true, nil
end

-- ── Teleport ────────────────────────────────────────────────────────────────

local function teleport(player: Player, zoneId: any)
	if type(zoneId) ~= "string" then
		return
	end
	local def = Zones.Get(zoneId)
	if not def then
		return
	end
	if not ZoneService.IsUnlocked(player, zoneId) then
		-- Without this the barrier is decoration and this remote is the way
		-- through it.
		Log.info("Zone", "%s tried to teleport into locked %s", player.Name, zoneId)
		return
	end

	local world = workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild(zoneId)
	local region = folder and folder:FindFirstChild(def.spawnRegion)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (region and region:IsA("BasePart") and root) then
		return -- geometry not built yet
	end

	char:PivotTo(CFrame.new((region :: BasePart).Position + Vector3.new(0, 6, 0)));
	(root :: BasePart).AssemblyLinearVelocity = Vector3.zero
end

-- ── Barriers ────────────────────────────────────────────────────────────────

--[[
	Per-player barriers via collision groups.

	Roblox has no per-player CanCollide — it is a replicated property, so one
	part cannot be solid for one player and not another. Collision groups can,
	because collision is defined between PAIRS of groups.

	The trick is that progression is linear, so a player only needs one number:
	the highest zone order they have unlocked. That gives 5 player groups rather
	than one per subset.

		Barrier_N  collides with  Player_P1 .. Player_P(N-1)     (still blocked)
		Barrier_N  passes through Player_PN .. Player_P5         (unlocked)

	A barrier is named per Config.Zones and lives at Workspace.World.<zone>.Barrier.
	It gates entry INTO its own zone, so barrier N is solid until zone N is owned.
]]

local PhysicsService = game:GetService("PhysicsService")

local PLAYER_GROUP = "ZoneProgress"   -- + order
local BARRIER_GROUP = "ZoneBarrier"   -- + order

local function setupCollisionGroups()
	for i = 1, #Zones.Order do
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, PLAYER_GROUP .. i)
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, BARRIER_GROUP .. i)
	end
	for barrier = 1, #Zones.Order do
		for progress = 1, #Zones.Order do
			-- Solid only while the player's progress is BELOW this barrier's zone.
			pcall(
				PhysicsService.CollisionGroupSetCollidable,
				PhysicsService,
				BARRIER_GROUP .. barrier,
				PLAYER_GROUP .. progress,
				progress < barrier
			)
		end
	end
end

-- Highest zone order this player owns. Drives which group they belong to.
local function progressOf(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 1
	end
	local best = 1
	for _, zoneId in ipairs(Zones.Order) do
		local def = Zones.Get(zoneId)
		if def and data.unlockedZones[zoneId] and def.order > best then
			best = def.order
		end
	end
	return best
end

function applyPlayerGroup(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local group = PLAYER_GROUP .. progressOf(player)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- Tags every barrier part with its zone's group. Re-run when geometry appears,
-- since C2/C3 may build zones after the server has started.
local function applyBarrierGroups()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, zoneId in ipairs(Zones.Order) do
		local def = Zones.Get(zoneId)
		local folder = def and world:FindFirstChild(zoneId)
		local barrier = folder and folder:FindFirstChild(def.barrier)
		if barrier then
			for _, d in ipairs(barrier:IsA("BasePart") and { barrier } or barrier:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CollisionGroup = BARRIER_GROUP .. def.order
				end
			end
		end
	end
end

-- ── Membership ──────────────────────────────────────────────────────────────

local function pollMembership()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local found = zoneAt((root :: BasePart).Position)
			local was = currentZone[player]
			if found ~= was then
				currentZone[player] = found
				ZoneService.ZoneChanged:Fire(player, found, was)
			end
		end
	end
end

function ZoneService.Init()
	Net.On("RequestUnlockZone", unlock)
	Net.On("RequestTeleport", teleport)
end

function ZoneService.Start()
	setupCollisionGroups()
	applyBarrierGroups()

	-- Character parts are recreated on every respawn, so the group has to be
	-- reapplied each time or a death silently re-blocks unlocked barriers.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			applyPlayerGroup(player)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			applyPlayerGroup(player)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			applyPlayerGroup(player)
		end)
	end

	DataService.Loaded:Connect(applyPlayerGroup)

	Players.PlayerRemoving:Connect(function(player)
		currentZone[player] = nil
	end)

	local interval = 1 / GameConfig.ZoneCheckHz
	task.spawn(function()
		while true do
			task.wait(interval)
			pollMembership()
		end
	end)

	-- Geometry may be built after startup; re-tag barriers periodically.
	task.spawn(function()
		while true do
			task.wait(10)
			applyBarrierGroups()
		end
	end)
end

return ZoneService
