--!strict
--[[
	UPGRADESERVICE — authoritative upgrade purchases and effect lookup. V2 (D-017).

	Four tracks: axe, carrier, fridge, register. Values and costs come
	exclusively from Shared.Config.Upgrades. Other services call GetLevel and
	GetValue rather than reading `data.upgrades` directly, so the lookup and the
	unloaded-profile guard live in one place.

	WHAT CHANGED FROM V1: `pack` became `carrier`, `harpoon` became `axe`, and
	`boots` is gone entirely. The boots track carried the only character effect
	in the game — a WalkSpeed write on spawn — so all of the CharacterAdded
	binding machinery went with it. If a future track needs a character effect,
	`applyCharacterEffects` below is where it goes; it deliberately still exists
	as an empty seam rather than being deleted, because rediscovering that
	upgrades can affect the character is harder than reading one function.

	Track dispatch is table-driven rather than an if/elseif chain. The V1 version
	repeated the same three-branch chain in GetLevel and again in purchase, and
	adding a fourth track meant finding every chain — exactly the kind of edit
	that gets done in two places out of three.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local DataService = require(ServerScriptService.Services.DataService)
local Net = require(ServerScriptService.Services.Net)

local UpgradeService = {}

-- Fires (player, track) after a successful purchase. StateService listens and
-- marks the replicated keys; nothing else should poll upgrade levels.
UpgradeService.Changed = Signal.new()

--[[
	The primary value of each track, for `GetValue`.

	Each track measures something different, so "the value" is per-track rather
	than a single number the caller can guess at. Callers that need a secondary
	field (the register's queue capacity) go through Config.Upgrades directly —
	this is a convenience, not the whole interface.
]]
local PRIMARY_VALUE: { [string]: (number) -> number } = {
	axe = Upgrades.GetDamage,
	carrier = Upgrades.GetCarryCapacity,
	fridge = Upgrades.GetFridgeCapacity,
	register = Upgrades.GetCheckoutSeconds,
}

function UpgradeService.GetLevel(player: Player, track: Types.UpgradeTrack): number?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end
	local level = (data.upgrades :: any)[track]
	return if typeof(level) == "number" then level else nil
end

function UpgradeService.GetValue(player: Player, track: Types.UpgradeTrack): number?
	local level = UpgradeService.GetLevel(player, track)
	if not level then
		return nil
	end
	local resolver = PRIMARY_VALUE[track]
	return if resolver then resolver(level) else nil
end

--[[
	Character effects. Empty by design.

	No V2 track changes anything on the character — the axe swaps a held model
	(A20's job), and carrier, fridge and register are all inventory or store
	capacity. The packet is explicit: apply character effects only when a
	configured track actually has one.
]]
local function applyCharacterEffects(_player: Player, _track: Types.UpgradeTrack) end

local function purchase(player: Player, track: any): (boolean, Types.RefusalReason?)
	--[[
		Order matters and is cheapest-first, same as CombatService: an unknown
		track costs a table lookup, while a funds check costs a profile read.
		Rejected requests are what arrive in volume during an attack.
	]]
	if typeof(track) ~= "string" then
		return false, "invalid"
	end

	local definition = Upgrades.Get(track)
	if not definition then
		return false, "unknown_track"
	end

	local data = DataService.GetData(player)
	if not data then
		-- Distinct from insufficient_funds, which is what V1 returned here.
		-- "You have no money" and "your save has not loaded" are different
		-- problems and the client should not tell the player the wrong one.
		return false, "not_loaded"
	end

	local typedTrack = track :: Types.UpgradeTrack
	local currentLevel = (data.upgrades :: any)[typedTrack]
	if typeof(currentLevel) ~= "number" then
		return false, "unknown_track"
	end

	local cost = Upgrades.GetCost(track, currentLevel)
	if not cost then
		-- nil means there is no next level. GetCost is the single source of
		-- that fact, so "maxed" is never computed twice with two answers.
		return false, "max_level"
	end

	-- Spend BEFORE writing the level. If Spend fails the profile is untouched;
	-- if it succeeds the write below cannot fail, so there is no window where
	-- cash has left and the level has not arrived.
	if not CurrencyService.Spend(player, cost, `upgrade_{track}`) then
		return false, "insufficient_funds"
	end

	;(data.upgrades :: any)[typedTrack] = currentLevel + 1

	applyCharacterEffects(player, typedTrack)
	UpgradeService.Changed:Fire(player, typedTrack)

	return true, nil
end

function UpgradeService.Init()
	Net.On("RequestPurchase", purchase)
end

function UpgradeService.Start() end

return UpgradeService
