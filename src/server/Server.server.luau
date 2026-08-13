--!strict
--[[
	BOOTSTRAP (server)

	Two-phase loader. Requires every ModuleScript in Services, calls Init() on all,
	then Start() on all. Two phases removes require-order dependency entirely:
	Init wires references, Start is when cross-service calls become legal.

	A service that throws in Init must not stop the others from starting — hence the
	pcall around each. Fail loud in the log, keep the server up.

	Job F4 fills in the real Net wiring. See docs/ARCHITECTURE.md §2.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Log = require(ReplicatedStorage:WaitForChild("Shared").Util.Log)

local t0 = os.clock()
local services: { [string]: any } = {}
local order: { string } = {}

for _, module in ipairs(ServerScriptService.Services:GetChildren()) do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			services[module.Name] = result
			table.insert(order, module.Name)
		else
			Log.error("boot", "require failed: %s — %s", module.Name, tostring(result))
		end
	end
end

for _, phase in ipairs({ "Init", "Start" }) do
	for _, name in ipairs(order) do
		local service = services[name]
		if type(service) == "table" and type(service[phase]) == "function" then
			local ok, err = pcall(service[phase])
			if not ok then
				Log.error("boot", "%s.%s failed — %s", name, phase, tostring(err))
			end
		end
	end
end

Log.info("boot", "server ready — %d service(s) in %.0fms", #order, (os.clock() - t0) * 1000)
