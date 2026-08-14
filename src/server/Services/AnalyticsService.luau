--!strict
--[[
	ANALYTICSSERVICE — where players quit, and where cash goes.

	Built on Roblox's own AnalyticsService, which has native funnel support and
	renders in the Creator Dashboard. No backend, no HTTP, no cost.

	SHIP THIS BEFORE LAUNCH. Retrofitting means losing the first week of live
	data, which is the most informative week the game will ever have — the week
	that tells you whether people quit before their first sell.

	Three numbers this exists to answer (ANALYTICS §7):
	  1. % of joins reaching first_collection — under 80% and the opening is
	     broken. That is the first COLLECTED store sale, not the first kill:
	     a player who hunts but never completes the store loop has not played
	     the game (GDD §9).
	  2. D1 retention — the discovery algorithm's input, so it gates traffic
	  3. Starter Pack conversion

	NEVER BLOCKS GAMEPLAY. Every call is pcall-wrapped and fired off-thread. An
	analytics outage must never cost a player their sell.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RbxAnalytics = game:GetService("AnalyticsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local DataService = require(ServerScriptService.Services.DataService)

local AnalyticsService = {}

--[[
	ONBOARDING FUNNEL — ANALYTICS §3.

	Ordered, and each step fires exactly once per player EVER. The guard lives on
	the profile (D-012), not in memory: a session-scoped guard re-fires every
	milestone on rejoin and the funnel quietly becomes a measure of how often
	people rejoin rather than how far they get.
]]
--[[
	Rewritten for D-017. The V1 steps measured a game that no longer exists:
	`first_sell` was the sell pad, `zone_2` was the five-zone gate, and
	`first_hatch`/`first_rebirth` belong to deferred designs. None of them could
	ever fire again, which would have left the funnel silently reporting a 0%
	completion rate rather than an error.

	These follow GDD §9's first-session shape, and `first_collection` is the one
	that matters: ECONOMY and GDD both make the first COLLECTED store sale a
	release blocker. Stocking and checkout are the two steps before it, so a
	drop-off tells you which half of the store loop lost the player.
]]
local ONBOARDING = {
	joined = 1,
	first_kill = 2,
	first_stock = 3,
	first_checkout = 4,
	first_collection = 5,
	first_upgrade = 6,
	first_worker = 7,
}

-- Session funnel — ANALYTICS §4. Repeats every session, so it is memory-scoped.
local SESSION_FUNNEL = "session"
local SESSION_STEPS = {
	session_start = 1,
	collected_once = 2, -- was sold_once; there is no sell action under D-017
	offer_shown = 3,
	offer_purchased = 4,
	session_5min = 5,
	session_20min = 6,
}

local sessionId: { [Player]: string } = {}
local sessionFired: { [Player]: { [string]: boolean } } = {}

-- ── Segmentation (D-013: three fields, not five) ────────────────────────────

local function customFields(player: Player): { [string]: string }
	local data = DataService.GetData(player)
	if not data then
		return {}
	end

	--[[
		The progression cut. D-013 picked zone / payer / progress, and the zone
		half no longer exists — D-017 replaced five gated zones with one shared
		hunting ground.

		The refrigerator is the best single proxy for where a player got to:
		ECONOMY §5 constraint 4 makes fridge capacity the deliberate bottleneck,
		so its level tracks real progress through the loop. That answers the
		same question D-013 wanted — conversion for players who never cleared
		the first bottleneck versus those who did.
	]]
	local progress = ("fridge_%d"):format(data.upgrades.fridge)

	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = progress,
		-- receipts is keyed by receipt id, not an array, so # is always 0.
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = (next(data.receipts) ~= nil) and "payer" or "free",
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = ("rebirth_%d"):format(data.rebirths),
	}
end

-- Everything routes through here: one pcall, one off-thread spawn, one place
-- to disable the whole system.
local function safe(fn: () -> ())
	if not GameConfig.AnalyticsEnabled then
		return
	end
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			Log.once("analytics_err", "Analytics", "call failed: %s", tostring(err))
		end
	end)
end

-- ── Onboarding ──────────────────────────────────────────────────────────────

--[[
	Fires a milestone if this player has never reached it.

	Returns true if it fired. Callers don't need to check first — the guard is
	here so no service has to remember it, and so the rule can't be
	half-implemented in six places.
]]
function AnalyticsService.Milestone(player: Player, step: string): boolean
	local index = ONBOARDING[step]
	if not index then
		Log.warn("Analytics", "unknown onboarding step '%s'", step)
		return false
	end

	local data = DataService.GetData(player)
	if not data then
		return false
	end
	if data.funnelSteps[step] then
		return false
	end

	data.funnelSteps[step] = true
	safe(function()
		RbxAnalytics:LogOnboardingFunnelStepEvent(player, index, step)
	end)
	Log.info("Analytics", "%s reached %s (step %d)", player.Name, step, index)
	return true
end

-- ── Session funnel ──────────────────────────────────────────────────────────

function AnalyticsService.SessionStep(player: Player, step: string)
	local index = SESSION_STEPS[step]
	if not index then
		Log.warn("Analytics", "unknown session step '%s'", step)
		return
	end
	local fired = sessionFired[player]
	if not fired or fired[step] then
		return
	end
	fired[step] = true

	safe(function()
		RbxAnalytics:LogFunnelStepEvent(player, SESSION_FUNNEL, sessionId[player], index, step)
	end)
end

-- ── Economy ─────────────────────────────────────────────────────────────────

--[[
	Every cash movement. Called from CurrencyService's two write paths and
	nowhere else, which is why every source and sink carries a label.

	ANALYTICS §5's question this answers: ECONOMY §7 rule 7 wants eggs to absorb
	60–70% of lifetime cash. Summing sinks by category is the only way to know,
	and it is unanswerable if a single `data.cash += x` exists somewhere else.
]]
function AnalyticsService.Economy(
	player: Player,
	isSource: boolean,
	amount: number,
	label: string,
	endingBalance: number
)
	safe(function()
		local flow = isSource and Enum.AnalyticsEconomyFlowType.Source
			or Enum.AnalyticsEconomyFlowType.Sink

		-- Transaction type drives how the dashboard groups it. A Robux purchase
		-- is IAP, a shop spend is Shop, everything else is ordinary play.
		local transaction = Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		if label == "product_purchase" or label == "starter_pack" then
			transaction = Enum.AnalyticsEconomyTransactionType.IAP.Name
		elseif label:match("^upgrade_") or label == "zone_unlock" or label:match("^egg_") then
			transaction = Enum.AnalyticsEconomyTransactionType.Shop.Name
		elseif label == "daily" or label == "quest" or label == "playtime_chest" then
			transaction = Enum.AnalyticsEconomyTransactionType.TimedReward.Name
		end

		RbxAnalytics:LogEconomyEvent(
			player,
			flow,
			"cash",
			math.abs(amount),
			endingBalance,
			transaction,
			label,
			customFields(player)
		)
	end)
end

-- ── Custom ──────────────────────────────────────────────────────────────────

function AnalyticsService.Event(player: Player, name: string, value: number?)
	safe(function()
		RbxAnalytics:LogCustomEvent(player, name, value or 0, customFields(player))
	end)
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function AnalyticsService.Init() end

function AnalyticsService.Start()
	DataService.Loaded:Connect(function(player: Player, data: any)
		sessionId[player] = ("%d_%d"):format(player.UserId, os.time())
		sessionFired[player] = {}

		AnalyticsService.Milestone(player, "joined")
		AnalyticsService.SessionStep(player, "session_start")

		-- Session-length steps. D1 retention is DERIVED from session_start
		-- timestamps (ANALYTICS §4) — firing a "d1_return" event would mean
		-- guessing the boundary ourselves and getting it wrong.
		task.delay(300, function()
			if player.Parent == Players then
				AnalyticsService.SessionStep(player, "session_5min")
			end
		end)
		task.delay(1200, function()
			if player.Parent == Players then
				AnalyticsService.SessionStep(player, "session_20min")
			end
		end)
	end)

	--[[
		Milestones are derived from signals that already exist, rather than by
		adding a call into every service. That keeps this the only file that
		knows the funnel — and specifically avoids editing UpgradeService, which
		belongs to another job in flight (WORKFLOW §2).
	]]
	local Currency = require(ServerScriptService.Services.CurrencyService)
	Currency.Changed:Connect(function(player: Player, _new: number, delta: number, reason: string)
		--[[
			`store_collection` is the ONLY source of store revenue under D-017
			(ECONOMY §1) — cash does not move at death, unload, reservation or
			checkout. So watching CurrencyService still catches the release-
			blocking milestone without this file knowing anything about
			refrigerators or registers.
		]]
		if reason == "store_collection" then
			AnalyticsService.Milestone(player, "first_collection")
			AnalyticsService.SessionStep(player, "collected_once")
		elseif reason:match("^upgrade_") then
			AnalyticsService.Milestone(player, "first_upgrade")
		end

		local data = DataService.GetData(player)
		if data then
			AnalyticsService.Economy(player, delta > 0, delta, reason, data.cash)
		end
	end)

	local Creature = require(ServerScriptService.Services.CreatureService)
	Creature.Died:Connect(function(killer: Player?)
		if killer then
			AnalyticsService.Milestone(killer, "first_kill")
		end
	end)

	--[[
		The zone-unlock funnel event is gone with ZoneService (D-017).

		Its replacements are the store-loop milestones — first stock, first
		checkout, first collection — and they belong to the services that
		produce them (A18, A22, A23), not here. This service stays an emitter;
		it does not reach into other services to infer their events.
	]]

	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.GetData(player)
		if data then
			AnalyticsService.Event(player, "session_end", data.stats.playtimeSeconds)
		end
		sessionId[player] = nil
		sessionFired[player] = nil
	end)
end

return AnalyticsService
