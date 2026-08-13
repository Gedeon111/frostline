--!strict
--[[
	TYPES — the shared vocabulary. FROZEN (docs/ARCHITECTURE.md).

	Import these, never redefine them locally. If two modules describe the same
	shape with two definitions, they will drift, and the drift shows up as a
	runtime bug rather than a type error.

		local Types = require(ReplicatedStorage.Shared.Types)
		local function pay(player: Player, pack: Types.PackContents) ... end

	Changing anything here requires an RFC in docs/DECISIONS.md.
]]

-- ─── Content ────────────────────────────────────────────────────────────────

export type BonusType = "cash" | "damage" | "luck"
export type UpgradeTrack = "pack" | "boots" | "harpoon"

export type CreatureTier = {
	id: string,
	displayName: string,
	hp: number,
	dropCount: number,      -- meat items per kill
	meatWeight: number,     -- weight per item, against pack capacity
	meatValue: number,      -- cash per item, before multipliers
	respawnSeconds: number,
	modelName: string,      -- ReplicatedStorage.Assets.Creatures.<modelName>
	shoulderHeight: number, -- studs, for placeholder generation + scale checks
	tint: Color3,
}

export type CreatureVariant = {
	id: string,
	chance: number,         -- 0..1
	valueMultiplier: number,
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

export type ZoneDef = {
	id: string,
	displayName: string,
	order: number,          -- 1..5, unlock sequence. Cannot be skipped.
	unlockCost: number,
	creatureTier: string,
	population: number,
	-- Instance NAMES under Workspace.World.<id>. The contract between whoever
	-- builds the zone and the code that reads it (ARCHITECTURE §7). Renaming one
	-- in Studio silently breaks a service, so it needs an RFC like any contract.
	spawnRegion: string,
	sellPads: { string },
	barrier: string,
	lighting: ZoneLighting,
}

export type UpgradeDef = {
	id: UpgradeTrack,
	displayName: string,
	unit: string,           -- shown in UI: "weight", "studs/s", "dmg"
	maxLevel: number,
	values: { number },      -- [level] -> effect value. #values == maxLevel
	costs: { number },       -- [n] -> cost to reach level n+1. #costs == maxLevel-1
}

export type ToolDef = {
	id: string,
	displayName: string,
	minLevel: number,       -- harpoon upgrade level this model appears at
	modelName: string,
}

export type ProductKind = "gamepass" | "product"

export type ProductDef = {
	id: string,
	displayName: string,
	kind: ProductKind,
	assetId: number,        -- 0 until P5 creates it on the dashboard
	robux: number,
	effect: string,         -- machine-readable key MonetizationService switches on
	amount: number?,
	description: string,
}

-- ─── Player state ───────────────────────────────────────────────────────────

export type PackContents = { [string]: number }  -- tierId -> count

export type UpgradeLevels = {
	pack: number,
	boots: number,
	harpoon: number,
}

export type MultiplierBreakdown = {
	companions: number,
	gamepass: number,
	rebirth: number,
	boost: number,
	event: number,
	season: number,
	total: number,          -- the product, clamped to GameConfig.MaxMultiplier
}

-- What the client is allowed to know. Anything absent here stays server-side.
export type PlayerState = {
	cash: number,
	pack: PackContents,
	packWeight: number,
	packCapacity: number,
	upgrades: UpgradeLevels,
	unlockedZones: { [string]: boolean },
	rebirths: number,
	multiplierBreakdown: MultiplierBreakdown,
}

-- ─── Results ────────────────────────────────────────────────────────────────

-- Typed refusal reasons. The client maps these to copy; it must never invent
-- its own, or two surfaces end up explaining the same failure differently.
export type RefusalReason =
	"insufficient_funds"
	| "max_level"
	| "unknown_track"
	| "unknown_zone"
	| "zone_locked"
	| "out_of_order"
	| "already_owned"
	| "pack_full"
	| "pack_empty"
	| "not_at_sell_pad"
	| "rate_limited"
	| "not_loaded"

export type PurchaseResult = {
	ok: boolean,
	reason: RefusalReason?,
}

return {}
