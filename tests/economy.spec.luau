--!strict
--[[
	V2 ECONOMY INVARIANTS - asserted against authoritative Config.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CarryVisuals = require(Shared.Config.CarryVisuals)
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)
local Store = require(Shared.Config.Store)
local Upgrades = require(Shared.Config.Upgrades)
local Workers = require(Shared.Config.Workers)

return function(describe, it, expect)
	describe("active upgrade tables", function()
		for _, track in ipairs(Upgrades.ActiveOrder) do
			it(track .. " is structurally sound", function()
				local definition = Upgrades.GetActive(track)
				expect(definition).toBeTruthy()
				expect(#(definition :: any).values).toBe((definition :: any).maxLevel)
				expect(#(definition :: any).costs).toBe((definition :: any).maxLevel - Upgrades.InitialLevel)
				for index = 2, #(definition :: any).costs do
					expect((definition :: any).costs[index]).toBeGreaterThanOrEqual(
						(definition :: any).costs[index - 1]
					)
				end
				expect(Upgrades.GetCost(track, (definition :: any).maxLevel)).toBeNil()
			end)
		end

		it("starter fridge holds at least two starter carrier loads", function()
			expect(Upgrades.GetValue("fridge", Upgrades.InitialLevel)).toBeGreaterThanOrEqual(
				Upgrades.GetValue("carrier", Upgrades.InitialLevel) * 2
			)
		end)

		it("register durations stay positive and never increase", function()
			local values = (Upgrades.GetActive("register") :: any).values
			for index = 2, #values do
				expect(values[index]).toBeLessThanOrEqual(values[index - 1])
			end
			expect(values[#values]).toBeGreaterThanOrEqual(0.001)
		end)
	end)

	describe("hunting and meat value", function()
		it("the strongest axe keeps every configured creature within the combat ceiling", function()
			local axe = Upgrades.GetActive("axe") :: any
			local damage = Upgrades.GetValue("axe", axe.maxLevel)
			for _, tierId in ipairs(Creatures.Order) do
				local creature = Creatures.Get(tierId)
				expect(creature).toBeTruthy()
				expect(math.ceil((creature :: any).hp / damage)).toBeLessThanOrEqual(GameConfig.MaxCleaveTargets)
			end
		end)

		for _, tierId in ipairs(Creatures.Order) do
			it(tierId .. " golden checkout value stays variant-specific", function()
				local base = Meat.Get(tierId)
				local golden = Meat.Get(tierId .. "_golden")
				expect(base).toBeTruthy()
				expect(golden).toBeTruthy()
				expect((golden :: any).weight).toBe((base :: any).weight)
				expect((golden :: any).unitValue).toBe((base :: any).unitValue * 10)
			end)
		end
	end)

	describe("worker and throughput bounds", function()
		it("initial hunter output is at most one quarter of active play", function()
			local hunter = Workers.Get("hunter") :: any
			local first = hunter.levels[Workers.UnlockedLevel]
			local perMinute = first.unitsPerCycle * 60 / first.cycleSeconds
			expect(perMinute).toBeLessThanOrEqual(
				Workers.ActiveStarterItemsPerMinuteBaseline * Workers.MaxInitialHunterFraction
			)
		end)

		it("the customer population fits every configured queue", function()
			for _, capacity in ipairs(Store.Register.QueueCapacityByLevel) do
				expect(capacity).toBeGreaterThanOrEqual(Store.Customers.MaxPerPlot)
			end
		end)
	end)

	describe("bounded representations and monetization", function()
		it("meat and cash visuals are independently capped", function()
			expect(CarryVisuals.VisualPieceCap).toBeGreaterThanOrEqual(1)
			expect(Store.Cash.VisualPieceCap).toBeGreaterThanOrEqual(1)
			expect(CarryVisuals.ReducedEffectPieceCap).toBeLessThanOrEqual(CarryVisuals.VisualPieceCap)
		end)

		it("cash multipliers cannot amplify the corrected slice", function()
			expect(GameConfig.MaxMultiplier).toBe(1)
		end)
	end)
end
