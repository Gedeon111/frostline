--!strict
--[[
	RUNALL — the single entry point (job E1).

	Callable from one `execute_luau` string in Edit mode, which is the whole
	requirement:

		return require(game.ServerStorage.Tests.RunAll)()

	Returns (passed, failed, report) and prints the report, so it works both from
	the MCP (read the return value) and from a script inside the game (read the
	output with get_console_output). WORKFLOW §8 explains why those are different
	channels.

	Every module in Tests ending in `.spec` is picked up automatically — adding a
	spec file needs no edit here. Rojo flattens `foo.spec.luau` to an instance
	named `foo.spec`, so the suffix survives.
]]

local ServerStorage = game:GetService("ServerStorage")

local Runner = require(script.Parent.Runner)

return function(): (number, number, string)
	local specs: { ModuleScript } = {}
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			table.insert(specs, child)
		end
	end

	-- Stable order so two runs are comparable line for line.
	table.sort(specs, function(a, b)
		return a.Name < b.Name
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
