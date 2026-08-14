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

local Creatures = require(Shared.Config.Creatures)
local HuntingGround = require(Shared.Config.HuntingGround)
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

--[[
	Parts whose top edge counts as "the shoulder", most specific first.

	`bear_base` is a Roblox-style rig, so UpperTorso is the real reference.
	Torso covers R6-style rigs and Body covers simple Part assemblies.
]]
local SHOULDER_PARTS = { "UpperTorso", "Torso", "Body" }

-- How far up and down to probe for ground at a spawn point. Not a gameplay
-- number — it only bounds the search, and 200 studs covers any plausible gap
-- between a SpawnZone marker and the terrain under it.
local GROUND_PROBE = 200

--[[
	The template's authored shoulder height, in studs.

	`Config.Creatures.shoulderHeight` means height AT THE SHOULDER, not total
	height. On a quadruped the head sits well above the shoulder, so dividing by
	the bounding box (which is what this used to do) leaves every creature short
	— measured at ~30% for snow_cub — and the error grows with tier, because it
	is proportional. titan_bear was arriving under 10 studs against a spec of 14.

	Falls back to total height when no recognised torso exists, so a future
	template with an unknown bone layout still spawns at a sane size instead of
	erroring or spawning at zero.
]]
local function authoredShoulderHeight(model: Model): number
	local lowest = math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			lowest = math.min(lowest, d.Position.Y - d.Size.Y * 0.5)
		end
	end
	if lowest == math.huge then
		return 0
	end

	for _, name in ipairs(SHOULDER_PARTS) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return (part.Position.Y + part.Size.Y * 0.5) - lowest
		end
	end

	local _, size = model:GetBoundingBox()
	return size.Y
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
	local minSq = HuntingGround.MinSpawnSpacing * HuntingGround.MinSpawnSpacing

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
		-- Scale the shared base so its SHOULDER lands on the tier's
		-- shoulderHeight. ScaleTo handles Motor6D rigs, so animations keep
		-- working at any scale.
		--[[
			ScaleTo sets scale ABSOLUTELY (1 = as authored), but the measurement
			below is taken at the template's CURRENT scale. If a template was
			saved at anything other than 1 — bear_base is at ~1.29 — dividing the
			target by the measured shoulder lands at `target / currentScale`
			instead of `target`. Multiplying the current scale back in cancels it,
			and the expression is correct for a template at scale 1 too.
		]]
		local shoulder = authoredShoulderHeight(model)
		if shoulder > 0 then
			model:ScaleTo(model:GetScale() * (tier.shoulderHeight / shoulder))
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
		--[[
			Sit the model ON the ground rather than guessing at half its height.

			This used to offset by `shoulderHeight * 0.5` as a stand-in for half
			the model height. Those are different numbers for any rig whose head
			clears its shoulder, and they diverged further once scaling was
			corrected — leaving creatures either buried or hovering. Measuring the
			actual gap between the pivot and the lowest part is exact and works
			for any template.
		]]
		-- Find the real ground. `sampleSpawnPoint` samples inside the SpawnZone
		-- volume, so its Y is the marker part's, not the terrain's — trusting it
		-- directly buried creatures by ~0.8 studs on the current map.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(
			position + Vector3.new(0, GROUND_PROBE, 0),
			Vector3.new(0, -GROUND_PROBE * 2, 0),
			params
		)
		local groundY = if hit then hit.Position.Y else position.Y

		model:PivotTo(CFrame.new(position))
		local pivotY = model:GetPivot().Position.Y
		local lowest = math.huge
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				lowest = math.min(lowest, d.Position.Y - d.Size.Y * 0.5)
			end
		end
		if lowest < math.huge then
			model:PivotTo(CFrame.new(Vector3.new(position.X, groundY + (pivotY - lowest), position.Z)))
		end
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
		--[[
			Drops go in as MEAT, not as a creature tier (D-017).

			The variant is resolved here, once, through Creatures.MeatIdFor — a
			golden kill yields `frost_cut_golden`, which carries its own value
			in Config.Meat. That is why quantity does not change for a variant:
			ECONOMY §2 requires the variant to be worth more per item rather
			than to drop more items, since more meat would just overflow the
			carrier and hide the reward instead of paying it.

			This line previously passed `info.tierId` into an inventory keyed by
			meat id, so every kill silently produced nothing.
		]]
		local meatId = Creatures.MeatIdFor(info.tierId, info.variant)
		if meatId then
			local drops = tier.dropCount
			local added = InventoryService.TryAdd(killer, meatId, drops)
			if added < drops then
				-- The kill still counts. Losing it to a full carrier feels like theft.
				Log.info("Creature", "%s carrier full: %d/%d meat", killer.Name, added, drops)
			end
		else
			Log.warn("Creature", "tier '%s' yields no meat id", info.tierId)
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

