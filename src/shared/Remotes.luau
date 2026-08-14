--!strict
--[[
	REMOTES — the definition table. V2 (D-017). FROZEN AFTER F5.

	These are DEFINITIONS, not instances. Net creates the real objects under
	ReplicatedStorage.Remotes at server boot, and the client waits for them.
	Nothing else may create a remote.

	THE ONE RULE
	The client sends INTENT, never OUTCOME. It never sends damage, meat counts,
	sale value, cash value, capacity, worker production, or a trusted position.

	Rate limiting is applied centrally by Net from GameConfig.RateLimits. No
	service writes its own rate check.

	WHAT V2 REMOVED, and why it must not quietly come back:

	`RequestSell` is gone with no replacement. In V1 the client could ask to
	convert its pack into cash. The corrected game has no such action at all —
	revenue exists only as `store.unclaimedCash` produced by a customer
	checkout, and only proximity collection turns it into spendable cash
	(ECONOMY §1). The F5 packet is explicit: do not leave a hidden compatibility
	route that awards cash.

	`RequestUnlockZone`, `RequestTeleport`, `RequestHatch`, `RequestEquip`,
	`RequestFuse`, `RequestClaim` and `RequestOffer` went with the five-zone and
	companion designs. They return with those features or not at all — a
	declared-but-unhandled remote is an open door with nobody watching it.

	THE THREE INTERACTIONS WITH NO REMOTE AT ALL (ARCHITECTURE §3): unloading
	the carrier, operating the register, and collecting counter cash. The server
	detects the player's authoritative character position inside configured
	world regions. The client cannot announce that it unloaded, completed a
	sale, or collected money — so there is nothing to forge.
]]

local Remotes = {}

Remotes.FolderName = "Remotes"

-- ── Server → Client ─────────────────────────────────────────────────────────
Remotes.ToClient = {
	-- (partial: PlayerState) — a diff, not the whole state. Client merges.
	StateChanged = "RemoteEvent",

	-- (kind: Types.NotifyKind, text: string, amount: number?)
	Notify = "RemoteEvent",

	-- (creature: Model, damage: number, killed: boolean)
	-- VFX/SFX trigger ONLY. Never authoritative. Sent to players within
	-- GameConfig.FeedbackRadius, not the whole server.
	CombatFeedback = "RemoteEvent",

	-- (creature: Model, tierId: string, variant: string?)
	CreatureSpawned = "RemoteEvent",
	CreatureDied = "RemoteEvent",

	-- (kind: Types.CarryFeedbackKind, amount: number, source: Instance?, target: Instance?)
	-- Meat flying into the carrier, and the stream from carrier to fridge. The
	-- transfer already happened server-side; this only says how to draw it.
	CarryFeedback = "RemoteEvent",

	-- (kind: Types.StoreFeedbackKind, amount: number, source: Instance?, target: Instance?)
	-- Stock, checkout, cash spawn and collection. Same rule — the ledger moved
	-- first, this is the animation.
	StoreFeedback = "RemoteEvent",
}

-- ── Client → Server ─────────────────────────────────────────────────────────
-- Every one is rate-limited AND revalidated server-side. The comment on each
-- says what the server must check — that list is the job spec for its handler.
Remotes.ToServer = {
	-- (creature: Model)
	-- cadence per SERVER clock; target registered and alive; character exists;
	-- creature inside the SERVER-built hitbox; range. Cleave targets are chosen
	-- by the server — the client never submits a victim list (D-015).
	RequestSwing = "RemoteEvent",
}

-- Functions return (ok: boolean, reason: Types.RefusalReason?) so the client can
-- show the right copy without inventing its own. Never predict the result
-- client-side — the button reflects server truth or nothing.
Remotes.Functions = {
	-- (track: Types.UpgradeTrack) -> (ok, reason?)
	-- profile loaded; track exists; next level exists; cash >= configured cost;
	-- Spend succeeds.
	RequestPurchase = "RemoteFunction",

	-- (key: string, value: boolean) -> (ok, reason?)                  [D-016]
	-- key is on the server's settable allow-list; value is a boolean.
	-- Settings are PREFERENCES, never entitlements: writing autoSwing = true
	-- records what the player wants and grants nothing.
	RequestSetting = "RemoteFunction",

	-- (workerId: Types.WorkerId, action: Types.WorkerAction) -> (ok, reason?)
	-- player holds a plot this session; worker exists; the transition is legal
	-- (no upgrading a locked worker, no unlocking twice); cash >= configured
	-- unlock/upgrade cost. Enable and disable are free.
	RequestWorkerAction = "RemoteFunction",
}

-- Flat name -> class, for Net to iterate at boot.
function Remotes.All(): { [string]: string }
	local out: { [string]: string } = {}
	for name, class in pairs(Remotes.ToClient) do
		out[name] = class
	end
	for name, class in pairs(Remotes.ToServer) do
		out[name] = class
	end
	for name, class in pairs(Remotes.Functions) do
		out[name] = class
	end
	return out
end

function Remotes.IsInbound(name: string): boolean
	return Remotes.ToServer[name] ~= nil or Remotes.Functions[name] ~= nil
end

return Remotes
