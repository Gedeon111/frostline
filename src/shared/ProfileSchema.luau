--!strict
--[[
	PROFILESCHEMA — pure v2 template, migration, reconciliation, and entitlement
	derivation. DataService owns persistence; this module makes its data rules
	testable without loading ProfileStore or DataStores.

	The root pack/unlockedZones and legacy upgrade keys are temporary runtime
	bridges. A15/A16/A19/A20/A21 remove their consumers, then F5-cleanup deletes
	the bridge without another data migration.
]]

local GameConfig = require(script.Parent.Config.GameConfig)
local Upgrades = require(script.Parent.Config.Upgrades)
local Workers = require(script.Parent.Config.Workers)
local Zones = require(script.Parent.Config.Zones)
local TableUtil = require(script.Parent.Util.TableUtil)

local ProfileSchema = {}

local function workerDefault()
	return {
		unlocked = false,
		level = Workers.LockedLevel,
		enabled = false,
	}
end

local initial = Upgrades.InitialLevel

ProfileSchema.Template = {
	version = GameConfig.ProfileVersion,
	cash = 0,
	totalCashEarned = 0,
	carry = {},
	store = {
		fridge = {},
		unclaimedCash = 0,
	},
	upgrades = {
		axe = initial,
		carrier = initial,
		fridge = initial,
		register = initial,

		-- Temporary v1 bridge.
		pack = initial,
		boots = initial,
		harpoon = initial,
	},
	workers = {
		stocker = workerDefault(),
		cashier = workerDefault(),
		hunter = workerDefault(),
	},
	rebirths = 0,
	settings = {
		music = true,
		sfx = true,
		reducedEffects = false,
		autoSwing = true,
	},
	funnelSteps = {},
	stats = {
		kills = 0,
		meatStocked = 0,
		customerSales = 0,
		cashCollections = 0,
		playtimeSeconds = 0,
		goldenKills = 0,
		sells = 0, -- legacy analytics only
	},
	receipts = {},
	firstJoinAt = 0,
	lastJoinAt = 0,

	-- Temporary v1 bridge.
	pack = {},
	unlockedZones = { [Zones.StartingZone] = true },
}

export type ProfileData = typeof(ProfileSchema.Template)

local function migrateV1(data: any)
	local oldPack = if typeof(data.pack) == "table" then data.pack else {}
	if typeof(data.carry) ~= "table" or next(data.carry) == nil then
		data.carry = TableUtil.DeepCopy(oldPack)
	end

	local upgrades = if typeof(data.upgrades) == "table" then data.upgrades else {}
	data.upgrades = upgrades
	upgrades.carrier = upgrades.carrier or upgrades.pack or initial
	upgrades.axe = upgrades.axe or upgrades.harpoon or initial
	upgrades.fridge = upgrades.fridge or initial
	upgrades.register = upgrades.register or initial

	if typeof(data.store) ~= "table" then
		data.store = {}
	end
	if typeof(data.store.fridge) ~= "table" then
		data.store.fridge = {}
	end
	data.store.unclaimedCash = data.store.unclaimedCash or 0

	if typeof(data.workers) ~= "table" then
		data.workers = {}
	end
	if typeof(data.settings) ~= "table" then
		data.settings = {}
	end
	if typeof(data.stats) ~= "table" then
		data.stats = {}
	end

	data.version = GameConfig.ProfileVersion
end

function ProfileSchema.Migrate(data: any): (boolean, string?)
	local version = data.version or 1
	local steps = 0

	while version < GameConfig.ProfileVersion do
		if version == 1 then
			migrateV1(data)
		else
			return false, `no migration from v{version}`
		end

		version = data.version
		steps += 1
		if steps > GameConfig.MigrationMaxSteps then
			return false, "migration loop guard"
		end
	end

	if version > GameConfig.ProfileVersion then
		return false, `profile v{version} is newer than runtime v{GameConfig.ProfileVersion}`
	end

	return true, nil
end

local function installLegacyBridge(data: any)
	data.pack = data.carry
	data.upgrades.pack = data.upgrades.carrier
	data.upgrades.harpoon = data.upgrades.axe
	data.upgrades.boots = data.upgrades.boots or initial
	data.unlockedZones = data.unlockedZones or { [Zones.StartingZone] = true }
end

function ProfileSchema.Prepare(data: any): (boolean, string?)
	local ok, reason = ProfileSchema.Migrate(data)
	if not ok then
		return false, reason
	end

	local reconciled = TableUtil.Reconcile(data, ProfileSchema.Template)
	for key in pairs(data) do
		data[key] = nil
	end
	for key, value in pairs(reconciled) do
		data[key] = value
	end

	installLegacyBridge(data)
	return true, nil
end

function ProfileSchema.IsAutoSwingActive(data: any, now: number, ownsPass: boolean): boolean
	if not data.settings.autoSwing then
		return false
	end
	local trialActive = now < data.firstJoinAt + GameConfig.AutoSwingTrialSeconds
	return trialActive or ownsPass
end

return ProfileSchema
