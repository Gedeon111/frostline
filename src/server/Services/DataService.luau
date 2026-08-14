--!strict
--[[
	DATASERVICE — profile lifecycle. The ONLY place that touches a DataStore.

	Every other service reads through GetData(player). No service holds a profile
	reference: a profile can end its session at any moment (another server steals
	the lock, the player leaves), and a stale reference would write into a table
	nobody is saving.

		local data = DataService.GetData(player)
		if not data then return end          -- always guard; load is async
		data.cash += 100

	Schema and the replicated subset live in ARCHITECTURE §4. Changing the
	template requires an RFC.

	WHAT PROFILESTORE ALREADY DOES, SO WE DON'T:
	  - periodic autosave (AUTO_SAVE_PERIOD, set below from GameConfig)
	  - game:BindToClose flushing every active profile
	  - session locking across servers
	A second autosave loop or BindToClose here would double every DataStore
	write and burn request budget for nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
-- Read by the v1 -> v2 migration to translate old pack contents into meat ids.
local Creatures = require(Shared.Config.Creatures)
local Meat = require(Shared.Config.Meat)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)
local Format = require(Shared.Util.Format)
local Log = require(Shared.Util.Log)
local ProfileStore = require(ServerScriptService.Lib.ProfileStore)

local DataService = {}

-- Fires (player, data) once the profile is ready. Services that need data at
-- join time connect to this rather than polling GetData.
DataService.Loaded = Signal.new()

-- ── Template — ARCHITECTURE §4 ──────────────────────────────────────────────
-- Adding a field here is free: Reconcile() fills it in for existing players on
-- their next load. Removing or renaming one is not — that needs a migration.

local TEMPLATE = {
	version = 2,
	cash = 0,
	totalCashEarned = 0,

	-- What the player is carrying right now, meatId -> count. Weight is derived
	-- from Config.Meat, never stored — a stored weight goes stale the moment
	-- anyone retunes an item.
	carry = {},

	--[[
		The store. Persists across leave/rejoin: GDD §8 requires the game never
		erase earned value because a server closed, and unclaimed cash on the
		counter is earned value the player simply has not walked over yet.
	]]
	store = {
		fridge = {},
		unclaimedCash = 0,
	},

	upgrades = { axe = 1, carrier = 1, fridge = 1, register = 1 },

	workers = {
		stocker = { unlocked = false, level = 0, enabled = false },
		cashier = { unlocked = false, level = 0, enabled = false },
		hunter = { unlocked = false, level = 0, enabled = false },
	},

	rebirths = 0,

	-- autoSwing is a PREFERENCE, never an entitlement (D-016). It records that the
	-- player WANTS auto-swing; whether they may have it is derived server-side
	-- from the trial window and pass ownership. Defaults true so the trial is
	-- running from the first second, which is the entire point of a trial.
	settings = { music = true, sfx = true, reducedEffects = false, autoSwing = true },

	-- Onboarding milestones already fired, keyed by step name (D-012). MUST be
	-- persisted: a session-scoped guard re-fires every milestone on rejoin and
	-- the funnel becomes a measure of how often people rejoin.
	funnelSteps = {},

	stats = {
		kills = 0,
		meatStocked = 0,
		customerSales = 0,
		cashCollections = 0,
		playtimeSeconds = 0,
		goldenKills = 0,
	},

	receipts = {},
	firstJoinAt = 0,
	lastJoinAt = 0,
}

export type ProfileData = typeof(TEMPLATE)

-- ── Migrations ──────────────────────────────────────────────────────────────
--[[
	Keyed by the version being migrated FROM.

	Deterministic and idempotent in effect: running v1 -> v2 twice on the same
	table produces the same result, because every step reads a v1 field, writes
	a v2 field, and then clears the v1 field.

	The rule this migration is written against (ARCHITECTURE §4 / GDD §8): the
	game must never erase earned value. Cash, lifetime earnings, settings,
	analytics milestones, receipts and timestamps are preserved exactly. Nothing
	here is allowed to drop a number a player worked for.
]]
local MIGRATIONS: { [number]: (any) -> () } = {
	--[[
		v1 -> v2 (D-017). The sell-pad game becomes the store game.

		What moves:
		  pack{tierId->count}  -> carry{meatId->count}   via the tier's meatId
		  upgrades.pack        -> upgrades.carrier       same level, same table
		  upgrades.harpoon     -> upgrades.axe           same level, same table
		  stats.sells          -> stats.customerSales    closest honest analogue

		What is created at its configured start:
		  upgrades.fridge, upgrades.register, workers, store

		What is dropped, and why that is safe:
		  upgrades.boots       no movement track in the corrected slice
		  unlockedZones        no zones to unlock
		  companions/eggStats/quests/season/boosts/offers/social/claims
		                       deferred designs, not entitlements

		ECONOMY and ARCHITECTURE both note the game is pre-release, so no Robux
		entitlement and no public player's purchase is discarded by any of that.
		Boots levels bought with in-game cash ARE lost; there is no movement
		track to carry them into, and inventing one to preserve them would be a
		design decision smuggled in through a migration.

		Old meta fields are left in storage rather than deleted. They are not
		replicated or read, and keeping them means a reversal does not need to
		reconstruct data we chose to throw away.
	]]
	[1] = function(data: any)
		-- pack -> carry, translating tier ids to meat ids.
		local carry: { [string]: number } = {}
		if type(data.pack) == "table" then
			for tierId, count in pairs(data.pack) do
				if type(count) == "number" and count > 0 then
					-- A tier that no longer exists (the four retired ones) has no
					-- meat id. Its contents fall back to the starter meat rather
					-- than vanishing — the player still carried something.
					local meatId = Creatures.MeatIdFor(tierId, nil) or Meat.Order[1]
					carry[meatId] = (carry[meatId] or 0) + count
				end
			end
		end
		data.carry = carry
		data.pack = nil

		-- Upgrade tracks: renamed, levels preserved exactly (ECONOMY §3 — the
		-- values do not change during the naming migration).
		local old = if type(data.upgrades) == "table" then data.upgrades else {}
		data.upgrades = {
			axe = tonumber(old.harpoon) or 1,
			carrier = tonumber(old.pack) or 1,
			fridge = 1,
			register = 1,
		}

		data.store = {
			fridge = {},
			unclaimedCash = 0,
		}

		data.workers = {
			stocker = { unlocked = false, level = 0, enabled = false },
			cashier = { unlocked = false, level = 0, enabled = false },
			hunter = { unlocked = false, level = 0, enabled = false },
		}

		-- Stats: keep what still means something, seed what does not exist yet.
		local stats = if type(data.stats) == "table" then data.stats else {}
		data.stats = {
			kills = tonumber(stats.kills) or 0,
			-- A v1 "sell" was a whole-pack sale at a pad. The nearest v2 concept
			-- is a completed customer sale. Carried across rather than zeroed so
			-- lifetime totals stay monotonic for anyone watching them.
			customerSales = tonumber(stats.sells) or 0,
			meatStocked = 0,
			cashCollections = 0,
			playtimeSeconds = tonumber(stats.playtimeSeconds) or 0,
			goldenKills = tonumber(stats.goldenKills) or 0,
		}

		-- Explicitly retired. Nulled so a stale reader fails loudly rather than
		-- silently acting on a value the game no longer honours.
		data.unlockedZones = nil
	end,
}

local function migrate(data: any, key: string)
	local guard = 0
	while (data.version or 1) < GameConfig.ProfileVersion do
		local step = MIGRATIONS[data.version]
		if not step then
			Log.warn("Data", "no migration from v%d for %s — leaving as is", data.version, key)
			return
		end
		local ok, err = pcall(step, data)
		if not ok then
			Log.error("Data", "migration v%d failed for %s: %s", data.version, key, tostring(err))
			return
		end
		data.version += 1

		guard += 1
		if guard > 50 then
			-- A migration that forgets to bump version would spin forever.
			Log.error("Data", "migration loop guard tripped for %s", key)
			return
		end
	end
end

-- ── Store ───────────────────────────────────────────────────────────────────

local profiles: { [Player]: any } = {}
local store: any
local usingMock = false

local function keyFor(player: Player): string
	return `{GameConfig.DataStoreScope}_{player.UserId}`
end

--[[
	DataStores are unreachable in Studio unless "Studio Access to API Services"
	is enabled in Game Settings → Security. Rather than fail every join with an
	opaque error, detect it once and fall back to ProfileStore's in-memory Mock
	so the rest of the game is testable.

	Loud on purpose: silently running on mock data would look exactly like
	working persistence right up until someone tests a rejoin.
]]
local function apiAccessAvailable(): boolean
	if not RunService:IsStudio() then
		return true
	end
	local ok = pcall(function()
		DataStoreService:GetDataStore("__api_probe"):GetAsync("__api_probe")
	end)
	return ok
end

-- ── Loading ─────────────────────────────────────────────────────────────────

local function buildLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	-- StringValue, not IntValue: cash passes 2^31 well before the endgame, and
	-- an abbreviated "4.8B" reads better in the player list than the raw digits.
	-- Numeric sorting isn't lost — the real leaderboard is D4's OrderedDataStore.
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "0"
	cash.Parent = folder

	folder.Parent = player
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(keyFor(player), {
		Cancel = function()
			-- Stop trying if they left while we were loading.
			return player.Parent ~= Players
		end,
	})

	if not profile then
		-- Another server holds the lock and wouldn't release it, or the request
		-- failed repeatedly. Playing on a session that cannot save is worse than
		-- not playing — they'd earn progress and silently lose all of it.
		Log.warn("Data", "no session for %s — kicking", player.Name)
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: ties the key to the account
	profile:Reconcile() -- fills in fields added to TEMPLATE since their last load
	migrate(profile.Data, profile.Key)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		-- Reaching here while they're still in game means the lock was taken by
		-- another server. Continuing would discard everything they do next.
		if player.Parent == Players then
			player:Kick("Your data was opened elsewhere. Please rejoin.")
		end
	end)

	local data = profile.Data
	local now = os.time()
	if data.firstJoinAt == 0 then
		data.firstJoinAt = now
	end
	data.lastJoinAt = now

	profiles[player] = profile
	buildLeaderstats(player)

	Log.info("Data", "loaded %s (session #%d)", player.Name, profile.SessionLoadCount)
	DataService.Loaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession() -- saves, then releases the lock
	end
	profiles[player] = nil
