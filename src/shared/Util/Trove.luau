--!strict
--[[
	TROVE — a cleanup container.

	Every service and controller owns one. Anything you create that outlives a
	single function goes in it, and Clean() disposes of the lot in reverse order.

		local trove = Trove.new()
		trove:Add(someInstance)
		trove:Connect(part.Touched, onTouch)
		trove:Add(function() customTeardown() end)
		trove:Clean()

	Reverse order matters: things added later usually depend on things added
	earlier, so tearing down forwards can leave a listener firing against a
	half-destroyed object.

	Handles Instances, RBXScriptConnections, functions, threads, and any table
	with Destroy or Disconnect. WORKFLOW §5 requires everything you create to be
	cleaned up — this is how.
]]

export type Trove = {
	Add: <T>(self: Trove, object: T) -> T,
	Connect: (self: Trove, signal: any, fn: (...any) -> ()) -> any,
	Remove: (self: Trove, object: any) -> boolean,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return (setmetatable({ _objects = {} }, Trove) :: any) :: Trove
end

local function dispose(object: any)
	local t = typeof(object)

	if t == "Instance" then
		object:Destroy()
	elseif t == "RBXScriptConnection" then
		object:Disconnect()
	elseif t == "function" then
		object()
	elseif t == "thread" then
		-- cancel() on an already-dead coroutine throws; a dead thread is
		-- already "cleaned", so swallow it rather than failing the whole Clean.
		pcall(task.cancel, object)
	elseif t == "table" then
		if typeof(object.Destroy) == "function" then
			object:Destroy()
		elseif typeof(object.Disconnect) == "function" then
			object:Disconnect()
		end
	end
end

-- Returns what you passed, so it composes:  local p = trove:Add(Instance.new("Part"))
function Trove:Add<T>(object: T): T
	table.insert(self._objects, object)
	return object
end

function Trove:Connect(signal: any, fn: (...any) -> ()): any
	return self:Add(signal:Connect(fn))
end

-- Dispose one object early and drop it from the trove.
function Trove:Remove(object: any): boolean
	local index = table.find(self._objects, object)
	if not index then
		return false
	end
	table.remove(self._objects, index)
	dispose(object)
	return true
end

function Trove:Clean()
	-- Snapshot and clear first: a disposer may add to the trove (a teardown that
	-- schedules more teardown), which would otherwise mutate the list mid-walk.
	local objects = self._objects
	self._objects = {}
	for i = #objects, 1, -1 do
		local ok, err = pcall(dispose, objects[i])
		if not ok then
			warn(`[Trove] failed to dispose {typeof(objects[i])}: {err}`)
		end
	end
end

function Trove:Destroy()
	self:Clean()
end

return Trove
