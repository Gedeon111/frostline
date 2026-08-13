--!strict
--[[
	CURRENCYSERVICE — the ONLY code that changes cash.

		CurrencyService.Award(player, 1240, "sell")
		if CurrencyService.Spend(player, 800, "zone_unlock") then ... end

	Two functions write `data.cash`. Nothing else may, anywhere. That constraint
	is what makes the economy auditable: every source and sink carries a label,
	so ANALYTICS §5 can reconstruct where cash comes from and where it goes
	without tracking state separately. A stray `data.cash += x` somewhere else is
	invisible to that, and ECONOMY §7 rule 7 (eggs absorb 60–70% of lifetime
	cash) becomes unanswerable.

	Multipliers are NOT applied here. Award takes a final amount. SellService
	assembles the multiplier through MonetizationService (MONETIZATION §1) —
	one assembly point, one place to look when a payout is wrong.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local DataService = require(ServerScriptService.Services.DataService)

local CurrencyService = {}

-- (player, newCash, delta, reason) — A2 replicates from this rather than
-- CurrencyService knowing StateService exists. Keeps the dependency one-way.
CurrencyService.Changed = Signal.new()

--[[
	Analytics sink. A14 replaces the body; the call sites are written now so
	that job is a one-file change instead of an audit of every service.

	Retrofitting analytics means losing the first week of live data, which is
	the most informative week the game will ever have (ANALYTICS §8).
]]
local function emit(player: Player, flow: "source" | "sink", amount: number, label: string, balance: number)
	Log.info("Cash", "%s %s %d via %s (bal %d)", player.Name, flow, amount, label, balance)
end

--[[
	Adds cash. Returns the amount actually granted, which can be less than
	requested if it would breach GameConfig.MaxCash.

	`source` is required and must be one of the labels in ANALYTICS §5.
]]
function CurrencyService.Award(player: Player, amount: number, source: string): number
	if amount <= 0 or amount ~= amount then -- non-positive or NaN
		Log.warn("Cash", "ignored bogus award of %s to %s", tostring(amount), player.Name)
		return 0
	end

	local data = DataService.GetData(player)
	if not data then
		-- Profile not loaded, or the session ended mid-flight. Dropping the
		-- award is correct: writing into a table nobody saves would show the
		-- player cash that vanishes on their next join.
		Log.warn("Cash", "award to %s dropped — no profile", player.Name)
		return 0
	end

	local granted = math.floor(amount)
	local headroom = GameConfig.MaxCash - data.cash
	if granted > headroom then
		granted = math.max(0, math.floor(headroom))
		Log.warn("Cash", "%s is at the cash ceiling", player.Name)
	end
	if granted <= 0 then
		return 0
	end

	data.cash += granted
	data.totalCashEarned += granted -- lifetime; drives leaderboards and rebirth

	emit(player, "source", granted, source, data.cash)
	CurrencyService.Changed:Fire(player, data.cash, granted, source)
	return granted
end

--[[
	Removes cash. Returns false and changes NOTHING if the player can't afford
	it — callers rely on that atomicity:

		if not CurrencyService.Spend(player, cost, "upgrade_pack") then
			return false, "insufficient_funds"
		end
		-- only now grant the thing

	Cash can never go negative through any path.
]]
function CurrencyService.Spend(player: Player, amount: number, sink: string): boolean
	if amount < 0 or amount ~= amount then
		Log.warn("Cash", "ignored bogus spend of %s by %s", tostring(amount), player.Name)
		return false
	end
	if amount == 0 then
		return true -- a free purchase is still a successful one
	end

	local data = DataService.GetData(player)
	if not data then
		return false
	end

	local cost = math.floor(amount)
	if data.cash < cost then
		return false
	end

	data.cash -= cost

	emit(player, "sink", cost, sink, data.cash)
	CurrencyService.Changed:Fire(player, data.cash, -cost, sink)
	return true
end

function CurrencyService.Get(player: Player): number
	local data = DataService.GetData(player)
	return data and data.cash or 0
end

function CurrencyService.CanAfford(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.cash >= amount
end

function CurrencyService.Init() end
function CurrencyService.Start() end

return CurrencyService
