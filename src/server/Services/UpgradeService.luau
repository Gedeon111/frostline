--!strict
--[[
	UPGRADESERVICE - authoritative purchases for the four v2 store-loop tracks.

	Costs and effects come only from Config.Upgrades. The legacy pack/harpoon
	fields are synchronized while A16/A20 still consume them; they are never
	accepted as purchase tracks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Types = require(Shared.Types)

local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local DataService = require(ServerScriptService.Services.DataService)
local Net = require(ServerScriptService.Services.Net)

local UpgradeService = {}

local function getStoredLevel(upgrades: Types.UpgradeLevels, track: Types.ActiveUpgradeTrack): number
	if track == "axe" then
		return upgrades.axe
	elseif track == "carrier" then
		return upgrades.carrier
	elseif track == "fridge" then
		return upgrades.fridge
	else
		return upgrades.register
	end
end

local function setStoredLevel(upgrades: Types.UpgradeLevels, track: Types.ActiveUpgradeTrack, level: number)
	if track == "axe" then
		upgrades.axe = level
		upgrades.harpoon = level -- temporary A20 bridge
	elseif track == "carrier" then
		upgrades.carrier = level
		upgrades.pack = level -- temporary A16 bridge
	elseif track == "fridge" then
		upgrades.fridge = level
	else
		upgrades.register = level
	end
end

function UpgradeService.GetLevel(player: Player, track: Types.ActiveUpgradeTrack): number?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end

	return getStoredLevel(data.upgrades, track)
end

function UpgradeService.GetValue(player: Player, track: Types.ActiveUpgradeTrack): number?
	local level = UpgradeService.GetLevel(player, track)
	if not level then
		return nil
	end

	return Upgrades.GetValue(track, level)
end

local function purchase(player: Player, track: string): (boolean, Types.RefusalReason?)
	local definition = Upgrades.GetActive(track)
	if not definition then
		return false, "unknown_track"
	end

	local data = DataService.GetData(player)
	if not data then
		return false, "not_loaded"
	end

	local typedTrack = track :: Types.ActiveUpgradeTrack
	local currentLevel = getStoredLevel(data.upgrades, typedTrack)
	if currentLevel >= definition.maxLevel then
		return false, "max_level"
	end

	local cost = definition.costs[currentLevel]
	if not CurrencyService.Spend(player, cost, `upgrade_{track}`) then
		return false, "insufficient_funds"
	end

	local nextLevel = currentLevel + (definition.maxLevel - #definition.costs)
	setStoredLevel(data.upgrades, typedTrack, nextLevel)
	return true, nil
end

function UpgradeService.Init()
	Net.On("RequestPurchase", purchase)
end

function UpgradeService.Start() end

return UpgradeService