--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local ProfileSchema = require(Shared.ProfileSchema)

return function(describe, it, expect)
	describe("v1 to v2 profile migration", function()
		it("preserves cash, carry, settings, stats, receipts, and timestamps", function()
			local old: any = {
				version = 1,
				cash = 4321,
				totalCashEarned = 9876,
				pack = { snow_cub = 3, snow_cub_golden = 1 },
				upgrades = { pack = 4, boots = 6, harpoon = 5 },
				settings = { music = false, sfx = true, reducedEffects = true, autoSwing = false },
				stats = { kills = 17, playtimeSeconds = 99, goldenKills = 2, sells = 4 },
				receipts = { receipt_alpha = true },
				firstJoinAt = 1000,
				lastJoinAt = 2000,
				unlockedZones = { tundra = true },
			}

			local ok, reason = ProfileSchema.Prepare(old)
			expect(ok).toBe(true)
			expect(reason).toBeNil()
			expect(old.version).toBe(GameConfig.ProfileVersion)
			expect(old.cash).toBe(4321)
			expect(old.totalCashEarned).toBe(9876)
			expect(old.carry.snow_cub).toBe(3)
			expect(old.carry.snow_cub_golden).toBe(1)
			expect(old.upgrades.carrier).toBe(4)
			expect(old.upgrades.axe).toBe(5)
			expect(old.settings.music).toBe(false)
			expect(old.settings.reducedEffects).toBe(true)
			expect(old.stats.kills).toBe(17)
			expect(old.stats.playtimeSeconds).toBe(99)
			expect(old.receipts.receipt_alpha).toBe(true)
			expect(old.firstJoinAt).toBe(1000)
			expect(old.lastJoinAt).toBe(2000)
		end)

		it("installs the temporary boot bridge without duplicating carry", function()
			local old: any = {
				version = 1,
				pack = { snow_cub = 2 },
				upgrades = { pack = 3, harpoon = 4 },
			}
			expect(ProfileSchema.Prepare(old)).toBe(true)
			expect(old.pack == old.carry).toBe(true)
			expect(old.upgrades.pack).toBe(old.upgrades.carrier)
			expect(old.upgrades.harpoon).toBe(old.upgrades.axe)
		end)
	end)

	describe("fresh v2 reconciliation", function()
		it("fills every nested store and worker default", function()
			local fresh: any = {}
			expect(ProfileSchema.Prepare(fresh)).toBe(true)
			expect(fresh.version).toBe(GameConfig.ProfileVersion)
			expect(fresh.store.fridge).toBeTruthy()
			expect(fresh.store.unclaimedCash).toBe(0)
			expect(fresh.workers.stocker.unlocked).toBe(false)
			expect(fresh.workers.cashier.level).toBe(0)
			expect(fresh.workers.hunter.enabled).toBe(false)
			expect(fresh.upgrades.axe).toBe(1)
			expect(fresh.upgrades.carrier).toBe(1)
			expect(fresh.upgrades.fridge).toBe(1)
			expect(fresh.upgrades.register).toBe(1)
		end)

		it("is deterministic and idempotent", function()
			local data: any = {
				version = 1,
				cash = 55,
				pack = { snow_cub = 7 },
				upgrades = { pack = 2, harpoon = 3 },
			}
			expect(ProfileSchema.Prepare(data)).toBe(true)
			data.store.unclaimedCash = 91
			expect(ProfileSchema.Prepare(data)).toBe(true)
			expect(data.cash).toBe(55)
			expect(data.carry.snow_cub).toBe(7)
			expect(data.store.unclaimedCash).toBe(91)
			expect(data.upgrades.carrier).toBe(2)
			expect(data.upgrades.axe).toBe(3)
		end)

		it("refuses profiles newer than the runtime", function()
			local future: any = { version = GameConfig.ProfileVersion + 1 }
			local ok, reason = ProfileSchema.Prepare(future)
			expect(ok).toBe(false)
			expect(reason).toBeTruthy()
		end)
	end)

	describe("Auto-Swing derivation", function()
		it("uses the configured trial, entitlement, and persisted toggle", function()
			local data: any = {
				firstJoinAt = 1000,
				settings = { autoSwing = true },
			}
			expect(ProfileSchema.IsAutoSwingActive(data, 1000 + GameConfig.AutoSwingTrialSeconds - 1, false)).toBe(true)
			expect(ProfileSchema.IsAutoSwingActive(data, 1000 + GameConfig.AutoSwingTrialSeconds, false)).toBe(false)
			expect(ProfileSchema.IsAutoSwingActive(data, 1000 + GameConfig.AutoSwingTrialSeconds, true)).toBe(true)
			data.settings.autoSwing = false
			expect(ProfileSchema.IsAutoSwingActive(data, 1000, true)).toBe(false)
		end)
	end)
end
