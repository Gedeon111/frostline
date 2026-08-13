--!strict
--[[
	CREATURESERVICE — spawning, HP, respawn, drops.

	Replaces the per-model `Main` script that used to live inside the bear.
	125 creatures each running their own script means 125 script instances, no
	central place to tune anything, and behaviour that can't be version
	controlled because Workspace isn't in git.

		CreatureService.Damage(model, 84)        --> died, overkill
		CreatureService.GetInfo(model)           --> { tierId, hp, maxHp, ... }
		CreatureService.Died:Connect(fn)         --> (killer, model, tierId, variant)

	HP IS SERVER-SIDE ONLY (D-003). `Humanoid.Health` is mirrored for visuals but
	is never read for gameplay: it's a replicated property, and treating it as
	authoritative invites confusion about who owns the number. The table here is
	the truth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Zones = require(Shared.Config.Zones)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local InventoryService = require(ServerScriptService.Services.InventoryService)

local CreatureService = {}

CreatureService.Died = Signal.new()
CreatureService.Spawned = Signal.new()

export type CreatureInfo = {
	model: Model,
	tierId: string,
	zoneId: string,
	variant: string?,
	hp: number,
	maxHp: number,
	home: Vector3,
	alive: boolean,
}

-- Model -> info. The authoritative record; nothing gameplay-relevant is stored
-- on the instance where a client could see or influence it.
local living: { [Model]: CreatureInfo } = {}
local folder: Folder

-- ── Templates ───────────────────────────────────────────────────────────────

--[[
	One shared base model, scaled and tinted per tier (ART_BIBLE §4: "same mesh,
	scaled + retinted"). A tier gets its own model as soon as one exists under
	Assets.Creatures with its `modelName`; until then it falls back to the base.

	No template at all still spawns something — a blocky placeholder — so the
	rest of the game stays testable before the art lands.
]]
local function getTemplate(tier: any): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local creatures = assets and assets:FindFirstChild("Creatures")
	if not creatures then
		return nil
	end
	local exact = creatures:FindFirstChild(tier.modelName)
	if exact and exact:IsA("Model") then
		return exact
	end
	local base = creatures:FindFirstChild("bear_base")
	return (base and base:IsA("Model")) and base or nil
end

local function buildPlaceholder(tier: any): Model
	local model = Instance.new("Model")
	model.Name = tier.modelName

	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(tier.shoulderHeight * 0.6, tier.shoulderHeight, tier.shoulderHeight * 1.4)
	body.Color = tier.tint
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.Parent = model

	model.PrimaryPart = body
	return model
end

-- ── Spawning ────────────────────────────────────────────────────────────────

local function sampleSpawnPoint(region: BasePart, taken: { Vector3 }): Vector3?
	-- Rejection sampling against MinSpawnSpacing. Clumped creatures read as a
	-- bug rather than as wildlife, and they make one swing hit three targets.
	local half = region.Size * 0.5
	local minSq = GameConfig.MinSpawnSpacing * GameConfig.MinSpawnSpacing

	for _ = 1, 30 do
		local offset = Vector3.new(
			(math.random() * 2 - 1) * half.X,
			0,
			(math.random() * 2 - 1) * half.Z
		)
		local point = region.Position + offset

		local ok = true
		for _, other in ipairs(taken) do
			local d = point - other
			if d:Dot(d) < minSq then
				ok = false
				break
			end
		end
		if ok then
			return point
		end
	end
	return nil -- region too small for the requested population; caller logs it
end

local function spawnOne(tierId: string, zoneId: string, position: Vector3): Model?
	local tier = Creatures.Get(tierId)
	if not tier then
		Log.warn("Creature", "unknown tier '%s'", tierId)
		return nil
	end

	local template = getTemplate(tier)
	local model: Model
	if template then
		model = template:Clone()
		-- Scale the shared base to this tier's size. ScaleTo handles Motor6D
		-- rigs, so the animations keep working at any scale.
		local _, size = model:GetBoundingBox()
		if size.Y > 0 then
			model:ScaleTo(tier.shoulderHeight / size.Y)
		end
	else
		model = buildPlaceholder(tier)
		Log.once("noasset_" .. tierId, "Creature", "no model for '%s', using placeholder", tierId)
	end

	model.Name = tierId

	-- Roll the variant before tinting so golden overrides the tier colour.
	local variant: string? = nil
	local tint = tier.tint
	local golden = Creatures.Variants.golden
	if math.random() < golden.chance then
		variant = golden.id
		tint = golden.tint
	end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Color = tint
		end
	end

	if model.PrimaryPart then
		model:PivotTo(CFrame.new(position + Vector3.new(0, tier.shoulderHeight * 0.5, 0)))
	end
	model.Parent = folder

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		-- Mirror only. Gameplay HP lives in `living`.
		hum.MaxHealth = tier.hp
		hum.Health = tier.hp
		hum.WalkSpeed = 8
		hum.BreakJointsOnDeath = false
	end

	living[model] = {
		model = model,
		tierId = tierId,
		zoneId = zoneId,
		variant = variant,
		hp = tier.hp,
		maxHp = tier.hp,
		home = position,
		alive = true,
	}

	CreatureService.Spawned:Fire(model, tierId, variant)
	-- Tell the clients. Without this the CreatureSpawned remote never fires and
	-- HarvestController (B2) has nothing to attach a prompt to, so the game is
	-- unplayable even though everything server-side works.
	Net.FireAll("CreatureSpawned", model, tierId, variant)
	return model
end

-- ── Damage & death ──────────────────────────────────────────────────────────

--[[
	Applies damage. Returns (died, overkill).

	Damaging an already-dead creature returns false and grants nothing — two
	players finishing the same bear in the same frame must not both get drops.
]]
function CreatureService.Damage(model: Model, amount: number, killer: Player?): (boolean, number)
	local info = living[model]
	if not info or not info.alive or amount <= 0 then
		return false, 0
	end

	info.hp -= amount

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = math.max(0, info.hp)
	end

	if info.hp > 0 then
		-- Flinch hook the model's animation reacts to.
		model:SetAttribute("Flinch", true)
		return false, 0
	end

	local overkill = -info.hp
	info.alive = false

	local tier = Creatures.Get(info.tierId)
	if tier and killer then
		local drops = tier.dropCount
		if info.variant == "golden" then
			-- Golden multiplies VALUE, not quantity (ECONOMY §1) — more meat
			-- would just overflow the pack and hide the reward.
			drops = tier.dropCount
		end
		local added = InventoryService.TryAdd(killer, info.tierId, drops)
		if added < drops then
			-- The kill still counts. Losing it to a full pack feels like theft.
			Log.info("Creature", "%s pack full: %d/%d meat", killer.Name, added, drops)
		end
	end

	CreatureService.Died:Fire(killer, model, info.tierId, info.variant)
	Net.FireAll("CreatureDied", model, info.tierId, info.variant)

	local respawnIn = tier and tier.respawnSeconds or 10
	local zoneId, tierId, home = info.zoneId, info.tierId, info.home
	living[model] = nil

	task.delay(0.8, function() -- let the death read before it vanishes
		model:Destroy()
	end)

	task.delay(respawnIn, function()
		local region = CreatureService.GetSpawnRegion(zoneId)
		local point = region and sampleSpawnPoint(region, {}) or home
		spawnOne(tierId, zoneId, point)
	end)

	return true, overkill
end

function CreatureService.GetInfo(model: Model): CreatureInfo?
	return living[model]
end

function CreatureService.IsAlive(model: Model): boolean
	local info = living[model]
	return info ~= nil and info.alive
end

function CreatureService.CountAlive(): number
	local n = 0
	for _, info in pairs(living) do
		if info.alive then
			n += 1
		end
	end
	return n
end

function CreatureService.GetSpawnRegion(zoneId: string): BasePart?
	local zone = Zones.Get(zoneId)
	local world = workspace:FindFirstChild("World")
	local zoneFolder = world and world:FindFirstChild(zoneId)
	if not (zone and zoneFolder) then
		return nil
	end
	local region = zoneFolder:FindFirstChild(zone.spawnRegion)
	return (region and region:IsA("BasePart")) and region or nil
end

-- ── Wander ──────────────────────────────────────────────────────────────────

--[[
	One loop for every creature, not one per creature. 125 individual
	`while true` loops is 125 coroutines competing for the scheduler; a single
	pass that nudges each idle creature costs a fraction of that.

	Offsets are measured from `home`, not from the current position — measuring
	from the current position makes them random-walk off the map over time.
]]
local function wanderLoop()
	while true do
		task.wait(GameConfig.CreatureWanderInterval.min)
		for model, info in pairs(living) do
			if info.alive and model.Parent then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and math.random() < 0.4 then
					local offset = Vector3.new(
						(math.random() * 2 - 1) * GameConfig.CreatureWanderRadius,
						0,
						(math.random() * 2 - 1) * GameConfig.CreatureWanderRadius
					)
					hum:MoveTo(info.home + offset)
				end
			end
		end
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function CreatureService.Init()
	folder = workspace:FindFirstChild("Creatures") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Creatures"
		folder.Parent = workspace
	end
	folder:ClearAllChildren() -- a stale set from a previous run isn't tracked
end

function CreatureService.Start()
	for _, zoneId in ipairs(Zones.Order) do
		local zone = Zones.Get(zoneId)
		if zone then
			local region = CreatureService.GetSpawnRegion(zoneId)
			if not region then
				-- Zone geometry not built yet (C2/C3). Skip rather than fail:
				-- the rest of the game must stay bootable.
				Log.once("nozone_" .. zoneId, "Creature", "no spawn region for '%s', skipping", zoneId)
			else
				local taken: { Vector3 } = {}
				local placed = 0
				for _ = 1, zone.population do
					local point = sampleSpawnPoint(region, taken)
					if not point then
						break
					end
					table.insert(taken, point)
					if spawnOne(zone.creatureTier, zoneId, point) then
						placed += 1
					end
				end
				if placed < zone.population then
					Log.warn("Creature", "%s: placed %d/%d — spawn region too small for %d-stud spacing",
						zoneId, placed, zone.population, GameConfig.MinSpawnSpacing)
				end
				Log.info("Creature", "%s: %d x %s", zoneId, placed, zone.creatureTier)
			end
		end
	end

	--[[
		Creatures spawn at server start, long before most players join, so a
		joining client has missed every CreatureSpawned. Replay the current set
		to them or they see no prompts at all on anything that existed before
		they arrived — which, for the first player of a session, is everything.
	]]
	local function replayTo(player: Player)
		for model, info in pairs(living) do
			if info.alive and model.Parent then
				Net.Fire(player, "CreatureSpawned", model, info.tierId, info.variant)
			end
		end
	end

	Players.PlayerAdded:Connect(function(player)
		-- Wait for the client's controllers to exist, or the event lands before
		-- anything is listening.
		task.delay(2, function()
			if player.Parent == Players then
				replayTo(player)
			end
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.delay(2, function()
			if player.Parent == Players then
				replayTo(player)
			end
		end)
	end

	task.spawn(wanderLoop)

	-- Drop tracking for a player who leaves mid-fight: nothing to clean up,
	-- since nothing is keyed by player. Kept as a note so nobody adds one.
	Players.PlayerRemoving:Connect(function() end)
end

return CreatureService
