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
local ProfileSchema = require(Shared.ProfileSchema)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Log = require(Shared.Util.Log)
local ProfileStore = require(ServerScriptService.Lib.ProfileStore)

local DataService = {}

-- Fires (player, data) once the profile is ready. Services that need data at
-- join time connect to this rather than polling GetData.
DataService.Loaded = Signal.new()

-- ── Template and migrations — ARCHITECTURE §4 ──────────────────────────────

local TEMPLATE = ProfileSchema.Template
export type ProfileData = ProfileSchema.ProfileData

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
	local prepared, migrationError = ProfileSchema.Prepare(profile.Data)
	if not prepared then
		Log.error("Data", "profile migration failed for %s: %s", profile.Key, tostring(migrationError))
		profile:EndSession()
		player:Kick("Could not update your data. Please rejoin.")
		return
	end

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
function DataService.GetData(player: Player): ProfileData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data :: ProfileData
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
			task.wait(GameConfig.LeaderstatsRefreshSeconds)
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
