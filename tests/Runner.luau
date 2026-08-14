--!strict
--[[
	RUNNER — a minimal describe/it/expect harness (job E1).

	Deliberately NOT TestEZ. The requirement is that the whole suite be callable
	from a single `execute_luau` string in Edit mode (WORKFLOW §8, layer 1), and
	vendoring a framework for that is more machinery than the thing it runs.

	A spec module returns a function taking (describe, it, expect):

		return function(describe, it, expect)
			describe("Format.Abbreviate", function()
				it("strips trailing zeros", function()
					expect(Format.Abbreviate(1000)).toBe("1K")
				end)
			end)
		end

	Only pure logic belongs here. Anything touching a loaded service is
	invisible from `execute_luau` — its module cache and `_G` are separate, so
	`require(DataService)` returns a fresh copy with empty state. That is layer 2
	(job P4), not this.
]]

local Runner = {}

export type Result = {
	suite: string,
	name: string,
	ok: boolean,
	err: string?,
}

--[[
	Matchers. Each throws on failure with a message naming both sides — a bare
	"assertion failed" costs more time than the test saves.

	`toBeCloseTo` exists because the economy is full of floats: 19/3 is not
	6.333333, and an exact comparison would fail on arithmetic rather than on
	design.
]]
local function makeExpect(actual: any)
	local function fail(message: string): ()
		error(message, 3)
	end

	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {tostring(expected)}, got {tostring(actual)}`)
			end
		end,
		toBeCloseTo = function(expected: number, tolerance: number?)
			local t = tolerance or 1e-6
			if typeof(actual) ~= "number" or math.abs(actual - expected) > t then
				fail(`expected ~{expected} (±{t}), got {tostring(actual)}`)
			end
		end,
		toBeGreaterThanOrEqual = function(expected: number)
			if typeof(actual) ~= "number" or actual < expected then
				fail(`expected >= {expected}, got {tostring(actual)}`)
			end
		end,
		toBeLessThanOrEqual = function(expected: number)
			if typeof(actual) ~= "number" or actual > expected then
				fail(`expected <= {expected}, got {tostring(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected truthy, got {tostring(actual)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected nil, got {tostring(actual)}`)
			end
		end,
	}
end

--[[
	Runs every spec module and returns (passed, failed, report).

	A spec that throws while BUILDING its describe block is recorded as a failure
	rather than aborting the run — one malformed spec should not hide the results
	of the other six.
]]
function Runner.Run(specs: { ModuleScript }): (number, number, string)
	local results: { Result } = {}
	local suite = "(top level)"

	local function it(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { suite = suite, name = name, ok = ok, err = if ok then nil else tostring(err) })
	end

	local function describe(name: string, fn: () -> ())
		local previous = suite
		suite = name
		local ok, err = pcall(fn)
		if not ok then
			table.insert(results, { suite = name, name = "<suite body>", ok = false, err = tostring(err) })
		end
		suite = previous
	end

	for _, module in ipairs(specs) do
		local ok, spec = pcall(require, module)
		if not ok then
			table.insert(results, { suite = module.Name, name = "<require>", ok = false, err = tostring(spec) })
		elseif typeof(spec) ~= "function" then
			table.insert(results, { suite = module.Name, name = "<require>", ok = false, err = "spec did not return a function" })
		else
			suite = module.Name
			local ranOk, err = pcall(spec, describe, it, makeExpect)
			if not ranOk then
				table.insert(results, { suite = module.Name, name = "<spec body>", ok = false, err = tostring(err) })
			end
		end
	end

	local passed, failed = 0, 0
	local lines: { string } = {}
	for _, r in ipairs(results) do
		if r.ok then
			passed += 1
		else
			failed += 1
			table.insert(lines, `  FAIL  {r.suite} > {r.name}\n        {r.err}`)
		end
	end

	table.insert(lines, 1, `{passed} passed, {failed} failed, {passed + failed} total`)
	return passed, failed, table.concat(lines, "\n")
end

return Runner
