--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local expected: { [string]: string } = {
	StateChanged = "RemoteEvent",
	Notify = "RemoteEvent",
	CombatFeedback = "RemoteEvent",
	CreatureSpawned = "RemoteEvent",
	CreatureDied = "RemoteEvent",
	CarryFeedback = "RemoteEvent",
	StoreFeedback = "RemoteEvent",
	RequestSwing = "RemoteEvent",
	RequestPurchase = "RemoteFunction",
	RequestSetting = "RemoteFunction",
	RequestWorkerAction = "RemoteFunction",
}

local function countKeys(source: { [any]: any }): number
	local count = 0
	for _ in pairs(source) do
		count += 1
	end
	return count
end

return function(describe, it, expect)
	describe("v2 remote declaration", function()
		it("matches the exact approved surface", function()
			local all = Remotes.All()
			expect(countKeys(all)).toBe(countKeys(expected))
			for name, className in pairs(expected) do
				expect(all[name]).toBe(className)
			end
		end)

		it("contains no hidden v1 action routes", function()
			local all = Remotes.All()
			expect(all.RequestSell).toBeNil()
			expect(all.RequestTeleport).toBeNil()
			expect(all.RequestUnlockZone).toBeNil()
			expect(all.RequestOffer).toBeNil()
			expect(all.RequestHatch).toBeNil()
			expect(all.RequestEquip).toBeNil()
			expect(all.RequestFuse).toBeNil()
			expect(all.RequestClaim).toBeNil()
		end)

		it("rate-limits every inbound action", function()
			local limits: any = GameConfig.RateLimits
			for name in pairs(Remotes.ToServer) do
				expect(limits[name]).toBeTruthy()
			end
			for name in pairs(Remotes.Functions) do
				expect(limits[name]).toBeTruthy()
			end
		end)
	end)

	describe("server Net generation", function()
		it("creates every declared remote with the declared class", function()
			local Net = require(ServerScriptService.Services.Net)
			for name, className in pairs(Remotes.All()) do
				local remote = Net.GetRemote(name)
				expect(remote).toBeTruthy()
				expect((remote :: Instance).ClassName).toBe(className)
			end
		end)
	end)
end