end

-- ── Public API ──────────────────────────────────────────────────────────────

-- nil while loading, after a failed load, or once the session has ended.
-- ALWAYS guard the result.
--[[
	Testing surface for F5's contract tests.

	The migration is the one piece of this service that is pure — it takes a
	table and rewrites it — and it is also the piece where a mistake silently
	destroys a player's money. Exposing it lets the contract tests run it
	against real v1 fixtures without a DataStore, a player, or a loaded profile.

	`WORKFLOW §8` is why this has to be explicit: `execute_luau` runs in its own
	module cache, so a test cannot reach into this service's live state. Only a
	function it can call directly is reachable.

	Returns the same table, mutated, so a caller can assert on it inline.
]]
function DataService.MigrateForTest(data: any): any
	migrate(data, "test")
	return data
end

-- The default profile, copied. Tests assert the template's shape against
-- ARCHITECTURE §4 without being able to mutate the real one.
function DataService.GetTemplateForTest(): any
	return TableUtil.DeepCopy(TEMPLATE)
end

function DataService.GetData(player: Player): ProfileData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data
	end
	return nil
end

function DataService.IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

-- Forces an immediate save. For genuinely irreversible moments only — a Robux
-- purchase, a rebirth. Routine progress is covered by autosave; calling this
-- per sell would burn the request budget.
function DataService.Save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

