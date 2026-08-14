--!strict
--[[
	RUNALL - the single pure-test entry point.

	Every descendant ModuleScript ending in ".spec" is discovered, including
	contract suites grouped under Tests/contracts.
]]

local ServerStorage = game:GetService("ServerStorage")
local Runner = require(script.Parent.Runner)

return function(): (number, number, string)
	local specs: { ModuleScript } = {}
	for _, child in ipairs(script.Parent:GetDescendants()) do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			table.insert(specs, child)
		end
	end

	table.sort(specs, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	if #specs == 0 then
		local message = "no *.spec modules found under " .. ServerStorage.Name .. ".Tests"
		print(message)
		return 0, 1, message
	end

	local started = os.clock()
	local passed, failed, report = Runner.Run(specs)
	local elapsed = os.clock() - started
	local full = `{report}\n  ({#specs} spec files, {string.format("%.0f", elapsed * 1000)}ms)`
	print(full)
	return passed, failed, full
end
