--!strict
--[[
	STORE — customer, refrigerator, register, and physical-cash tuning.
]]

local Store = {}

Store.SchedulerHz = 5

Store.Unload = {
	ScanHz = 10,
	FeedbackPieceCap = 6,
}

Store.Customers = {
	ModelName = "customer_basic",
	MaxPerPlot = 4,
	InitialDelaySeconds = 2,
	SpawnIntervalSeconds = { min = 4, max = 6 },
	WalkSpeed = 10,
	ArrivalTolerance = 2,
	SeekRetrySeconds = 1,
	ReservationTimeoutSeconds = 60,
	BasketItems = 1,
	PatienceSeconds = 30,
}

Store.Register = {
	ScanHz = 10,
	QueueCapacityByLevel = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 },
	ProgressResetGraceSeconds = 0.25,
}

Store.Cash = {
	ScanHz = 10,
	PickupRadius = 8,
	VisualPieceCap = 12,
	ValueBuckets = { 1, 5, 10, 25, 100, 500, 1000 },
	MagnetSeconds = 0.45,
	ArrivalStaggerSeconds = 0.03,
	CountTweenSeconds = 0.35,
}

Store.Analytics = {
	BatchSeconds = 10,
	CarryFullIdleSeconds = 30,
	StockAvailableIdleSeconds = 10,
	QueueBlockedSeconds = 10,
}

return Store
