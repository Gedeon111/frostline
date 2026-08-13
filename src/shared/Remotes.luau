--!strict
--[[
	REMOTES — the definition table. FROZEN (docs/ARCHITECTURE.md §3).

	These are DEFINITIONS, not instances. Net (job F4) creates the real objects
	under ReplicatedStorage.Remotes at server boot, and the client waits for them.
	Nothing else may create a remote.

	THE ONE RULE
	The client sends INTENT, never OUTCOME. It never sends damage, cash, item
	counts, positions, or "I killed it". Any remote that would let the client
	assert a number is a bug — job A12 will find it, and it will be right.

	Rate limiting is applied centrally by Net from GameConfig.RateLimits. No
	service writes its own rate check.
]]

local Remotes = {}

Remotes.FolderName = "Remotes"

-- ── Server → Client ─────────────────────────────────────────────────────────
Remotes.ToClient = {
	-- (partial: PlayerState) — a diff, not the whole state. Client merges.
	StateChanged = "RemoteEvent",

	-- (kind: "cash"|"unlock"|"error"|"full", text: string, amount: number?)
	Notify = "RemoteEvent",

	-- (creature: Model, damage: number, killed: boolean)
	-- VFX/SFX trigger ONLY. Never authoritative. Sent to players within
	-- GameConfig.FeedbackRadius, not the whole server.
	CombatFeedback = "RemoteEvent",

	-- (creature: Model, tierId: string, variant: string?)
	CreatureSpawned = "RemoteEvent",
	CreatureDied = "RemoteEvent",
}

-- ── Client → Server ─────────────────────────────────────────────────────────
-- Every one is rate-limited AND revalidated server-side. The comment on each
-- says what the server must check — that list is the job spec for its handler.
Remotes.ToServer = {
	-- (creature: Model)
	-- creature alive and registered; distance <= SwingRange * SwingRangeTolerance;
	-- cooldown elapsed per SERVER timestamp; player in that creature's zone.
	RequestSwing = "RemoteEvent",

	-- ()
	-- player inside a sell region; pack non-empty. Clear before award, guarded,
	-- so a double-fire in one frame cannot double-pay.
	RequestSell = "RemoteEvent",

	-- (zoneId: string)
	-- zone unlocked by this player.
	RequestTeleport = "RemoteEvent",

	-- (offerId: string)
	-- offer active for this player, not expired, not already purchased.
	-- Windows come from server os.time — never a client clock.
	RequestOffer = "RemoteEvent",
}

-- Functions return (ok: boolean, reason: Types.RefusalReason?) so the client can
-- show the right copy without inventing its own. Never predict the result
-- client-side — the button reflects server truth or nothing.
Remotes.Functions = {
	-- (track: string, ) -> (ok, reason?)
	-- track exists; level+1 <= maxLevel; cash >= cost; Spend succeeds.
	RequestPurchase = "RemoteFunction",

	-- (zoneId: string) -> (ok, reason?)
	-- zone exists; previous zone unlocked (order cannot be skipped); cash >= cost.
	-- Atomic: cash never leaves without the zone arriving.
	RequestUnlockZone = "RemoteFunction",

	-- (eggId: string, count: number) -> (ok, companions?, reason?)   [G4]
	-- egg inside its availability window; cash >= cost * count; count <= bundle
	-- limit. The roll is server-side and must not be predictable from anything
	-- the client holds.
	RequestHatch = "RemoteFunction",

	-- (companionId: string, slot: number) -> (ok, reason?)           [G3]
	-- owned; slot < limit (3 base, 6 with the gamepass).
	RequestEquip = "RemoteFunction",

	-- (companionId: string, tier: string) -> (ok, reason?)           [G3]
	-- at least 5 duplicates at that tier. Atomic — a failure mid-fuse must not
	-- consume duplicates without granting the result.
	RequestFuse = "RemoteFunction",

	-- (kind: "daily"|"quest"|"season"|"index", id: string) -> (ok, reward?, reason?)
	-- earned; unclaimed; window valid per SERVER os.time.
	RequestClaim = "RemoteFunction",
}

-- Flat name -> class, for Net to iterate at boot.
function Remotes.All(): { [string]: string }
	local out: { [string]: string } = {}
	for name, class in pairs(Remotes.ToClient) do out[name] = class end
	for name, class in pairs(Remotes.ToServer) do out[name] = class end
	for name, class in pairs(Remotes.Functions) do out[name] = class end
	return out
end

function Remotes.IsInbound(name: string): boolean
	return Remotes.ToServer[name] ~= nil or Remotes.Functions[name] ~= nil
end

return Remotes
