--!strict
--[[
	STATESERVICE — replicates the client-visible slice of a profile.

	The client is shown exactly the subset in ARCHITECTURE §4 and nothing else.
	Everything absent from that list — receipts, analytics counters, session
	timestamps — stays server-side, because anything replicated is readable by
	the player and becomes something an exploiter can reason about.

	BATCHING IS THE WHOLE POINT. A sell awards cash, clears the pack, and bumps
	stats in the same frame. Firing per change is three packets for one action;
	at 20 players selling on a loop that is a lot of traffic to say one thing.
	Changes accumulate into a dirty set and go out once per tick at
	GameConfig.StateReplicationHz.

	Services never call in here directly. They fire their own Changed signals
	and this listens — so CurrencyService doesn't need to know replication
	exists, and the dependency stays one-way.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)
local TableUtil = require(Shared.Util.TableUtil)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local CurrencyService = require(ServerScriptService.Services.CurrencyService)
local InventoryService = require(ServerScriptService.Services.InventoryService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)

local StateService = {}

-- player -> { key = true } awaiting send. Values are read at flush time, not
-- captured here: if cash changes three times in one tick the client should get
-- the final figure, not a replay of the sequence.
local dirty: { [Player]: { [string]: boolean } } = {}

--[[
	Where `plotId` comes from.

	A seam rather than a require, because PlotService (A17) does not exist yet
	and StateService must not fail to load waiting for it. A17 assigns this:

		StateService.PlotResolver = PlotService.GetPlotId

	Until then every player replicates plotId = nil, which is the honest answer
	and is exactly what the client must already handle — a player is briefly
	plotless between joining and being assigned regardless.
]]
StateService.PlotResolver = function(_player: Player): string?
	return nil
end

--[[
	The allow-list. A key absent here is never sent, even if something marks it
	dirty by mistake — which is the safe direction for a mistake to fail in.

	Each entry derives its value rather than reading the profile blindly, so
	computed fields (carryWeight, fridgeCapacity) live in exactly one place.
]]
local REPLICATED: { [string]: (Player, any) -> any } = {
	cash = function(_, data)
		return data.cash
	end,

	-- ── Carry ───────────────────────────────────────────────────────────────
	carry = function(_, data)
		return table.clone(data.carry)
	end,
	carryWeight = function(player)
		return InventoryService.GetWeight(player)
	end,
	carryCapacity = function(player)
		return InventoryService.GetCapacity(player)
	end,

	--[[
		── Store ───────────────────────────────────────────────────────────────

		The fridge is replicated because the player has to see what is in stock
		to decide whether to hunt or to stand at the register. Customer
		RESERVATIONS are not: they are session-only server state, and exposing
		which units are spoken for tells a client nothing it can act on while
		giving an exploiter a model of the queue to reason about (A15 packet).
	]]
	fridge = function(_, data)
		return table.clone(data.store.fridge)
	end,
	fridgeWeight = function(_, data)
		return Meat.WeightOf(data.store.fridge)
	end,
	fridgeCapacity = function(player)
		return UpgradeService.GetValue(player, "fridge") or 0
	end,

	--[[
		Money sitting on the counter, not yet collected.

		Replicated deliberately: the pile is drawn in the world and the player
		can see it, so hiding the number buys nothing. It is NOT spendable —
		only proximity collection moves it into `cash` (ECONOMY §1).
	]]
	unclaimedCash = function(_, data)
		return data.store.unclaimedCash
	end,

	upgrades = function(_, data)
		return table.clone(data.upgrades)
	end,

	--[[
		Worker unlock/level/enabled, for the computer UI.

		Deep-copied rather than shallow: each worker is its own table, and
		table.clone would hand the client's payload a reference to the live
		record. Mutating a replicated payload is not supposed to happen, but a
		shallow copy makes it possible, and this is cheap.
	]]
	workers = function(_, data)
		return TableUtil.DeepCopy(data.workers)
	end,

	--[[
		Session plot assignment. NEVER persisted (ARCHITECTURE §4) — a player
		keeps their store contents and upgrades, not a plot number. Nil until
		PlotService (A17) assigns one, which is why the client must treat it as
		optional rather than assuming a plot exists at join.
	]]
	plotId = function(player)
		return StateService.PlotResolver(player)
	end,
	--[[
		Is auto-swing active RIGHT NOW (D-016)?

		Three things must hold: the player wants it (`settings.autoSwing`), and
		they are entitled to it — either inside the trial window or owning the
		pass. Derived here rather than stored, so it cannot go stale the moment
		the trial lapses mid-session.

		The client treats this purely as a cadence hint. It is not a permission
		gate and cannot be one: `RequestSwing` carries intent only, so a crafted
		client can auto-swing regardless (D-016 says why that is acceptable).
	]]
	autoSwing = function(_, data)
		if not data.settings.autoSwing then
			return false
		end
		local trialActive = os.time() < (data.firstJoinAt + GameConfig.AutoSwingTrialSeconds)
		-- A13 replaces this with MonetizationService.OwnsGamepass(player, "autoswing").
		local ownsPass = false
		return trialActive or ownsPass
	end,

	-- When the free window closes, as a server timestamp. The HUD counts this
	-- down (B3) — the countdown IS the conversion moment, so the client needs the
	-- number rather than just a boolean that flips one day without warning.
	autoSwingTrialEndsAt = function(_, data)
		return data.firstJoinAt + GameConfig.AutoSwingTrialSeconds
	end,

	-- The raw preference, so the toggle can render its own on/off state even
	-- while the entitlement is absent (an expired player still sees their switch).
	autoSwingEnabled = function(_, data)
		return data.settings.autoSwing
	end,

	-- EffectsController (B4) gates every particle, number and flash on this.
	-- Replicated because the setting lives on the profile but is only ever acted
	-- on by the client — the server has no use for it beyond storing it.
	reducedEffects = function(_, data)
		return data.settings.reducedEffects
	end,

}

--[[
	DELIBERATELY ABSENT, so nobody re-adds them assuming an oversight:

	`multiplierBreakdown` — ECONOMY §8 defers companions, boosts, events,
	seasons and rebirth multipliers until the corrected loop passes V1/V2. The
	V1 stub replicated a table of 1s for a UI that no longer exists. A13 brings
	it back when there is a real multiplier stack to show.

	`rebirths` — post-slice (ECONOMY §9), and nothing in the corrected slice
	renders it.

	ARCHITECTURE §4's v2 subset is the complete list. Adding a key here without
	adding it there is how the two drift apart.
]]

--[[
	Marks a key for the next flush. Unknown keys are dropped loudly — a typo
	would otherwise be a field that silently never reaches the client, which is
	miserable to debug from the UI side.
]]
function StateService.Mark(player: Player, key: string)
	if not REPLICATED[key] then
		Log.warn("State", "'%s' is not replicated — see ARCHITECTURE §4", key)
		return
	end
	local set = dirty[player]
	if not set then
		set = {}
		dirty[player] = set
	end
	set[key] = true
end

function StateService.MarkAll(player: Player)
	for key in pairs(REPLICATED) do
		StateService.Mark(player, key)
	end
end

local function build(player: Player, keys: { [string]: boolean }): { [string]: any }?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end
	local payload = {}
	for key in pairs(keys) do
		local getter = REPLICATED[key]
		if getter then
			payload[key] = getter(player, data)
		end
	end
	return payload
end

-- Sends everything at once. Used on join, before the character exists, so the
-- HUD has real numbers on its first frame instead of zeros that snap.
function StateService.PushFull(player: Player)
	local all = {}
	for key in pairs(REPLICATED) do
		all[key] = true
	end
	local payload = build(player, all)
	if payload then
		Net.Fire(player, "StateChanged", payload)
		StateService._packetsSent += 1
	end
	dirty[player] = nil
end

-- Diagnostics for the A2 verification and for A12 later.
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

	--[[
		Only the carry keys. The A15 packet requires that changing one fridge
		item does not resend unrelated state, and the reverse holds too: picking
		up meat must not resend the fridge, the workers, or the upgrade levels.

		This is why each service fires its own signal rather than one global
		"something changed" — a single broadcast would collapse into MarkAll and
		every pickup would ship the whole profile.
	]]
	InventoryService.Changed:Connect(function(player: Player)
		StateService.Mark(player, "carry")
		StateService.Mark(player, "carryWeight")
		StateService.Mark(player, "carryCapacity")
	end)

	--[[
		An upgrade changes the level table, and may change a derived capacity.

		`fridge` capacity has no other trigger — nothing touches the fridge when
		you buy a bigger one — so without this the client shows the old maximum
		until some unrelated stock change happens to flush it.
	]]
	UpgradeService.Changed:Connect(function(player: Player, track: string)
		StateService.Mark(player, "upgrades")
		if track == "carrier" then
			StateService.Mark(player, "carryCapacity")
		elseif track == "fridge" then
			StateService.Mark(player, "fridgeCapacity")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	local interval = 1 / GameConfig.StateReplicationHz
	task.spawn(function()
		while true do
			task.wait(interval)
			for player, keys in pairs(dirty) do
				dirty[player] = nil
				if player.Parent == Players then
					local payload = build(player, keys)
					if payload and next(payload) ~= nil then
						Net.Fire(player, "StateChanged", payload)
						StateService._packetsSent += 1
					end
				end
			end
		end
	end)
end

return StateService
