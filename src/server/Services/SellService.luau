--!strict
--[[
	SELLSERVICE — converts a full pack into cash. The payoff of the whole loop.

	LAYOUT-AGNOSTIC BY DESIGN. It finds every part named "SellPad" anywhere under
	Workspace.World and treats each as a sell region. That means a single shared
	outpost, eight per-plot pads, or satellite posts in each zone all work with
	no code change — the level designer moves and duplicates pads freely and
	nothing here needs touching.

	Detection is a polled region check, NOT Touched. Touched misses fast-moving
	players, double-fires on a single step, and is trivially spoofed by a client
	that simply never reports leaving.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local InventoryService = require(ServerScriptService.Services.InventoryService)

local SellService = {}

-- Players currently standing on a pad. B3's sell prompt reads this.
local inRegion: { [Player]: BasePart } = {}

-- Guards a double-fire landing in the same frame before the pack is cleared.
local selling: { [Player]: boolean } = {}

--[[
	The multiplier. A13 replaces this body with
	MonetizationService.GetCashMultiplier(player).

	Written as a call site NOW so multipliers land in exactly one place. The
	alternative — bolting them on later — reliably ends up applied in three
	places with slightly different rules, and then nobody can explain a payout.
]]
local function getMultiplier(_player: Player): number
	return 1
end

local function findPads(): { BasePart }
	local pads = {}
	local world = workspace:FindFirstChild("World")
	if not world then
		return pads
	end
	for _, d in ipairs(world:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "SellPad" then
			table.insert(pads, d)
		end
	end
	return pads
end

local function padContaining(position: Vector3, pads: { BasePart }): BasePart?
	for _, pad in ipairs(pads) do
		-- Local-space test, so a rotated pad still works.
		local local_ = pad.CFrame:PointToObjectSpace(position)
		local half = pad.Size * 0.5
		if math.abs(local_.X) <= half.X
			and math.abs(local_.Z) <= half.Z
			and math.abs(local_.Y) <= half.Y + 6 -- headroom: the player stands ON it
		then
			return pad
		end
	end
	return nil
end

function SellService.IsAtPad(player: Player): boolean
	return inRegion[player] ~= nil
end

--[[
	Sells the whole pack.

	ORDER MATTERS: clear first, then award. If Award somehow failed after a
	clear the player loses meat, which is bad — but if we awarded first and the
	clear failed, they could sell the same pack repeatedly, which is worse.
	Clearing first also makes a same-frame double-fire find an empty pack.
]]
function SellService.Sell(player: Player): (boolean, string?)
	if selling[player] then
		return false, "rate_limited"
	end

	local data = DataService.GetData(player)
	if not data then
		return false, "not_loaded"
	end
	if not inRegion[player] then
		return false, "not_at_sell_pad"
	end
	if InventoryService.IsEmpty(player) then
		return false, "pack_empty"
	end

	selling[player] = true

	local contents = InventoryService.Clear(player)
	local base = InventoryService.GetValue(contents)
	local multiplier = math.min(getMultiplier(player), GameConfig.MaxMultiplier)
	local payout = math.floor(base * multiplier)

	local granted = CurrencyService.Award(player, payout, "sell")
	data.stats.sells += 1

	selling[player] = nil

	Net.Fire(player, "Notify", "cash", "Sold!", granted)
	Log.info("Sell", "%s sold %d base x%.2f = %d", player.Name, base, multiplier, granted)
	return true, nil
end

function SellService.Init()
	Net.On("RequestSell", function(player: Player)
		local ok, reason = SellService.Sell(player)
		if not ok and reason ~= "pack_empty" then
			Log.info("Sell", "%s refused: %s", player.Name, tostring(reason))
		end
		if not ok and reason == "pack_empty" then
			-- Worth telling the player: an empty-pack sell is a mistake they
			-- can see and correct, not an exploit.
			Net.Fire(player, "Notify", "error", "Nothing to sell", nil)
		end
	end)
end

function SellService.Start()
	Players.PlayerRemoving:Connect(function(player)
		inRegion[player] = nil
		selling[player] = nil
	end)

	-- Pads are re-scanned each tick rather than cached, so pads built or moved
	-- in Studio during a session are picked up without a restart. At 5Hz over a
	-- handful of pads that costs nothing.
	local interval = 1 / GameConfig.ZoneCheckHz
	task.spawn(function()
		while true do
			task.wait(interval)
			local pads = findPads()
			if #pads > 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					inRegion[player] = root and padContaining((root :: BasePart).Position, pads) or nil
				end
			end
		end
	end)
end

return SellService
