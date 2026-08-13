--!strict
--[[
	HARVESTCONTROLLER — client-side creature prompts and swing intent.

	The prompt cadence is cosmetic. CombatService independently validates every
	request using the server clock, range, creature registry, and profile state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)

local HarvestController = {}

HarvestController.SwingStarted = Signal.new()

type PromptRecord = {
	prompt: ProximityPrompt,
	displayName: string,
}

type SwingSession = {
	creature: Model,
}

local prompts: { [Model]: PromptRecord } = {}
local activeSwing: SwingSession? = nil

local function isPackFull(): boolean
	local weight = State.Get("packWeight")
	local capacity = State.Get("packCapacity")
	return typeof(weight) == "number" and typeof(capacity) == "number" and weight >= capacity
end

local function promptText(record: PromptRecord): string
	return if isPackFull() then "PACK FULL" else record.displayName
end

local function refreshPrompts()
	for _, record in pairs(prompts) do
		record.prompt.ActionText = promptText(record)
	end
end

local function stopSwing(creature: Model)
	local session = activeSwing
	if session and session.creature == creature then
		activeSwing = nil
	end
end

local function startSwing(creature: Model)
	local record = prompts[creature]
	if not record then
		return
	end

	local existing = activeSwing
	if existing and existing.creature == creature then
		return
	end

	local session = { creature = creature }
	activeSwing = session

	task.spawn(function()
		while activeSwing == session and prompts[creature] == record do
			Net.Fire("RequestSwing", creature)
			HarvestController.SwingStarted:Fire(creature)
			task.wait(GameConfig.SwingCooldown)
		end
	end)
end

local function removePrompt(creature: Model)
	stopSwing(creature)

	local record = prompts[creature]
	if not record then
		return
	end

	prompts[creature] = nil
	record.prompt:Destroy()
end

local function createPrompt(creature: Model, tierId: string)
	removePrompt(creature)

	local anchor = creature.PrimaryPart or creature:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end

	local tier = Creatures.Get(tierId)
	local record: PromptRecord = {
		prompt = Instance.new("ProximityPrompt"),
		displayName = if tier then tier.displayName else creature.Name,
	}
	local prompt = record.prompt
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = promptText(record)
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = GameConfig.SwingRange
	prompt.Parent = anchor

	prompts[creature] = record

	prompt.Triggered:Connect(function()
		startSwing(creature)
	end)

	prompt.TriggerEnded:Connect(function()
		stopSwing(creature)
	end)
end


function HarvestController.Init() end

function HarvestController.Start()
	Net.On("CreatureSpawned", function(creature: any, tierId: any)
		if typeof(creature) == "Instance" and creature:IsA("Model") and typeof(tierId) == "string" then
			createPrompt(creature, tierId)
		end
	end)

	Net.On("CreatureDied", function(creature: any)
		if typeof(creature) == "Instance" and creature:IsA("Model") then
			removePrompt(creature)
		end
	end)

	State.ObserveMany({ "packWeight", "packCapacity" }, refreshPrompts)
end

return HarvestController
