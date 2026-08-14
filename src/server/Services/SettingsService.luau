--!strict
--[[
	SETTINGSSERVICE — the one writer for `profile.settings` (D-016).

	Settings are PREFERENCES. Nothing here grants an entitlement, and that
	distinction is the whole security model of this file: writing
	`autoSwing = true` records that the player wants auto-swing on. Whether they
	may actually have it is derived in StateService from the trial window and
	pass ownership, and is recomputed every replication tick.

	Get that backwards — treat a setting as permission — and the 399 Robux pass
	becomes a boolean the client can ask for.

	B9's settings menu (music, sfx, reducedEffects) lands on this same remote. It
	exists as one generic endpoint rather than a remote per switch so the
	allow-list stays in one readable place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

-- How often the trial-expiry watcher looks. Not a gameplay number: it only sets
-- how promptly the toggle stops working, and 5s of grace is imperceptible.
local TRIAL_POLL_SECONDS = 5

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local StateService = require(ServerScriptService.Services.StateService)

local SettingsService = {}

--[[
	The allow-list: setting key -> the replicated keys to re-push when it changes.

	A key absent here is rejected. Without the list, `RequestSetting` is an
	arbitrary write into the profile table — a client could set
	`settings.__index`, or invent keys until the profile stops fitting in a
	DataStore.

	Every value is a boolean. That is asserted below rather than assumed; it is
	what keeps this endpoint from becoming a general-purpose profile writer.
]]
local SETTABLE: { [string]: { string } } = {
	-- Changing the preference changes whether auto-swing is live, so both the
	-- derived flag and the raw preference must be re-pushed.
	autoSwing = { "autoSwing", "autoSwingEnabled" },
	music = {},
	sfx = {},
	reducedEffects = {},
}

local function onRequestSetting(player: Player, key: any, value: any): (boolean, string?)
	if typeof(key) ~= "string" then
		return false, "invalid"
	end

	local affected = SETTABLE[key]
	if not affected then
		-- Not logged per call: an exploiter probing key names would otherwise
		-- write the console full on demand.
		Log.once(`setting_{player.UserId}_{key}`, "Settings", "%s tried to set unknown key '%s'", player.Name, key)
		return false, "invalid"
	end

	if typeof(value) ~= "boolean" then
		return false, "invalid"
	end

	local data = DataService.GetData(player)
	if not data then
		return false, "not_loaded"
	end

	if data.settings[key] == value then
		-- Idempotent. A toggle spammed by a stuck button should not dirty the
		-- profile or push replication every time.
		return true, nil
	end

	data.settings[key] = value

	for _, replicatedKey in ipairs(affected) do
		StateService.Mark(player, replicatedKey)
	end

	return true, nil
end

function SettingsService.Init()
	Net.On("RequestSetting", onRequestSetting)
end

function SettingsService.Start()
	--[[
		The auto-swing trial expires on a wall clock, so nothing the player does
		marks the moment it lapses. Without a watcher, a player mid-session keeps
		auto-swinging until some unrelated change happens to flush state — a free
		extension of arbitrary length.

		Only the TRANSITION is pushed. Marking every player every tick would send
		a replication packet per player per interval forever, to say a value that
		has not changed — StateService batches at 10Hz precisely to avoid that
		kind of traffic, and this would put it straight back.
	]]
	local wasActive: { [Player]: boolean } = {}

	Players.PlayerRemoving:Connect(function(player)
		wasActive[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TRIAL_POLL_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.GetData(player)
				if data then
					local active = os.time() < (data.firstJoinAt + GameConfig.AutoSwingTrialSeconds)
					if wasActive[player] == nil then
						wasActive[player] = active
					elseif wasActive[player] ~= active then
						wasActive[player] = active
						StateService.Mark(player, "autoSwing")
						Log.info("Settings", "%s auto-swing trial %s", player.Name, active and "started" or "expired")
					end
				end
			end
		end
	end)
end

return SettingsService