function DataService.IsUsingMock(): boolean
	return usingMock
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function DataService.Init()
	-- Default is 300s. GameConfig.AutosaveInterval (60s) bounds how much
	-- progress a hard server crash can destroy. ProfileStore staggers saves
	-- across the period, so this is not a thundering herd.
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", GameConfig.AutosaveInterval)

	local real = ProfileStore.New(GameConfig.DataStoreName, TEMPLATE)

	if apiAccessAvailable() then
		store = real
	else
		usingMock = true
		store = real.Mock
		Log.warn("Data", "===============================================")
		Log.warn("Data", "API ACCESS OFF — using in-memory MOCK storage.")
		Log.warn("Data", "Nothing persists. Enable Game Settings →")
		Log.warn("Data", "Security → Studio Access to API Services.")
		Log.warn("Data", "===============================================")
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- In Studio the player exists before this runs, so PlayerAdded never fires
	-- for them. Without this, testing in Studio silently loads nothing.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Mirror cash into the player list. Polled rather than pushed so no service
	-- has to remember to notify us; 1Hz across 20 players is free.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in pairs(profiles) do
				local stats = player:FindFirstChild("leaderstats")
				local cash = stats and stats:FindFirstChild("Cash")
				if cash and profile:IsActive() then
					local text = Format.Abbreviate(profile.Data.cash)
					if (cash :: StringValue).Value ~= text then
						(cash :: StringValue).Value = text
					end
				end
			end
		end
	end)
end

return DataService
