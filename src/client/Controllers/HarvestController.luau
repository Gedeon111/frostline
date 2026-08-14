--!strict
--[[
	HARVESTCONTROLLER — the swing hitbox (D-015) and swing cadence (D-016).

	A box is carried in front of the character and every live creature inside it
	is a valid target. There is no prompt. What differs is what makes a swing
	*fire*:

	  tap  (default)  one click / tap / Space = one swing
	  auto (D-016)    fires on cooldown with no input, while `autoSwing` is
	                  active — free for the first 10 minutes, then the pass

	`autoSwing` arrives from the server via State. It is a CADENCE HINT, not a
	permission gate, and cannot be one: `RequestSwing` carries intent only, so
	the server cannot tell a held button from a timer. D-016 explains why that is
	acceptable and why A12 should not chase it.

	WHAT THIS FILE IS ALLOWED TO DECIDE: nothing that matters. It picks a moment
	to say "I am swinging, and the nearest thing is that one." `CombatService`
	independently re-derives the hitbox from the character's server-side CFrame
	and chooses the victims itself, so everything here is a cadence hint. A
	crafted client can lie about its target and gain nothing — the server never
	reads the list, only the intent (ARCHITECTURE §3).

	One RunService connection, throttled to SCAN_HZ rather than run per frame
	(ARCHITECTURE §8). Swings resolve at ~1.7Hz; scanning at 15Hz is already an
	order of magnitude more often than the result can change.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)
local Trove = require(Shared.Util.Trove)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)

local HarvestController = {}

-- Fired when a swing goes out, for EffectsController (B4) and any swing
-- animation. Carries the creature the client believes it is hitting, which is
-- good enough for cosmetics and is never treated as authoritative.
HarvestController.SwingStarted = Signal.new()

local SCAN_HZ = 15

local trove = Trove.new()
local lastSwing = 0
local scanAccumulator = 0

local player = Players.LocalPlayer

--[[
	The box, in world space, centred ahead of the character.

	Built from the root's CFrame so it rotates with the player — a box that
	ignored facing would let you hit things behind you, which reads as broken
	even though it would be easier to farm with.
]]
local function hitboxCFrame(): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root.CFrame * CFrame.new(0, 0, -GameConfig.HitboxForwardOffset)
end

-- Standard OBB containment: transform the point into box space and compare
-- against half-extents on each axis.
local function isInside(box: CFrame, half: Vector3, point: Vector3): boolean
	local p = box:PointToObjectSpace(point)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

--[[
	Nearest live creature inside the box, or nil.

	Reads `workspace.Creatures` directly rather than keeping a client-side
	registry fed by CreatureSpawned/CreatureDied. The folder is already the
	server's own truth, and a mirrored registry is one more thing that can drift
	out of sync and leave the player swinging at a corpse.
]]
local function findTarget(box: CFrame): Model?
	local folder = workspace:FindFirstChild("Creatures")
	if not folder then
		return nil
	end

	local half = GameConfig.HitboxSize * 0.5
	local best: Model? = nil
	local bestDistance = math.huge

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child.PrimaryPart then
			local position = child:GetPivot().Position
			if isInside(box, half, position) then
				local d = (position - box.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = child, d
				end
			end
		end
	end
	return best
end

--[[
	Attempts one swing. Returns whether it went out.

	The cooldown is enforced locally as well as on the server, so tap-spamming
	sends nothing rather than earning a stream of `cooldown` rejections — those
	are indistinguishable from an attack in A12's counters, and a legitimate
	player mashing the button should not look like one.
]]
local function trySwing(): boolean
	local now = os.clock()
	if (now - lastSwing) < GameConfig.SwingCooldown then
		return false
	end

	local box = hitboxCFrame()
	if not box then
		return false
	end

	local target = findTarget(box)
	if not target then
		return false
	end

	lastSwing = now
	Net.Fire("RequestSwing", target)
	HarvestController.SwingStarted:Fire(target)
	return true
end

-- Auto cadence only. Tap swings come from the input handlers below, so this
-- returns immediately for a player who has not got auto-swing.
local function step(dt: number)
	if not State.Get("autoSwing") then
		return
	end

	scanAccumulator += dt
	if scanAccumulator < (1 / SCAN_HZ) then
		return
	end
	scanAccumulator = 0

	trySwing()
end

local function onInput(input: InputObject, processed: boolean)
	-- `processed` is true when the UI already consumed it. Without this check,
	-- tapping the shop button would also swing at whatever is in front of you.
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space)
	then
		trySwing()
	end
end

--[[
	The auto-swing toggle, for the HUD button (B3).

	Writes the PREFERENCE and nothing else. If the trial has lapsed and the
	player has no pass, this still succeeds and still returns true — they have
	said what they want, and the entitlement is decided server-side. The button
	should therefore reflect `autoSwingEnabled` (their switch position), while
	whether swinging is actually automatic follows `autoSwing`. Rendering the
	button from `autoSwing` would make it appear to flip itself back off the
	moment the trial ends, which reads as a broken button rather than an expiry.
]]
function HarvestController.SetAutoSwing(enabled: boolean): (boolean, string?)
	return Net.Invoke("RequestSetting", "autoSwing", enabled)
end

function HarvestController.IsAutoSwingActive(): boolean
	return State.Get("autoSwing") == true
end

function HarvestController.Init() end

function HarvestController.Start()
	trove:Connect(RunService.Heartbeat, step)
	trove:Connect(UserInputService.InputBegan, onInput)

	-- A fresh character resets the cadence, so respawning doesn't inherit a
	-- cooldown from the previous life.
	trove:Connect(player.CharacterAdded, function()
		lastSwing = 0
		scanAccumulator = 0
	end)
end

function HarvestController.Stop()
	trove:Clean()
end

return HarvestController
