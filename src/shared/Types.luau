--!strict
--[[
	TYPES — the shared vocabulary. V2 (D-017). FROZEN AFTER F5.

	Import these, never redefine them locally. If two modules describe the same
	shape with two definitions they will drift, and the drift surfaces as a
	runtime bug rather than a type error.

		local Types = require(ReplicatedStorage.Shared.Types)
		local function stock(player: Player, meat: Types.MeatCounts) ... end

	Changing anything here requires an RFC in docs/DECISIONS.md.

	WHAT CHANGED FROM V1, and why it matters when reading old code:
	the game is no longer hunt→sell-pad. It is hunt→carry→refrigerator→customer
	→register→counter cash→collection (GDD §2). `pack` became `carry`, the
	`harpoon`/`boots` tracks became `axe`/`carrier`/`fridge`/`register`, and
	there is no sell remote at all — store revenue only ever becomes spendable
	through proximity collection (ECONOMY §1).
]]

-- ─── Identifiers ────────────────────────────────────────────────────────────

--[[
	Meat is identified by string id, not by creature tier.

	ECONOMY §2 is explicit that a rare variant must map to a DISTINCT meatId
	rather than just dropping more of the ordinary item — otherwise a golden
	kill inflates count while producing ordinary-value inventory, and the
	variant is cosmetic in the one place it should not be.
]]
export type MeatId = string

export type UpgradeTrack = "axe" | "carrier" | "fridge" | "register"

export type WorkerId = "stocker" | "cashier" | "hunter"

-- `unlock` buys the worker; `upgrade` raises its level; `enable`/`disable`
-- toggle it without refund. Every one is server-validated against plot
-- ownership and cost (ARCHITECTURE §3).
export type WorkerAction = "unlock" | "upgrade" | "enable" | "disable"

-- ─── Content definitions ────────────────────────────────────────────────────

export type MeatDef = {
	id: MeatId,
	displayName: string,
	weight: number,         -- against carrier and fridge capacity
	value: number,          -- cash per unit at checkout, before multipliers
	modelName: string,      -- ReplicatedStorage.Assets.Meat.<modelName>
	tint: Color3,
}

export type CreatureTier = {
	id: string,
	displayName: string,
	hp: number,
	dropCount: number,      -- meat items per kill
	meatId: MeatId,         -- which meat this creature yields
	respawnSeconds: number,
	modelName: string,
	shoulderHeight: number,
	tint: Color3,
}

--[[
	A variant overrides the meat id, so a golden kill yields genuinely different
	inventory rather than a recoloured model over ordinary stock.
]]
export type CreatureVariant = {
	id: string,
	chance: number,         -- 0..1
	meatId: MeatId,
	tint: Color3,
	emissive: boolean,
}

--[[
	Upgrade levels carry a table per level rather than a bare number, because
	the four tracks measure different things: the axe has damage, the register
	has both a duration and a queue size. A parallel `values`/`costs` pair
	could not express that without a second convention per track.
]]
export type UpgradeLevel = {
	cost: number,           -- cash to REACH this level. Level 1 costs 0.
	damage: number?,        -- axe
	capacity: number?,      -- carrier, fridge
	checkoutSeconds: number?, -- register
	queueCapacity: number?, -- register
	modelName: string?,     -- visible model swap at this level, if any
}

export type UpgradeDef = {
	id: UpgradeTrack,
	displayName: string,
	unit: string,           -- shown in UI: "dmg", "weight", "sec"
	maxLevel: number,
	levels: { UpgradeLevel }, -- #levels == maxLevel; levels[1].cost is always 0
}

export type WorkerLevel = {
	cost: number,
	ratePerMinute: number,  -- units moved / sales processed / meat produced
}

export type WorkerDef = {
	id: WorkerId,
	displayName: string,
	description: string,
	unlockCost: number,
	maxLevel: number,
	levels: { WorkerLevel },
}

