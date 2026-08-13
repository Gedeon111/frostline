--!strict
--[[
	LOG — the only sanctioned output.

	WORKFLOW §5: no bare print or warn anywhere outside this module. Not style
	policing — a shipped game printing every hit at 100 hits/minute per player
	floods the console for everyone and hides the one message that matters.

		local Log = require(ReplicatedStorage.Shared.Util.Log)
		Log.info("SellService", "paid %d to %s", amount, player.Name)

	info() is silenced unless GameConfig.Debug. warn() and error() always fire —
	a real problem must be visible in production, and P6 turns Debug off before
	release.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Log = {}

local function emit(level: string, scope: string, message: string, ...): string
	local body = if select("#", ...) > 0 then string.format(message, ...) else message
	return `[{level}][{scope}] {body}`
end

-- Routine detail. Dev-only: invisible once Debug is off.
function Log.info(scope: string, message: string, ...)
	if not GameConfig.Debug then
		return
	end
	print(emit("i", scope, message, ...))
end

-- Something unexpected but survivable. Always emitted.
function Log.warn(scope: string, message: string, ...)
	warn(emit("!", scope, message, ...))
end

-- Something broken. Always emitted; does NOT throw.
--
-- Deliberate: most callers are inside a pcall'd service method or a remote
-- handler, where throwing would abort work the player is waiting on. Use
-- assert() when you genuinely want to stop.
function Log.error(scope: string, message: string, ...)
	warn(emit("X", scope, message, ...))
end

--[[
	Fires once per unique key, then never again.

	For conditions that would otherwise repeat every frame — a missing asset
	looked up in a loop, a nil marker part. One line tells you; sixty thousand
	tells you nothing and costs frames.
]]
local seen: { [string]: true } = {}

function Log.once(key: string, scope: string, message: string, ...)
	if seen[key] then
		return
	end
	seen[key] = true
	Log.warn(scope, message, ...)
end

-- Test-only, so a spec asserting on Log.once isn't poisoned by an earlier run.
function Log.resetOnce()
	table.clear(seen)
end

return Log
