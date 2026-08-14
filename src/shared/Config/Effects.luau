--!strict
--[[
	EFFECTS — the feel layer's numbers. Source: docs/GDD.md §6, ART_BIBLE §2.

	Job B4 owns the behaviour; this owns every constant it uses. GDD §6 calls
	these "non-negotiable, these are the game", which means they are exactly the
	numbers a designer will want to tune without reading Luau — so none of them
	may live in the controller (WORKFLOW §5).

	Nothing here is authoritative. Every value below changes how a hit LOOKS.
	Damage, drops and cash are decided by the server and arrive as facts.
]]

local Palette = require(script.Parent.Palette)

return {
	-- ── Hit ──
	-- GDD §6: "Hit registers with a snap: freeze-frame 40ms, white flash on the
	-- bear, chunk particles, low thud."
	FlashSeconds = 0.06,
	FlashColor = Palette.snow,
	FlashTransparency = 0.35,

	-- Client-side cosmetic only. GameConfig.HitstopSeconds is the shared value
	-- so combat and effects cannot drift apart.
	ChunkCount = { min = 3, max = 5 },
	ChunkSize = 0.35,
	ChunkColor = Palette.blood,
	ChunkSpeed = { min = 14, max = 26 },
	ChunkLifetime = 0.7,

	-- ── Floating damage numbers ──
	-- Pooled, never allocated per hit: at 100 hits/minute across a cleave of 8,
	-- per-hit BillboardGui creation is a guaranteed frame-rate problem.
	NumberRiseStuds = 30,
	NumberSeconds = 0.5,
	NumberColor = Palette.snow,
	NumberSize = 28,
	NumberStroke = 2,
	-- Ceiling on simultaneous numbers. A cleave of 8 plus stragglers fits inside
	-- this; beyond it the oldest is recycled rather than a new one allocated.
	NumberPoolSize = 24,
	ChunkPoolSize = 48,

	-- ── Kill ──
	ToppleSeconds = 0.8,
	ToppleAngleDegrees = 82,
	MeatArcStuds = 6,
	MeatSeconds = 0.55,

	-- ── Sell ──
	-- GDD §6: "Sell is the payoff: whole-pack sell, single big number."
	SellNumberSeconds = 0.8,
	SellNumberColor = Palette.gold,
	SellNumberSize = 64,
	SellPunchScale = 1.35,

	--[[
		reducedEffects (profile setting, replicated) keeps the layer that carries
		INFORMATION and drops the layer that is only spectacle.

		Damage numbers and the sell payout survive: a player who cannot see what
		they earned is playing a worse game, not a cheaper one. Particles,
		hitstop and topple are cut.
	]]
	ReducedKeepsNumbers = true,
}
