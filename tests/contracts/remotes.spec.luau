--!strict
--[[
	CONTRACT: remotes and refusal reasons (F5).

	The F5 packet requires that every declared remote is created and that the
	retired ones are actually gone. Both directions matter:

	  a declared remote that is never created  → a client call that hangs
	  a created remote that is never handled   → an open door with nobody
	                                             watching it

	The second is the reason `RequestSell` gets its own test. D-017 is explicit
	that no hidden compatibility route may award cash, and the way that mistake
	usually survives a refactor is a remote left declared "just in case".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

return function(describe, it, expect)
	describe("the V2 remote set", function()
		local expectedToClient = {
			"StateChanged",
			"Notify",
			"CombatFeedback",
			"CreatureSpawned",
			"CreatureDied",
			"CarryFeedback",
			"StoreFeedback",
		}
		local expectedInbound = {
			"RequestSwing",
			"RequestPurchase",
			"RequestSetting",
			"RequestWorkerAction",
		}

		for _, name in ipairs(expectedToClient) do
			it(`declares {name} outbound`, function()
				expect(Remotes.ToClient[name]).toBeTruthy()
				expect(Remotes.IsInbound(name)).toBe(false)
			end)
		end

		for _, name in ipairs(expectedInbound) do
			it(`declares {name} inbound`, function()
				expect(Remotes.IsInbound(name)).toBe(true)
			end)
		end

		it("declares nothing beyond the V2 set", function()
			local all = Remotes.All()
			local allowed: { [string]: boolean } = {}
			for _, n in ipairs(expectedToClient) do
				allowed[n] = true
			end
			for _, n in ipairs(expectedInbound) do
				allowed[n] = true
			end
			for name in pairs(all) do
				expect(allowed[name]).toBe(true)
			end
		end)
	end)

	describe("retired remotes are gone, not merely unhandled", function()
		--[[
			`RequestSell` is the load-bearing one. In V1 it converted a pack into
			cash on demand. The corrected game has no such action: revenue only
			becomes spendable through proximity collection of counter cash
			(ECONOMY §1). If this remote reappears, the entire store loop can be
			bypassed.
		]]
		for _, name in ipairs({
			"RequestSell",
			"RequestUnlockZone",
			"RequestTeleport",
			"RequestHatch",
			"RequestEquip",
			"RequestFuse",
			"RequestClaim",
			"RequestOffer",
		}) do
			it(`{name} is not declared anywhere`, function()
				expect(Remotes.ToClient[name]).toBeNil()
				expect(Remotes.ToServer[name]).toBeNil()
				expect(Remotes.Functions[name]).toBeNil()
				expect(Remotes.All()[name]).toBeNil()
			end)
		end
	end)

	describe("classes are correct", function()
		it("functions are RemoteFunctions and events are RemoteEvents", function()
			for name, class in pairs(Remotes.ToClient) do
				expect(class).toBe("RemoteEvent")
			end
			for name, class in pairs(Remotes.ToServer) do
				expect(class).toBe("RemoteEvent")
			end
			for name, class in pairs(Remotes.Functions) do
				expect(class).toBe("RemoteFunction")
			end
		end)

		it("All() returns every declared remote exactly once", function()
			local count = 0
			for _ in pairs(Remotes.All()) do
				count += 1
			end
			local declared = 0
			for _ in pairs(Remotes.ToClient) do
				declared += 1
			end
			for _ in pairs(Remotes.ToServer) do
				declared += 1
			end
			for _ in pairs(Remotes.Functions) do
				declared += 1
			end
			expect(count).toBe(declared)
		end)
	end)

	describe("rate limits", function()
		it("every inbound remote has a limit or falls to _default", function()
			expect(GameConfig.RateLimits._default).toBeTruthy()
			for name in pairs(Remotes.All()) do
				if Remotes.IsInbound(name) then
					local limit = GameConfig.RateLimits[name] or GameConfig.RateLimits._default
					expect(limit.budget).toBeGreaterThanOrEqual(1)
					expect(limit.perSeconds).toBeGreaterThanOrEqual(1)
				end
			end
		end)

		it("carries no limits for remotes that no longer exist", function()
			-- A stale limit reads as though the feature is merely disabled
			-- rather than removed, which is how a retired remote gets revived
			-- by someone who assumes it was intentional.
			for name in pairs(GameConfig.RateLimits) do
				if name ~= "_default" then
					expect(Remotes.IsInbound(name)).toBe(true)
				end
			end
		end)

		it("swing allows more than one per cooldown", function()
			-- The limiter must not be stricter than the game rule, or a
			-- legitimate player at max cadence trips it on latency jitter.
			local perSecond = GameConfig.RateLimits.RequestSwing.budget
				/ GameConfig.RateLimits.RequestSwing.perSeconds
			expect(perSecond).toBeGreaterThanOrEqual(1 / GameConfig.SwingCooldown)
		end)
	end)
end
