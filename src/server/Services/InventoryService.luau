--!strict
--[[
	INVENTORYSERVICE — the carry. V2 (D-017).

	The friction that makes the loop a loop (GDD §2). Meat has weight, the
	carrier has a capacity, and a full carrier forces the walk home. Without it
	there is no trip, and without the trip there is no game.

		local added = InventoryService.TryAdd(player, "frost_cut", 2)
		local moved = InventoryService.TryRemove(player, "frost_cut", 2)

	WHAT CHANGED FROM V1: contents are keyed by `meatId` rather than creature
	tier, capacity comes from the `carrier` track, and `Clear` is gone. Clear
	existed for SellService — one call that emptied the pack and handed it to
	something that paid for it. There is no such action now: meat leaves the
	carrier only by moving INTO the refrigerator, which is a transfer, not a
	sale. `TryRemove` and `RemoveAll` replace it, and neither one produces cash.

	VARIANTS ARE NEVER COLLAPSED. `frost_cut` and `frost_cut_golden` are
	separate keys the whole way through, because collapsing them at any point
	would silently pay ordinary prices for golden stock — the exact failure
	ECONOMY §2 exists to prevent.

	Capacity is derived from the carrier level on every call, never cached. An
	upgrade must take effect on the very next pickup, not after a rejoin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Meat = require(Shared.Config.Meat)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local DataService = require(ServerScriptService.Services.DataService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)

local InventoryService = {}

-- (player, weight, capacity) — StateService replicates from this.
InventoryService.Changed = Signal.new()

--[[
	Flat capacity bonus from gamepasses (+100 Carrier, MONETIZATION §4).

	Stubbed to 0 until A13. Written as a call site now so the bonus lands in one
	place rather than being remembered in three.
]]
local function gamepassBonus(_player: Player): number
	return 0
end

function InventoryService.GetCapacity(player: Player): number
	-- nil means the profile is not loaded. Zero capacity is the safe answer:
	-- every add is refused until the real level is known, rather than a player
	-- briefly carrying against a made-up maximum.
	local base = UpgradeService.GetValue(player, "carrier")
	if not base then
		return 0
	end
	return base + gamepassBonus(player)
end

function InventoryService.GetWeight(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	return Meat.WeightOf(data.carry)
end

function InventoryService.GetFree(player: Player): number
	return math.max(0, InventoryService.GetCapacity(player) - InventoryService.GetWeight(player))
end

function InventoryService.IsFull(player: Player): boolean
	return InventoryService.GetFree(player) <= 0
end

function InventoryService.IsEmpty(player: Player): boolean
	local data = DataService.GetData(player)
	return data == nil or next(data.carry) == nil
end

--[[
	Contents, copied.

	Handing out the live table would let a caller mutate the carry without
	going through TryAdd, bypassing every capacity check in this file. The
	packet requires it explicitly: mutation of returned contents cannot affect
	the profile.
]]
function InventoryService.GetContents(player: Player): { [string]: number }
	local data = DataService.GetData(player)
	if not data then
		return {}
	end
	return table.clone(data.carry)
end

--[[
	Adds up to `count` items, returning how many actually fit.

	PARTIAL ADDS ARE CORRECT, not a compromise. A carrier with 3 free weight
	accepts one 2-weight cut and refuses the rest. Both alternatives are worse:
	refusing the whole drop loses the player a kill they earned, and accepting
	it all silently breaks the capacity rule the entire loop rests on.

	CombatService relies on this — the kill still counts when the carrier is
	full, the player just carries less of it. Losing a kill to a full carrier
	feels like theft.
]]
function InventoryService.TryAdd(player: Player, meatId: string, count: number): number
	if count <= 0 then
		return 0
	end

	local data = DataService.GetData(player)
	if not data then
		return 0
	end

	local def = Meat.Get(meatId)
	if not def then
		Log.warn("Inv", "TryAdd with unknown meat '%s'", meatId)
		return 0
	end

	-- A zero or negative weight divides by zero below and lets a player carry
	-- infinite meat. Guard it rather than trusting config.
	if def.weight <= 0 then
		Log.warn("Inv", "meat '%s' has non-positive weight", meatId)
		return 0
	end

	local free = InventoryService.GetFree(player)
	local fits = math.min(count, math.floor(free / def.weight))
	if fits <= 0 then
		return 0
	end

	data.carry[meatId] = (data.carry[meatId] or 0) + fits
	InventoryService.Changed:Fire(player, InventoryService.GetWeight(player), InventoryService.GetCapacity(player))
	return fits
end

--[[
	Removes exactly `count`, or nothing at all.

	All-or-nothing on purpose. This is the primitive StoreInventoryService (A18)
	uses to move meat into the refrigerator, and a partial removal there would
	take meat out of the carrier without a matching amount arriving in the
	fridge if the second half of the transfer failed. The packet states it
	directly: a failed removal changes nothing.
]]
function InventoryService.TryRemove(player: Player, meatId: string, count: number): boolean
	if count <= 0 then
		return false
	end

	local data = DataService.GetData(player)
	if not data then
		return false
	end

	local held = data.carry[meatId]
	if not held or held < count then
		return false
	end

	if held == count then
		data.carry[meatId] = nil
	else
		data.carry[meatId] = held - count
	end

	InventoryService.Changed:Fire(player, InventoryService.GetWeight(player), InventoryService.GetCapacity(player))
	return true
end

--[[
	Empties the carry and returns what was in it.

	Unlike V1's Clear this produces no cash and has no payer — it exists so a
	full unload is one atomic step rather than a loop of TryRemove calls that
	could fail halfway and leave meat split between two places.

	The caller owns what comes back. If depositing it fails, the caller must put
	it back with TryAdd; nothing here does that for them, because this service
	has no idea where the meat was going.
]]
function InventoryService.RemoveAll(player: Player): { [string]: number }
	local data = DataService.GetData(player)
	if not data then
		return {}
	end

	local contents = data.carry
	data.carry = {}

	InventoryService.Changed:Fire(player, 0, InventoryService.GetCapacity(player))
	return contents
end

--[[
	What contents are worth before multipliers.

	Store checkout applies the multiplier once, at the sale (ECONOMY §1). This
	is a pure helper over Config.Meat and does not read a profile, so it works
	for a customer's basket as readily as for a carry.
]]
function InventoryService.GetValue(contents: { [string]: number }): number
	return Meat.ValueOf(contents)
end

function InventoryService.Init() end

function InventoryService.Start()
	-- Push once on load so the client's carry bar has real numbers before the
	-- first pickup rather than rendering zeros until something happens.
	DataService.Loaded:Connect(function(player: Player)
		InventoryService.Changed:Fire(
			player,
			InventoryService.GetWeight(player),
			InventoryService.GetCapacity(player)
		)
	end)

	-- A carrier upgrade changes capacity immediately, with no pickup to trigger
	-- the push. Without this the bar shows the old maximum until the next kill.
	UpgradeService.Changed:Connect(function(player: Player, track: string)
		if track == "carrier" then
			InventoryService.Changed:Fire(
				player,
				InventoryService.GetWeight(player),
				InventoryService.GetCapacity(player)
			)
		end
	end)
end

return InventoryService
