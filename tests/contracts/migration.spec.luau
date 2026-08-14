--!strict
--[[
	CONTRACT: v1 -> v2 profile migration (F5).

	This is the test that matters most in the whole suite. A shape mistake in a
	config file is annoying; a mistake here destroys money real players earned,
	silently, on their next login — and there is no undo, because the migrated
	profile is what gets written back.

	The F5 packet's "Done when" is asserted directly:
	  - an old fixture migrates without losing cash/carry/receipts
	  - a fresh fixture reconciles
	  - Auto-Swing state still derives correctly

	Every fixture below is a realistic v1 profile, not a minimal stub. A
	migration that only works on tidy input is a migration that fails in
	production, where profiles carry half-finished features and fields nobody
	remembers adding.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)

local DataService = require(ServerScriptService.Services.DataService)

-- A representative v1 profile: mid-progression, some of everything.
local function v1Fixture(): any
	return {
		version = 1,
		cash = 12345,
		totalCashEarned = 98765,
		pack = { snow_cub = 4, frost_bear = 2 },
		upgrades = { pack = 5, boots = 3, harpoon = 7 },
		unlockedZones = { shelf_ice = true, glacier_ridge = true },
		rebirths = 2,
		companions = { wolf = { count = 3, golden = false } },
		equipped = {},
		indexClaimed = {},
		eggStats = { hatches = 17, byEgg = {} },
		quests = { daily = {}, weekly = {}, dailyResetAt = 0, weeklyResetAt = 0 },
		season = { id = "s1", xp = 400, tier = 4, premium = true, claimed = {} },
		boosts = { luck = 1786700000 },
		offers = { starterShownAt = 100, starterPurchased = true, dealsSeed = 42 },
		social = { groupClaimed = true },
		funnelSteps = { first_kill = true, first_sell = true },
		stats = { kills = 250, sells = 31, playtimeSeconds = 4200, goldenKills = 3 },
		settings = { music = false, sfx = true, reducedEffects = true, autoSwing = false },
		claims = { lastDailyAt = 500, dailyStreak = 4, redeemedCodes = { launch = true } },
		receipts = { ["receipt-abc"] = true, ["receipt-def"] = true },
		firstJoinAt = 1786600000,
		lastJoinAt = 1786690000,
	}
end

return function(describe, it, expect)
	describe("value preservation — nothing a player earned may vanish", function()
		it("preserves cash exactly", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.cash).toBe(12345)
		end)

		it("preserves lifetime earnings", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.totalCashEarned).toBe(98765)
		end)

		it("preserves receipts", function()
			-- Receipt ids are the idempotency guard for real Robux purchases.
			-- Losing one means a player can be charged twice for the same thing.
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.receipts["receipt-abc"]).toBe(true)
			expect(data.receipts["receipt-def"]).toBe(true)
		end)

		it("preserves settings, including the auto-swing preference", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.settings.music).toBe(false)
			expect(data.settings.reducedEffects).toBe(true)
			-- The fixture had auto-swing deliberately turned OFF. A migration
			-- that reset it to the template default would silently re-enable a
			-- paid feature's toggle against the player's choice.
			expect(data.settings.autoSwing).toBe(false)
		end)

		it("preserves analytics milestones", function()
			-- D-012: these guard once-per-player-ever funnel events. Losing them
			-- re-fires the funnel and makes the metric measure rejoins.
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.funnelSteps.first_kill).toBe(true)
		end)

		it("preserves timestamps, which the trial derives from", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.firstJoinAt).toBe(1786600000)
			expect(data.lastJoinAt).toBe(1786690000)
		end)

		it("preserves rebirths", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.rebirths).toBe(2)
		end)
	end)

	describe("carry — pack contents survive as meat", function()
		it("converts every pack item into real meat ids", function()
			local data = DataService.MigrateForTest(v1Fixture())
			-- 4 snow_cub + 2 frost_bear. frost_bear is a retired tier, so its
			-- contents fall back to starter meat rather than being dropped.
			expect(Meat.CountOf(data.carry)).toBe(6)
		end)

		it("produces only ids that exist", function()
			local data = DataService.MigrateForTest(v1Fixture())
			for meatId in pairs(data.carry) do
				expect(Meat.Get(meatId)).toBeTruthy()
			end
		end)

		it("removes the v1 pack field", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.pack).toBeNil()
		end)

		it("handles an empty pack", function()
			local fixture = v1Fixture()
			fixture.pack = {}
			local data = DataService.MigrateForTest(fixture)
			expect(Meat.CountOf(data.carry)).toBe(0)
		end)

		it("handles a missing pack field", function()
			-- A profile written before pack existed, or corrupted.
			local fixture = v1Fixture()
			fixture.pack = nil
			local data = DataService.MigrateForTest(fixture)
			expect(Meat.CountOf(data.carry)).toBe(0)
		end)
	end)

	describe("upgrade tracks are renamed, not reset", function()
		it("harpoon level becomes axe level", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.upgrades.axe).toBe(7)
		end)

		it("pack level becomes carrier level", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.upgrades.carrier).toBe(5)
		end)

		it("fridge and register start at level 1", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.upgrades.fridge).toBe(1)
			expect(data.upgrades.register).toBe(1)
		end)

		it("boots is gone", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.upgrades.boots).toBeNil()
		end)

		it("defaults to level 1 when upgrades are missing entirely", function()
			local fixture = v1Fixture()
			fixture.upgrades = nil
			local data = DataService.MigrateForTest(fixture)
			expect(data.upgrades.axe).toBe(1)
			expect(data.upgrades.carrier).toBe(1)
		end)
	end)

	describe("new V2 structures are created", function()
		it("store starts empty with no unclaimed cash", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.store).toBeTruthy()
			expect(data.store.unclaimedCash).toBe(0)
			expect(Meat.CountOf(data.store.fridge)).toBe(0)
		end)

		it("all three workers exist, locked and disabled", function()
			local data = DataService.MigrateForTest(v1Fixture())
			for _, id in ipairs({ "stocker", "cashier", "hunter" }) do
				expect(data.workers[id]).toBeTruthy()
				expect(data.workers[id].unlocked).toBe(false)
				expect(data.workers[id].enabled).toBe(false)
				expect(data.workers[id].level).toBe(0)
			end
		end)
	end)

	describe("stats", function()
		it("carries kills and playtime across", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.stats.kills).toBe(250)
			expect(data.stats.playtimeSeconds).toBe(4200)
			expect(data.stats.goldenKills).toBe(3)
		end)

		it("maps v1 sells onto customer sales", function()
			-- Keeps a lifetime total monotonic rather than resetting it to zero
			-- for anyone watching the number.
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.stats.customerSales).toBe(31)
		end)

		it("seeds the new counters at zero", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.stats.meatStocked).toBe(0)
			expect(data.stats.cashCollections).toBe(0)
		end)
	end)

	describe("retired fields", function()
		it("clears unlockedZones", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.unlockedZones).toBeNil()
		end)
	end)

	describe("version and idempotence", function()
		it("ends at version 2", function()
			local data = DataService.MigrateForTest(v1Fixture())
			expect(data.version).toBe(GameConfig.ProfileVersion)
		end)

		it("migrating an already-v2 profile changes nothing", function()
			local once = DataService.MigrateForTest(v1Fixture())
			local cash, axe, carried = once.cash, once.upgrades.axe, Meat.CountOf(once.carry)
			local twice = DataService.MigrateForTest(once)
			expect(twice.version).toBe(2)
			expect(twice.cash).toBe(cash)
			expect(twice.upgrades.axe).toBe(axe)
			expect(Meat.CountOf(twice.carry)).toBe(carried)
		end)
	end)

	describe("a fresh v2 template is already correct", function()
		it("needs no migration", function()
			local template = DataService.GetTemplateForTest()
			expect(template.version).toBe(2)
		end)

		it("has every field ARCHITECTURE §4 lists", function()
			local t = DataService.GetTemplateForTest()
			for _, field in ipairs({
				"cash", "totalCashEarned", "carry", "store", "upgrades", "workers",
				"rebirths", "settings", "funnelSteps", "stats", "receipts",
				"firstJoinAt", "lastJoinAt",
			}) do
				expect(t[field] ~= nil).toBe(true)
			end
		end)

		it("carries no V1 fields", function()
			local t = DataService.GetTemplateForTest()
			for _, field in ipairs({ "pack", "unlockedZones", "companions", "boosts", "claims" }) do
				expect(t[field]).toBeNil()
			end
		end)

		it("derives auto-swing from firstJoinAt and the trial window", function()
			-- D-016's trial has no stored field: it is firstJoinAt plus the
			-- configured duration. The template must therefore leave firstJoinAt
			-- at 0 and the preference on, so a brand-new player's trial starts
			-- the moment DataService stamps their join time.
			local t = DataService.GetTemplateForTest()
			expect(t.firstJoinAt).toBe(0)
			expect(t.settings.autoSwing).toBe(true)
			expect(GameConfig.AutoSwingTrialSeconds).toBeGreaterThanOrEqual(1)
		end)
	end)
end
