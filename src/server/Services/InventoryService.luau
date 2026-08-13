--!strict
--[[
	INVENTORYSERVICE — the carry-weight pack.

	This is the friction that makes the core loop a loop (GDD §2). Meat has
	weight, the pack has a capacity, and a full pack forces the walk back.
	Without it there is no trip, and without the trip there is no game.

		local added = InventoryService.TryAdd(player, "snow_cub", 2)
		local contents = InventoryService.Clear(player)   -- SellService pays for this

	Capacity is derived from the pack upgrade level every time it is asked for,
	never cached. A capacity upgrade must take effect on the very next pickup,
	not after a rejoin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Upgrades = require(Shared.Config.Upgrades)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local DataService = require(ServerScriptService.Services.DataService)

local InventoryService = {}

-- (player, weight, capacity) — A2 replicates from this; B3's pack bar reads it.
InventoryService.Changed = Signal.new()

--[[
	Flat capacity bonus from gamepasses (+100 Pack, MONETIZATION §4).

	Stubbed to 0 until A13. Written as a call site now so the bonus lands in one
	place rather than being remembered in three.
]]
local function gamepassBonus(_player: Player): number
	return 0
end

function InventoryService.GetCapacity(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	return Upgrades.GetValue("pack", data.upgrades.pack) + gamepassBonus(player)
end

function InventoryService.GetWeight(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end

	local total = 0
	for tierId, count in pairs(data.pack) do
		local tier = Creatures.Get(tierId)
		if tier then
			total += tier.meatWeight * count
		else
			-- A tier removed from config while a player still carries it.
			-- Counting it as weightless is wrong; log so it gets noticed.
			Log.once("pack_" .. tierId, "Inv", "unknown tier '%s' in a pack", tierId)
		end
	end
	return total
end

function InventoryService.GetFree(player: Player): number
	return math.max(0, InventoryService.GetCapacity(player) - InventoryService.GetWeight(player))
end

function InventoryService.IsFull(player: Player): boolean
	return InventoryService.GetFree(player) <= 0
end

--[[
	Adds up to `count` items, returning how many actually fit.

	PARTIAL ADDS ARE CORRECT, not a compromise. A pack with 3 free weight
	accepts one 2-weight meat and refuses the rest. The alternatives are both
	worse: refusing the whole drop loses the player a kill they earned, and
	accepting it all silently breaks the capacity rule the entire loop rests on.

	A5 relies on this — the kill still counts when the pack is full, the player
	just carries less of it. Losing a kill to a full pack feels like theft.
]]
function InventoryService.TryAdd(player: Player, tierId: string, count: number): number
	if count <= 0 then
		return 0
	end

	local data = DataService.GetData(player)
	if not data then
		return 0
	end

	local tier = Creatures.Get(tierId)
	if not tier then
		Log.warn("Inv", "TryAdd with unknown tier '%s'", tierId)
		return 0
	end

	-- A zero or negative weight would divide by zero below and let a player
	-- carry infinite meat. Guard it rather than trusting config.
	if tier.meatWeight <= 0 then
		Log.warn("Inv", "tier '%s' has non-positive meatWeight", tierId)
		return 0
	end

	local free = InventoryService.GetFree(player)
	local fits = math.min(count, math.floor(free / tier.meatWeight))
	if fits <= 0 then
		return 0
	end

	data.pack[tierId] = (data.pack[tierId] or 0) + fits
	InventoryService.Changed:Fire(player, InventoryService.GetWeight(player), InventoryService.GetCapacity(player))
	return fits
end

--[[
	Empties the pack and returns what was in it.

	SellService must clear BEFORE awarding, so a double-fire in one frame finds
	an empty pack on the second pass and cannot double-pay.
]]
function InventoryService.Clear(player: Player): { [string]: number }
	local data = DataService.GetData(player)
	if not data then
		return {}
	end

	local contents = data.pack
	data.pack = {}

	InventoryService.Changed:Fire(player, 0, InventoryService.GetCapacity(player))
	return contents
end

function InventoryService.GetContents(player: Player): { [string]: number }
	local data = DataService.GetData(player)
	if not data then
		return {}
	end
	-- A copy: handing out the live table would let a caller mutate the pack
	-- without going through TryAdd, bypassing every capacity check here.
	return table.clone(data.pack)
end

function InventoryService.IsEmpty(player: Player): boolean
	local data = DataService.GetData(player)
	return data == nil or next(data.pack) == nil
end

--[[
	What the contents are worth before multipliers. SellService applies those.
	Lives here because it needs the same tier lookup the weight maths uses.
]]
function InventoryService.GetValue(contents: { [string]: number }): number
	local total = 0
	for tierId, count in pairs(contents) do
		local tier = Creatures.Get(tierId)
		if tier then
			total += tier.meatValue * count
		end
	end
	return total
end

function InventoryService.Init() end

function InventoryService.Start()
	-- Capacity changes when the pack upgrade is bought; push the new value so
	-- the client's bar updates without waiting for the next pickup.
	DataService.Loaded:Connect(function(player: Player)
		InventoryService.Changed:Fire(
			player,
			InventoryService.GetWeight(player),
			InventoryService.GetCapacity(player)
		)
	end)
end

return InventoryService