export type ProductKind = "gamepass" | "product"

export type ProductDef = {
	id: string,
	displayName: string,
	kind: ProductKind,
	assetId: number,        -- 0 until P5 creates it on the dashboard
	robux: number,
	effect: string,
	amount: number?,
	description: string,
}

-- ─── Session state ──────────────────────────────────────────────────────────

--[[
	Customer lifecycle. Session-only and server-owned; the client sees customers
	as models moving in the datamodel, never as a state machine over a remote
	(ARCHITECTURE §3).

	`reserving` exists as its own state because reservation happens BEFORE the
	walk to the fridge (ECONOMY §5). A customer that reserved but has not yet
	collected still holds stock, and cancelling it must return that stock
	exactly once (ECONOMY §10 rule 4).
]]
export type CustomerState =
	"spawning"
	| "reserving"
	| "walking_to_stock"
	| "collecting"
	| "queueing"
	| "checking_out"
	| "leaving"
	| "cancelled"

export type CustomerBasket = { [MeatId]: number }

-- ─── Feedback kinds ─────────────────────────────────────────────────────────

export type NotifyKind = "cash" | "error" | "info" | "full"

-- Cosmetic only. Every one of these follows an authoritative change that has
-- already happened server-side.
export type CarryFeedbackKind =
	"meat_gained"      -- kill → carrier
	| "carry_full"
	| "unload_started" -- carrier → fridge
	| "unload_finished"

export type StoreFeedbackKind =
	"stock_added"
	| "stock_reserved"
	| "stock_taken"
	| "checkout_started"
	| "checkout_finished"
	| "cash_spawned"   -- pile appeared on the counter
	| "cash_collected"
	| "fridge_full"

-- ─── Player state ───────────────────────────────────────────────────────────

export type MeatCounts = { [MeatId]: number }

export type UpgradeLevels = {
	axe: number,
	carrier: number,
	fridge: number,
	register: number,
}

export type WorkerRecord = {
	unlocked: boolean,
	level: number,
	enabled: boolean,
}

export type WorkerRecords = {
	stocker: WorkerRecord,
	cashier: WorkerRecord,
	hunter: WorkerRecord,
}

export type StoreData = {
	fridge: MeatCounts,
	unclaimedCash: number,
}

--[[
	What the client is allowed to know (ARCHITECTURE §4). Anything absent here
	stays server-side.

	`plotId` is session-only and never persisted — a player keeps their store
	contents and upgrades, not a permanent plot number (GDD §4).

	`unclaimedCash` IS replicated: the counter pile has to render, and hiding
	the number the player can plainly see on the counter buys nothing.
]]
export type PlayerState = {
	cash: number,
	carry: MeatCounts,
	carryWeight: number,
	carryCapacity: number,
	fridge: MeatCounts,
	fridgeWeight: number,
	fridgeCapacity: number,
	unclaimedCash: number,
	upgrades: UpgradeLevels,
	workers: WorkerRecords,
	plotId: string?,
	autoSwing: boolean,
	autoSwingTrialEndsAt: number,
	autoSwingEnabled: boolean,
	reducedEffects: boolean,
}

-- ─── Results ────────────────────────────────────────────────────────────────

--[[
	Typed refusal reasons. The client maps these to copy and must never invent
	its own, or two surfaces explain the same failure differently.

	V1's sell-pad and zone reasons are gone: there is no sell action and no zone
	gate in the corrected slice.
]]
export type RefusalReason =
	"insufficient_funds"
	| "max_level"
	| "unknown_track"
	| "unknown_worker"
	| "unknown_action"
	| "worker_locked"
	| "already_owned"
	| "carry_full"
	| "carry_empty"
	| "fridge_full"
	| "no_plot"
	| "invalid"
	| "rate_limited"
	| "not_loaded"

export type PurchaseResult = {
	ok: boolean,
	reason: RefusalReason?,
}

return {}
