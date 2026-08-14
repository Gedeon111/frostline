--!strict
--[[
	TYPES — FROSTLINE's shared vocabulary.

	D-017 makes the store contract canonical. Legacy upgrade/profile names remain
	typed only as a temporary boot bridge for services explicitly scheduled for
	A15/A16/A19/A20/A21. New code uses ActiveUpgradeTrack and the v2 state fields.
]]

-- ─── Content ────────────────────────────────────────────────────────────────

export type MeatId = string
export type MeatContents = { [MeatId]: number }
export type PackContents = MeatContents -- temporary v1 source compatibility

export type ActiveUpgradeTrack = "axe" | "carrier" | "fridge" | "register"
export type LegacyUpgradeTrack = "pack" | "boots" | "harpoon"
export type UpgradeTrack = ActiveUpgradeTrack | LegacyUpgradeTrack

export type WorkerId = "stocker" | "cashier" | "hunter"
export type WorkerAction = "unlock" | "upgrade" | "enable" | "disable" | "toggle"
export type CustomerState =
	"enter"
	| "seek_stock"
	| "reserve"
	| "take"
	| "queue"
	| "checkout"
	| "leave"
	| "cancelled"

export type NotifyKind = "cash" | "success" | "error" | "full" | "guidance"
export type CarryFeedbackKind = "pickup" | "unload"
export type StoreFeedbackKind = "stock_taken" | "checkout" | "cash_spawned" | "cash_collected"

export type MeatDef = {
	id: MeatId,
	displayName: string,
	creatureTier: string,
	variant: string?,
	weight: number,
	unitValue: number,
	modelName: string,
	tint: Color3,
}

export type CreatureTier = {
	id: string,
	displayName: string,
	hp: number,
	dropCount: number,
	meatId: MeatId,
	-- Temporary v1 fields. A19 moves all weight/value lookup to Config.Meat.
	meatWeight: number,
	meatValue: number,
	respawnSeconds: number,
	modelName: string,
	shoulderHeight: number,
	tint: Color3,
}

export type CreatureVariant = {
	id: string,
	chance: number,
	valueMultiplier: number,
	meatSuffix: string,
	tint: Color3,
	emissive: boolean,
}

export type ZoneLighting = {
	ClockTime: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	FogEnd: number,
	FogColor: Color3,
}

-- Legacy-only until A19 retires Config.Zones.
export type ZoneDef = {
	id: string,
	displayName: string,
	order: number,
	unlockCost: number,
	creatureTier: string,
	population: number,
	spawnRegion: string,
	sellPads: { string },
	barrier: string,
	lighting: ZoneLighting,
}

export type UpgradeDef = {
	id: string,
	displayName: string,
	unit: string,
	maxLevel: number,
	values: { number },
	costs: { number },
}

export type ToolDef = {
	id: string,
	displayName: string,
	minLevel: number,
	modelName: string,
}

export type ProductKind = "gamepass" | "product"

export type ProductDef = {
	id: string,
	displayName: string,
	kind: ProductKind,
	assetId: number,
	robux: number,
	effect: string,
	amount: number?,
	description: string,
}

export type WorkerLevelDef = {
	cycleSeconds: number,
	unitsPerCycle: number,
	upgradeCost: number?,
}

export type WorkerDef = {
	id: WorkerId,
	displayName: string,
	unlockCost: number,
	levels: { WorkerLevelDef },
}

-- ─── Player state ───────────────────────────────────────────────────────────

export type UpgradeLevels = {
	axe: number,
	carrier: number,
	fridge: number,
	register: number,
	-- Temporary v1 fields removed after A15/A16/A20/A21.
	pack: number?,
	boots: number?,
	harpoon: number?,
}

export type WorkerProgress = {
	unlocked: boolean,
	level: number,
	enabled: boolean,
}

export type WorkerStates = {
	stocker: WorkerProgress,
	cashier: WorkerProgress,
	hunter: WorkerProgress,
}

export type MultiplierBreakdown = {
	gamepass: number,
	rebirth: number,
	total: number,
}

export type PlayerState = {
	cash: number,
	carry: MeatContents,
	carryWeight: number,
	carryCapacity: number,
	fridge: MeatContents,
	fridgeWeight: number,
	fridgeCapacity: number,
	unclaimedCash: number,
	upgrades: UpgradeLevels,
	workers: WorkerStates,
	plotId: string?,
	rebirths: number,
	autoSwing: boolean,
	autoSwingTrialEndsAt: number,
	autoSwingEnabled: boolean,
	reducedEffects: boolean,
	multiplierBreakdown: MultiplierBreakdown,

	-- Temporary v1 replication fields. A15 removes them.
	pack: PackContents?,
	packWeight: number?,
	packCapacity: number?,
	unlockedZones: { [string]: boolean }?,
}

-- ─── Results ────────────────────────────────────────────────────────────────

export type RefusalReason =
	"insufficient_funds"
	| "max_level"
	| "unknown_track"
	| "unknown_worker"
	| "invalid_action"
	| "invalid"
	| "already_unlocked"
	| "not_unlocked"
	| "not_owner"
	| "capacity_full"
	| "inventory_empty"
	| "no_stock"
	| "queue_empty"
	| "rate_limited"
	| "not_loaded"

export type PurchaseResult = {
	ok: boolean,
	reason: RefusalReason?,
}

return {}
