--!strict
--[[
	REMOTES — canonical v2 definition table (D-017).

	Net creates every declared object. The client sends intent, never outcomes,
	quantities, trusted positions, damage, stock, checkout value, or cash.
]]

local Remotes = {}

Remotes.FolderName = "Remotes"

Remotes.ToClient = {
	-- (partial: Types.PlayerState)
	StateChanged = "RemoteEvent",

	-- (kind: Types.NotifyKind, text: string, amount: number?)
	Notify = "RemoteEvent",

	-- (creature: Model, damage: number, killed: boolean)
	CombatFeedback = "RemoteEvent",

	-- (creature: Model, tierId: string, variant: string?)
	CreatureSpawned = "RemoteEvent",
	CreatureDied = "RemoteEvent",

	-- (kind: Types.CarryFeedbackKind, amount: number, source: Instance?, target: Instance?)
	CarryFeedback = "RemoteEvent",

	-- (kind: Types.StoreFeedbackKind, amount: number, source: Instance?, target: Instance?)
	StoreFeedback = "RemoteEvent",
}

Remotes.ToServer = {
	-- (creature: Model)
	-- Server validates cadence, character, registered/alive target, hitbox, and range.
	RequestSwing = "RemoteEvent",
}

Remotes.Functions = {
	-- (track: Types.ActiveUpgradeTrack) -> (ok, Types.RefusalReason?)
	RequestPurchase = "RemoteFunction",

	-- (key: string, value: boolean) -> (ok, Types.RefusalReason?)
	RequestSetting = "RemoteFunction",

	-- (workerId: Types.WorkerId, action: Types.WorkerAction)
	--   -> (ok, Types.RefusalReason?)
	RequestWorkerAction = "RemoteFunction",
}

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
