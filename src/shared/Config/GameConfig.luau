--!strict
--[[
	GAMECONFIG — global v2 constants.

	Gameplay services read every tunable number from Config. Values retained from
	D-015/D-016 are deliberately unchanged during the store reset.
]]

return {
	-- Combat
	SwingCooldown = 0.6,
	SwingRange = 18,
	SwingRangeTolerance = 1.25,
	HitstopSeconds = 0.04,
	FeedbackRadius = 120,
	HitboxSize = Vector3.new(12, 8, 14),
	HitboxForwardOffset = 7,
	MaxCleaveTargets = 8,

	-- Auto-Swing (D-016)
	AutoSwingTrialSeconds = 600,

	-- Character compatibility until movement is re-specced
	BaseWalkSpeed = 16,
	MaxWalkSpeed = 28,

	-- Economy and persistence
	MaxMultiplier = 1,
	MaxCash = 1e15,
	AutosaveInterval = 60,
	DataStoreName = "Frostline_Player",
	DataStoreScope = "live",
	ProfileVersion = 2,
	MigrationMaxSteps = 16,
	LeaderstatsRefreshSeconds = 1,

	-- Replication
	StateReplicationHz = 10,

	-- Inbound remote limits
	RateLimits = {
		RequestSwing = { budget = 10, perSeconds = 1 },
		RequestPurchase = { budget = 6, perSeconds = 1 },
		RequestSetting = { budget = 4, perSeconds = 1 },
		RequestWorkerAction = { budget = 6, perSeconds = 1 },
		_default = { budget = 5, perSeconds = 1 },
	},

	-- Temporary v1 CreatureService compatibility; A19 moves these to HuntingGround.
	MinSpawnSpacing = 12,
	CreatureWanderRadius = 30,
	CreatureWanderInterval = { min = 4, max = 8 },

	-- Corrected onboarding release targets
	TargetSecondsToFirstKill = 30,
	TargetSecondsToFirstStock = 60,
	TargetSecondsToFirstCheckout = 90,
	TargetSecondsToFirstCollection = 100,
	MaxPlotTravelSpreadFraction = 0.15,

	AnalyticsEnabled = true,
	Debug = true,
}
