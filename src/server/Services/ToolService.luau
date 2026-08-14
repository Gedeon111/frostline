--!strict
--[[
	TOOLSERVICE — the axe in the player's hand.

	NO `Tool`, NO BACKPACK. The axe is welded to the character on spawn and
	stays there. GDD §2 has the player swinging by walking into bears, and
	D-015 removed even the prompt — there is no equip step to attach a Tool to,
	and a backpack slot for something that can never be put away is UI noise.

	It also makes the upgrade swap simple. `Config.Upgrades` changes the visible
	axe at levels 1/4/7/10; swapping a welded model is destroy-and-re-weld,
	whereas a Tool would have to be un-equipped, replaced and re-equipped while
	the player is mid-swing.

	COSMETIC ONLY. Damage comes from `Config.Upgrades` via UpgradeService and
	nothing else. If this file ever contributes to damage there are two sources
	of truth for one number and the economy stops being tunable from one place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Trove = require(Shared.Util.Trove)
local Log = require(Shared.Util.Log)

local UpgradeService = require(ServerScriptService.Services.UpgradeService)

local ToolService = {}

--[[
	Where the axe sits in the hand.

	Chosen by eye against an R15 rig and kept here rather than in Config,
	because it describes THIS model's geometry — the offset from the grip's
	centre to where a hand closes around it — not a tunable game value. A
	different axe mesh needs a different offset, so it belongs with the code
	that knows which attachment it is welding to.
]]
local GRIP_OFFSET = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(90), 0, 0)

-- R15 first, then R6. Returns the part to weld to, or nil if the character has
-- not finished loading its limbs.
local function findHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return (hand and hand:IsA("BasePart")) and hand or nil
end

local function findTemplate(modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local tools = assets and assets:FindFirstChild("Tools")
	local template = tools and tools:FindFirstChild(modelName)
	return (template and template:IsA("Model")) and template or nil
end

local troves: { [Player]: Trove.Trove } = {}

local function clearAxe(player: Player)
	local trove = troves[player]
	if trove then
		trove:Clean()
	end
end

--[[
	Welds the axe matching the player's current axe level.

	Rebuilt from scratch every time rather than re-parented: a Motor6D or weld
	that survives a respawn points at a destroyed limb, and the symptom is an
	axe lying on the floor at the old death position.
]]
local function attachAxe(player: Player)
	clearAxe(player)

	local character = player.Character
	if not character then
		return
	end

	local level = UpgradeService.GetLevel(player, "axe")
	if not level then
		-- Profile not loaded yet. DataService.Loaded fires attachAxe again, so
		-- there is nothing to retry here.
		return
	end

	local modelName = Upgrades.GetModelName("axe", level)
	if not modelName then
		Log.warn("Tool", "no axe model configured for level %d", level)
		return
	end

	local template = findTemplate(modelName)
	if not template then
		-- The asset is hand-built in Studio and may simply not exist yet. Warn
		-- once and carry on — a missing axe must not stop the player hunting,
		-- because damage does not come from this model.
		Log.once("noaxe_" .. modelName, "Tool", "Assets.Tools.%s missing — no visible axe", modelName)
		return
	end

	local hand = findHand(character)
	if not hand then
		return
	end

	local trove = troves[player] or Trove.new()
	troves[player] = trove

	local axe = trove:Add(template:Clone())
	local grip = axe.PrimaryPart
	if not grip then
		Log.warn("Tool", "%s has no PrimaryPart", modelName)
		trove:Clean()
		return
	end

	axe.Parent = character
	axe:PivotTo(hand.CFrame * GRIP_OFFSET)

	-- Motor6D rather than WeldConstraint: animations drive Motor6D joints, so
	-- a swing animation can move the axe. A WeldConstraint would pin it rigidly
	-- and the axe would never follow an animated arm.
	local motor = Instance.new("Motor6D")
	motor.Name = "AxeGrip"
	motor.Part0 = hand
	motor.Part1 = grip
	motor.C0 = GRIP_OFFSET
	motor.Parent = hand
	trove:Add(motor)
end

function ToolService.Init() end

function ToolService.Start()
	local function bind(player: Player)
		if player.Character then
			attachAxe(player)
		end
		player.CharacterAdded:Connect(function()
			-- The limbs are not all present the instant CharacterAdded fires.
			task.defer(attachAxe, player)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bind(player)
	end
	Players.PlayerAdded:Connect(bind)

	Players.PlayerRemoving:Connect(function(player)
		clearAxe(player)
		troves[player] = nil
	end)

	-- The profile decides which axe, so the first attach has to wait for it.
	local DataService = require(ServerScriptService.Services.DataService)
	DataService.Loaded:Connect(function(player: Player)
		attachAxe(player)
	end)

	-- Level 4, 7 and 10 swap the model. Nothing else touches the character on
	-- upgrade, so without this the player keeps swinging the rusted axe while
	-- doing steel damage.
	UpgradeService.Changed:Connect(function(player: Player, track: string)
		if track == "axe" then
			attachAxe(player)
		end
	end)
end

return ToolService
