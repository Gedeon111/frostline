--!strict
--[[
	PALETTE — the nine colours of FROSTLINE. Source: docs/ART_BIBLE.md §2.

	THE ONLY PLACE A WORLD COLOUR IS DEFINED. A `Color3.fromRGB` or `fromHex`
	anywhere outside this file is the same defect as a literal 0.6 in a service:
	it is a design value hiding where the designer cannot find it.

	D-014 traded away the restrained *geometry* and kept the restrained *colour*,
	which makes this table load-bearing in a way it was not before. A studded
	blocky game in these nine colours is a distinct object; the same game in
	saturated primaries is one of ten thousand. **Adding a colour here needs an
	RFC** (WORKFLOW §3) — that is not ceremony, it is the differentiator.

	`Theme.luau` (C1) is deliberately separate and NOT governed by this file: it
	holds the Figma-derived UI kit, whose colours are baked into uploaded artwork
	and cannot be retinted from here. D-014 flags the divergence as a C1 handoff.
]]

local Palette = {
	snow = Color3.fromHex("F2F6F8"),       -- ground, primary surfaces
	snowShadow = Color3.fromHex("C9D6DE"), -- ambient shadow, secondary surfaces
	ice = Color3.fromHex("7FB2C9"),        -- ice walls, glass, water
	iceDeep = Color3.fromHex("2E5C73"),    -- crevasses, depth
	night = Color3.fromHex("101820"),      -- Black Ice ground, UI background
	bone = Color3.fromHex("E8E2D4"),       -- bear fur base, trader parka trim
	blood = Color3.fromHex("C4392E"),      -- meat, damage flash, pack-full, accent
	gold = Color3.fromHex("F2B035"),       -- cash, golden variant, affordable
	aurora = Color3.fromHex("4FE0A8"),     -- Aurora Basin accent, unlock success
}

return Palette
