--!strict
--[[
	UPGRADESERVICE — authoritative upgrade purchases and effect lookup.

	Upgrade values and costs come exclusively from Shared.Config.Upgrades. Other
	services use GetLevel and GetValue instead of reading profile upgrades so the
	lookup and unloaded-profile guard stay in one place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Types = require(Shared.Types)

local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local DataService = require(ServerScriptService.Services.DataService)
local Net = require(ServerScriptService.Services.Net)

local UpgradeService = {}

local characterConnections: { [Player]: RBXScriptConnection } = {}

function UpgradeService.GetLevel(player: Player, track: Types.UpgradeTrack): number?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end

	if track == "pack" then
		return data.upgrades.pack
	elseif track == "boots" then
		return data.upgrades.boots
	elseif track == "harpoon" then
		return data.upgrades.harpoon
	end

	return nil
end

function UpgradeService.GetValue(player: Player, track: Types.UpgradeTrack): number?
	local level = UpgradeService.GetLevel(player, track)
	if not level then
		return nil
	end
	return Upgrades.GetValue(track, level)
end

local function applyBoots(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
	end

	local walkSpeed = UpgradeService.GetValue(player, "boots")
	if not walkSpeed then
		return
	end

	humanoid.WalkSpeed = walkSpeed
end

local function applyCurrentCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end

	if character:FindFirstChildOfClass("Humanoid") then
		applyBoots(player, character)
	else
		task.spawn(applyBoots, player, character)
	end
end

local function bindPlayer(player: Player)
	if not characterConnections[player] then
		characterConnections[player] = player.CharacterAdded:Connect(function(character)
			applyBoots(player, character)
		end)
	end
	applyCurrentCharacter(player)
end

local function unbindPlayer(player: Player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

local function purchase(player: Player, track: string): (boolean, Types.RefusalReason?)
	local definition = Upgrades.Get(track)
	if not definition then
		return false, "unknown_track"
	end

	local typedTrack = track :: Types.UpgradeTrack
	local data = DataService.GetData(player)
	if not data then
		return false, "insufficient_funds"
	end

	local currentLevel: number
	if typedTrack == "pack" then
		currentLevel = data.upgrades.pack
	elseif typedTrack == "boots" then
		currentLevel = data.upgrades.boots
	else
		currentLevel = data.upgrades.harpoon
	end

	local nextLevel = currentLevel + (definition.maxLevel - #definition.costs)
	if nextLevel > definition.maxLevel then
		return false, "max_level"
	end

	local cost = definition.costs[currentLevel]
	if not CurrencyService.Spend(player, cost, `upgrade_{track}`) then
		return false, "insufficient_funds"
	end

	if typedTrack == "pack" then
		data.upgrades.pack = nextLevel
	elseif typedTrack == "boots" then
		data.upgrades.boots = nextLevel
	else
		data.upgrades.harpoon = nextLevel
	end

	if typedTrack == "boots" then
		applyCurrentCharacter(player)
	end

	return true, nil
end

function UpgradeService.Init()
	Net.On("RequestPurchase", purchase)

	DataService.Loaded:Connect(function(player: Player)
		bindPlayer(player)
	end)
end

function UpgradeService.Start()
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(unbindPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end
end

return UpgradeService
