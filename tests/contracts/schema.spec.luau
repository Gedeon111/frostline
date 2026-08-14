--!strict
--[[
	CONTRACT: config shape and table invariants (F5).

	The F5 packet requires contract tests that assert exact config shape, table
	invariants, refusal unions, migration preservation, and that every declared
	remote is created. This file covers shape and invariants; migration and
	remote creation are their own spec files.

	These are not gameplay-balance tests. They assert that the CONTRACT other
	packets code against is actually the shape ARCHITECTURE describes — so that
	"no service packet needs to invent a number" is a checkable claim rather
	than a hope.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)
local Plots = require(Shared.Config.Plots)
local Store = require(Shared.Config.Store)
local Upgrades = require(Shared.Config.Upgrades)
local Workers = require(Shared.Config.Workers)

return function(describe, it, expect)
	describe("upgrade tracks match ARCHITECTURE §4", function()
		local expected = { "axe", "carrier", "fridge", "register" }

		it("has exactly the four V2 tracks", function()
			expect(#Upgrades.Order).toBe(#expected)
			for _, track in ipairs(expected) do
				expect(Upgrades.Get(track)).toBeTruthy()
			end
		end)

		it("has no V1 tracks left", function()
			expect(Upgrades.Get("pack")).toBeNil()
			expect(Upgrades.Get("boots")).toBeNil()
			expect(Upgrades.Get("harpoon")).toBeNil()
		end)

		for _, track in ipairs(expected) do
			it(`{track}: levels table is maxLevel long`, function()
				local def = Upgrades.Get(track) :: any
				expect(#def.levels).toBe(def.maxLevel)
			end)

			it(`{track}: level 1 is free`, function()
				local def = Upgrades.Get(track) :: any
				expect(def.levels[1].cost).toBe(0)
			end)

			it(`{track}: costs increase monotonically`, function()
				local def = Upgrades.Get(track) :: any
				for i = 2, #def.levels do
					expect(def.levels[i].cost).toBeGreaterThanOrEqual(def.levels[i - 1].cost)
				end
			end)

			it(`{track}: no cost past max level`, function()
				local def = Upgrades.Get(track) :: any
				expect(Upgrades.GetCost(track, def.maxLevel)).toBeNil()
			end)
		end
	end)

	describe("every track supplies the field its accessor reads", function()
		--[[
			The four tracks carry different fields, so a missing one would only
			surface as arithmetic-on-nil inside whichever service happened to
			read it first. Assert the accessors return usable numbers at every
			level instead.
		]]
		it("axe has damage at every level", function()
			for level = 1, 10 do
				expect(Upgrades.GetDamage(level)).toBeGreaterThanOrEqual(1)
			end
		end)
		it("carrier has capacity at every level", function()
			for level = 1, 10 do
				expect(Upgrades.GetCarryCapacity(level)).toBeGreaterThanOrEqual(1)
			end
		end)
		it("fridge has capacity at every level", function()
			for level = 1, 10 do
				expect(Upgrades.GetFridgeCapacity(level)).toBeGreaterThanOrEqual(1)
			end
		end)
		it("register has checkout seconds and queue capacity at every level", function()
			for level = 1, 10 do
				expect(Upgrades.GetCheckoutSeconds(level)).toBeGreaterThanOrEqual(0.01)
				expect(Upgrades.GetQueueCapacity(level)).toBeGreaterThanOrEqual(1)
			end
		end)
	end)

	describe("ECONOMY §3 store constraints", function()
		it("starting fridge holds at least two full starter carriers", function()
			-- Stated requirement, not a preference: the player must be able to
			-- do two hunting trips before stock becomes the bottleneck.
			expect(Upgrades.GetFridgeCapacity(1)).toBeGreaterThanOrEqual(Upgrades.GetCarryCapacity(1) * 2)
		end)

		it("register speed never reaches zero", function()
			expect(Upgrades.GetCheckoutSeconds(10)).toBeGreaterThanOrEqual(0.01)
		end)

		it("checkout gets faster as the register levels", function()
			for level = 2, 10 do
				expect(Upgrades.GetCheckoutSeconds(level)).toBeLessThanOrEqual(
					Upgrades.GetCheckoutSeconds(level - 1)
				)
			end
		end)

		it("fridge capacity grows faster than carrier capacity", function()
			-- Otherwise the carrier, not the fridge, becomes the readable stock
			-- bottleneck, which inverts ECONOMY §5 constraint 4.
			local carrierGrowth = Upgrades.GetCarryCapacity(10) / Upgrades.GetCarryCapacity(1)
			local fridgeGrowth = Upgrades.GetFridgeCapacity(10) / Upgrades.GetFridgeCapacity(1)
			expect(fridgeGrowth).toBeGreaterThanOrEqual(carrierGrowth)
		end)
	end)

	describe("meat", function()
		it("every meat id resolves", function()
			for _, meatId in ipairs(Meat.Order) do
				expect(Meat.Get(meatId)).toBeTruthy()
			end
		end)

		it("weight and value are positive", function()
			for _, meatId in ipairs(Meat.Order) do
				local def = Meat.Get(meatId) :: any
				expect(def.weight).toBeGreaterThanOrEqual(1)
				expect(def.value).toBeGreaterThanOrEqual(1)
			end
		end)

		it("golden is worth more than ordinary at the same weight", function()
			-- ECONOMY §2: a golden creature cannot merely increase a visual drop
			-- count while producing ordinary-value inventory.
			local plain = Meat.Get("frost_cut") :: any
			local golden = Meat.Get("frost_cut_golden") :: any
			expect(golden.weight).toBe(plain.weight)
			expect(golden.value).toBeGreaterThanOrEqual(plain.value * 2)
		end)

		it("WeightOf and ValueOf sum correctly", function()
			local counts = { frost_cut = 3, frost_cut_golden = 2 }
			expect(Meat.WeightOf(counts)).toBe(3 * 2 + 2 * 2)
			expect(Meat.ValueOf(counts)).toBe(3 * 5 + 2 * 50)
			expect(Meat.CountOf(counts)).toBe(5)
		end)

		it("ignores unknown ids rather than erroring", function()
			-- A stale id from an old profile must not crash a weight check.
			expect(Meat.WeightOf({ not_a_real_meat = 5 })).toBe(0)
		end)
	end)

	describe("creatures reference real meat", function()
		it("every tier's meatId exists", function()
			for _, tierId in ipairs(Creatures.Order) do
				local tier = Creatures.Get(tierId) :: any
				expect(Meat.Get(tier.meatId)).toBeTruthy()
			end
		end)

		it("every variant's meatId exists", function()
			for _, variant in pairs(Creatures.Variants) do
				expect(Meat.Get((variant :: any).meatId)).toBeTruthy()
			end
		end)

		it("MeatIdFor honours the variant", function()
			expect(Creatures.MeatIdFor("snow_cub", nil)).toBe("frost_cut")
			expect(Creatures.MeatIdFor("snow_cub", "golden")).toBe("frost_cut_golden")
		end)

		it("MeatIdFor returns nil for an unknown tier", function()
			expect(Creatures.MeatIdFor("not_a_tier", nil)).toBeNil()
		end)

		it("the starter tier exists", function()
			expect(Creatures.Get(Creatures.StarterTier)).toBeTruthy()
		end)
	end)

	describe("workers", function()
		it("has exactly stocker, cashier, hunter", function()
			expect(#Workers.Order).toBe(3)
			for _, id in ipairs({ "stocker", "cashier", "hunter" }) do
				expect(Workers.Get(id)).toBeTruthy()
			end
		end)

		it("unlock order is cheapest first", function()
			-- ECONOMY §7 pacing table: stocker reachable first, hunter last.
			local previous = -1
			for _, id in ipairs(Workers.Order) do
				local def = Workers.Get(id) :: any
				expect(def.unlockCost).toBeGreaterThanOrEqual(previous + 1)
				previous = def.unlockCost
			end
		end)

		it("every worker is buyable with ordinary cash before rebirth", function()
			-- GDD §7: rebirth may not gate the feature that defines the
			-- management fantasy, so unlock costs must be finite and positive.
			for _, id in ipairs(Workers.Order) do
				local def = Workers.Get(id) :: any
				expect(def.unlockCost).toBeGreaterThanOrEqual(1)
				expect(#def.levels).toBe(def.maxLevel)
			end
		end)

		it("rates increase with level", function()
			for _, id in ipairs(Workers.Order) do
				local def = Workers.Get(id) :: any
				for i = 2, #def.levels do
					expect(def.levels[i].ratePerMinute).toBeGreaterThanOrEqual(def.levels[i - 1].ratePerMinute)
				end
			end
		end)

		it("the hunter produces real meat", function()
			expect(Meat.Get(Workers.HunterMeatId)).toBeTruthy()
		end)
	end)

	describe("plots match ARCHITECTURE §7", function()
		it("there are eight", function()
			expect(Plots.Count).toBe(8)
			expect(#Plots.AllNames()).toBe(8)
		end)

		it("names are zero-padded and ordered", function()
			expect(Plots.NameFor(1)).toBe("Plot01")
			expect(Plots.NameFor(8)).toBe("Plot08")
		end)

		it("required markers cover the full loop", function()
			-- Each of these is something a service must find or the loop breaks.
			local required = table.concat(Plots.RequiredMarkers, ",")
			for _, marker in ipairs({
				"PlayerSpawn",
				"Refrigerator/UnloadZone",
				"Refrigerator/CustomerPickup",
				"Register/OperatorZone",
				"Register/CashOrigin",
				"WorkerComputer",
				"HunterDropoff",
				"HuntGate",
			}) do
				expect(string.find(required, marker, 1, true) ~= nil).toBe(true)
			end
		end)

		it("ordered marker groups declare a minimum", function()
			for _, group in pairs(Plots.OrderedMarkers) do
				expect((group :: any).minimum).toBeGreaterThanOrEqual(1)
			end
		end)
	end)

	describe("store tuning is present and sane", function()
		it("spawn interval is a real range", function()
			expect(Store.CustomerSpawnInterval.min).toBeGreaterThanOrEqual(1)
			expect(Store.CustomerSpawnInterval.max).toBeGreaterThanOrEqual(Store.CustomerSpawnInterval.min)
		end)

		it("basket size is a real range", function()
			expect(Store.BasketSize.min).toBeGreaterThanOrEqual(1)
			expect(Store.BasketSize.max).toBeGreaterThanOrEqual(Store.BasketSize.min)
		end)

		it("cash pile is capped", function()
			-- ECONOMY §6: one sale must never create one part per currency unit.
			expect(Store.MaxCashPieces).toBeGreaterThanOrEqual(1)
			expect(Store.CashPieceValue).toBeGreaterThanOrEqual(1)
		end)

		it("player-operated checkout outpaces customer arrival", function()
			-- ECONOMY §5 constraint 1, at the starter level.
			expect(Upgrades.GetCheckoutSeconds(1)).toBeLessThanOrEqual(Store.CustomerSpawnInterval.min)
		end)
	end)

	describe("D-015 and D-016 survive the reset", function()
		-- GDD §3 keeps both authoritative. A reset that quietly dropped the
		-- trial or the hitbox would be a monetization and control regression.
		it("hitbox config is intact", function()
			expect(GameConfig.HitboxSize).toBeTruthy()
			expect(GameConfig.HitboxForwardOffset).toBeGreaterThanOrEqual(1)
			expect(GameConfig.MaxCleaveTargets).toBeGreaterThanOrEqual(1)
		end)

		it("the trial is still ten minutes", function()
			expect(GameConfig.AutoSwingTrialSeconds).toBe(600)
		end)

		it("the hitbox stays inside the server range gate", function()
			-- Otherwise the client targets creatures the server then rejects as
			-- out of range, which reads as the game ignoring you.
			local reach = GameConfig.HitboxForwardOffset + (GameConfig.HitboxSize.Z / 2)
			expect(reach).toBeLessThanOrEqual(GameConfig.SwingRange * GameConfig.SwingRangeTolerance)
		end)
	end)

	describe("profile version", function()
		it("is 2", function()
			expect(GameConfig.ProfileVersion).toBe(2)
		end)
	end)
end
