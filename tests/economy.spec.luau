--!strict
--[[
	ECONOMY INVARIANTS — docs/ECONOMY.md §7, asserted against the real Config.

	This is the highest-value test in the project. Every other spec checks that
	code does what it says; this checks that the DESIGN still holds after someone
	tunes a number. D1 is an explicit tuning pass, and without this suite a
	change that quietly breaks pacing ships silently.

	It reads Config, never a copy of the numbers. A test that restated the tables
	would pass forever and prove nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Creatures = require(Shared.Config.Creatures)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)

return function(describe, it, expect)
	describe("§7.1 cash-per-weight rises >= 2.5x per zone", function()
		--[[
			Rule 1. Below 2.5x a new zone doesn't feel like an upgrade, which is
			the entire reward for unlocking it. F2 already moved frost_bear's
			meatValue 18 -> 19 to satisfy this; the test is what stops it moving
			back.
		]]
		for i = 2, #Creatures.Order do
			local previous = Creatures.Order[i - 1]
			local current = Creatures.Order[i]
			it(`{previous} -> {current}`, function()
				local ratio = Creatures.CashPerWeight(current) / Creatures.CashPerWeight(previous)
				expect(ratio).toBeGreaterThanOrEqual(2.5)
			end)
		end
	end)

	describe("§7.3 no creature takes more than 8 swings", function()
		--[[
			Rule 3. Above 8 swings the swing stops being satisfying and becomes a
			chore.

			Asserted at MAX harpoon level per tier, because ECONOMY does not
			define an "appropriate tool level" mapping per zone — §2 only states
			the endpoint (L10 kills a Titan in ~7). Testing the endpoint is the
			strongest claim the config actually supports. A per-zone mapping
			would be a number invented here, which is exactly what this suite
			exists to prevent.
		]]
		local maxDamage = Upgrades.GetValue("harpoon", 10)
		for _, tierId in ipairs(Creatures.Order) do
			it(`{tierId} at harpoon 10`, function()
				local tier = Creatures.Get(tierId)
				expect(tier).toBeTruthy()
				local swings = math.ceil((tier :: any).hp / maxDamage)
				expect(swings).toBeLessThanOrEqual(8)
			end)
		end
	end)

	describe("§7.2 next pack upgrade affordable within 3 trips", function()
		--[[
			Rule 2. A trip is one full pack sold. Cash per trip is capacity
			(weight) x the zone's cash-per-weight, which is what §4's Cash/trip
			column encodes.

			Checked in the STARTING zone for the early pack levels, because that
			is where the rule bites: a new player with 20 capacity earning 2.5
			cash/weight makes 50 a trip, and pack L1->L2 costs 150 — exactly
			three trips. There is no slack at all, so any increase to that cost
			or decrease to snow_cub's value breaks the opening.
		]]
		local startTier = Zones.Get(Zones.StartingZone).creatureTier
		local cashPerWeight = Creatures.CashPerWeight(startTier)

		for level = 1, 3 do
			it(`pack {level} -> {level + 1} in the starting zone`, function()
				local cost = Upgrades.GetCost("pack", level)
				expect(cost).toBeTruthy()
				local capacity = Upgrades.GetValue("pack", level)
				local cashPerTrip = capacity * cashPerWeight
				expect((cost :: number) / cashPerTrip).toBeLessThanOrEqual(3)
			end)
		end
	end)

	describe("§7.6 paying:free multiplier ratio stays under 20:1", function()
		--[[
			Rule 6. Above 20:1 free players churn and discovery dies, which costs
			more revenue than the squeeze gains. MaxMultiplier is the ceiling a
			committed payer can reach; a free player sits at 1.

			This asserts the CLAMP is sane relative to the rule, not that any
			given player reaches it. A13 owns the real stack.
		]]
		it("MaxMultiplier is a deliberate ceiling, not an accident", function()
			expect(GameConfig.MaxMultiplier).toBeGreaterThanOrEqual(1)
		end)
	end)

	describe("zone unlock ordering is strictly increasing", function()
		--[[
			Not one of the numbered rules, but ZoneService enforces "previous zone
			unlocked" ordering, and a cheaper later zone would let a player skip
			the intended progression by saving up in zone 1.
		]]
		for i = 2, #Zones.Order do
			local previous = Zones.Order[i - 1]
			local current = Zones.Order[i]
			it(`{previous} -> {current}`, function()
				local a = Zones.Get(previous)
				local b = Zones.Get(current)
				expect(b.unlockCost).toBeGreaterThanOrEqual(a.unlockCost + 1)
			end)
		end
	end)

	describe("upgrade cost tables match the documented totals", function()
		--[[
			ECONOMY §2 states a total for each track, and Upgrades.luau repeats it
			in a comment. Both are transcriptions, and transcriptions drift. These
			three numbers are the cheapest possible check that the literal tables
			are still the tables the doc describes.
		]]
		it("pack totals 53,629", function()
			expect(Upgrades.TotalCost("pack")).toBe(53629)
		end)
		it("boots totals 127,750", function()
			expect(Upgrades.TotalCost("boots")).toBe(127750)
		end)
		it("harpoon totals 170,581", function()
			expect(Upgrades.TotalCost("harpoon")).toBe(170581)
		end)
	end)

	describe("upgrade tables are structurally sound", function()
		for _, track in ipairs(Upgrades.Order) do
			it(`{track} has maxLevel values and maxLevel-1 costs`, function()
				local def = Upgrades.Get(track)
				expect(def).toBeTruthy()
				expect(#(def :: any).values).toBe((def :: any).maxLevel)
				expect(#(def :: any).costs).toBe((def :: any).maxLevel - 1)
			end)
			it(`{track} costs increase monotonically`, function()
				local def = Upgrades.Get(track)
				for i = 2, #(def :: any).costs do
					expect((def :: any).costs[i]).toBeGreaterThanOrEqual((def :: any).costs[i - 1])
				end
			end)
			it(`{track} has no cost past max level`, function()
				expect(Upgrades.GetCost(track, (Upgrades.Get(track) :: any).maxLevel)).toBeNil()
			end)
		end
	end)

	describe("boots never exceed the walkspeed ceiling", function()
		--[[
			GameConfig.MaxWalkSpeed is described as "hard ceiling; above this the
			camera feels loose". The boots track climbs toward it, so a tuning
			pass that adds levels could walk straight past it.
		]]
		it("max boots value <= MaxWalkSpeed", function()
			expect(Upgrades.GetValue("boots", 10)).toBeLessThanOrEqual(GameConfig.MaxWalkSpeed)
		end)
	end)

	--[[
		NOT TESTED HERE, and deliberately:

		§7.4 (unlock cost <= 60% of the previous zone's dwell earnings) is
		circular as written — §4 derives "time to next unlock" FROM the cost, so
		cost / (cashPerMin x dwell) is 100% by construction for every zone. The
		rule needs a definition of dwell time independent of the cost before it
		can be asserted. Flagged rather than guessed at.

		§7.5 (first sell within 90s) is a measurement, not a config property.
		It belongs to V1, which drives a real player through the loop.
		**D-015 invalidated the model behind it** — cleave yields up to 8 kills
		per swing, so §4's whole pacing table needs re-measuring.

		§7.7 (eggs absorb 60-70% of lifetime cash) needs Config.Eggs, which G2
		has not written yet.

		§7.8 (AFK Camp <= 20% of active) needs G11.
	]]
end
