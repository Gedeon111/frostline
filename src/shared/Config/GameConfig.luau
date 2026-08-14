--!strict
--[[
	GAMECONFIG — global constants. Source: docs/ECONOMY.md, docs/GDD.md §6.

	No gameplay number may be written anywhere else. A literal 0.6 or 128 in a
	service is an automatic reject (WORKFLOW §5) — not pedantry: tuning happens in
	D1 against this file, and a number hiding in a service is a number D1 cannot
	find.
]]

return {
	-- ── Combat (GDD §6 — these are feel targets, treat as load-bearing) ──
	SwingCooldown = 0.6,        -- seconds between swings, server-enforced
	SwingRange = 18,            -- studs, player to creature
	SwingRangeTolerance = 1.25, -- lag allowance on the server distance check
	HitstopSeconds = 0.04,      -- client-side only, cosmetic
	FeedbackRadius = 120,       -- studs; CombatFeedback goes to nearby players only

	-- ── Hitbox combat (D-015) ──
	-- There is no prompt. A box is carried in front of the character and every
	-- live creature inside it is struck once per SwingCooldown.
	--
	-- The SERVER rebuilds this box from the character's own CFrame and picks the
	-- victims itself. The client nominates one creature purely to say "I am
	-- swinging, and here is roughly what at" — it never supplies the list, so a
	-- crafted client cannot widen its own cleave.
	HitboxSize = Vector3.new(12, 8, 14),  -- studs, W x H x D
	HitboxForwardOffset = 7,              -- studs ahead of HumanoidRootPart
	MaxCleaveTargets = 8,                 -- bound on one swing. See ECONOMY note in D-015.

	-- ── Auto-swing trial (D-016) ──
	-- Free auto-swing for this long after a player's FIRST EVER join, then the
	-- `autoswing` gamepass is required. Wall-clock from `firstJoinAt`, not
	-- playtime — deliberate, see D-016. Default swinging is tap-per-swing.
	AutoSwingTrialSeconds = 600,

	-- ── Movement ──
	BaseWalkSpeed = 16,
	MaxWalkSpeed = 28,          -- hard ceiling; above this the camera feels loose

	-- ── Economy ──
	MaxMultiplier = 250,        -- ECONOMY §5: catches exploits, not customers.
	                            -- A committed payer legitimately reaches ~192x.
	MaxCash = 1e15,             -- sanity clamp; float precision degrades past this

	-- ── Persistence ──
	AutosaveInterval = 60,
	DataStoreName = "Frostline_Player",
	DataStoreScope = "live",    -- P4/tests override to "test" — never share keys
	ProfileVersion = 1,

	-- ── Replication ──
	StateReplicationHz = 10,    -- one batched StateChanged per tick, never per change
	ZoneCheckHz = 5,            -- region polling for zone membership + sell pads

	-- ── Rate limits (per player, per remote) ──
	-- Applied centrally in Net (F4). No service writes its own rate check.
	RateLimits = {
		RequestSwing = { budget = 10, perSeconds = 1 },
		RequestSell = { budget = 4, perSeconds = 1 },
		RequestPurchase = { budget = 6, perSeconds = 1 },
		RequestUnlockZone = { budget = 4, perSeconds = 1 },
		RequestTeleport = { budget = 3, perSeconds = 1 },
		RequestHatch = { budget = 6, perSeconds = 1 },
		RequestEquip = { budget = 10, perSeconds = 1 },
		RequestFuse = { budget = 4, perSeconds = 1 },
		RequestClaim = { budget = 6, perSeconds = 1 },
		RequestOffer = { budget = 3, perSeconds = 1 },
		-- Toggling is a deliberate human action; 4/s is generous for a button and
		-- still stops a loop from writing the profile every frame.
		RequestSetting = { budget = 4, perSeconds = 1 },
		_default = { budget = 5, perSeconds = 1 },
	},

	-- ── Creature spawning ──
	MinSpawnSpacing = 12,       -- studs; clumped creatures read as a bug
	CreatureWanderRadius = 30,
	CreatureWanderInterval = { min = 4, max = 8 },

	-- ── Onboarding (ECONOMY §7 rule 5 — a release blocker, not a nice-to-have) ──
	TargetSecondsToFirstSell = 90,
	SellArrowShowsAtPackFraction = 0.5,

	-- ── Analytics ──
	-- Kill switch. Analytics must never be the reason the game breaks, so it
	-- can be turned off without touching AnalyticsService.
	AnalyticsEnabled = true,

	-- ── Dev ──
	Debug = true,               -- gates Log output. MUST be false at release (P6).
}
