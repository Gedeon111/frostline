--!strict
--[[
	EFFECTSCONTROLLER — the feel layer (job B4, spec in docs/GDD.md §6).

	Hit flash, chunk particles, hitstop, floating damage numbers, kill topple,
	meat pop, and the sell payout number.

	THIS FILE KNOWS NO GAME RULES. It is told what happened and shows it. It
	never computes damage, never decides a kill, never touches cash. Every number
	it renders arrived from the server as a fact — which is why it can be wrong
	on screen for a frame without ever being wrong in the game.

	D-015 raised the stakes here: cleave means one swing can kill up to eight
	creatures in the same frame, so everything below is POOLED. Allocating a
	BillboardGui per hit was already questionable at one target; at eight it is a
	guaranteed frame-rate problem on the phones this game is aimed at.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Effects = require(Shared.Config.Effects)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local Trove = require(Shared.Util.Trove)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)

local EffectsController = {}

local player = Players.LocalPlayer
local trove = Trove.new()

local container: Folder? = nil
local numberPool: { BillboardGui } = {}
local chunkPool: { Part } = {}

-- Hitstop is a client-side visual scale, never a change to Workspace.Gravity or
-- any global timescale (B4 packet is explicit). Tracked so overlapping hits in
-- one cleave don't stack into a freeze.
local hitstopUntil = 0

local function reduced(): boolean
	return State.Get("reducedEffects") == true
end

-- ── Pools ───────────────────────────────────────────────────────────────────

local function makeNumber(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Parent = container

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.TextStrokeTransparency = 0
	label.Parent = gui

	return gui
end

local function makeChunk(): Part
	local part = Instance.new("Part")
	part.Name = "Chunk"
	part.Size = Vector3.one * Effects.ChunkSize
	part.Color = Effects.ChunkColor
	part.Material = Enum.Material.Plastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Anchored = false
	part.Parent = container
	return part
end

--[[
	Takes the least-recently-used entry rather than growing the pool.

	Recycling an in-flight number is deliberate: at steady state the pool is full
	and the oldest number is the one nearest the end of its 0.5s life, so the
	visual cost of stealing it is near zero — and allocation stays at zero, which
	is the B4 acceptance criterion.
]]
local function take<T>(pool: { T }, index: number): T
	local item = pool[index]
	table.remove(pool, index)
	table.insert(pool, item)
	return item
end

-- ── Hit ─────────────────────────────────────────────────────────────────────

local function flash(creature: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Effects.FlashColor
	highlight.FillTransparency = Effects.FlashTransparency
	highlight.OutlineTransparency = 1
	highlight.Adornee = creature
	highlight.Parent = creature
	-- Debris rather than a task.delay: a creature destroyed mid-flash takes the
	-- Highlight with it, and Debris does not care that it already vanished.
	Debris:AddItem(highlight, Effects.FlashSeconds)
end

local function chunks(origin: Vector3, direction: Vector3)
	local count = math.random(Effects.ChunkCount.min, Effects.ChunkCount.max)
	for _ = 1, count do
		local part = take(chunkPool, 1)
		part.CFrame = CFrame.new(origin)
		part.Transparency = 0
		part.Anchored = false
		part.AssemblyLinearVelocity = (
			direction + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5)
		).Unit * math.random(Effects.ChunkSpeed.min, Effects.ChunkSpeed.max)

		task.delay(Effects.ChunkLifetime, function()
			if part.Parent then
				part.Anchored = true
				part.Transparency = 1
			end
		end)
	end
end

local function damageNumber(position: Vector3, amount: number, color: Color3?, size: number?)
	local gui = take(numberPool, 1)
	local label = gui:FindFirstChild("Label") :: TextLabel

	local attach = Instance.new("Part")
	attach.Anchored = true
	attach.CanCollide = false
	attach.CanQuery = false
	attach.Transparency = 1
	attach.Size = Vector3.one * 0.05
	attach.CFrame = CFrame.new(position)
	attach.Parent = container

	gui.Adornee = attach
	gui.Enabled = true
	label.Text = Format.Abbreviate(amount)
	label.TextColor3 = color or Effects.NumberColor
	label.TextSize = size or Effects.NumberSize
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0

	local seconds = Effects.NumberSeconds
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(attach, info, {
		CFrame = CFrame.new(position + Vector3.new(0, Effects.NumberRiseStuds, 0)),
	}):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	task.delay(seconds, function()
		gui.Enabled = false
		gui.Adornee = nil
		attach:Destroy()
	end)
end

local function hitstop()
	local now = os.clock()
	if now < hitstopUntil then
		return
	end
	hitstopUntil = now + GameConfig.HitstopSeconds
	-- Deliberately does NOT touch the character's WalkSpeed or any input state:
	-- the B4 packet requires hitstop never affect movement input. It is purely a
	-- window other visuals can read to hold themselves still.
end

-- ── Kill ────────────────────────────────────────────────────────────────────

local function topple(creature: Model)
	local primary = creature.PrimaryPart
	if not primary then
		return
	end
	local goal = primary.CFrame * CFrame.Angles(math.rad(Effects.ToppleAngleDegrees), 0, 0)
	TweenService:Create(
		primary,
		TweenInfo.new(Effects.ToppleSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ CFrame = goal }
	):Play()
end

local function meatPop(origin: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local toward = if root and root:IsA("BasePart")
		then (root.Position - origin).Unit
		else Vector3.yAxis
	chunks(origin, (toward + Vector3.yAxis).Unit * Effects.MeatArcStuds)
end

-- ── Handlers ────────────────────────────────────────────────────────────────

local function onCombatFeedback(creature: any, damage: any, killed: any)
	if typeof(creature) ~= "Instance" or not creature:IsA("Model") then
		return
	end
	if typeof(damage) ~= "number" then
		return
	end

	local position = creature:GetPivot().Position
	local isReduced = reduced()

	-- Numbers survive reducedEffects: they carry information, not spectacle.
	if Effects.ReducedKeepsNumbers or not isReduced then
		damageNumber(position + Vector3.new(0, 3, 0), damage)
	end

	if isReduced then
		return
	end

	flash(creature)
	hitstop()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local direction = if root and root:IsA("BasePart")
		then (position - root.Position).Unit
		else Vector3.yAxis
	chunks(position, direction)

	if killed == true then
		topple(creature)
		meatPop(position)
	end
end

local function onNotify(kind: any, _text: any, amount: any)
	-- The sell payoff. Only "cash" carries an amount worth celebrating; the other
	-- kinds are toasts and belong to NotifyController, not here.
	if kind ~= "cash" or typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	damageNumber(
		root.Position + Vector3.new(0, 5, 0),
		amount,
		Effects.SellNumberColor,
		Effects.SellNumberSize
	)
end

function EffectsController.Init() end

function EffectsController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	container = trove:Add(folder)

	for _ = 1, Effects.NumberPoolSize do
		table.insert(numberPool, trove:Add(makeNumber()))
	end
	for _ = 1, Effects.ChunkPoolSize do
		local chunk = trove:Add(makeChunk())
		chunk.Anchored = true
		chunk.Transparency = 1
		table.insert(chunkPool, chunk)
	end

	Net.On("CombatFeedback", onCombatFeedback)
	Net.On("Notify", onNotify)
end

function EffectsController.Stop()
	trove:Clean()
	table.clear(numberPool)
	table.clear(chunkPool)
end

return EffectsController
