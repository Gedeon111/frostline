--!strict
--[[
	STATE — the client's mirror of the replicated profile slice.

	The server sends partial diffs on StateChanged (A2). This merges them and
	lets anything on the client observe a single key:

		State.Observe("cash", function(cash)
			label.Text = Format.Abbreviate(cash)
		end)

	Observe fires IMMEDIATELY with the current value, then on every change. That
	matters: a UI element that only subscribed to future changes renders blank
	until the next update, which for something like `rebirths` could be never.

	READ-ONLY. Nothing here writes to the server. The client displays what it is
	told and sends intent through Net — it never computes authoritative values.
	If a number needs to be right, it comes from the server (ARCHITECTURE §3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local Net = require(script.Parent.Net)

local State = {}

type Observer = (value: any) -> ()

local values: { [string]: any } = {}
local observers: { [string]: { Observer } } = {}

--[[
	True once the first payload has arrived.

	The first StateChanged is a full push sent on profile load, before the
	character spawns. UI built before that would render zeros and then snap to
	real numbers, which reads as a bug.
]]
State.Ready = false
State.ReadyChanged = Signal.new()

function State.Get(key: string): any
	return values[key]
end

-- Convenience for the common numeric reads, so callers don't sprinkle
-- `or 0` at every use site.
function State.GetNumber(key: string): number
	local v = values[key]
	return type(v) == "number" and v or 0
end

--[[
	Subscribes to one key. Returns a disconnect function.

	Observing a key that has not arrived yet is fine and deliberate — the
	callback simply isn't called until the first value shows up. Controllers
	load in arbitrary order, so requiring "subscribe only after it exists"
	would be a race nobody can reason about.
]]
function State.Observe(key: string, fn: Observer): () -> ()
	local list = observers[key]
	if not list then
		list = {}
		observers[key] = list
	end
	table.insert(list, fn)

	if values[key] ~= nil then
		local ok, err = pcall(fn, values[key])
		if not ok then
			Log.error("State", "observer for '%s' errored: %s", key, tostring(err))
		end
	end

	return function()
		local current = observers[key]
		if not current then
			return
		end
		local i = table.find(current, fn)
		if i then
			table.remove(current, i)
		end
	end
end

-- Observes several keys with one callback, invoked once per change on any of
-- them. For UI that reads a few values at once — a pack bar needs both weight
-- and capacity, and rebuilding it twice per update is wasted work.
function State.ObserveMany(keys: { string }, fn: () -> ()): () -> ()
	local disconnects = {}
	for _, key in ipairs(keys) do
		table.insert(disconnects, State.Observe(key, function()
			fn()
		end))
	end
	return function()
		for _, d in ipairs(disconnects) do
			d()
		end
	end
end

local function apply(payload: { [string]: any })
	if type(payload) ~= "table" then
		Log.warn("State", "ignored a non-table payload")
		return
	end

	for key, value in pairs(payload) do
		values[key] = value

		local list = observers[key]
		if list then
			-- Iterate a copy: an observer may unsubscribe itself, and mutating
			-- the list mid-walk would silently skip the next one.
			for _, fn in ipairs(table.clone(list)) do
				local ok, err = pcall(fn, value)
				if not ok then
					Log.error("State", "observer for '%s' errored: %s", key, tostring(err))
				end
			end
		end
	end

	if not State.Ready then
		State.Ready = true
		State.ReadyChanged:Fire()
	end
end

-- For debugging and for the B1 verification.
function State.Snapshot(): { [string]: any }
	return table.clone(values)
end

function State.Init()
	-- Connect during Init, not Start: the server pushes the full state as soon
	-- as the profile loads, which can land before controllers finish starting.
	-- A listener attached late misses it and the UI stays empty until the next
	-- change.
	Net.On("StateChanged", apply)
end

function State.Start() end

return State
