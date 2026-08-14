--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CarryVisuals = require(Shared.Config.CarryVisuals)
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Meat = require(Shared.Config.Meat)
local Plots = require(Shared.Config.Plots)
local Products = require(Shared.Config.Products)
local Store = require(Shared.Config.Store)
local Upgrades = require(Shared.Config.Upgrades)
local Workers = require(Shared.Config.Workers)

local function countKeys(source: { [any]: any }): number
	local count = 0
	for _ in pairs(source) do
		count += 1
	end
	return count
end

return function(describe, it, expect)
	describe("v2 plot contract", function()
		it("defines exactly eight stable plot names", function()
			expect(Plots.Count).toBe(8)
			expect(#Plots.Names).toBe(Plots.Count)
			for index, name in ipairs(Plots.Names) do
				expect(name).toBe(string.format("Plot%02d", index))
			end
		end)

		it("defines every store-loop marker", function()
			local required: { [string]: boolean } = {
				PlayerSpawn = true,
				StoreEntrance = true,
				CustomerSpawn = true,
				CustomerExit = true,
				CustomerPath = true,
				Refrigerator = true,
				["Refrigerator/UnloadZone"] = true,
				["Refrigerator/CustomerPickup"] = true,
				["Refrigerator/MeatDisplay"] = true,
				Register = true,
				["Register/OperatorZone"] = true,
				["Register/QueuePoints"] = true,
				["Register/CashOrigin"] = true,
				WorkerComputer = true,
				HunterDropoff = true,
				HuntGate = true,
			}
			expect(#Plots.RequiredPaths).toBe(countKeys(required))
			for _, path in ipairs(Plots.RequiredPaths) do
				expect(required[path]).toBe(true)
			end
		end)
	end)

	describe("v2 upgrade contract", function()
		it("exposes only the four active purchase tracks", function()
			local expected = { "axe", "carrier", "fridge", "register" }
			expect(#Upgrades.ActiveOrder).toBe(#expected)
			for index, track in ipairs(expected) do
				expect(Upgrades.ActiveOrder[index]).toBe(track)
				expect(Upgrades.GetActive(track)).toBeTruthy()
			end
			expect(Upgrades.GetActive("pack")).toBeNil()
			expect(Upgrades.GetActive("boots")).toBeNil()
			expect(Upgrades.GetActive("harpoon")).toBeNil()
		end)

		for _, track in ipairs(Upgrades.ActiveOrder) do
			it(track .. " has one value per level and one fewer costs", function()
				local definition = Upgrades.GetActive(track)
				expect(definition).toBeTruthy()
				expect(#(definition :: any).values).toBe((definition :: any).maxLevel)
				expect(#(definition :: any).costs).toBe((definition :: any).maxLevel - Upgrades.InitialLevel)
			end)
		end

		it("starts refrigerator storage at two carrier loads", function()
			local carrier = Upgrades.GetValue("carrier", Upgrades.InitialLevel)
			local fridge = Upgrades.GetValue("fridge", Upgrades.InitialLevel)
			expect(fridge).toBeGreaterThanOrEqual(carrier * 2)
		end)

		it("keeps register duration positive and decreasing", function()
			local definition = Upgrades.GetActive("register") :: any
			for index = 2, #definition.values do
				expect(definition.values[index]).toBeLessThanOrEqual(definition.values[index - 1])
			end
			expect(definition.values[#definition.values]).toBeGreaterThanOrEqual(0.001)
		end)
	end)

	describe("meat identity and value", function()
		for _, tierId in ipairs(Creatures.Order) do
			it(tierId .. " golden meat preserves identity and weight", function()
				local base = Meat.Get(tierId)
				local golden = Meat.Get(tierId .. "_golden")
				expect(base).toBeTruthy()
				expect(golden).toBeTruthy()
				expect((golden :: any).weight).toBe((base :: any).weight)
				expect((golden :: any).unitValue).toBe((base :: any).unitValue * 10)
				expect((golden :: any).id == (base :: any).id).toBe(false)
			end)
		end
	end)

	describe("workers and bounded visuals", function()
		it("orders normal-cash workers from stocker to hunter", function()
			expect(#Workers.Order).toBe(3)
			expect(Workers.Order[1]).toBe("stocker")
			expect(Workers.Order[2]).toBe("cashier")
			expect(Workers.Order[3]).toBe("hunter")
			local stocker = Workers.Get("stocker") :: any
			local cashier = Workers.Get("cashier") :: any
			local hunter = Workers.Get("hunter") :: any
			expect(stocker.unlockCost).toBeLessThanOrEqual(cashier.unlockCost)
			expect(cashier.unlockCost).toBeLessThanOrEqual(hunter.unlockCost)
		end)

		it("initial hunter stays below the configured active-play fraction", function()
			local hunter = Workers.Get("hunter") :: any
			local initialRate = hunter.levels[Workers.UnlockedLevel].unitsPerCycle
				* 60 / hunter.levels[Workers.UnlockedLevel].cycleSeconds
			expect(initialRate).toBeLessThanOrEqual(
				Workers.ActiveStarterItemsPerMinuteBaseline * Workers.MaxInitialHunterFraction
			)
		end)

		it("caps every visual representation", function()
			expect(CarryVisuals.VisualPieceCap).toBeGreaterThanOrEqual(1)
			expect(CarryVisuals.ReducedEffectPieceCap).toBeLessThanOrEqual(CarryVisuals.VisualPieceCap)
			expect(Store.Cash.VisualPieceCap).toBeGreaterThanOrEqual(1)
			expect(Store.Unload.FeedbackPieceCap).toBeGreaterThanOrEqual(1)
		end)

		it("bounds register queues for every level", function()
			local register = Upgrades.GetActive("register") :: any
			expect(#Store.Register.QueueCapacityByLevel).toBe(register.maxLevel)
			for _, capacity in ipairs(Store.Register.QueueCapacityByLevel) do
				expect(capacity).toBeGreaterThanOrEqual(Store.Customers.MaxPerPlot)
			end
		end)
	end)

	describe("preserved Auto-Swing product", function()
		it("keeps one 399 Robux gamepass and the ten-minute trial", function()
			expect(#Products.All()).toBe(1)
			local product = Products.Get("autoswing")
			expect(product).toBeTruthy()
			expect((product :: any).kind).toBe("gamepass")
			expect((product :: any).robux).toBe(399)
			expect(GameConfig.AutoSwingTrialSeconds).toBe(600)
		end)
	end)
end
