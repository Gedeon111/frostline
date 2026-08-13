--!strict
--[[
	BOOTSTRAP (client)

	Mirror of the server loader. Requires every ModuleScript in Controllers, calls
	Init() on all, then Start() on all.

	Controllers must not touch remotes during Init — the server may not have created
	them yet. Wait until Start, and go through Controllers.Net (job F4), never
	:FireServer() directly. See docs/ARCHITECTURE.md §3.
]]

local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local controllersFolder = scripts:WaitForChild("Controllers")

local t0 = os.clock()
local controllers: { [string]: any } = {}
local order: { string } = {}

for _, module in ipairs(controllersFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			controllers[module.Name] = result
			table.insert(order, module.Name)
		else
			warn(string.format("[boot] require failed: %s — %s", module.Name, tostring(result)))
		end
	end
end

for _, phase in ipairs({ "Init", "Start" }) do
	for _, name in ipairs(order) do
		local controller = controllers[name]
		if type(controller) == "table" and type(controller[phase]) == "function" then
			local ok, err = pcall(controller[phase])
			if not ok then
				warn(string.format("[boot] %s.%s failed — %s", name, phase, tostring(err)))
			end
		end
	end
end

print(string.format("[boot] client ready — %d controller(s) in %.0fms", #order, (os.clock() - t0) * 1000))