--[[
	Every live creature whose pivot sits inside `box` (D-015 hitbox combat).

	`box` is a CFrame at the box centre; `size` its full extents. A point is
	inside when each component of its box-local offset is within half that size —
	the standard OBB test, done here rather than with GetPartBoundsInBox because
	creatures are Models and we want the registry's authoritative `alive` flag,
	not whatever parts happen to be streamed in.

	Sorted nearest-first from `box.Position` and truncated to `limit`, so the cap
	drops the far creatures rather than an arbitrary hash-order selection — two
	players swinging into the same crowd should hit the same bears.
]]
function CreatureService.GetAliveInBox(box: CFrame, size: Vector3, limit: number): { Model }
	local half = size * 0.5
	local found: { { model: Model, d: number } } = {}

	for model, info in pairs(living) do
		if info.alive and model.Parent then
			local pivot = model:GetPivot().Position
			local local_ = box:PointToObjectSpace(pivot)
			if math.abs(local_.X) <= half.X
				and math.abs(local_.Y) <= half.Y
				and math.abs(local_.Z) <= half.Z
			then
				table.insert(found, { model = model, d = (pivot - box.Position).Magnitude })
			end
		end
	end

	table.sort(found, function(a, b)
		return a.d < b.d
	end)

	local out: { Model } = {}
	for i = 1, math.min(#found, limit) do
		table.insert(out, found[i].model)
	end
	return out
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

--[[
	The one shared hunting ground (D-017).

	V1 resolved a spawn region per zone folder. There are no zones now — GDD §4
	has eight private plots around a single wilderness everyone shares, so there
	is exactly one region and every creature spawns in it.

	DELIBERATELY TOLERANT ABOUT WHERE IT LIVES. ARCHITECTURE §7 names the folder
	`HuntingGround`, but the wilderness that already exists in the place is a
	257 x 495 stud `SpawnZone` under `World.shelf_ice` — built before the reset,
	and perfectly good as a hunting area. Demanding the new name would delete a
	working world to satisfy a spelling.

	So: prefer the contract name, then fall back to any `SpawnZone` under World,
	and say which one was used. Renaming the folder later is a one-word change
	in Studio that this will silently start preferring.

	`zoneId` survives as a parameter and as a CreatureInfo field purely so
	respawn can put a creature back where it came from. It is not a progression
	gate and nothing checks membership against it.
]]
function CreatureService.GetSpawnRegion(_zoneId: string?): BasePart?
	local world = workspace:FindFirstChild(HuntingGround.WorldFolderName)
	if not world then
		return nil
	end

	-- Preferred: the ARCHITECTURE §7 path.
	local ground = world:FindFirstChild(HuntingGround.FolderName)
	local region = ground and ground:FindFirstChild(HuntingGround.SpawnRegionName)
	if region and region:IsA("BasePart") then
		return region
	end

	-- Fallback: the largest SpawnZone anywhere under World. Largest rather than
	-- first, because a leftover marker from an old layout should never win over
	-- the actual hunting area, and folder order is not dependable.
	local best: BasePart? = nil
	local bestArea = 0
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == HuntingGround.SpawnRegionName then
			local area = descendant.Size.X * descendant.Size.Z
			if area > bestArea then
				best, bestArea = descendant, area
			end
		end
	end

	if best then
		Log.once(
			"spawnregion",
			"Creature",
			"using %s as the hunting ground (%.0f x %.0f studs). ARCHITECTURE §7 expects World.%s.%s",
			best:GetFullName(),
			best.Size.X,
			best.Size.Z,
			HuntingGround.FolderName,
			HuntingGround.SpawnRegionName
		)
	end
	return best
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
		task.wait(HuntingGround.WanderInterval.min)
		for model, info in pairs(living) do
			if info.alive and model.Parent then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and math.random() < 0.4 then
					local offset = Vector3.new(
						(math.random() * 2 - 1) * HuntingGround.WanderRadius,
						0,
						(math.random() * 2 - 1) * HuntingGround.WanderRadius
					)
					hum:MoveTo(info.home + offset)
				end
			end
		end
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function CreatureService.Init()
	folder = workspace:FindFirstChild(HuntingGround.RuntimeFolderName) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = HuntingGround.RuntimeFolderName
		folder.Parent = workspace
	end
	folder:ClearAllChildren() -- a stale set from a previous run isn't tracked
end

function CreatureService.Start()
	--[[
		One population in one shared ground, rather than a loop over five zones.

		The old version warned four times on every boot about zones that were
		never going to exist. Silence about a thing that cannot happen is worth
		more than a warning nobody can action.
	]]
	do
		local region = CreatureService.GetSpawnRegion(nil)
		if not region then
			-- The wilderness is hand-built and may not exist yet. Skip rather
			-- than fail: the rest of the game must stay bootable, and the store
			-- half can be worked on without any creatures at all.
			Log.warn(
				"Creature",
				"no %s.%s in %s — nothing will spawn",
				HuntingGround.FolderName,
				HuntingGround.SpawnRegionName,
				HuntingGround.WorldFolderName
			)
		else
			local tierId = HuntingGround.StarterTierId
			local taken: { Vector3 } = {}
			local placed = 0
			for _ = 1, HuntingGround.Population do
				local point = sampleSpawnPoint(region, taken)
				if not point then
					break
				end
				table.insert(taken, point)
				if spawnOne(tierId, HuntingGround.FolderName, point) then
					placed += 1
				end
			end
			if placed < HuntingGround.Population then
				Log.warn("Creature", "placed %d/%d — spawn region too small for %d-stud spacing",
					placed, HuntingGround.Population, HuntingGround.MinSpawnSpacing)
			end
			Log.info("Creature", "hunting ground: %d x %s", placed, tierId)
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
