--!strict
--[[
	UTIL SPECS — Format and TableUtil (job E1).

	Both are pure, both are used everywhere, and both have edge cases that are
	invisible until they are wrong in front of a player: a cash counter reading
	"1000K" instead of "1M", or a profile reconcile that shares a table between
	two players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)

return function(describe, it, expect)
	describe("Format.Abbreviate", function()
		it("leaves values under 1000 whole", function()
			expect(Format.Abbreviate(0)).toBe("0")
			expect(Format.Abbreviate(999)).toBe("999")
		end)

		it("strips trailing zeros", function()
			expect(Format.Abbreviate(1000)).toBe("1K")
			expect(Format.Abbreviate(1500)).toBe("1.5K")
		end)

		it("keeps two decimals at most", function()
			expect(Format.Abbreviate(1234567)).toBe("1.23M")
		end)

		it("re-signs negatives by magnitude", function()
			expect(Format.Abbreviate(-1500)).toBe("-1.5K")
		end)

		--[[
			The boundary Format.luau documents: 999999 scales to 999.999, which
			passes a naive "< 1000" check, but rounds to "1000.00" and would
			render "1000K" instead of "1M".
		]]
		it("rolls 999999 up to 1M rather than rendering 1000K", function()
			expect(Format.Abbreviate(999999)).toBe("1M")
		end)

		it("survives NaN", function()
			expect(Format.Abbreviate(0 / 0)).toBe("0")
		end)
	end)

	describe("Format.Comma", function()
		it("groups thousands", function()
			expect(Format.Comma(1234567)).toBe("1,234,567")
		end)
		it("leaves short numbers alone", function()
			expect(Format.Comma(999)).toBe("999")
		end)
	end)

	describe("Format.Time", function()
		it("shows two units at most", function()
			expect(Format.Time(45)).toBe("45s")
			expect(Format.Time(1425)).toBe("23m 45s")
			expect(Format.Time(5025)).toBe("1h 23m")
		end)
		it("clamps negatives to zero", function()
			expect(Format.Time(-10)).toBe("0s")
		end)
	end)

	describe("Format.Fraction", function()
		it("renders the pack bar without a label word", function()
			expect(Format.Fraction(84, 128)).toBe("84 / 128")
		end)
	end)

	describe("Format.Multiplier", function()
		it("drops a trailing .0", function()
			expect(Format.Multiplier(2)).toBe("x2")
			expect(Format.Multiplier(8.4)).toBe("x8.4")
		end)
	end)

	describe("TableUtil.DeepCopy", function()
		it("copies nested tables rather than sharing them", function()
			local source = { a = { b = { c = 1 } } }
			local copy = TableUtil.DeepCopy(source)
			copy.a.b.c = 2
			expect(source.a.b.c).toBe(1)
		end)
	end)

	describe("TableUtil.Reconcile", function()
		--[[
			This is what backfills new profile fields for existing players
			(D-012, D-016). If it shared a table with the template, two players
			would mutate the same `settings` — a class of bug that only shows up
			under load and looks like data corruption.
		]]
		it("fills missing keys from the template", function()
			local result = TableUtil.Reconcile({ a = 1 }, { a = 0, b = 2 })
			expect(result.a).toBe(1)
			expect(result.b).toBe(2)
		end)

		it("does not share nested tables with the template", function()
			local template = { settings = { music = true } }
			local one = TableUtil.Reconcile({}, template)
			local two = TableUtil.Reconcile({}, template)
			one.settings.music = false
			expect(two.settings.music).toBe(true)
			expect(template.settings.music).toBe(true)
		end)

		it("handles a nil source", function()
			local result = TableUtil.Reconcile(nil, { a = 1 })
			expect(result.a).toBe(1)
		end)
	end)

	describe("TableUtil.Diff", function()
		it("reports only changed keys", function()
			local diff = TableUtil.Diff({ a = 1, b = 2 }, { a = 1, b = 3 })
			expect(diff.b).toBe(3)
			expect(diff.a).toBeNil()
		end)
	end)

	describe("TableUtil.Count / IsEmpty", function()
		it("counts non-array keys", function()
			expect(TableUtil.Count({ a = 1, b = 2 })).toBe(2)
		end)
		it("recognises an empty table", function()
			expect(TableUtil.IsEmpty({})).toBe(true)
			expect(TableUtil.IsEmpty({ a = 1 })).toBe(false)
		end)
	end)
end
