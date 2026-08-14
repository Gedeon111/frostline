--!strict
--[[
	STATESERVICE - batched replication of the canonical v2 player-state subset.

	Only fields listed in ARCHITECTURE section 4 are exposed. Profile aliases,
	receipts, analytics, reservations, queues, and customer internals remain
	server-only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)
local Upgrades = require(Shared.Config.Upgrades)
local ProfileSchema = require(Shared.ProfileSchema)
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)

local StateService = {}

local dirty: { [Player]: { [string]: boolean } } = {}
local sessionPlotIds: { [Player]: string } = {}

local function activeUpgrades(data: any): Types.UpgradeLevels
	return {
		axe = data.upgrades.axe,
		carrier = data.upgrades.carrier,
		fridge = data.upgrades.fridge,
		register = data.upgrades.register,
	}
end

local REPLICATED: { [string]: (Player, any) -> any } = {
	cash = function(_, data)
		return data.cash
	end,
	carry = function(_, data)
		return table.clone(data.carry)
	end,
	carryWeight = function(_, data)
		return Meat.GetWeight(data.carry)
	end,
	carryCapacity = function(_, data)
		return Upgrades.GetValue("carrier", data.upgrades.carrier)
	end,
	fridge = function(_, data)
		return table.clone(data.store.fridge)
	end,
	fridgeWeight = function(_, data)
		return Meat.GetWeight(data.store.fridge)
	end,
	fridgeCapacity = function(_, data)
		return Upgrades.GetValue("fridge", data.upgrades.fridge)
	end,
	unclaimedCash = function(_, data)
		return data.store.unclaimedCash
	end,
	upgrades = function(_, data)
		return activeUpgrades(data)
	end,
	workers = function(_, data)
		return TableUtil.DeepCopy(data.workers)
	end,
	plotId = function(player)
		return sessionPlotIds[player]
	end,
	autoSwing = function(_, data)
		-- The pass is not configured in this pre-release slice. The future
		-- MonetizationService supplies entitlement without changing profile data.
		return ProfileSchema.IsAutoSwingActive(data, os.time(), false)
	end,
	autoSwingTrialEndsAt = function(_, data)
		return data.firstJoinAt + GameConfig.AutoSwingTrialSeconds
	end,
	autoSwingEnabled = function(_, data)
		return data.settings.autoSwing
	end,
	reducedEffects = function(_, data)
		return data.settings.reducedEffects
	end,
}

function StateService.Mark(player: Player, key: string)
	if not REPLICATED[key] then
		Log.warn("State", "'%s' is not replicated - see ARCHITECTURE section 4", key)
		return
	end

	local keys = dirty[player]
	if not keys then
		keys = {}
		dirty[player] = keys
	end
	keys[key] = true
end

function StateService.MarkAll(player: Player)
	for key in pairs(REPLICATED) do
		StateService.Mark(player, key)
	end
end

function StateService.MarkCarry(player: Player)
	StateService.Mark(player, "carry")
	StateService.Mark(player, "carryWeight")
end

function StateService.MarkFridge(player: Player)
	StateService.Mark(player, "fridge")
	StateService.Mark(player, "fridgeWeight")
end

function StateService.MarkUnclaimedCash(player: Player)
	StateService.Mark(player, "unclaimedCash")
end

function StateService.MarkWorkers(player: Player)
	StateService.Mark(player, "workers")
end

function StateService.MarkUpgrade(player: Player, track: Types.ActiveUpgradeTrack)
	StateService.Mark(player, "upgrades")
	if track == "carrier" then
		StateService.Mark(player, "carryCapacity")
	elseif track == "fridge" then
		StateService.Mark(player, "fridgeCapacity")
	end
end

function StateService.SetPlotId(player: Player, plotId: string?)
	if sessionPlotIds[player] == plotId then
		return
	end

	sessionPlotIds[player] = plotId
	StateService.Mark(player, "plotId")
end

function StateService.GetPlotId(player: Player): string?
	return sessionPlotIds[player]
end

local function build(player: Player, keys: { [string]: boolean }): { [string]: any }?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end

	local payload: { [string]: any } = {}
	for key in pairs(keys) do
		local getter = REPLICATED[key]
		if getter then
			local value = getter(player, data)
			if value ~= nil then
				payload[key] = value
			end
		end
	end
	return payload
end

local function send(player: Player, keys: { [string]: boolean })
	local payload = build(player, keys)
	if payload and next(payload) ~= nil then
		Net.Fire(player, "StateChanged", payload)
		StateService._packetsSent += 1
	end
end

function StateService.PushFull(player: Player)
	local all: { [string]: boolean } = {}
	for key in pairs(REPLICATED) do
		all[key] = true
	end

	send(player, all)
	dirty[player] = nil
end

StateService._packetsSent = 0

function StateService.GetPacketCount(): number
	return StateService._packetsSent
end

function StateService.Init() end

function StateService.Start()
	DataService.Loaded:Connect(function(player: Player)
		StateService.PushFull(player)
	end)

	CurrencyService.Changed:Connect(function(player: Player)
		StateService.Mark(player, "cash")
	end)

	InventoryService.Changed:Connect(function(player: Player)
		StateService.MarkCarry(player)
	end)

	UpgradeService.Changed:Connect(function(player: Player, track: Types.ActiveUpgradeTrack)
		StateService.MarkUpgrade(player, track)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		dirty[player] = nil
		sessionPlotIds[player] = nil
	end)

	local interval = 1 / GameConfig.StateReplicationHz
	task.spawn(function()
		while true do
			task.wait(interval)
			for player, keys in pairs(dirty) do
				dirty[player] = nil
				if player.Parent == Players then
					send(player, keys)
				end
			end
		end
	end)
end

return StateService
